import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/providers/profile_notifier.dart';
import '../auth/login.dart';
import '../auth/providers/auth_provider.dart';
import '../home/main_nav_wrapper.dart';

class Splash extends StatefulWidget {
  const Splash({super.key});

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final AnimationController _pulseCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textSlide;
  late final Animation<double> _textFade;
  late final Animation<double> _badgeSlide;
  late final Animation<double> _badgeFade;
  late final Animation<double> _loaderFade;

  @override
  void initState() {
    super.initState();

    // ── Entrance Animation Controller (1200ms) ──────────────────────────────
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
    );

    _logoFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.40, curve: Curves.easeIn),
    );

    _textSlide = Tween<double>(begin: 24.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _textFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.35, 0.70, curve: Curves.easeIn),
    );

    _badgeSlide = Tween<double>(begin: 18.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.50, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _badgeFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.50, 0.80, curve: Curves.easeIn),
    );

    _loaderFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.65, 0.95, curve: Curves.easeIn),
    );

    // ── Looping Ambient / Heartbeat Controller (2200ms) ─────────────────────
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _entranceCtrl.forward();

    // ── Navigation Sequence ────────────────────────────────────────────────
    Future.delayed(const Duration(milliseconds: 2000), () {
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
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  /// Calculates a natural cardiac "lub-dub" heartbeat scale multiplier.
  double _getHeartbeatScale(double t) {
    if (t < 0.12) {
      final p = t / 0.12;
      return 1.0 + (0.07 * math.sin(p * math.pi));
    }
    if (t < 0.18) return 1.0;
    if (t < 0.30) {
      final p = (t - 0.18) / 0.12;
      return 1.0 + (0.04 * math.sin(p * math.pi));
    }
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Ambient Healthcare Background ────────────────────────────────
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFEBF8FA),
                  Color(0xFFF7FCFD),
                  Colors.white,
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // ── Subtle Floating Decorative Elements ──────────────────────────
          CustomPaint(
            size: Size(size.width, size.height),
            painter: _BackgroundPatternPainter(),
          ),

          // ── Center Content ───────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Animated Logo with Pulse Rings ─────────────────────
                    _buildAnimatedHeroLogo(),
                    const SizedBox(height: 32),

                    // ── Staggered Title & Tagline ──────────────────────────
                    _buildAnimatedText(),
                    const SizedBox(height: 16),

                    // ── Express Badge ──────────────────────────────────────
                    _buildExpressBadge(),
                    const SizedBox(height: 52),

                    // ── Modern Animated Loader ─────────────────────────────
                    _buildAnimatedLoader(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the hero emblem with expanding radar pulse waves and heartbeat rhythm.
  Widget _buildAnimatedHeroLogo() {
    return AnimatedBuilder(
      animation: Listenable.merge([_entranceCtrl, _pulseCtrl]),
      builder: (context, child) {
        final entranceScale = _logoScale.value;
        final entranceFade = _logoFade.value;
        final t = _pulseCtrl.value;
        final heartbeatScale = _getHeartbeatScale(t);

        // Radar wave 1 (starts at t=0.0 -> t=0.65)
        double wave1Scale = 1.0;
        double wave1Opacity = 0.0;
        if (t <= 0.65) {
          final progress = t / 0.65;
          wave1Scale = 1.0 + (progress * 0.65);
          wave1Opacity = (1.0 - progress) * 0.40 * entranceFade;
        }

        // Radar wave 2 (starts at t=0.15 -> t=0.80)
        double wave2Scale = 1.0;
        double wave2Opacity = 0.0;
        if (t >= 0.15 && t <= 0.80) {
          final progress = (t - 0.15) / 0.65;
          wave2Scale = 1.0 + (progress * 0.85);
          wave2Opacity = (1.0 - progress) * 0.25 * entranceFade;
        }

        return Opacity(
          opacity: entranceFade,
          child: Transform.scale(
            scale: entranceScale * heartbeatScale,
            child: SizedBox(
              width: 170,
              height: 170,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer radar ripple 2
                  if (wave2Opacity > 0)
                    Transform.scale(
                      scale: wave2Scale,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: wave2Opacity),
                            width: 2.0,
                          ),
                        ),
                      ),
                    ),

                  // Outer radar ripple 1
                  if (wave1Opacity > 0)
                    Transform.scale(
                      scale: wave1Scale,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF0EA5E9).withValues(alpha: wave1Opacity),
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),

                  // Main Glowing Logo Container
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF00B4D8), // Vibrant Aqua
                          Color(0xFF087F8C), // Brand Teal
                          Color(0xFF055A63), // Deep Medical Teal
                        ],
                      ),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.38),
                          blurRadius: 36,
                          spreadRadius: 2,
                          offset: const Offset(0, 14),
                        ),
                        BoxShadow(
                          color: const Color(0xFF00B4D8).withValues(alpha: 0.25),
                          blurRadius: 18,
                          spreadRadius: -2,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Soft inner glow highlight
                        Positioned(
                          top: 8,
                          left: 12,
                          child: Container(
                            width: 38,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),

                        // Center Icon
                        const Icon(
                          Icons.local_pharmacy_rounded,
                          color: Colors.white,
                          size: 54,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the app title and tagline with staggered entrance.
  Widget _buildAnimatedText() {
    return AnimatedBuilder(
      animation: _entranceCtrl,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _textSlide.value),
          child: Opacity(
            opacity: _textFade.value,
            child: Column(
              children: const [
                Text(
                  'PharmaCustomer',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: AppTheme.text,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your medicines, delivered fast.',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.mutedText,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds a modern pill badge highlighting express speed & trust.
  Widget _buildExpressBadge() {
    return AnimatedBuilder(
      animation: _entranceCtrl,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _badgeSlide.value),
          child: Opacity(
            opacity: _badgeFade.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.18),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Express Delivery in 15-30 Mins',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds a modern glowing horizontal progress bar with gentle status text.
  Widget _buildAnimatedLoader() {
    return FadeTransition(
      opacity: _loaderFade,
      child: Column(
        children: [
          // Sleek pill-shaped progress track
          Container(
            width: 140,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (context, child) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 1.0,
                    child: Transform.translate(
                      offset: Offset((_pulseCtrl.value * 2.0 - 1.0) * 140, 0),
                      child: Container(
                        width: 70,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              const Color(0xFF0EA5E9),
                              AppTheme.primary,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              // Gentle breath opacity for the status text
              final opacity = 0.65 + (0.35 * math.sin(_pulseCtrl.value * math.pi));
              return Opacity(
                opacity: opacity,
                child: const Text(
                  'Preparing your healthcare store...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.mutedText,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Custom painter for ambient medical crosses and soft floating circular particles.
class _BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    // Top-right subtle cross
    _drawCross(canvas, Offset(size.width * 0.85, size.height * 0.14), 16, paint);

    // Top-left soft cross
    _drawCross(canvas, Offset(size.width * 0.15, size.height * 0.22), 12, paint);

    // Center-right soft dot
    canvas.drawCircle(Offset(size.width * 0.90, size.height * 0.42), 6, paint);

    // Center-left soft dot
    canvas.drawCircle(Offset(size.width * 0.10, size.height * 0.52), 8, paint);

    // Bottom-left subtle cross
    _drawCross(canvas, Offset(size.width * 0.18, size.height * 0.78), 14, paint);

    // Bottom-right soft dot
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.72), 5, paint);
  }

  void _drawCross(Canvas canvas, Offset center, double armLength, Paint paint) {
    final strokeWidth = armLength * 0.35;
    // Horizontal bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: armLength * 2, height: strokeWidth),
        Radius.circular(strokeWidth / 2),
      ),
      paint,
    );
    // Vertical bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: strokeWidth, height: armLength * 2),
        Radius.circular(strokeWidth / 2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
