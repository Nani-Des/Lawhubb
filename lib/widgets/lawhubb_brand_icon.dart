import 'package:flutter/material.dart';

/// App logo from [assets/Icons/Icon1.jpeg] for app bars, hero, and branding.
class LawHubbBrandIcon extends StatelessWidget {
  final double size;
  final double borderRadius;
  final BoxDecoration? decoration;

  const LawHubbBrandIcon({
    super.key,
    this.size = 36,
    this.borderRadius = 10,
    this.decoration,
  });

  static const String assetPath = 'assets/Icons/Icon1.jpeg';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: decoration ??
          BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.grey[800]!),
          ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          Icons.balance,
          color: Colors.white,
          size: size * 0.55,
        ),
      ),
    );
  }
}
