import 'package:flutter/material.dart';

/// Franja diagonal de brillo delgada que recorre un header en loop —
/// mismo mecanismo que la tarjeta "Total de Saldos" del Dashboard: una
/// banda angosta, rotada, con gradiente transparente→blanco tenue→
/// transparente, desplazándose de un extremo al otro. Se usa como overlay
/// sobre headers con gradiente oscuro (Gestión de usuarios, Gestión de
/// permisos) para el mismo acabado premium sutil.
class ShimmerHeaderOverlay extends StatefulWidget {
  const ShimmerHeaderOverlay({super.key});

  @override
  State<ShimmerHeaderOverlay> createState() => _ShimmerHeaderOverlayState();
}

class _ShimmerHeaderOverlayState extends State<ShimmerHeaderOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600))
    ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final width = MediaQuery.sizeOf(context).width;
            return Transform.translate(
              offset: Offset((_ctrl.value * 2 - 1) * width, 0),
              child: Transform.rotate(
                angle: 0.45,
                child: Container(
                  width: 60,
                  height: 260,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
