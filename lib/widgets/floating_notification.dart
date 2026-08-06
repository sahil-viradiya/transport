import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../app/core/theme/app_colors.dart';
import 'app_text.dart';

/// A lightweight in-app "floating" notification shown in the TOP-RIGHT corner.
///
/// Unlike browser push (which needs a granted permission) or a bottom snackbar,
/// this is a pure in-app overlay that always works while the app is open — so a
/// new trip, an accepted trip, an inspection, an approval request etc. surface
/// instantly in the corner. Multiple cards stack and auto-dismiss.
class FloatingNotify {
  FloatingNotify._();

  static OverlayEntry? _hostEntry;
  static final ValueNotifier<List<FloatItem>> _items = ValueNotifier(const []);
  static int _seq = 0;

  static void show({
    required String title,
    required String body,
    IconData icon = Icons.notifications_rounded,
    Color color = AppColors.primary,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 5),
  }) {
    // Prevent stacking duplicate cards with identical title and body at the same time
    final isDuplicate = _items.value.any(
        (item) => item.title == title && item.body == body);
    if (isDuplicate) return;

    final overlay = _overlay();
    if (overlay == null) return;
    _ensureHost(overlay);
    final id = ++_seq;
    _items.value = [
      ..._items.value,
      FloatItem(id, title, body, icon, color, onTap),
    ];
    Future.delayed(duration, () => dismiss(id));
  }

  static void dismiss(int id) {
    _items.value = _items.value.where((e) => e.id != id).toList();
  }

  /// Resolve the root navigator's overlay (survives route changes). Falls back
  /// to Get.overlayContext or Get.context if key isn't ready yet.
  static OverlayState? _overlay() {
    try {
      final ov = Get.key.currentState?.overlay;
      if (ov != null) return ov;
    } catch (_) {}
    try {
      final ctx = Get.overlayContext ?? Get.context;
      if (ctx != null) return Overlay.maybeOf(ctx);
    } catch (_) {}
    return null;
  }

  static void _ensureHost(OverlayState overlay) {
    if (_hostEntry != null) {
      try {
        if (_hostEntry!.mounted) {
          _hostEntry!.remove();
        }
      } catch (_) {}
      _hostEntry = null;
    }
    _hostEntry = OverlayEntry(
      builder: (_) => _FloatingHost(items: _items, onDismiss: dismiss),
    );
    try {
      overlay.insert(_hostEntry!);
    } catch (_) {
      _hostEntry = null;
    }
  }
}

class FloatItem {
  final int id;
  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const FloatItem(
      this.id, this.title, this.body, this.icon, this.color, this.onTap);
}

class _FloatingHost extends StatelessWidget {
  final ValueNotifier<List<FloatItem>> items;
  final void Function(int) onDismiss;

  const _FloatingHost({required this.items, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width =
        media.size.width - 24 < 360 ? media.size.width - 24 : 360.0;
    return Positioned(
      top: media.padding.top + 12,
      right: 12,
      child: SafeArea(
        child: SizedBox(
          width: width,
          child: ValueListenableBuilder<List<FloatItem>>(
            valueListenable: items,
            builder: (_, list, __) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final it in list)
                    _FloatingCard(
                      key: ValueKey(it.id),
                      item: it,
                      onClose: () => onDismiss(it.id),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FloatingCard extends StatefulWidget {
  final FloatItem item;
  final VoidCallback onClose;

  const _FloatingCard({super.key, required this.item, required this.onClose});

  @override
  State<_FloatingCard> createState() => _FloatingCardState();
}

class _FloatingCardState extends State<_FloatingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260))
      ..forward();
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0.25, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = widget.item;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                widget.onClose();
                item.onTap?.call();
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: item.color.withValues(alpha: 0.35), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: item.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(item.title,
                              style: AppTextStyle.bodyMedium,
                              fontWeight: FontWeight.w700,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          AppText(item.body,
                              style: AppTextStyle.labelMedium,
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.textSecondary,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: widget.onClose,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.close_rounded,
                            size: 18, color: AppColors.textHint),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
