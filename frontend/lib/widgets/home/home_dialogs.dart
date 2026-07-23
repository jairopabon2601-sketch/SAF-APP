// ignore_for_file: use_build_context_synchronously

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../controllers/home_actions.dart';
import '../../controllers/home_permissions_dialog.dart';
import '../../screens/home/home_dependencies.dart';
import '../../screens/home/push_diagnostics_screen.dart';
import 'cached_avatar.dart';
import 'shimmer_header_overlay.dart';

Uint8List _toJpegBytes(Uint8List source) {
  var decoded = img.decodeImage(source);
  if (decoded == null) return source;
  // Redimensionar aquí (y no en el picker nativo) para soportar cualquier
  // formato sin depender del ImageResizer de Android, que no maneja PNG.
  if (decoded.width > 600 || decoded.height > 600) {
    decoded = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: 600)
        : img.copyResize(decoded, height: 600);
  }
  decoded = img.bakeOrientation(decoded);
  return Uint8List.fromList(img.encodeJpg(decoded, quality: 85));
}

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
                      color: textSoft.withValues(alpha: 0.8),
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

  Widget buildProfileSheet(
    String email, {
    Future<({String? filename, String? error})> Function(Uint8List)?
        onUploadPhoto,
  }) =>
      _ProfileSheetContent(
        fullName: fullName,
        photoUrl: photoUrl,
        photoCacheKey: photoCacheKey,
        email: email,
        avatarFallback: buildAvatarFallback(fullName.split(' ').first),
        showGestionUsuarios: isAdmin,
        onUploadPhoto: onUploadPhoto,
        onGestionUsuarios: () {
          Navigator.of(screenContext).pop();
          showUsersManagement();
        },
        onGestionPermisos: () {
          Navigator.of(screenContext).pop();
          showGestionPermisos();
        },
        onDiagnosticoPush: () {
          Navigator.of(screenContext).pop();
          Navigator.of(screenContext).push(MaterialPageRoute(
            builder: (_) => const PushDiagnosticsScreen(),
          ));
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
  final String photoCacheKey;
  final String email;
  final Widget avatarFallback;
  final bool showGestionUsuarios;
  final Future<({String? filename, String? error})> Function(Uint8List)?
      onUploadPhoto;
  final VoidCallback onGestionUsuarios;
  final VoidCallback onGestionPermisos;
  final VoidCallback onDiagnosticoPush;
  final VoidCallback onLogoutConfirmed;

  const _ProfileSheetContent({
    required this.fullName,
    required this.photoUrl,
    required this.photoCacheKey,
    required this.email,
    required this.avatarFallback,
    required this.showGestionUsuarios,
    this.onUploadPhoto,
    required this.onGestionUsuarios,
    required this.onGestionPermisos,
    required this.onDiagnosticoPush,
    required this.onLogoutConfirmed,
  });

  @override
  State<_ProfileSheetContent> createState() => _ProfileSheetContentState();
}

class _ProfileSheetContentState extends State<_ProfileSheetContent>
    with TickerProviderStateMixin {
  String _currentPhotoUrl = '';
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    if (widget.onUploadPhoto == null || _uploading) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    final rawBytes = await file.readAsBytes();
    setState(() => _uploading = true);
    try {
      // El servidor guarda siempre con extensión .jpg, así que normalizamos
      // cualquier formato de origen (PNG, WEBP, HEIC, etc.) a JPEG aquí.
      final bytes = await compute(_toJpegBytes, rawBytes);
      final result = await widget.onUploadPhoto!(bytes);
      if (!mounted) return;
      if (result.filename != null) {
        final bust = DateTime.now().millisecondsSinceEpoch;
        setState(() {
          _currentPhotoUrl =
              'https://www.jorgemario.co/ext/saf/img/icons/${result.filename}?v=$bust';
        });
        unawaited(showDialog(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.45),
          builder: (_) => const _PhotoSuccessDialog(),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'No se pudo subir la foto')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

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
    _currentPhotoUrl = widget.photoUrl;
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
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => _LogoutConfirmDialog(
        onConfirm: () => Navigator.pop(ctx, true),
        onCancel: () => Navigator.pop(ctx, false),
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
        color: cardBg,
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
                    const SizedBox(height: 14),
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
                      child: GestureDetector(
                        onTap: widget.onUploadPhoto != null
                            ? _pickAndUpload
                            : null,
                        child: SizedBox(
                          width: 96,
                          height: 96,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color:
                                            Colors.white.withValues(alpha: 0.90),
                                        width: 3),
                                  ),
                                  child: ClipOval(
                                    child: _uploading
                                        ? Container(
                                            color: Colors.black54,
                                            child: const Center(
                                              child: SizedBox(
                                                width: 28,
                                                height: 28,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2.5,
                                                ),
                                              ),
                                            ),
                                          )
                                        : SizedBox(
                                            width: 96,
                                            height: 96,
                                            child: CachedAvatarImage(
                                              url: _currentPhotoUrl,
                                              cacheKey: widget.photoCacheKey,
                                              fallback: widget.avatarFallback,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              if (widget.onUploadPhoto != null)
                                Positioned(
                                  bottom: -6,
                                  right: -6,
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF4361EE),
                                          Color(0xFF00D2FF)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              Colors.black.withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                            ],
                          ),
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
                // Gestión de usuarios (solo admin)
                if (widget.showGestionUsuarios) SlideTransition(
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(children: [
                          const Positioned.fill(child: ShimmerHeaderOverlay()),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: widget.onGestionUsuarios,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.28)),
                                      ),
                                      child: const Icon(
                                          Icons.manage_accounts_rounded,
                                          color: Colors.white, size: 24),
                                    ),
                                    const SizedBox(width: 14),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                        ]),
                      ),
                    ),
                  ),
                ),

                if (widget.showGestionUsuarios) const SizedBox(height: 14),

                // Gestión de permisos por perfil (solo super admin)
                if (widget.showGestionUsuarios) SlideTransition(
                  position: _card1Slide,
                  child: FadeTransition(
                    opacity: _card1Fade,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF3B0764),
                            Color(0xFF7C3AED),
                            Color(0xFFC026D3),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.45),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: const Color(0xFFC026D3).withValues(alpha: 0.20),
                            blurRadius: 32,
                            spreadRadius: -4,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(children: [
                          const Positioned.fill(child: ShimmerHeaderOverlay()),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: widget.onGestionPermisos,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.28)),
                                      ),
                                      child: const Icon(Icons.tune_rounded,
                                          color: Colors.white, size: 24),
                                    ),
                                    const SizedBox(width: 14),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Gestión de permisos',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700)),
                                          SizedBox(height: 2),
                                          Text('Qué módulos ve cada perfil',
                                              style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        color: Colors.white54, size: 15),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),

                if (widget.showGestionUsuarios) const SizedBox(height: 14),

                // Diagnóstico de notificaciones push (visible para todos)
                SlideTransition(
                  position: _card1Slide,
                  child: FadeTransition(
                    opacity: _card1Fade,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF064E3B),
                            Color(0xFF0F766E),
                            Color(0xFF14B8A6),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F766E).withValues(alpha: 0.45),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: const Color(0xFF14B8A6).withValues(alpha: 0.20),
                            blurRadius: 32,
                            spreadRadius: -4,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(children: [
                          const Positioned.fill(child: ShimmerHeaderOverlay()),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: widget.onDiagnosticoPush,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.28)),
                                      ),
                                      child: const Icon(
                                          Icons.notifications_active_rounded,
                                          color: Colors.white, size: 24),
                                    ),
                                    const SizedBox(width: 14),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Diagnóstico de notificaciones',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700)),
                                          SizedBox(height: 2),
                                          Text('Revisa por qué no llegan push',
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
                        ]),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

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

// ── Animated logout confirmation dialog ─────────────────────────────────────
class _LogoutConfirmDialog extends StatefulWidget {
  const _LogoutConfirmDialog({
    required this.onConfirm,
    required this.onCancel,
  });
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  State<_LogoutConfirmDialog> createState() => _LogoutConfirmDialogState();
}

class _LogoutConfirmDialogState extends State<_LogoutConfirmDialog>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 460));
  late final AnimationController _iconCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 620));
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
    Future.delayed(const Duration(milliseconds: 190),
        () { if (mounted) _iconCtrl.forward(); });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  static const _grad = LinearGradient(
    colors: [Color(0xFF4A0010), Color(0xFF9B0028), Color(0xFFE5003A), Color(0xFFFF4D6D)],
    stops: [0.0, 0.30, 0.65, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
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
                    color: const Color(0xFFE5003A).withValues(alpha: 0.18),
                    blurRadius: 48,
                    offset: const Offset(0, 20)),
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // ── Gradient header ──────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: const BoxDecoration(
                  gradient: _grad,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(children: [
                  ScaleTransition(
                    scale: _iconScale,
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFFE5003A)
                                  .withValues(alpha: 0.40),
                              blurRadius: 20,
                              offset: const Offset(0, 6)),
                        ],
                      ),
                      child: const Icon(Icons.logout_rounded,
                          color: Colors.white, size: 36),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('¿Cerrar sesión?',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.4)),
                ]),
              ),
              // ── Body ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                child: Column(children: [
                  Text(
                    'Se cerrará tu sesión activa y tendrás que\nvolver a iniciar sesión para continuar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: textSoft,
                        height: 1.6),
                  ),
                  const SizedBox(height: 22),
                  // Confirm button (full width, gradient)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _grad,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFE5003A)
                                .withValues(alpha: 0.40),
                            blurRadius: 14,
                            offset: const Offset(0, 5)),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: widget.onConfirm,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Sí, cerrar sesión',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Cancel button
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8899BB),
                      minimumSize: const Size(double.infinity, 46),
                      side: BorderSide(
                          color: lineCol, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: widget.onCancel,
                    child: const Text('No, quedarse',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
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

// ─────────────────────────────────────────────────────────────────────────────
// Pop-up de éxito al actualizar la foto de perfil. Se cierra solo.
class _PhotoSuccessDialog extends StatefulWidget {
  const _PhotoSuccessDialog();

  @override
  State<_PhotoSuccessDialog> createState() => _PhotoSuccessDialogState();
}

class _PhotoSuccessDialogState extends State<_PhotoSuccessDialog>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 460));
  late final AnimationController _iconCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 620));
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));
  late final Animation<double> _scale = Tween(begin: 0.78, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut));
  late final Animation<double> _fade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _entryCtrl,
          curve: const Interval(0.0, 0.45, curve: Curves.easeOut)));
  late final Animation<double> _iconScale =
      Tween(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut));
  late final Animation<double> _glow =
      Tween(begin: 0.25, end: 0.6).animate(_pulse);

  @override
  void initState() {
    super.initState();
    _entryCtrl.forward();
    _pulse.repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 190), () {
      if (mounted) _iconCtrl.forward();
    });
    // Auto-cierre
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _iconCtrl.dispose();
    _pulse.dispose();
    super.dispose();
  }

  static const _grad = LinearGradient(
    colors: [
      Color(0xFF003D1F),
      Color(0xFF00713A),
      Color(0xFF00A857),
      Color(0xFF3DDC84),
    ],
    stops: [0.0, 0.30, 0.65, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Dialog(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF00A857).withValues(alpha: 0.22),
                    blurRadius: 48,
                    offset: const Offset(0, 20)),
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // ── Cabecera con gradiente + check animado ─────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: const BoxDecoration(
                  gradient: _grad,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _glow,
                    builder: (_, child) => Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white
                                .withValues(alpha: _glow.value),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: child,
                    ),
                    child: ScaleTransition(
                      scale: _iconScale,
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 46),
                    ),
                  ),
                ),
              ),
              // ── Texto ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
                child: Column(children: [
                  Text('¡Foto actualizada!',
                      style: TextStyle(
                          color: textMain,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    'Tu nueva foto de perfil se guardó correctamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: textSoft.withValues(alpha: 0.85),
                        fontSize: 13.5,
                        height: 1.4),
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
