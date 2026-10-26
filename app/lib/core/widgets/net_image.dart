import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A remote picture, decoded at [cacheWidth] physical pixels.
///
/// Native: `CachedNetworkImage`, which keeps the file on disk between launches.
///
/// Web: Flutter's own `Image.network`. The browser already caches the file,
/// and `cached_network_image` on the web hands the image cache bitmaps that
/// the browser has since closed: leave a tab and come back, and every photo
/// that was on screen redraws as "no image" (WebGL: `texImage2D: no image`).
/// That was the flicker on mab.uz.
Widget netImage({
  required String url,
  required Widget placeholder,
  required Widget error,
  BoxFit fit = BoxFit.cover,
  int? cacheWidth,
  String? semanticLabel,
}) {
  final Widget image;
  if (kIsWeb) {
    image = Image.network(
      url,
      fit: fit,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      frameBuilder: (context, child, frame, sync) {
        if (sync || frame != null) return child;
        return placeholder;
      },
      errorBuilder: (_, _, _) => error,
    );
  } else {
    image = CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      memCacheWidth: cacheWidth,
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => error,
    );
  }
  if (semanticLabel == null) return image;
  return Semantics(label: semanticLabel, image: true, child: image);
}
