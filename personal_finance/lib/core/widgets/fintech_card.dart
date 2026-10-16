import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/app_theme.dart';

/// Reusable fintech card with subtle border, elevation, and optional interactive press feedback
class FintechCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Border? border;
  final double borderRadius;

  const FintechCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.backgroundColor,
    this.gradient,
    this.border,
    this.borderRadius = 18,
  });

  @override
  State<FintechCard> createState() => _FintechCardState();
}

class _FintechCardState extends State<FintechCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) _controller.reverse();
  }

  void _onTapCancel() {
    if (widget.onTap != null) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultBg =
        widget.backgroundColor ??
        (isDark ? AppTheme.cardCharcoal : Colors.white);
    final defaultBorder =
        widget.border ??
        Border.all(
          color: isDark ? AppTheme.borderPrimary : const Color(0xFFE5E7EB),
          width: 1,
        );

    final defaultGradient =
        widget.gradient ?? (isDark ? AppTheme.glassCardGradient : null);

    final content = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: widget.onTap != null ? _scaleAnimation.value : 1.0,
        child: child,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            color: defaultGradient == null ? defaultBg : null,
            gradient: defaultGradient,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: defaultBorder,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.04),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    return content;
  }
}
