import 'package:flutter/material.dart';

import '../theme.dart';

/// Branded launch screen shown while settings and the session are loading.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: brandGradient),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutBack,
          builder: (context, value, child) => Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Transform.scale(scale: 0.8 + 0.2 * value, child: child),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
