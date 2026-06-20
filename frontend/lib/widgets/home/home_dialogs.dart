// ignore_for_file: use_build_context_synchronously

import '../../controllers/home_actions.dart';
import '../../screens/home/home_dependencies.dart';

extension HomeDialogs<T extends StatefulWidget> on HomeController<T> {
  Widget buildLoadingView() => SizedBox(
        height: 400,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: homeAccent),
              const SizedBox(height: 16),
              Text('Cargando datos...',
                  style: TextStyle(
                      color: const Color(0xFF8899BB).withValues(alpha: 0.8),
                      fontSize: 13)),
            ],
          ),
        ),
      );
  Widget buildAvatarFallback(String name) => Container(
        color: homeAccent,
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'U',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
      );

  Widget buildProfileSheet(String email) => _ProfileSheetContent(
        fullName: fullName,
        photoUrl: photoUrl,
        email: email,
        avatarFallback: buildAvatarFallback(fullName.split(' ').first),
        onGestionUsuarios: () {
          Navigator.of(screenContext).pop();
          showUsersManagement();
        },
        onLogoutConfirmed: () {
          Navigator.of(screenContext).pop();
          logout();
        },
      );
}

// ─────────────────────────────────────────────────────────────────────────────
class _ProfileSheetContent extends StatefulWidget {
  final String fullName;
  final String photoUrl;
  final String email;
  final Widget avatarFallback;
  final VoidCallback onGestionUsuarios;
  final VoidCallback onLogoutConfirmed;

  const _ProfileSheetContent({
    required this.fullName,
    required this.photoUrl,
    required this.email,
    required this.avatarFallback,
    required this.onGestionUsuarios,
    required this.onLogoutConfirmed,
  });

  @override
  State<_ProfileSheetContent> createState() => _ProfileSheetContentState();
}

class _ProfileSheetContentState extends State<_ProfileSheetContent>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  late final Animation<double> _avatarScale = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
  );
  late final Animation<double> _avatarFade = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.0, 0.30, curve: Curves.easeOut),
  );
  late final Animation<Offset> _nameSlide =
      Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
    CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.25, 0.60, curve: Curves.easeOutCubic)),
  );
  late final Animation<double> _nameFade = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.20, 0.55, curve: Curves.easeOut),
  );
  late final Animation<Offset> _card1Slide =
      Tween<Offset>(begin: const Offset(0, 0.7), end: Offset.zero).animate(
    CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.40, 0.78, curve: Curves.easeOutCubic)),
  );
  late final Animation<double> _card1Fade = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.38, 0.70, curve: Curves.easeOut),
  );
  late final Animation<Offset> _card2Slide =
      Tween<Offset>(begin: const Offset(0, 0.7), end: Offset.zero).animate(
    CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.54, 0.92, curve: Curves.easeOutCubic)),
  );
  late final Animation<double> _card2Fade = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.50, 0.82, curve: Curves.easeOut),
  );
  late final Animation<double> _glowAlpha =
      Tween<double>(begin: 0.25, end: 0.55).animate(_pulse);
  late final Animation<double> _glowRadius =
      Tween<double>(begin: 18.0, end: 36.0).animate(_pulse);

  @override
  void initState() {
    super.initState();
    _entrance.forward();
    _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    super.dispose();
  }

  // ── orbe decorativo ───────────────────────────────────────────────
  Widget _orb(double size, Color color, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: alpha),
        ),
      );

  // ── confirmación de logout ────────────────────────────────────────
  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: EdgeInsets.zero,
        titlePadding: EdgeInsets.zero,
        title: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF4A0010),
                      Color(0xFF9B0028),
                      Color(0xFFE5003A),
                      Color(0xFFFF4D6D),
                    ],
                    stops: [0.0, 0.30, 0.65, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFE5003A).withValues(alpha: 0.50),
                        blurRadius: 24,
                        spreadRadius: 2,
                        offset: const Offset(0, 8)),
                    BoxShadow(
                        color: const Color(0xFFFF4D6D).withValues(alpha: 0.25),
                        blurRadius: 40,
                        spreadRadius: -2,
                        offset: const Offset(0, 14)),
                  ],
                ),
                child: const Icon(Icons.logout_rounded,
                    color: Colors.white, size: 38),
              ),
              const SizedBox(height: 20),
              const Text('¿Cerrar sesión?',
                  style: TextStyle(
                      color: homeNavy,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4)),
              const SizedBox(height: 8),
              const Text(
                'Se cerrará tu sesión activa y tendrás que\nvolver a iniciar sesión para continuar.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0xFF8899BB), fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF4A0010),
                      Color(0xFF9B0028),
                      Color(0xFFE5003A),
                      Color(0xFFFF4D6D),
                    ],
                    stops: [0.0, 0.30, 0.65, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFE5003A).withValues(alpha: 0.50),
                        blurRadius: 18,
                        offset: const Offset(0, 6)),
                    BoxShadow(
                        color: const Color(0xFFFF4D6D).withValues(alpha: 0.25),
                        blurRadius: 32,
                        spreadRadius: -4,
                        offset: const Offset(0, 12)),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(ctx, true),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('Sí, cerrar sesión',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF8899BB),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(
                          color: Color(0xFFE2E8F0), width: 1.5),
                    ),
                  ),
                  child: const Text('No, quedarse',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        actions: const [],
      ),
    );
    if (confirm == true && mounted) {
      widget.onLogoutConfirmed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.fullName.isNotEmpty
        ? widget.fullName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join()
        : 'U';

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // ── Header dark: drag handle + orbes + avatar ─────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF060D2E), Color(0xFF0D1B4B), Color(0xFF1E3A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // Orbes decorativos
                Positioned(
                    top: -28, right: -24,
                    child: _orb(130, const Color(0xFF3B82F6), 0.18)),
                Positioned(
                    top: 10, left: -40,
                    child: _orb(100, const Color(0xFF6366F1), 0.13)),
                Positioned(
                    bottom: -10, right: 60,
                    child: _orb(70, const Color(0xFF06B6D4), 0.10)),
                // Contenido
                Column(
                  children: [
                    // Drag handle sobre fondo oscuro
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.30),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Avatar con glow pulsante
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, child) => ScaleTransition(
                        scale: _avatarScale,
                        child: FadeTransition(
                          opacity: _avatarFade,
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF60A5FA)
                                      .withValues(alpha: _glowAlpha.value),
                                  blurRadius: _glowRadius.value,
                                  spreadRadius: 4,
                                ),
                                BoxShadow(
                                  color: const Color(0xFF818CF8)
                                      .withValues(alpha: _glowAlpha.value * 0.5),
                                  blurRadius: _glowRadius.value * 1.6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: child,
                          ),
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.85),
                              width: 3),
                        ),
                        child: ClipOval(
                          child: widget.photoUrl.isNotEmpty
                              ? Image.network(widget.photoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      widget.avatarFallback)
                              : widget.avatarFallback,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Nombre + email con slide up
                    SlideTransition(
                      position: _nameSlide,
                      child: FadeTransition(
                        opacity: _nameFade,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              Text(
                                widget.fullName,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              if (widget.email.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.20)),
                                  ),
                                  child: Text(
                                    widget.email,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  initials.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ],
            ),
          ),

          // ── Opciones ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              children: [
                // Gestión de usuarios
                SlideTransition(
                  position: _card1Slide,
                  child: FadeTransition(
                    opacity: _card1Fade,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF0B0D2E),
                            Color(0xFF1A1B6E),
                            Color(0xFF2563EB),
                            Color(0xFF38BDF8),
                          ],
                          stops: [0.0, 0.35, 0.70, 1.0],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.45),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.20),
                            blurRadius: 32,
                            spreadRadius: -4,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: widget.onGestionUsuarios,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.manage_accounts_rounded,
                                      color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Gestión de usuarios',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700)),
                                      SizedBox(height: 2),
                                      Text('Usuarios, perfiles y accesos',
                                          style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded,
                                    color: Colors.white54, size: 15),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Cerrar sesión
                SlideTransition(
                  position: _card2Slide,
                  child: FadeTransition(
                    opacity: _card2Fade,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF4A0010),
                            Color(0xFF9B0028),
                            Color(0xFFE5003A),
                            Color(0xFFFF4D6D),
                          ],
                          stops: [0.0, 0.30, 0.65, 1.0],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE5003A).withValues(alpha: 0.50),
                            blurRadius: 20,
                            offset: const Offset(0, 7),
                          ),
                          BoxShadow(
                            color: const Color(0xFFFF4D6D).withValues(alpha: 0.25),
                            blurRadius: 36,
                            spreadRadius: -4,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _handleLogout,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.logout_rounded,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 10),
                                Text('Cerrar sesión',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      letterSpacing: 0.3,
                                    )),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }
}
