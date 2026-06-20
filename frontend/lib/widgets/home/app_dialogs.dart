import 'package:flutter/material.dart';

// ─── Base animated wrapper ───────────────────────────────────────────────────
/// Wraps any Dialog in a scale-from-0.82 + fade-in entrance animation.
class AppAnimatedDialog extends StatefulWidget {
  const AppAnimatedDialog({super.key, required this.child});
  final Widget child;

  @override
  State<AppAnimatedDialog> createState() => _AppAnimatedDialogState();
}

class _AppAnimatedDialogState extends State<AppAnimatedDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 380));
  late final Animation<double> _scale = Tween(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  late final Animation<double> _fade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.0, 0.55, curve: Curves.easeOut)));

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: ScaleTransition(scale: _scale, child: widget.child),
      );
}

// ─── Confirm dialog ──────────────────────────────────────────────────────────
/// Animated confirmation dialog with gradient header + icon + two buttons.
/// Pops [true] on confirm, [false] on cancel.
class AppConfirmDialog extends StatefulWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.confirmLabel,
    this.gradientColors = const [Color(0xFFB91C1C), Color(0xFFEF4444)],
    this.cancelLabel = 'Cancelar',
    this.infoText,
    this.bodyWidget,
  });

  final String title;
  final String message;
  final IconData icon;
  final String confirmLabel;
  final List<Color> gradientColors;
  final String cancelLabel;
  final String? infoText;
  final Widget? bodyWidget;

  @override
  State<AppConfirmDialog> createState() => _AppConfirmDialogState();
}

class _AppConfirmDialogState extends State<AppConfirmDialog>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450));
  late final AnimationController _iconCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
  late final Animation<double> _scale = Tween(begin: 0.78, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut));
  late final Animation<double> _fade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _entryCtrl,
          curve: const Interval(0.0, 0.45, curve: Curves.easeOut)));
  late final Animation<double> _iconScale =
      Tween(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut));

  @override
  void initState() {
    super.initState();
    _entryCtrl.forward();
    Future.delayed(const Duration(milliseconds: 180),
        () { if (mounted) _iconCtrl.forward(); });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grad = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: widget.gradientColors,
    );
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Dialog(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 48,
                    offset: const Offset(0, 20)),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // ── Gradient header ──────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: BoxDecoration(
                  gradient: grad,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(children: [
                  ScaleTransition(
                    scale: _iconScale,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 2),
                      ),
                      child:
                          Icon(widget.icon, color: Colors.white, size: 36),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(widget.title,
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3)),
                ]),
              ),
              // ── Body ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                child: Column(children: [
                  if (widget.bodyWidget != null) ...[
                    widget.bodyWidget!,
                    const SizedBox(height: 14),
                  ],
                  Text(widget.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.55,
                          color: Color(0xFF64748B))),
                  if (widget.infoText != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: widget.gradientColors.first
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.info_outline_rounded,
                            size: 13,
                            color: widget.gradientColors.last),
                        const SizedBox(width: 6),
                        Text(widget.infoText!,
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: widget.gradientColors.last)),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(
                              color: Color(0xFFE2E8F0), width: 1.5),
                          padding:
                              const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(widget.cancelLabel,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: grad,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: widget.gradientColors.first
                                  .withValues(alpha: 0.38),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(widget.confirmLabel,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Result dialog ───────────────────────────────────────────────────────────
/// Animated success / error feedback dialog.
class AppResultDialog extends StatefulWidget {
  const AppResultDialog({
    super.key,
    required this.message,
    required this.success,
    this.title,
    this.icon,
  });

  final String message;
  final bool success;
  final String? title;
  final IconData? icon;

  @override
  State<AppResultDialog> createState() => _AppResultDialogState();
}

class _AppResultDialogState extends State<AppResultDialog>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  late final AnimationController _iconCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 550));
  late final Animation<double> _scale = Tween(begin: 0.80, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut));
  late final Animation<double> _fade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _entryCtrl,
          curve: const Interval(0.0, 0.45, curve: Curves.easeOut)));
  late final Animation<double> _iconScale =
      Tween(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut));

  @override
  void initState() {
    super.initState();
    _entryCtrl.forward();
    Future.delayed(const Duration(milliseconds: 160),
        () { if (mounted) _iconCtrl.forward(); });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color colorA =
        widget.success ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final Color colorB =
        widget.success ? const Color(0xFF34D399) : const Color(0xFFEF4444);
    final heading =
        widget.title ?? (widget.success ? '¡Operación exitosa!' : 'Algo salió mal');
    final icono = widget.icon ??
        (widget.success
            ? Icons.check_circle_outline_rounded
            : Icons.error_outline_rounded);
    final grad = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colorA, colorB]);

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Dialog(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 36),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: colorA.withValues(alpha: 0.20),
                    blurRadius: 40,
                    offset: const Offset(0, 16)),
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // ── Header ──────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  gradient: grad,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Center(
                  child: ScaleTransition(
                    scale: _iconScale,
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.40),
                            width: 2),
                      ),
                      child: Icon(icono, color: Colors.white, size: 34),
                    ),
                  ),
                ),
              ),
              // ── Body ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                child: Column(children: [
                  Text(heading,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0D1B4B))),
                  const SizedBox(height: 8),
                  Text(widget.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                          height: 1.5)),
                  const SizedBox(height: 24),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: grad,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: colorA.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Aceptar',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Picker dialog ───────────────────────────────────────────────────────────
/// Animated list-picker dialog. Pops [T] on selection, [null] on cancel.
class AppPickerDialog<T> extends StatefulWidget {
  const AppPickerDialog({
    super.key,
    required this.title,
    required this.items,
    required this.labelBuilder,
    this.subtitleBuilder,
    this.leadingBuilder,
    this.selectedValue,
    this.titleIcon,
    this.gradientColors = const [Color(0xFF0D1B4B), Color(0xFF1E3A8A)],
  });

  final String title;
  final List<T> items;
  final String Function(T) labelBuilder;
  final String? Function(T)? subtitleBuilder;
  final Widget? Function(T)? leadingBuilder;
  final T? selectedValue;
  final IconData? titleIcon;
  final List<Color> gradientColors;

  @override
  State<AppPickerDialog<T>> createState() => _AppPickerDialogState<T>();
}

class _AppPickerDialogState<T> extends State<AppPickerDialog<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 360));
  late final Animation<double> _scale = Tween(begin: 0.84, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  late final Animation<double> _fade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut)));

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Dialog(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 36,
                    offset: const Offset(0, 14)),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // ── Header ──────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.gradientColors,
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(children: [
                  if (widget.titleIcon != null) ...[
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(widget.titleIcon,
                          color: Colors.white, size: 17),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(widget.title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.2)),
                ]),
              ),
              // ── Items ────────────────────────────────────────
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shrinkWrap: true,
                  itemCount: widget.items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (_, i) {
                    final item = widget.items[i];
                    final label = widget.labelBuilder(item);
                    final subtitle = widget.subtitleBuilder?.call(item);
                    final leading = widget.leadingBuilder?.call(item);
                    final isSelected = widget.selectedValue == item;
                    return InkWell(
                      onTap: () => Navigator.pop(context, item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 13),
                        child: Row(children: [
                          if (leading != null) ...[
                            leading,
                            const SizedBox(width: 12)
                          ],
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(label,
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? const Color(0xFF0D1B4B)
                                              : const Color(0xFF374151))),
                                  if (subtitle != null)
                                    Text(subtitle,
                                        style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF9CA3AF))),
                                ]),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_rounded,
                                color: Color(0xFF0D1B4B), size: 18),
                        ]),
                      ),
                    );
                  },
                ),
              ),
              // ── Cancel ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    minimumSize: const Size(double.infinity, 42),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
