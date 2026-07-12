import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'content_sanitizer.dart';

enum ChatApiErrorType { connection, auth, server, timeout, parse }

class ChatApiError {
  final ChatApiErrorType type;
  final String message;
  ChatApiError(this.type, this.message);
}

class ChatApiService {
  HttpClient? _activeClient;
  bool _cancelled = false;

  /// Stop an in-progress stream. Already received tokens are kept; the
  /// partial response is finalized by the caller.
  void cancel() {
    _cancelled = true;
    _activeClient?.close(force: true);
  }

  Future<String?> streamChat({
    required String baseUrl,
    required String model,
    required List<Map<String, String>> messages,
    required void Function(String) onChunk,
    String? apiKey,
    void Function(ChatApiError)? onError,
  }) async {
    _cancelled = false;
    final chatUrl = _chatUrl(baseUrl);
    final client = HttpClient();
    _activeClient = client;
    client.connectionTimeout = const Duration(seconds: 30);

    try {
      final safeMessages = messages.map((m) {
        return {
          'role': ContentSanitizer.sanitize(m['role'] ?? ''),
          'content': ContentSanitizer.sanitize(m['content'] ?? ''),
        };
      }).toList();

      final requestBody = {
        'model': model,
        'messages': safeMessages,
        'stream': true,
      };

      final body = ContentSanitizer.safeEncodeJson(requestBody);

      final request = await client.postUrl(Uri.parse(chatUrl));
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      if (apiKey != null && apiKey.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $apiKey');
      }
      final bytes = utf8.encode(body);
      request.contentLength = bytes.length;
      request.add(bytes);

      final response = await request.close();
      if (response.statusCode == 401 || response.statusCode == 403) {
        final err = await response.transform(utf8.decoder).join();
        client.close();
        if (!_cancelled) onError?.call(ChatApiError(ChatApiErrorType.auth, 'Auth failed: $err'));
        return null;
      }
      if (response.statusCode != 200) {
        final err = await response.transform(utf8.decoder).join();
        client.close();
        if (!_cancelled) {
          onError?.call(ChatApiError(ChatApiErrorType.server, 'HTTP ${response.statusCode}: $err'));
        }
        return null;
      }

      final decoder = const Utf8Decoder(allowMalformed: true);
      String lineBuffer = '';

      await for (final chunk in response.transform(decoder)) {
        if (_cancelled) break;
        lineBuffer += chunk;
        while (true) {
          final nl = lineBuffer.indexOf('\n');
          if (nl == -1) break;
          final rawLine = lineBuffer.substring(0, nl);
          lineBuffer = lineBuffer.substring(nl + 1);

          final trimmed = rawLine.trim();
          if (trimmed.isEmpty) continue;

          if (trimmed.startsWith('data: ')) {
            final data = trimmed.substring(6).trim();
            if (data == '[DONE]') continue;
            _parseSseData(data, onChunk);
          } else if (trimmed.startsWith('{')) {
            _parseSseData(trimmed, onChunk);
          }
        }
      }

      if (!_cancelled && lineBuffer.trim().isNotEmpty) {
        final trimmed = lineBuffer.trim();
        if (trimmed.startsWith('data: ')) {
          final data = trimmed.substring(6).trim();
          if (data != '[DONE]') _parseSseData(data, onChunk);
        } else if (trimmed.startsWith('{')) {
          _parseSseData(trimmed, onChunk);
        }
      }

      client.close();
      _activeClient = null;
      return null;
    } on SocketException catch (e) {
      client.close();
      _activeClient = null;
      if (!_cancelled) onError?.call(ChatApiError(ChatApiErrorType.connection, e.message));
      return null;
    } on TimeoutException {
      client.close();
      _activeClient = null;
      if (!_cancelled) onError?.call(ChatApiError(ChatApiErrorType.timeout, 'Request timed out'));
      return null;
    } catch (e) {
      client.close();
      _activeClient = null;
      if (!_cancelled) onError?.call(ChatApiError(ChatApiErrorType.parse, 'Error: $e'));
      return null;
    }
  }

  String _chatUrl(String baseUrl) {
    var base = baseUrl;
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    if (base.toLowerCase().endsWith('/v1')) {
      base = base.substring(0, base.length - 3);
    }
    return '$base/v1/chat/completions';
  }

  void _parseSseData(String data, void Function(String) onChunk) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final choices = json['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        final first = choices[0];
        final delta = first['delta'] as Map<String, dynamic>?;
        final content = delta?['content'] as String?;
        if (content != null && content.isNotEmpty) {
          onChunk(ContentSanitizer.sanitize(content));
        }
      }
    } catch (_) {}
  }
}
