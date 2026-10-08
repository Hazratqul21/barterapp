import 'package:flutter/material.dart';

/// The application uses the real viewport on web, tablets and phones.
/// Individual pages constrain reading width; the root never simulates a phone.
class DeviceFrame extends StatelessWidget {
  const DeviceFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}
