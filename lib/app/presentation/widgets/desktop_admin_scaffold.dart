import 'package:flutter/material.dart';

/// Shared wide-screen frame for administrative features.
///
/// This component is intentionally presentation-only: navigation state,
/// actions, and data stay owned by the feature that supplies the slots.
class DesktopAdminScaffold extends StatelessWidget {
  const DesktopAdminScaffold({
    super.key,
    required this.sidebar,
    required this.topNavigation,
    required this.child,
  });

  final Widget sidebar;
  final Widget topNavigation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sidebar,
        Expanded(
          child: Column(
            children: [
              topNavigation,
              const Divider(height: 1),
              Expanded(child: child),
            ],
          ),
        ),
      ],
    );
  }
}
