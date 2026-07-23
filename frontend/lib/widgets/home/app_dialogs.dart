import '../../screens/home/home_constants.dart';
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
  late final Animation<double> _scale = Tween(begin: 0.82, end: 1.0)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
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
  late final AnimationController _ringCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  late final Animation<double> _scale = Tween(begin: 0.78, end: 1.0)
      .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut));
  late final Animation<double> _fade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _entryCtrl,
          curve: const Interval(0.0, 0.45, curve: Curves.easeOut)));
  late final Animation<double> _iconScale = Tween(begin: 0.0, end: 1.0)
      .animate(CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut));
  late final Animation<double> _ringScale = Tween(begin: 0.55, end: 1.55)
      .animate(CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut));
  late final Animation<double> _ringFade = Tween(begin: 0.55, end: 0.0)
      .animate(CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _entryCtrl.forward();
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) {
        _iconCtrl.forward();
        _ringCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _iconCtrl.dispose();
    _ringCtrl.dispose();
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
              color: cardBg,
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
                  SizedBox(
                    width: 112,
                    height: 112,
                    child: Stack(alignment: Alignment.center, children: [
                      AnimatedBuilder(
                        animation: _ringCtrl,
                        builder: (_, __) => Opacity(
                          opacity: _ringFade.value,
                          child: Transform.scale(
                            scale: _ringScale.value,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ),
                      ),
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
                    ]),
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
                      style: TextStyle(
                          fontSize: 13.5, height: 1.55, color: textSoft)),
                  if (widget.infoText != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color:
                            widget.gradientColors.first.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.info_outline_rounded,
                            size: 13, color: widget.gradientColors.last),
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
                          foregroundColor: textSoft,
                          side: BorderSide(color: lineCol, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 13),
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
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(widget.confirmLabel,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
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
    this.warning = false,
  });

  final String message;
  final bool success;
  final String? title;
  final IconData? icon;
  /// Cuando es true, muestra un estilo ámbar de advertencia/información en
  /// vez del verde de éxito o rojo de error (independiente de [success]).
  final bool warning;

  @override
  State<AppResultDialog> createState() => _AppResultDialogState();
}

class _AppResultDialogState extends State<AppResultDialog>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  late final AnimationController _iconCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 550));
  late final AnimationController _ringCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 850));
  late final Animation<double> _scale = Tween(begin: 0.80, end: 1.0)
      .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut));
  late final Animation<double> _fade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _entryCtrl,
          curve: const Interval(0.0, 0.45, curve: Curves.easeOut)));
  late final Animation<double> _iconScale = Tween(begin: 0.0, end: 1.0)
      .animate(CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut));
  late final Animation<double> _ringScale = Tween(begin: 0.55, end: 1.6)
      .animate(CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut));
  late final Animation<double> _ringFade = Tween(begin: 0.55, end: 0.0)
      .animate(CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _entryCtrl.forward();
    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted) {
        _iconCtrl.forward();
        _ringCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _iconCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color colorA = widget.warning
        ? const Color(0xFF92400E)
        : (widget.success ? const Color(0xFF059669) : const Color(0xFFDC2626));
    final Color colorB = widget.warning
        ? const Color(0xFFFBBF24)
        : (widget.success ? const Color(0xFF34D399) : const Color(0xFFEF4444));
    final heading = widget.title ??
        (widget.warning
            ? 'Ten en cuenta'
            : (widget.success ? '¡Operación exitosa!' : 'Algo salió mal'));
    final icono = widget.icon ??
        (widget.warning
            ? Icons.warning_amber_rounded
            : (widget.success
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded));
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
              color: cardBg,
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
                  child: SizedBox(
                    width: 108,
                    height: 108,
                    child: Stack(alignment: Alignment.center, children: [
                      AnimatedBuilder(
                        animation: _ringCtrl,
                        builder: (_, __) => Opacity(
                          opacity: _ringFade.value,
                          child: Transform.scale(
                            scale: _ringScale.value,
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ),
                      ),
                      ScaleTransition(
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
                    ]),
                  ),
                ),
              ),
              // ── Body ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                child: Column(children: [
                  Text(heading,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: textMain)),
                  const SizedBox(height: 8),
                  Text(widget.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: textSoft, height: 1.5)),
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

// ─── Picker dialog helpers ────────────────────────────────────────────────
const List<Color> _pickerAvatarPalette = [
  Color(0xFF4361EE),
  Color(0xFF7C3AED),
  Color(0xFF0EA5E9),
  Color(0xFF059669),
  Color(0xFFD97706),
  Color(0xFFDC2626),
  Color(0xFFDB2777),
  Color(0xFF0284C7),
];

/// Color determinístico por label, para que cada fila de un picker tenga
/// una identidad visual aunque el llamador no pase un color explícito.
Color _autoColor(String label) {
  if (label.isEmpty) return _pickerAvatarPalette.first;
  final hash = label.codeUnits.fold<int>(0, (acc, c) => acc + c);
  return _pickerAvatarPalette[hash % _pickerAvatarPalette.length];
}

String _pickerInitials(String label) {
  final trimmed = label.trim();
  if (trimmed.isEmpty) return '?';
  final parts =
      trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2);
  return parts.map((p) => p[0]).join().toUpperCase();
}

Widget _pickerAvatar(String label, Color color) => Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color.lerp(color, Colors.white, 0.30)!, color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.32),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(_pickerInitials(label),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w800)),
    );

/// Feedback táctil de "presionar": encoge levemente el row al tocar.
class _PickerRowScale extends StatefulWidget {
  const _PickerRowScale({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PickerRowScale> createState() => _PickerRowScaleState();
}

class _PickerRowScaleState extends State<_PickerRowScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    lowerBound: 0.96,
    upperBound: 1.0,
  )..value = 1.0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => _ctrl.reverse(),
        onTapUp: (_) {
          _ctrl.forward();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.forward(),
        child: ScaleTransition(scale: _ctrl, child: widget.child),
      );
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
    this.colorBuilder,
    this.selectedValue,
    this.titleIcon,
    this.gradientColors = const [Color(0xFF0D1B4B), Color(0xFF1E3A8A)],
  });

  final String title;
  final List<T> items;
  final String Function(T) labelBuilder;
  final String? Function(T)? subtitleBuilder;
  final Widget? Function(T)? leadingBuilder;

  /// Color de acento por item (avatar, selección). Si no se da, se deriva
  /// de forma determinística a partir del label para que cada fila tenga
  /// igual un color de identidad sin que el llamador tenga que definirlo.
  final Color? Function(T)? colorBuilder;
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
  late final Animation<double> _scale = Tween(begin: 0.84, end: 1.0)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
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
              color: cardBg,
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
                      child:
                          Icon(widget.titleIcon, color: Colors.white, size: 17),
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
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    itemCount: widget.items.length,
                    itemBuilder: (_, i) {
                      final item = widget.items[i];
                      final label = widget.labelBuilder(item);
                      final subtitle = widget.subtitleBuilder?.call(item);
                      final customLeading = widget.leadingBuilder?.call(item);
                      final isSelected = widget.selectedValue == item;
                      final accent =
                          widget.colorBuilder?.call(item) ?? _autoColor(label);

                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration:
                            Duration(milliseconds: 260 + (i.clamp(0, 10) * 45)),
                        curve: Curves.easeOutCubic,
                        builder: (_, t, child) => Transform.translate(
                          offset: Offset(18 * (1 - t), 0),
                          child:
                              Opacity(opacity: t.clamp(0.0, 1.0), child: child),
                        ),
                        child: _PickerRowScale(
                          onTap: () => Navigator.pop(context, item),
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 11),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accent.withValues(
                                      alpha: isDarkTheme ? 0.20 : 0.10)
                                  : (isDarkTheme
                                      ? Colors.white.withValues(alpha: 0.035)
                                      : const Color(0xFFF6F7FB)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? accent.withValues(alpha: 0.45)
                                    : Colors.transparent,
                                width: 1.2,
                              ),
                            ),
                            child: Row(children: [
                              customLeading ?? _pickerAvatar(label, accent),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                              color: textMain)),
                                      if (subtitle != null)
                                        Text(subtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 11.5,
                                                color: textSoft)),
                                    ]),
                              ),
                              if (isSelected)
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                      color: accent, shape: BoxShape.circle),
                                  child: const Icon(Icons.check_rounded,
                                      color: Colors.white, size: 14),
                                )
                              else
                                Icon(Icons.chevron_right_rounded,
                                    color: textSoft.withValues(alpha: 0.5),
                                    size: 20),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // ── Cancel ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: appCancelButton('Cancelar', () => Navigator.pop(context),
                    height: 46),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
