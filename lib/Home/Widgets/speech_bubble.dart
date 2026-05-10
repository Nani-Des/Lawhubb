import 'package:flutter/material.dart';
import 'dart:async';
import 'package:nhap/l10n/app_localizations.dart';

class SpeechBubble extends StatefulWidget {
  final VoidCallback onPressed;
  final TextStyle textStyle;

  SpeechBubble({required this.onPressed, required this.textStyle});

  @override
  _SpeechBubbleState createState() => _SpeechBubbleState();
}

class _SpeechBubbleState extends State<SpeechBubble> {
  bool _isVisible = true;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _startBlinking();
  }

  void _startBlinking() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _isVisible = !_isVisible;
      });
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('👨‍⚕️', style: TextStyle(fontSize: 24)), // Doctor emoji
            SizedBox(width: 10),
            AnimatedOpacity(
              opacity: _isVisible ? 1.0 : 0.0,
              duration: Duration(milliseconds: 500),
              child: Text(
                AppLocalizations.of(context)?.attorneysNearYou ??
                    'Attorneys near you',
                style: widget.textStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
