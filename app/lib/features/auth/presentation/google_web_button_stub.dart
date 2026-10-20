import 'package:flutter/widgets.dart';

/// Native builds draw their own button; Google's rendered one is web-only.
Widget googleWebButton({required String locale}) => const SizedBox.shrink();
