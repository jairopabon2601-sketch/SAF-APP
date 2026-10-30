import 'dart:math' as math;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../widgets/saf_logo.dart';

/// Fondo animado del portal: degradado profundo con dos "orbes" de luz que
/// flotan lentamente. Un solo AnimationController y RepaintBoundary para que
/// no obligue a repintar el contenido que va encima.
class PortalBackground extends StatefulWidget {
  const PortalBackground({super.key, required this.child});
  final Widget child;

  @override
  State<PortalBackground> createState() => _PortalBackgroundState();
}

class _PortalBackgroundState extends State<PortalBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 14))
    ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF020714), Color(0xFF070D2A), Color(0xFF0D0840)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final t = _ctrl.value * 2 * math.pi;
              return Stack(children: [
                Align(
                  alignment: Alignment(-0.9 + 0.25 * math.sin(t),
                      -0.95 + 0.15 * math.cos(t)),
                  child: const _Orb(color: Color(0xFF6C63FF), size: 320),
                ),
                Align(
                  alignment: Alignment(0.95 + 0.2 * math.cos(t),
                      0.9 + 0.15 * math.sin(t)),
                  child: const _Orb(color: Color(0xFF00D2FF), size: 300),
                ),
              ]);
            },
          ),
        ),
      ),
      Positioned.fill(child: widget.child),
    ]);
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [
          color.withValues(alpha: 0.45),
          color.withValues(alpha: 0.0),
        ]),
      ),
    );
  }
}

/// Logo SAF de vidrio, igual al del login de la app: círculo translúcido
/// con borde blanco y un halo violeta/cian que respira.
class PortalLogo extends StatefulWidget {
  const PortalLogo({super.key, this.size = 84, this.animated = true});
  final double size;
  final bool animated;

  @override
  State<PortalLogo> createState() => _PortalLogoState();
}

class _PortalLogoState extends State<PortalLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void initState() {
    super.initState();
    if (widget.animated) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) {
          final p = Curves.easeInOut.transform(_pulse.value);
          return Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF)
                      .withValues(alpha: 0.24 + 0.30 * p),
                  blurRadius: s * (0.45 + 0.25 * p),
                  spreadRadius: s * 0.02 * p,
                ),
                BoxShadow(
                  color: const Color(0xFF00D2FF)
                      .withValues(alpha: 0.10 + 0.14 * p),
                  blurRadius: s * (0.6 + 0.2 * p),
                ),
              ],
            ),
            child: child,
          );
        },
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Colors.white.withValues(alpha: 0.16),
                  Colors.white.withValues(alpha: 0.05),
                ]),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24), width: 1.2),
              ),
              padding: EdgeInsets.all(s * 0.20),
              child: const CustomPaint(painter: SafLogoPainter(Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Brillo diagonal que cruza un widget cada pocos segundos.
class PortalShine extends StatefulWidget {
  const PortalShine({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.period = const Duration(milliseconds: 3600),
    this.alpha = 0.22,
  });

  final Widget child;
  final double borderRadius;
  final Duration period;
  final double alpha;

  @override
  State<PortalShine> createState() => _PortalShineState();
}

class _PortalShineState extends State<PortalShine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Stack(children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  final t = (_ctrl.value / 0.42).clamp(0.0, 1.0);
                  if (t <= 0 || t >= 1) return const SizedBox.shrink();
                  return Align(
                    alignment: Alignment(-1.7 + 3.4 * t, 0),
                    child: Transform.rotate(
                      angle: 0.35,
                      child: Container(
                        width: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: widget.alpha),
                            Colors.white.withValues(alpha: 0),
                          ]),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Entrada escalonada (fade + slide) para listas y bloques.
class PortalEntrance extends StatelessWidget {
  const PortalEntrance({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.offsetY = 18,
  });

  final Widget child;
  final int delayMs;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    final total = 450 + delayMs;
    final start = delayMs / total;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: total),
      curve: Interval(start, 1.0, curve: Curves.easeOutCubic),
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, offsetY * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

/// Tarjeta de vidrio esmerilado del portal.
BoxDecoration portalGlass({double radius = 24}) => BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.07),
          Colors.white.withValues(alpha: 0.025),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.30),
          blurRadius: 30,
          offset: const Offset(0, 14),
        ),
      ],
    );

const portalCyan = Color(0xFF00C6FF);
const portalTextSoft = Color(0xFF94A3B8);

String portalCop(num v) {
  final neg = v < 0;
  final digits = v.abs().round().toString();
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write('.');
    b.write(digits[i]);
  }
  return '${neg ? '-' : ''}\$ $b';
}

const _mesesCortos = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];
const _mesesLargos = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];
const _dias = [
  'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
];

DateTime? _parse(String ymd) {
  try {
    return DateTime.parse(ymd.length >= 10 ? ymd.substring(0, 10) : ymd);
  } catch (_) {
    return null;
  }
}

/// '2026-10-31' → '31 oct 2026'
String portalFechaCorta(String ymd) {
  final d = _parse(ymd);
  if (d == null) return ymd;
  return '${d.day.toString().padLeft(2, '0')} ${_mesesCortos[d.month - 1]} ${d.year}';
}

/// '2026-10-31' → 'Sábado 31 de octubre'
String portalFechaLarga(String ymd) {
  final d = _parse(ymd);
  if (d == null) return ymd;
  return '${_dias[d.weekday - 1]} ${d.day} de ${_mesesLargos[d.month - 1]}';
}

/// Número que "cuenta" hasta su valor con formato de pesos.
class PortalCountUp extends StatelessWidget {
  const PortalCountUp({super.key, required this.value, required this.style});
  final double value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(portalCop(v), style: style),
    );
  }
}

/// Anillo de progreso animado (cuotas pagadas / total).
class PortalRing extends StatelessWidget {
  const PortalRing({
    super.key,
    required this.progress,
    required this.color,
    required this.child,
    this.size = 84,
    this.stroke = 9,
  });

  final double progress;
  final Color color;
  final Widget child;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 1300),
        curve: Curves.easeOutCubic,
        builder: (_, v, c) => CustomPaint(
          painter: _RingPainter(v, color, stroke),
          child: c,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.color, this.stroke);
  final double v;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final bg = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(r, 0, 2 * math.pi, false, bg);
    if (v <= 0) return;
    final glow = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(r, -math.pi / 2, 2 * math.pi * v, false, glow);
    canvas.drawArc(r, -math.pi / 2, 2 * math.pi * v, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.v != v || old.color != color || old.stroke != stroke;
}
