import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:knowledgetree/services/content_sanitizer.dart';

class RagStageEvent {
  final String stage;
  final String message;
  final int attempt;
  const RagStageEvent({
    required this.stage,
    required this.message,
    required this.attempt,
  });
}

class RagSearchResult {
  final String? response;
  final int attempts;
  final String mode;
  final List<String> sources;
  final String? error;
  const RagSearchResult({
    this.response,
    this.attempts = 1,
    this.mode = 'web',
    this.sources = const [],
    this.error,
  });
}

class RagApiService {
  HttpClient? _activeClient;
  bool _cancelled = false;

  /// Stop an in-progress RAG pipeline. Closes the SSE connection so the
  /// backend stops crawling/searching; already-streamed stages are kept.
  void cancel() {
    _cancelled = true;
    _activeClient?.close(force: true);
  }

  String _normalize(String url) {
    var base = url.trim();
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    if (!base.startsWith('http://') && !base.startsWith('https://')) {
      base = 'http://$base';
    }
    return base;
  }

  /// Run the RAG pipeline. Stage events (searching / crawling / indexing /
  /// retrieving / generating) are streamed to [onStage]; the final answer is
  /// returned once the SSE stream terminates.
  Future<RagSearchResult> search({
    required String baseUrl,
    required String query,
    String mode = 'web',
    String model = '',
    String? apiKey,
    void Function(RagStageEvent stage)? onStage,
  }) async {
    _cancelled = false;
    final client = HttpClient();
    _activeClient = client;
    client.connectionTimeout = const Duration(seconds: 15);
    RagSearchResult result = const RagSearchResult();

    try {
      final request = await client
          .postUrl(Uri.parse('${_normalize(baseUrl)}/v1/rag/search'));
      request.headers.set('Content-Type', 'application/json');
      if (apiKey != null && apiKey.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $apiKey');
      }
      final body = jsonEncode({
        'query': ContentSanitizer.sanitize(query),
        'mode': mode,
        'model': model,
        'max_loops': 2,
      });
      final bytes = utf8.encode(body);
      request.contentLength = bytes.length;
      request.add(bytes);

      final response = await request.close();
      if (response.statusCode != 200) {
        final err = await response.transform(utf8.decoder).join();
        client.close();
        return RagSearchResult(error: 'HTTP ${response.statusCode}: $err');
      }

      final decoder = const Utf8Decoder(allowMalformed: true);
      String buffer = '';
      await for (final chunk in response.transform(decoder)) {
        if (_cancelled) break;
        buffer += chunk;
        while (true) {
          final nl = buffer.indexOf('\n');
          if (nl == -1) break;
          final rawLine = buffer.substring(0, nl).trim();
          buffer = buffer.substring(nl + 1);
          if (rawLine.isEmpty) continue;
          if (rawLine.startsWith('data: ')) {
            final data = rawLine.substring(6).trim();
            if (data == '[DONE]') continue;
            result = _parseEvent(data, result, onStage);
          }
        }
      }
      if (!_cancelled && buffer.trim().isNotEmpty) {
        final rawLine = buffer.trim();
        if (rawLine.startsWith('data: ')) {
          final data = rawLine.substring(6).trim();
          if (data != '[DONE]') {
            result = _parseEvent(data, result, onStage);
          }
        }
      }
      client.close();
      _activeClient = null;
      if (_cancelled) {
        return RagSearchResult(error: 'Search stopped');
      }
      return result;
    } on SocketException catch (e) {
      client.close();
      _activeClient = null;
      if (_cancelled) return RagSearchResult(error: 'Search stopped');
      return RagSearchResult(error: 'Connection failed: ${e.message}');
    } on TimeoutException {
      client.close();
      _activeClient = null;
      if (_cancelled) return RagSearchResult(error: 'Search stopped');
      return RagSearchResult(error: 'Request timed out');
    } catch (e) {
      client.close();
      _activeClient = null;
      if (_cancelled) return RagSearchResult(error: 'Search stopped');
      return RagSearchResult(error: 'Error: $e');
    }
  }

  RagSearchResult _parseEvent(String data, RagSearchResult current,
      void Function(RagStageEvent stage)? onStage) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final event = json['event'] as String?;
      switch (event) {
        case 'stage':
          onStage?.call(RagStageEvent(
            stage: json['stage'] as String? ?? '',
            message: json['message'] as String? ?? '',
            attempt: (json['attempt'] as num?)?.toInt() ?? 1,
          ));
        case 'retry':
          onStage?.call(RagStageEvent(
            stage: 'retry',
            message: json['message'] as String? ?? 'Retrying...',
            attempt: (json['attempt'] as num?)?.toInt() ?? 1,
          ));
        case 'done':
          return RagSearchResult(
            response: json['response'] as String?,
            attempts: (json['attempts'] as num?)?.toInt() ?? 1,
            mode: json['mode'] as String? ?? 'web',
            sources: (json['sources'] as List?)
                    ?.whereType<String>()
                    .toList() ??
                const [],
          );
        case 'error':
          return RagSearchResult(error: json['message'] as String?);
      }
    } catch (_) {}
    return current;
  }

  /// Upload [files] to the backend knowledge base (multipart/form-data).
  /// Returns the parsed JSON response ({status, uploaded, files, chunks}).
  Future<Map<String, dynamic>> uploadFiles({
    required String baseUrl,
    required List<PlatformFile> files,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    final boundary = '----ktboundary${DateTime.now().microsecondsSinceEpoch}';

    try {
      final request = await client
          .postUrl(Uri.parse('${_normalize(baseUrl)}/v1/rag/upload'));
      request.headers.set('Content-Type', 'multipart/form-data; boundary=$boundary');

      final builder = BytesBuilder();
      for (final f in files) {
        final name = ContentSanitizer.sanitize(f.name);
        builder.add(utf8.encode('--$boundary\r\n'));
        builder.add(utf8
            .encode('Content-Disposition: form-data; name="files"; filename="$name"\r\n'));
        builder.add(utf8.encode('Content-Type: application/octet-stream\r\n\r\n'));
        Uint8List data;
        try {
          data = await f.readAsBytes();
        } catch (_) {
          continue;
        }
        builder.add(data);
        builder.add(utf8.encode('\r\n'));
      }
      builder.add(utf8.encode('--$boundary--\r\n'));

      final body = builder.takeBytes();
      request.contentLength = body.length;
      request.add(body);

      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      client.close();
      if (response.statusCode != 200) {
        return {'error': 'HTTP ${response.statusCode}: $text'};
      }
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      client.close();
      return {'error': 'Upload failed: $e'};
    }
  }

  /// Current knowledge-base status ({uploaded_files, web_files, chunks}).
  Future<Map<String, dynamic>> indexStatus(String baseUrl) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final request =
          await client.getUrl(Uri.parse('${_normalize(baseUrl)}/v1/rag/index'));
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      client.close();
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      client.close();
      return {'error': 'Status failed: $e'};
    }
  }

  /// Delete the backend knowledge base (crawled pages + uploaded files).
  Future<Map<String, dynamic>> clearIndex(String baseUrl) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client
          .deleteUrl(Uri.parse('${_normalize(baseUrl)}/v1/rag/index'));
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      client.close();
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      client.close();
      return {'error': 'Clear failed: $e'};
    }
  }
}
