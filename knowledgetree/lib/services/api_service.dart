import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiService {
  String? _baseUrl;
  String? _apiKey;

  String? get baseUrl => _baseUrl;
  String? get apiKey => _apiKey;

  void configure(String baseUrl, {String? apiKey}) {
    _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    _apiKey = apiKey;
  }

  Future<bool> healthCheck() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse('$_baseUrl/health'));
      if (_apiKey != null && _apiKey!.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $_apiKey');
      }
      final response = await request.close();
      final ok = response.statusCode == 200;
      client.close();
      return ok;
    } catch (e) {
      debugPrint('Health check failed: $e');
      return false;
    }
  }

  Future<String?> chatStream({
    required String model,
    required List<Map<String, String>> messages,
    required void Function(String chunk) onChunk,
    String? urlOverride,
  }) async {
    final base = urlOverride ?? _baseUrl;
    if (base == null) return 'API URL not configured';

    var chatBase = base;
    if (chatBase.endsWith('/')) chatBase = chatBase.substring(0, chatBase.length - 1);
    if (chatBase.toLowerCase().endsWith('/v1')) {
      chatBase = chatBase.substring(0, chatBase.length - 3);
    }

    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$chatBase/v1/chat/completions'));
      request.headers.set('Content-Type', 'application/json');
      if (_apiKey != null && _apiKey!.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $_apiKey');
      }

      final body = jsonEncode({
        'model': model,
        'messages': messages,
        'stream': true,
      });

      final bytes = utf8.encode(body);
      request.contentLength = bytes.length;
      request.add(bytes);

      final response = await request.close();
      if (response.statusCode != 200) {
        final error = await response.transform(utf8.decoder).join();
        client.close();
        return 'Server error ${response.statusCode}: $error';
      }

      final decoder = utf8.decoder;
      String buffer = '';
      await for (final chunk in response.transform(decoder)) {
        buffer += chunk;
        while (true) {
          final idx = buffer.indexOf('\n');
          if (idx == -1) break;
          final line = buffer.substring(0, idx).trim();
          buffer = buffer.substring(idx + 1);

          if (line.isEmpty) continue;
          if (!line.startsWith('data: ')) continue;

          final data = line.substring(6);
          if (data == '[DONE]') break;

          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final choices = json['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final delta = choices[0]['delta'] as Map<String, dynamic>?;
              final content = delta?['content'] as String?;
              if (content != null && content.isNotEmpty) {
                onChunk(content);
              }
            }
          } catch (_) {}
        }
      }
      client.close();
      return null;
    } catch (e) {
      client.close();
      return 'Connection failed: $e';
    }
  }
}
