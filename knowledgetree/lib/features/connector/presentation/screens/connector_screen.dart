import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:knowledgetree/core/theme/colors.dart';
import 'package:knowledgetree/core/utils/backend_url.dart';
import 'package:knowledgetree/services/backend_config_service.dart';
import 'package:knowledgetree/features/connector/presentation/screens/profiles_screen.dart';
import 'package:knowledgetree/features/connector/data/profile_provider.dart';
import 'package:knowledgetree/features/connector/domain/ai_profile.dart';

class ConnectorScreen extends ConsumerStatefulWidget {
  final VoidCallback? onConnected;
  const ConnectorScreen({super.key, this.onConnected});

  @override
  ConsumerState<ConnectorScreen> createState() => _ConnectorScreenState();
}

class _ConnectorScreenState extends ConsumerState<ConnectorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _apiUrlController = TextEditingController();
  final _modelController = TextEditingController();
  String _provider = 'OpenRouter';
  bool _isConnecting = false;

  final _providers = ['OpenRouter', 'Ollama', 'Custom'];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _apiUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _provider = prefs.getString('provider') ?? 'Ollama';
      _baseUrlController.text = prefs.getString('base_url') ?? '';
      _apiKeyController.text = prefs.getString('api_key') ?? '';
      _apiUrlController.text = prefs.getString('api_url') ?? '';
      _modelController.text = prefs.getString('model_name') ?? '';
    });
  }

  /// Mirror the active profile's fields into the form whenever the active
  /// profile changes elsewhere (e.g. switched in ProfilesScreen).
  void _syncFromProfile(AiProfile? p) {
    if (p == null) return;
    setState(() {
      _provider = p.provider;
      _baseUrlController.text = p.baseUrl;
      _apiKeyController.text = p.apiKey;
      _apiUrlController.text = p.apiUrl;
      _modelController.text = p.modelName;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('provider', _provider);
    await prefs.setString('base_url', _baseUrlController.text.trim());
    await prefs.setString('api_key', _apiKeyController.text.trim());
    await prefs.setString('api_url', _apiUrlController.text.trim());
    await prefs.setString('model_name', _modelController.text.trim());
  }

  String? get _effectiveBaseUrl {
    final raw = _baseUrlController.text.trim();
    if (raw.isEmpty) return null;
    return BackendUrl.resolve(raw);
  }

  /// Push the selected provider + credentials to the backend so it can route
  /// requests to the chosen upstream provider. Delegates the HTTP work to the
  /// shared [BackendConfigService].
  Future<void> _pushConfigToServer(String baseUrl) async {
    await BackendConfigService.pushConfigToServer(
      baseUrl: baseUrl,
      provider: _provider,
      apiUrl: _apiUrlController.text,
      apiKey: _apiKeyController.text.trim(),
      model: _modelController.text.trim(),
    );
  }

  Future<void> _saveOnly() async {
    try {
      await _save();
      final url = _effectiveBaseUrl;
      if (url != null) await _pushConfigToServer(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Settings saved'),
              ],
            ),
            backgroundColor: AppColors.snackbarBg,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: AppColors.urgent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _connect() async {
    final url = _effectiveBaseUrl;
    if (url == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Enter a Base URL or API URL'),
            backgroundColor: AppColors.urgent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isConnecting = true);

    final healthUrl = Uri.parse('$url/health');
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(healthUrl);
      if (_apiKeyController.text.trim().isNotEmpty) {
        request.headers.set('Authorization', 'Bearer ${_apiKeyController.text.trim()}');
      }
      final response = await request.close();
      final ok = response.statusCode == 200;
      client.close();

      if (mounted) {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Connected ✓' : 'Error: GET $healthUrl → ${response.statusCode}'),
            backgroundColor: ok ? AppColors.success : AppColors.urgent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }

      if (ok) {
        await _save();
        await _pushConfigToServer(url);
        widget.onConnected?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: GET $healthUrl → ${e.toString().replaceAll(RegExp(r'^[^:]+:\s*'), '')}'),
            backgroundColor: AppColors.urgent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final active = profileState.active;

    // Keep the form in sync when the active profile (or its contents) changes
    // from elsewhere, e.g. switched or edited in ProfilesScreen.
    ref.listen(profileProvider, (prev, next) {
      final prevJson = prev?.active?.toJson().toString();
      final nextJson = next.active?.toJson().toString();
      if (prev?.activeId != next.activeId || prevJson != nextJson) {
        _syncFromProfile(next.active);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: AppColors.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text('Settings',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(Icons.account_tree, color: AppColors.textOnPrimary, size: 40),
                ),
                const SizedBox(height: 20),
                Text('Knowledge Tree AI',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3)),
                const SizedBox(height: 8),
                Text('Configure your AI provider',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 14.5)),
                const SizedBox(height: 28),
                if (active != null) _activeBanner(active),
                const SizedBox(height: 20),
                _buildProviderDropdown(),
                const SizedBox(height: 16),
                _buildBaseUrlField(),
                const SizedBox(height: 16),
                _buildApiKeyField(),
                const SizedBox(height: 16),
                _buildApiUrlField(),
                const SizedBox(height: 16),
                _buildModelField(),
                const SizedBox(height: 28),
                _buildConnectButton(),
                const SizedBox(height: 14),
                _buildSaveButton(),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfilesScreen()),
                    );
                  },
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Manage Profiles'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                if (Theme.of(context).platform == TargetPlatform.android) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'On Android emulator, use 10.0.2.2 instead of 127.0.0.1 to reach your host machine.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _activeBanner(AiProfile active) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Active: ${active.name}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 3),
                Text(
                  active.modelName.isNotEmpty
                      ? '${active.provider} · ${active.modelName}'
                      : active.provider,
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _provider,
      items: _providers.map((p) => DropdownMenuItem(
        value: p,
        child: Text(p, style: TextStyle(color: AppColors.textPrimary)),
      )).toList(),
      onChanged: (v) => setState(() => _provider = v!),
      decoration: _inputDecoration('Provider'),
      dropdownColor: AppColors.surfaceCard,
      style: TextStyle(color: AppColors.textPrimary),
      icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
    );
  }

  Widget _buildBaseUrlField() {
    return TextFormField(
      controller: _baseUrlController,
      decoration: _inputDecoration('Base URL (e.g. http://10.0.2.2:8000)'),
      style: TextStyle(color: AppColors.textPrimary),
      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
    );
  }

  Widget _buildApiKeyField() {
    return TextFormField(
      controller: _apiKeyController,
      decoration: _inputDecoration('API Key'),
      obscureText: true,
      style: TextStyle(color: AppColors.textPrimary),
    );
  }

  Widget _buildApiUrlField() {
    return TextFormField(
      controller: _apiUrlController,
      decoration: _inputDecoration('API URL (optional, overrides base)'),
      style: TextStyle(color: AppColors.textPrimary),
    );
  }

  Widget _buildModelField() {
    return TextFormField(
      controller: _modelController,
      decoration: _inputDecoration('Model Name (e.g. openai/gpt-oss-20b:free)'),
      style: TextStyle(color: AppColors.textPrimary),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textTertiary),
      filled: true,
      fillColor: AppColors.surfaceCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.urgent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.urgent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildConnectButton() {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: _isConnecting ? null : _connect,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
        ),
        child: _isConnecting
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.textOnPrimary,
                ),
              )
            : const Text('Connect & Save',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, letterSpacing: 0.2)),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: _isConnecting ? null : _saveOnly,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text('Save Only', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
