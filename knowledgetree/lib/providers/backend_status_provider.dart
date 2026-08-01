import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:knowledgetree/core/utils/backend_url.dart';

enum BackendStatus { checking, connected, disconnected }

class BackendConnectionNotifier extends Notifier<BackendStatus> {
  Timer? _timer;

  @override
  BackendStatus build() {
    _ping();
    return BackendStatus.checking;
  }

  void _ping() async {
    _timer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    final url = BackendUrl.resolve(prefs.getString('base_url') ?? '');
    if (url.isEmpty) {
      state = BackendStatus.disconnected;
      _timer = Timer(const Duration(seconds: 15), _ping);
      return;
    }
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(Uri.parse('$url/health'));
      final response = await request.close();
      client.close();
      state = response.statusCode == 200
          ? BackendStatus.connected
          : BackendStatus.disconnected;
    } catch (_) {
      state = BackendStatus.disconnected;
    }
    _timer = Timer(const Duration(seconds: 15), _ping);
  }

  void refresh() {
    _ping();
  }
}

final backendStatusProvider =
    NotifierProvider<BackendConnectionNotifier, BackendStatus>(
  BackendConnectionNotifier.new,
);
