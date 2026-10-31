import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Botón "Continuar con Google" con el logo oficial (assets/icons/google_g.svg).
///
/// Se hunde un poco al presionarlo, vibra suave al tocarlo y cambia el logo
/// por un indicador de carga mientras [loading] es true. Con [onTap] null
/// queda deshabilitado.
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({
    super.key,
    required this.onTap,
    this.loading = false,
    this.height = 50,
  });

  final VoidCallback? onTap;
  final bool loading;
  final double height;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null && !widget.loading;
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _pressed ? 0.10 : 0.18),
              blurRadius: _pressed ? 6 : 14,
              offset: Offset(0, _pressed ? 2 : 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled
                ? () {
                    HapticFeedback.selectionClick();
                    widget.onTap!();
                  }
                : null,
            onTapDown: enabled ? (_) => _setPressed(true) : null,
            onTapUp: enabled ? (_) => _setPressed(false) : null,
            onTapCancel: () => _setPressed(false),
            splashColor: const Color(0xFF4285F4).withValues(alpha: 0.12),
            highlightColor: const Color(0xFF4285F4).withValues(alpha: 0.05),
            child: SizedBox(
              height: widget.height,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(scale: anim, child: child),
                      ),
                      child: widget.loading
                          ? const Padding(
                              key: ValueKey('cargando'),
                              padding: EdgeInsets.all(2),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.2, color: Color(0xFF4285F4)),
                            )
                          : SvgPicture.asset(
                              'assets/icons/google_g.svg',
                              key: const ValueKey('logo'),
                              width: 22,
                              height: 22,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Continuar con Google',
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
