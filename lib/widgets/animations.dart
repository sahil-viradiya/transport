import 'package:flutter/material.dart';

/// A card wrapper that gently "lifts" (translates up + soft shadow) on mouse
/// hover and shows a click cursor — a web-native feel. On touch devices there's
/// no hover, so it's effectively a no-op there.
class HoverLift extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double lift;

  const HoverLift({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.lift = 4,
  });

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -widget.lift : 0, 0),
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ]
              : const [],
        ),
        child: widget.child,
      ),
    );
  }
}

/// Fades + slides its child in on first build. Give each instance a stable
/// [key] (e.g. ValueKey of the item id) so it animates only when it first
/// appears — not on every parent rebuild (typing, filtering, etc.).
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double offset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 320),
    this.delay = Duration.zero,
    this.offset = 0.06,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ac, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: Offset(0, widget.offset),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _ac.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ac.forward();
      });
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
