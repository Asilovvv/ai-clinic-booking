import 'dart:async';

import 'package:flutter/material.dart';

import '../../bloc/settings_cubit.dart';
import '../theme.dart';

/// Branded launch screen shown while settings and the session are loading.
/// When that takes more than a few seconds it says why: a free cloud server
/// sleeps when nobody uses it and needs up to a minute to wake up.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: brandGradient),
        child: Column(
          children: [
            const Spacer(flex: 3),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutBack,
              builder: (context, value, child) => Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: Transform.scale(scale: 0.8 + 0.2 * value, child: child),
              ),
              child: const Column(
                children: [
                  BrandLogo(size: 112),
                  SizedBox(height: 20),
                  Text(
                    'Smile AI',
                    style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),
            AnimatedOpacity(
              opacity: _slow ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 48),
                child: Column(
                  children: [
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      context.strings.wakingUp,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, height: 1.35),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded square with the assistant sparkle.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 84});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(Icons.auto_awesome, color: Colors.white, size: size * 0.52),
    );
  }
}
