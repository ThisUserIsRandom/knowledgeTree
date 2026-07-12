import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:knowledgetree/features/connector/domain/ai_profile.dart';
import 'package:knowledgetree/services/backend_config_service.dart';

/// Persists a list of [AiProfile]s and which one is active, and applies the
/// active profile to the flat SharedPreferences keys the rest of the app
/// already reads (provider / base_url / api_key / api_url / model_name).
class ProfileStore {
  static const String _profilesKey = 'kt_profiles';
  static const String _activeKey = 'kt_active_profile_id';

  /// Load all profiles. On first run, seed one "Default" profile from the
  /// legacy flat settings so existing configurations keep working.
  static Future<List<AiProfile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profilesKey);
    if (raw == null || raw.isEmpty) {
      final legacy = AiProfile(
        id: AiProfile.newId(),
        name: 'Default',
        provider: prefs.getString('provider') ?? 'OpenRouter',
        baseUrl: prefs.getString('base_url') ?? '',
        apiUrl: prefs.getString('api_url') ?? '',
        apiKey: prefs.getString('api_key') ?? '',
        modelName: prefs.getString('model_name') ?? '',
      );
      final list = [legacy];
      await saveProfiles(list);
      await saveActiveId(legacy.id);
      return list;
    }
    final decoded = jsonDecode(raw) as List;
    return decoded.map((e) => AiProfile.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<String?> loadActiveId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeKey);
  }

  static Future<void> saveProfiles(List<AiProfile> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _profilesKey,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> saveActiveId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, id);
  }

  /// Write the active profile's fields into the flat prefs the app already
  /// uses, and push them to the backend so server-side routing updates.
  static Future<void> applyActive(AiProfile p, {bool pushToServer = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('provider', p.provider);
    await prefs.setString('base_url', p.baseUrl);
    await prefs.setString('api_key', p.apiKey);
    await prefs.setString('api_url', p.apiUrl);
    await prefs.setString('model_name', p.modelName);

    if (pushToServer && p.baseUrl.trim().isNotEmpty) {
      await BackendConfigService.pushConfigToServer(
        baseUrl: p.baseUrl,
        provider: p.provider,
        apiUrl: p.apiUrl,
        apiKey: p.apiKey,
        model: p.modelName,
      );
    }
  }
}
