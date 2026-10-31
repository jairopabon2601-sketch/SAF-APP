import 'package:flutter/material.dart';

/// Entrada suave al cambiar de pestaña en la pantalla principal: el
/// contenido nuevo aparece con un fundido y sube unos pocos píxeles.
///
/// Solo anima la pestaña que entra (la anterior se retira de inmediato), así
/// que nunca se construyen dos pestañas pesadas a la vez. Si el sistema tiene
/// "reducir movimiento" activado, no anima.
class TabEntrance extends StatefulWidget {
  const TabEntrance({super.key, required this.child});

  final Widget child;

  @override
  State<TabEntrance> createState() => _TabEntranceState();
}

class _TabEntranceState extends State<TabEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, 0.015),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  bool _iniciado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciado) return;
    _iniciado = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}
