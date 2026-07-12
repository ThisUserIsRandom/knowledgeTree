import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Pushes the selected provider configuration to the python-serv backend so
/// it can route requests to the correct upstream (ollama / openrouter / ...).
///
/// This is shared by the connector screen and the profiles screen so both
/// stay in sync with the server.
class BackendConfigService {
  static String _normalize(String url) {
    var u = url.trim();
    if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'http://$u';
    return u.endsWith('/') ? u.substring(0, u.length - 1) : u;
  }

  static String providerToApiType(String provider) {
    final p = provider.trim().toLowerCase();
    if (p == 'ollama') return 'ollama';
    if (p == 'openrouter') return 'openrouter';
    return 'openai_compatible';
  }

  /// Resolve the upstream base url the server should route to. Falls back to a
  /// provider-specific default when the optional API URL field is empty.
  static String? resolveUpstreamBase(String provider, String apiUrl) {
    final raw = apiUrl.trim();
    if (raw.isNotEmpty) return _normalize(raw);
    if (provider == 'OpenRouter') return 'https://openrouter.ai/api/v1';
    if (provider == 'Ollama') return 'http://localhost:11434';
    return null;
  }

  static Future<void> pushConfigToServer({
    required String baseUrl,
    required String provider,
    required String apiUrl,
    required String apiKey,
    required String model,
  }) async {
    final upstreamBase = resolveUpstreamBase(provider, apiUrl);
    if (upstreamBase == null) return;
    final key = apiKey.trim();
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.postUrl(Uri.parse('$baseUrl/v1/config/set'));
      request.headers.set('Content-Type', 'application/json');
      if (key.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $key');
      }
      final body = jsonEncode({
        'provider': provider,
        'api_type': providerToApiType(provider),
        'base_url': upstreamBase,
        'api_key': key,
        'model': model.trim(),
      });
      final bytes = utf8.encode(body);
      request.contentLength = bytes.length;
      request.add(bytes);
      final response = await request.close();
      await response.drain();
      client.close();
    } catch (e) {
      // Non-fatal: backend may not expose live config.
      if (kDebugMode) debugPrint('Push config to server failed: $e');
    }
  }
}
