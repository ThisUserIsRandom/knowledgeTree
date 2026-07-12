import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:knowledgetree/core/theme/app_theme.dart';
import 'package:knowledgetree/features/connector/presentation/screens/connector_screen.dart';
import 'package:knowledgetree/features/main_menu/presentation/screens/main_menu_screen.dart';

class KnowledgeTreeApp extends StatelessWidget {
  const KnowledgeTreeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Knowledge Tree AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      home: const _AppRouter(),
    );
  }
}

class _AppRouter extends StatefulWidget {
  const _AppRouter();

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter>
    with SingleTickerProviderStateMixin {
  bool _showConnector = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
    _checkConfig();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final hasConfig = prefs.getString('model_name') != null;
    setState(() => _showConnector = !hasConfig);
  }

  void _onConnected() {
    _animController.forward().then((_) {
      setState(() => _showConnector = false);
      _animController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            if (!_showConnector)
              Opacity(
                  opacity: 1.0 - _fadeAnimation.value,
                  child: const MainMenuScreen()),
            if (_showConnector)
              Opacity(
                  opacity: _fadeAnimation.value,
                  child: ConnectorScreen(onConnected: _onConnected)),
          ],
        );
      },
    );
  }
}
