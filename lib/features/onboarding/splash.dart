import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/profile_notifier.dart';
import '../auth/login.dart';
import '../auth/providers/auth_provider.dart';
import '../home/main_nav_wrapper.dart';

class Splash extends StatefulWidget {
  const Splash({super.key});

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      bool isAuth = false;
      String name = 'User';
      String phone = '';
      String email = '';
      try {
        final auth = context.read<AuthProvider>();
        isAuth = auth.isAuthenticated;
        final profile = context.read<ProfileNotifier>();
        name = profile.name.isNotEmpty ? profile.name : 'User';
        phone = profile.phoneNumber;
        email = profile.email;
      } catch (_) {}

      final destination = isAuth
          ? MainNavWrapper(
              name: name,
              phoneNumber: phone,
              email: email,
            )
          : const Login();

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, _) => destination,
          transitionsBuilder: (_, a, _, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.35),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_pharmacy_outlined,
                    color: Colors.white,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  AppStrings.appName,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your medicines, delivered fast.',
                  style: TextStyle(color: AppTheme.mutedText, fontSize: 14),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.primary,
                    ),
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
