import 'package:flutter/material.dart';

import 'app_back_button.dart';

/// Shared light-green gradient header used across the app flow.
///
/// Renders the top bar (back + title + optional trailing action) over a single,
/// continuous [Color(0xFFEAFBE8)] → white gradient. Because the gradient is a
/// fixed part of this widget (not the Scaffold app bar), the background cannot
/// shift when content scrolls beneath — every page using this widget shows an
/// identical, non-changing header.
class AppGradientHeader extends StatelessWidget {
  const AppGradientHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.content,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Widget? content;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFEAFBE8),
            Color(0xFFEAFBE8),
            Colors.white,
          ],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppBackButton.light(onPressed: onBack),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            content ?? const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}