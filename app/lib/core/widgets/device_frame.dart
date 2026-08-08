import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/girih.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// Below this the browser window simply *is* the phone and nothing is added.
const kFrameBreakpoint = 720.0;

/// The phone the web build lives inside.
const _frameWidth = 420.0;
const _frameMaxHeight = 900.0;

/// Wraps the whole app so a desktop browser shows the same product a phone
/// does, rather than a second design nobody maintains.
///
/// The app used to grow a left-hand drawer past 700px — a different navigation
/// model, different chrome, and a second set of layouts to keep in step with
/// the first. Everything about this marketplace is built for a phone in a
/// field or a workshop; the desktop visit is a person looking at the same
/// thing on a bigger screen, not a different product.
///
/// It sits in `MaterialApp.builder`, above the navigator, so every pushed route
/// — listing, chat, create — is inside the frame too.
class DeviceFrame extends StatelessWidget {
  const DeviceFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // A real phone, or a narrow window: hand back the app untouched.
        if (constraints.maxWidth < kFrameBreakpoint) return child;

        final height = math.min(
          _frameMaxHeight,
          math.max(560.0, constraints.maxHeight - Gap.x10),
        );

        final media = MediaQuery.of(context);

        return ColoredBox(
          color: p.isDark ? const Color(0xFF07100C) : const Color(0xFFEFEAE1),
          child: Stack(
            children: [
              // The same tilework as the app's own wallpaper, so the space
              // around the device belongs to the product rather than being
              // empty grey.
              const Positioned.fill(
                child: GirihField(opacity: 0.05, cell: 96),
              ),
              Center(
                child: Container(
                  width: _frameWidth + 6,
                  height: height + 6,
                  decoration: BoxDecoration(
                    color: p.isDark
                        ? const Color(0xFF1B241F)
                        : const Color(0xFF16241D),
                    borderRadius: BorderRadius.circular(Radii.xl + 12),
                    boxShadow: Shadows.lifted,
                  ),
                  padding: const EdgeInsets.all(3),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.xl + 9),
                    // Everything inside is told it is on a phone: a chat
                    // bubble sizing itself against the window would be as wide
                    // as the desktop, not as wide as the screen it is drawn on.
                    child: MediaQuery(
                      data: media.copyWith(
                        size: Size(_frameWidth, height),
                        padding: EdgeInsets.zero,
                        viewPadding: EdgeInsets.zero,
                        viewInsets: EdgeInsets.zero,
                      ),
                      child: SizedBox(
                        width: _frameWidth,
                        height: height,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
