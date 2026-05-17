import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Renders assistant/user text with markdown (**bold**, lists, headings) when present.
class FormattedMessageBody extends StatelessWidget {
  final String text;
  final Color textColor;
  final double fontSize;
  final bool enableMarkdown;

  const FormattedMessageBody({
    super.key,
    required this.text,
    required this.textColor,
    this.fontSize = 14,
    this.enableMarkdown = true,
  });

  static bool looksLikeMarkdown(String input) {
    final t = input.trim();
    if (t.isEmpty) return false;
    return RegExp(
      r'(\*\*.+\*\*|\*.+\*|^#{1,3}\s|^\s*[-*•]\s|^\s*\d+\.\s)',
      multiLine: true,
    ).hasMatch(t);
  }

  MarkdownStyleSheet _styleSheet() {
    final base = TextStyle(
      color: textColor,
      fontSize: fontSize,
      height: 1.4,
    );
    return MarkdownStyleSheet(
      p: base,
      pPadding: EdgeInsets.zero,
      strong: base.copyWith(fontWeight: FontWeight.w700),
      em: base.copyWith(fontStyle: FontStyle.italic),
      h1: base.copyWith(fontSize: fontSize + 6, fontWeight: FontWeight.bold),
      h2: base.copyWith(fontSize: fontSize + 4, fontWeight: FontWeight.bold),
      h3: base.copyWith(fontSize: fontSize + 2, fontWeight: FontWeight.w600),
      listBullet: base,
      listIndent: 22,
      blockSpacing: 10,
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: textColor.withValues(alpha: 0.2)),
        ),
      ),
      blockquote: base.copyWith(
        color: textColor.withValues(alpha: 0.85),
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: textColor.withValues(alpha: 0.35),
            width: 3,
          ),
        ),
      ),
      code: base.copyWith(
        fontFamily: 'monospace',
        backgroundColor: textColor.withValues(alpha: 0.08),
      ),
      codeblockDecoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    if (!enableMarkdown) {
      return Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          height: 1.35,
        ),
      );
    }

    return MarkdownBody(
      data: trimmed,
      selectable: true,
      shrinkWrap: true,
      fitContent: true,
      styleSheet: _styleSheet(),
    );
  }
}
