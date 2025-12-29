import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

class ChatFAB extends StatelessWidget {
  final GlobalKey fabKey;
  final VoidCallback onTap;

  const ChatFAB({
    super.key,
    required this.fabKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Showcase(
      key: fabKey,
      description: 'Tap to ask questions on various topics.',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Color(0xFFF5F5F5),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: const Icon(
            Icons.question_mark_rounded,
            color: Colors.black87,
            size: 24,
          ),
        ),
      ),
    );
  }
}







