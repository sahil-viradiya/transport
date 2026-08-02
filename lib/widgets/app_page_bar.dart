import 'package:flutter/material.dart';

import 'app_text.dart';

/// Standard application bar for feature pages.
class AppPageBar extends StatelessWidget implements PreferredSizeWidget {
  const AppPageBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
        leading: leading,
        title: AppText(title,
            style: AppTextStyle.headlineSmall, fontWeight: FontWeight.bold),
        actions: actions,
      );
}
