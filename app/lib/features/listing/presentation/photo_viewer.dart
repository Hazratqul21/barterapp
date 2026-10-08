import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';

/// Photos full screen: swipe between them, pinch or double-tap to zoom,
/// close to return to the same photo on the listing.
///
/// Someone trading a tractor for a car wants to see the rust before they
/// write; a 300px hero is not enough for that.
Future<int?> showPhotoViewer(
  BuildContext context, {
  required List<String> photos,
  required int initial,
  required String semanticLabel,
}) {
  Haptics.light();
  return Navigator.of(context, rootNavigator: true).push<int>(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => _PhotoViewer(
        photos: photos,
        initial: initial,
        semanticLabel: semanticLabel,
      ),
      transitionsBuilder: (context, animation, _, child) =>
          shouldReduceMotion(context)
          ? child
          : FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({
    required this.photos,
    required this.initial,
    required this.semanticLabel,
  });

  final List<String> photos;
  final int initial;
  final String semanticLabel;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _pages = PageController(
    initialPage: widget.initial,
  );
  late int _index = widget.initial;

  /// While a photo is zoomed, the pager must not steal the pan.
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop(_index);

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            physics: _zoomed
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: widget.photos.length,
            onPageChanged: (i) {
              Haptics.selection();
              setState(() => _index = i);
            },
            itemBuilder: (context, i) => _ZoomablePhoto(
              url: widget.photos[i],
              semanticLabel: widget.semanticLabel,
              onZoomChanged: (zoomed) => setState(() => _zoomed = zoomed),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Gap.x2),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: material.closeButtonTooltip,
                    onPressed: _close,
                    icon: const Icon(Symbols.close_rounded),
                  ),
                  const Spacer(),
                  if (widget.photos.length > 1)
                    PhotoCounter(index: _index, count: widget.photos.length),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({
    required this.url,
    required this.semanticLabel,
    required this.onZoomChanged,
  });

  final String url;
  final String semanticLabel;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  final _transform = TransformationController();
  TapDownDetails? _doubleTap;

  @override
  void initState() {
    super.initState();
    _transform.addListener(() {
      widget.onZoomChanged(_transform.value.getMaxScaleOnAxis() > 1.01);
    });
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  /// Double-tap: zoom 2.5× towards the finger, or back out.
  void _toggleZoom() {
    if (_transform.value.getMaxScaleOnAxis() > 1.01) {
      _transform.value = Matrix4.identity();
      return;
    }
    final at = _doubleTap?.localPosition ?? Offset.zero;
    const scale = 2.5;
    _transform.value = Matrix4.identity()
      ..translateByDouble(-at.dx * (scale - 1), -at.dy * (scale - 1), 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _doubleTap = d,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: RemoteImage(
            url: widget.url,
            semanticLabel: widget.semanticLabel,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

/// "2 / 5" on a dark pill — legible over any photo.
class PhotoCounter extends StatelessWidget {
  const PhotoCounter({super.key, required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const StadiumBorder(),
      ),
      child: Text(
        '${index + 1} / $count',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
