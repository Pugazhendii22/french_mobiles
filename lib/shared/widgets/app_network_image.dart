import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_shimmer.dart';

/// A cached remote image with themed loading and failure states.
///
/// Product photos arrive from Firestore as URLs that may be empty or dead, so
/// an empty [url] and a load error resolve to the same neutral placeholder
/// rather than a broken-image glyph.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.placeholderIcon = Icons.smartphone_rounded,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadius.card;

    if (url.trim().isEmpty) {
      return _fallback(radius);
    }

    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 220),
        placeholder: (context, _) => AppShimmer(
          width: width ?? double.infinity,
          height: height ?? 0,
          borderRadius: radius,
        ),
        errorWidget: (context, _, __) => _fallback(radius),
      ),
    );
  }

  Widget _fallback(BorderRadius radius) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: Icon(placeholderIcon, size: 28, color: AppColors.textTertiary),
    );
  }
}
