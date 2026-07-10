import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import '../utils/responsive.dart';
import 'forgot_password_screen.dart';
import 'home/home_constants.dart';

// ── Particle ──────────────────────────────────────────────────────────────────
class _Particle {
  final double x, startY, radius, speed, alpha, phase;
  final Color color;
  const _Particle({
    required this.x,
    required this.startY,
    required this.radius,
    required this.speed,
    required this.alpha,
    required this.phase,
    required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  _ParticlePainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final dy = (progress * p.speed * size.height) % size.height;
      final y = (p.startY * size.height - dy + size.height) % size.height;
      final a =
          (math.sin(progress * math.pi * 4 + p.phase) * 0.3 + 0.55) * p.alpha;
      canvas.drawCircle(
        Offset(p.x * size.width, y),
        p.radius,
        Paint()..color = p.color.withValues(alpha: a.clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}

// ── SAF Logo ──────────────────────────────────────────────────────────────────
class _SafLogoPainter extends CustomPainter {
  final Color color;
  const _SafLogoPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = size.width * 0.38,
        nodeR = size.width * 0.115,
        ringW = size.width * 0.07;
    final gap = 2 * math.asin(nodeR / r) + 0.06;
    final angles = [
      -math.pi * 3 / 4,
      -math.pi / 4,
      math.pi / 4,
      math.pi * 3 / 4
    ];
    final ring = Paint()
      ..color = color
      ..strokeWidth = ringW
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;
    for (int i = 0; i < angles.length; i++) {
      final start = angles[i] + gap / 2;
      var sweep = (angles[(i + 1) % angles.length] - gap / 2) - start;
      if (sweep < 0) sweep += math.pi * 2;
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), start,
          sweep, false, ring);
    }
    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final a in angles) {
      canvas.drawCircle(
          Offset(cx + r * math.cos(a), cy + r * math.sin(a)), nodeR, dot);
    }
  }

  @override
  bool shouldRepaint(_SafLogoPainter old) => old.color != color;
}

// ── Dot Grid ─────────────────────────────────────────────────────────────────
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white;
    const s = 26.0;
    for (double x = s / 2; x < size.width; x += s) {
      for (double y = s / 2; y < size.height; y += s) {
        canvas.drawCircle(Offset(x, y), 0.85, p);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter _) => false;
}

// ── Aurora ────────────────────────────────────────────────────────────────────
class _AuroraPainter extends CustomPainter {
  final double t;
  const _AuroraPainter(this.t);

  void _band(Canvas canvas, Size size,
      {required double cx,
      required double cy,
      required double rx,
      required double ry,
      required Color c1,
      required Color c2,
      required double a}) {
    final rect =
        Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          c1.withValues(alpha: a),
          c2.withValues(alpha: a * 0.4),
          Colors.transparent
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(rx / ry, 1.0);
    canvas.drawCircle(Offset.zero, ry, paint);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    _band(canvas, size,
        cx: size.width * (0.25 + 0.14 * math.sin(t * math.pi * 2 * 0.7)),
        cy: size.height * (0.20 + 0.09 * math.cos(t * math.pi * 2 * 0.5)),
        rx: size.width * 0.88,
        ry: size.height * 0.28,
        c1: const Color(0xFF3A5BF5),
        c2: const Color(0xFF6C63FF),
        a: 0.24);
    _band(canvas, size,
        cx: size.width * (0.76 + 0.11 * math.cos(t * math.pi * 2 * 0.6)),
        cy: size.height * (0.52 + 0.10 * math.sin(t * math.pi * 2 * 0.4)),
        rx: size.width * 0.92,
        ry: size.height * 0.22,
        c1: const Color(0xFF00B4D8),
        c2: const Color(0xFF0077B6),
        a: 0.16);
    _band(canvas, size,
        cx: size.width * (0.48 + 0.09 * math.sin(t * math.pi * 2 * 0.35)),
        cy: size.height * (0.82 + 0.07 * math.cos(t * math.pi * 2 * 0.9)),
        rx: size.width * 0.82,
        ry: size.height * 0.24,
        c1: const Color(0xFF8B2FC9),
        c2: const Color(0xFF6C63FF),
        a: 0.20);
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t;
}

// ── Orbit Ring ────────────────────────────────────────────────────────────────

// ── Radar Pulse ───────────────────────────────────────────────────────────────

// ── Login Screen ──────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final ApiService _api = ApiService();
  final BiometricService _biometrics = BiometricService();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  // Paso 0 = solo correo, paso 1 = contraseña (+ Face ID si ya está
  // habilitado para ese correo). Separado del correo/contraseña "de una",
  // como pidió el cliente.
  int _step = 0;
  bool _biometricAvailable = false;
  bool _biometricEnabledForEmail = false;
  bool _biometricChecking = false;
  String _biometricLabel = 'Face ID';

  late AnimationController _entryCtrl,
      _pulseCtrl,
      _floatCtrl,
      _particleCtrl,
      _shimmerCtrl;
  late Animation<double> _fadeIn, _pulse, _float;
  late Animation<Offset> _slideUp;
  late List<_Particle> _particles;

  static const _colors = [
    Color(0xFF6C63FF),
    Color(0xFF00D2FF),
    Color(0xFF7B2FBE),
    Color(0xFFFFFFFF),
  ];

  @override
  void initState() {
    super.initState();
    _loadLastEmail();
    final rng = math.Random(42);
    _particles = List.generate(
        40,
        (i) => _Particle(
              x: rng.nextDouble(),
              startY: rng.nextDouble(),
              radius: rng.nextDouble() * 2.2 + 0.7,
              speed: rng.nextDouble() * 0.055 + 0.02,
              alpha: rng.nextDouble() * 0.38 + 0.12,
              phase: rng.nextDouble() * math.pi * 2,
              color: _colors[i % _colors.length],
            ));

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..forward();
    _fadeIn = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat();
    _pulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.54, end: 0.86)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.86, end: 0.54)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
    ]).animate(_pulseCtrl);

    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3400))
      ..repeat();
    _float = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: -7.0, end: 7.0)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 7.0, end: -7.0)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
    ]).animate(_floatCtrl);

    _particleCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 20))
          ..repeat();
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3600))
      ..repeat();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _floatCtrl.dispose();
    _particleCtrl.dispose();
    _shimmerCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLastEmail() async {
    final email = await _api.getLastEmail();
    if (email != null && mounted) setState(() => _emailCtrl.text = email);
    final supported = await _biometrics.isDeviceSupported;
    if (!mounted) return;
    setState(() => _biometricAvailable = supported);
    if (supported) await _refreshBiometricEnabledState();
  }

  Future<void> _refreshBiometricEnabledState() async {
    final email = _emailCtrl.text.trim();
    final enabled = email.isNotEmpty && await _biometrics.isEnabledFor(email);
    final label = await _biometrics.biometricLabel;
    if (!mounted) return;
    setState(() {
      _biometricEnabledForEmail = enabled;
      _biometricLabel = label;
    });
  }

  // Paso 1 (correo) → paso 2 (contraseña). Antes email y contraseña
  // aparecían juntos; el cliente pidió separarlo en dos pasos.
  Future<void> _goToPasswordStep() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    await _refreshBiometricEnabledState();
    if (!mounted) return;
    setState(() => _step = 1);
    // Si ya hay Face ID habilitado para este correo, lo ofrece de una vez
    // en vez de obligar a tocar el botón — igual se puede cancelar y
    // escribir la contraseña.
    if (_biometricEnabledForEmail) {
      unawaited(_loginWithBiometrics());
    }
  }

  void _backToEmailStep() {
    setState(() {
      _step = 0;
      _error = null;
      _passwordCtrl.clear();
    });
  }

  Future<void> _loginWithBiometrics() async {
    if (_biometricChecking || _loading) return;
    setState(() {
      _biometricChecking = true;
      _error = null;
    });
    try {
      final ok = await _biometrics.authenticate(
        reason: 'Inicia sesión en SAF con $_biometricLabel',
      );
      if (!ok) return;
      final saved = await _biometrics.getSavedCredentials();
      if (saved == null) return;
      _emailCtrl.text = saved.email;
      _passwordCtrl.text = saved.password;
      await _login(skipBiometricPrompt: true);
    } finally {
      if (mounted) setState(() => _biometricChecking = false);
    }
  }

  /// Tras un login manual exitoso, si el equipo soporta Face ID/huella y
  /// esta cuenta todavía no lo tiene activado, ofrece guardarlo para la
  /// próxima vez — sin esto, no hay otra forma de que el usuario active
  /// el ingreso biométrico.
  Future<void> _maybeOfferEnableBiometrics() async {
    if (!_biometricAvailable) return;
    final email = _emailCtrl.text.trim();
    if (await _biometrics.isEnabledFor(email)) return;
    if (!mounted) return;
    final accept = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1830),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('¿Usar $_biometricLabel la próxima vez?',
            style: const TextStyle(color: Colors.white, fontSize: 17)),
        content: Text(
          'Vas a poder entrar sin escribir tu contraseña cada vez.',
          style:
              TextStyle(color: const Color(0xFF8BA7E8).withValues(alpha: 0.9)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ahora no',
                style: TextStyle(color: Color(0xFF8BA7E8))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Activar $_biometricLabel',
                style: const TextStyle(
                    color: Color(0xFF9DA8FF), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (accept == true) {
      await _biometrics.enable(email, _passwordCtrl.text);
    }
  }

  Future<void> _login({bool skipBiometricPrompt = false}) async {
    if (_step == 1 && !_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _api.login(_emailCtrl.text.trim(), _passwordCtrl.text);
      if (!mounted) return;
      if (r['success'] == true) {
        if (!skipBiometricPrompt) await _maybeOfferEnableBiometrics();
        if (!mounted) return;
        // Aplica el tema del usuario que acaba de iniciar sesión ANTES de
        // navegar a Home — si no, se ve por un instante el tema del usuario
        // anterior (guardado localmente) hasta que loadData() termine de
        // sincronizar en segundo plano. Con timeout corto (4s) para no
        // demorar el login si el servidor está lento.
        final codigoUsuario = (_api.user?['codigo_usuario'] ?? '').toString();
        final dark = await _api.fetchThemePreference(codigoUsuario);
        if (dark != null && dark != appThemeDark.value) {
          await setThemeDark(dark);
        }
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        setState(() =>
            _error = r['message'] as String? ?? 'Credenciales incorrectas');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error de conexión. Verifica tu red.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        // ── Background ────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF020714), Color(0xFF070D2A), Color(0xFF0D0840)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),

        // ── Aurora ────────────────────────────────────────────────────
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) =>
                CustomPaint(painter: _AuroraPainter(_particleCtrl.value)),
          ),
        ),

        // ── Dot grid ──────────────────────────────────────────────────
        Positioned.fill(
          child: Opacity(
              opacity: 0.045, child: CustomPaint(painter: _DotGridPainter())),
        ),

        // ── Blobs ─────────────────────────────────────────────────────
        Positioned(
            top: -size.height * 0.15,
            left: -size.width * 0.30,
            child: _blob(size.width * 1.05, const Color(0xFF3A5BF5), 0.38)),
        Positioned(
            top: size.height * 0.08,
            right: -size.width * 0.28,
            child: _blob(size.width * 0.68, const Color(0xFF8B2FC9), 0.32)),
        Positioned(
            bottom: -size.height * 0.10,
            left: size.width * 0.05,
            child: _blob(size.width * 0.72, const Color(0xFF00B4D8), 0.19)),

        // ── Particles ─────────────────────────────────────────────────
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) => CustomPaint(
                painter: _ParticlePainter(_particles, _particleCtrl.value)),
          ),
        ),

        // ── Content ───────────────────────────────────────────────────
        SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: context.sp(24)),
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: Column(children: [
                  SizedBox(height: size.height * 0.045),

                  // ── Logo + radar + orbiting rings ────────────────
                  AnimatedBuilder(
                    animation: Listenable.merge([_pulse, _float]),
                    builder: (_, __) {
                      final logoH = context.h(0.200);
                      final logoBox = context.w(0.906);
                      final outerR = context.w(0.400);
                      final haloR = context.w(0.347);
                      final glassR = context.w(0.320);
                      return Transform.translate(
                        offset: Offset(0, _float.value),
                        child: SizedBox(
                          height: logoH,
                          child: OverflowBox(
                            maxWidth: logoBox,
                            maxHeight: logoBox,
                            child:
                                Stack(alignment: Alignment.center, children: [
                              Container(
                                width: outerR,
                                height: outerR,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      const Color(0xFF00D2FF).withValues(
                                          alpha: 0.24 + 0.08 * _pulse.value),
                                      const Color(0xFF6C63FF).withValues(
                                          alpha: 0.18 + 0.08 * _pulse.value),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.42, 1.0],
                                  ),
                                ),
                              ),
                              // Logo area
                              SizedBox(
                                width: logoH,
                                height: logoH,
                                child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Pulsing glow halo
                                      Container(
                                        width: haloR,
                                        height: haloR,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF6C63FF)
                                                  .withValues(
                                                      alpha: 0.24 +
                                                          0.34 * _pulse.value),
                                              blurRadius:
                                                  44 + 28 * _pulse.value,
                                              spreadRadius:
                                                  -1 + 5 * _pulse.value,
                                            ),
                                            BoxShadow(
                                              color: const Color(0xFF00D2FF)
                                                  .withValues(
                                                      alpha: 0.10 +
                                                          0.16 * _pulse.value),
                                              blurRadius:
                                                  58 + 20 * _pulse.value,
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Glass logo
                                      ClipOval(
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(
                                              sigmaX: 18, sigmaY: 18),
                                          child: Container(
                                            width: glassR,
                                            height: glassR,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: RadialGradient(colors: [
                                                Colors.white
                                                    .withValues(alpha: 0.16),
                                                Colors.white
                                                    .withValues(alpha: 0.05),
                                              ]),
                                              border: Border.all(
                                                color: Colors.white
                                                    .withValues(alpha: 0.24),
                                                width: 1.2,
                                              ),
                                            ),
                                            padding:
                                                EdgeInsets.all(glassR * 0.20),
                                            child: const CustomPaint(
                                                painter: _SafLogoPainter(
                                                    Colors.white)),
                                          ),
                                        ),
                                      ),
                                    ]),
                              ),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 18),

                  // ── SAF shimmer text ──────────────────────────────
                  AnimatedBuilder(
                    animation: _shimmerCtrl,
                    builder: (_, __) {
                      final phase = _shimmerCtrl.value * math.pi * 2;
                      final shimmer = 0.5 - 0.5 * math.cos(phase);
                      final axis = Alignment(math.cos(phase), math.sin(phase));
                      return ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (b) => LinearGradient(
                          begin: axis,
                          end: Alignment(-axis.x, -axis.y),
                          colors: [
                            const Color(0xFFFFFFFF),
                            Color.lerp(
                              const Color(0xFFB8CBFF),
                              Colors.white,
                              0.35 + 0.35 * shimmer,
                            )!,
                            const Color(0xFFFFFFFF),
                          ],
                          stops: const [0.0, 0.52, 1.0],
                        ).createShader(b),
                        child: Text(
                          'SAF',
                          style: TextStyle(
                            fontSize: context.sp(54),
                            fontWeight: FontWeight.w900,
                            letterSpacing: context.sp(16),
                            color: Colors.white,
                            height: 1.0,
                            shadows: [
                              Shadow(
                                color: Color(0xFF6C63FF)
                                    .withValues(alpha: 0.16 + 0.22 * shimmer),
                                blurRadius: 14 + 10 * shimmer,
                              ),
                              Shadow(
                                color: Color(0xFF00D2FF)
                                    .withValues(alpha: 0.08 + 0.14 * shimmer),
                                blurRadius: 22 + 12 * shimmer,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 5),

                  // ── Tagline ───────────────────────────────────────
                  Text(
                    'SOCIEDAD DE AHORROS FAMILIAR',
                    style: TextStyle(
                      color: const Color(0xFF8BA7E8).withValues(alpha: 0.75),
                      fontSize: 9.5,
                      letterSpacing: 2.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  SizedBox(height: size.height * 0.036),

                  // ── Glassmorphism card ────────────────────────────
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, child) => Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF6C63FF)
                                .withValues(alpha: 0.55 + 0.15 * _pulse.value),
                            const Color(0xFF00C6FF)
                                .withValues(alpha: 0.30 + 0.10 * _pulse.value),
                            const Color(0xFF8B2FC9)
                                .withValues(alpha: 0.45 + 0.12 * _pulse.value),
                            const Color(0xFF6C63FF)
                                .withValues(alpha: 0.28 + 0.08 * _pulse.value),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF)
                                .withValues(alpha: 0.28 + 0.18 * _pulse.value),
                            blurRadius: 36 + 16 * _pulse.value,
                            spreadRadius: -5,
                            offset: const Offset(0, 18),
                          ),
                          BoxShadow(
                            color: const Color(0xFF00C6FF)
                                .withValues(alpha: 0.12 + 0.08 * _pulse.value),
                            blurRadius: 56,
                            spreadRadius: -14,
                            offset: const Offset(0, 28),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.38),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(1.5),
                      child: child!,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26.5),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26.5),
                            color:
                                const Color(0xFF07102A).withValues(alpha: 0.88),
                          ),
                          child: Stack(
                            children: [
                              // Inner top light reflection
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 88,
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(26.5),
                                      topRight: Radius.circular(26.5),
                                    ),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.065),
                                        Colors.transparent,
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                    context.sp(24), 28, context.sp(24), 28),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Header
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 46,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF6C63FF),
                                                  Color(0xFF00D2FF)
                                                ],
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF6C63FF)
                                                      .withValues(alpha: 0.75),
                                                  blurRadius: 14,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Bienvenido de nuevo',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: context.sp(22),
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.2,
                                                  ),
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                    _step == 0
                                                        ? 'Ingresa tu correo para continuar'
                                                        : 'Ingresa tu contraseña para continuar',
                                                    style: TextStyle(
                                                        color:
                                                            Color(0xFF8BA7E8),
                                                        fontSize:
                                                            context.sp(12.5))),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 22),

                                      Container(
                                        height: 1,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [
                                            Colors.transparent,
                                            Colors.white
                                                .withValues(alpha: 0.14),
                                            Colors.transparent,
                                          ]),
                                        ),
                                      ),

                                      const SizedBox(height: 22),

                                      // Email — mismo campo siempre; solo
                                      // cambia si se puede editar o no. Así
                                      // no "salta" de un estilo a otro entre
                                      // pasos. El botón de editar va FUERA
                                      // del campo (en un Stack encima) en vez
                                      // de como suffixIcon: un TextFormField
                                      // con enabled:false bloquea también los
                                      // toques dentro de su propia decoración
                                      // (incluido el suffixIcon), así que
                                      // dentro del campo el botón quedaba
                                      // muerto.
                                      Stack(
                                        alignment: Alignment.centerRight,
                                        children: [
                                          _GlowField(
                                            ctrl: _emailCtrl,
                                            label: 'Correo electrónico',
                                            icon: Icons.email_outlined,
                                            enabled: _step == 0,
                                            // Placeholder sin interacción:
                                            // solo reserva el espacio que
                                            // ocupa el botón de editar (que
                                            // vive aparte, superpuesto) para
                                            // que un correo largo no quede
                                            // debajo de él.
                                            suffixIcon: _step == 1
                                                ? const SizedBox(width: 40)
                                                : null,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            textInputAction:
                                                TextInputAction.done,
                                            onSubmitted: (_) =>
                                                _goToPasswordStep(),
                                            validator: (v) {
                                              if (v == null ||
                                                  v.trim().isEmpty) {
                                                return 'Ingresa tu correo';
                                              }
                                              if (!v.contains('@')) {
                                                return 'Correo inválido';
                                              }
                                              return null;
                                            },
                                          ),
                                          if (_step == 1)
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.edit_outlined,
                                                  color: Color(0xFF8BA7E8),
                                                  size: 19),
                                              onPressed: _backToEmailStep,
                                            ),
                                        ],
                                      ),

                                      const SizedBox(height: 22),

                                      // Lo que cambia entre pasos (botón
                                      // "Siguiente" vs. Face ID/contraseña)
                                      // entra con fade + slide hacia arriba,
                                      // y la tarjeta crece/encoge con la
                                      // misma duración — para que se note
                                      // que es una animación y no un salto
                                      // seco, y sin dejar el hueco vacío que
                                      // quedaba antes.
                                      AnimatedSize(
                                        duration:
                                            const Duration(milliseconds: 360),
                                        curve: Curves.easeInOutCubic,
                                        alignment: Alignment.topCenter,
                                        child: AnimatedSwitcher(
                                          duration:
                                              const Duration(milliseconds: 320),
                                          switchInCurve: Curves.easeOutCubic,
                                          switchOutCurve: Curves.easeInCubic,
                                          transitionBuilder: (child, anim) =>
                                              FadeTransition(
                                            opacity: anim,
                                            child: SlideTransition(
                                              position: Tween<Offset>(
                                                begin: const Offset(0, 0.10),
                                                end: Offset.zero,
                                              ).animate(anim),
                                              child: child,
                                            ),
                                          ),
                                          child: _step == 0
                                              ? _ShimmerButton(
                                                  key: const ValueKey(
                                                      'step_email'),
                                                  shimmerCtrl: _shimmerCtrl,
                                                  pulseAnim: _pulse,
                                                  loading: false,
                                                  onPressed: _goToPasswordStep,
                                                  label: 'Siguiente',
                                                  icon: Icons
                                                      .arrow_forward_rounded,
                                                )
                                              : Column(
                                                  key: const ValueKey(
                                                      'step_password'),
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    // Face ID/huella — solo
                                                    // si ya está habilitado
                                                    // para este correo.
                                                    if (_biometricEnabledForEmail) ...[
                                                      _BiometricButton(
                                                        label: _biometricLabel,
                                                        checking:
                                                            _biometricChecking,
                                                        onTap:
                                                            _loginWithBiometrics,
                                                      ),
                                                      const SizedBox(
                                                          height: 16),
                                                      Row(children: [
                                                        Expanded(
                                                            child: Container(
                                                                height: 1,
                                                                color: Colors
                                                                    .white
                                                                    .withValues(
                                                                        alpha:
                                                                            0.10))),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      10),
                                                          child: Text(
                                                              'o ingresa tu contraseña',
                                                              style: TextStyle(
                                                                  color: const Color(
                                                                          0xFF8BA7E8)
                                                                      .withValues(
                                                                          alpha:
                                                                              0.65),
                                                                  fontSize:
                                                                      11.5)),
                                                        ),
                                                        Expanded(
                                                            child: Container(
                                                                height: 1,
                                                                color: Colors
                                                                    .white
                                                                    .withValues(
                                                                        alpha:
                                                                            0.10))),
                                                      ]),
                                                      const SizedBox(
                                                          height: 16),
                                                    ],

                                                    // Password
                                                    _GlowField(
                                                      ctrl: _passwordCtrl,
                                                      label: 'Contraseña',
                                                      icon: Icons
                                                          .lock_outline_rounded,
                                                      obscure: _obscure,
                                                      textInputAction:
                                                          TextInputAction.done,
                                                      onSubmitted: (_) =>
                                                          _login(),
                                                      suffixIcon: IconButton(
                                                        icon: Icon(
                                                          _obscure
                                                              ? Icons
                                                                  .visibility_off_outlined
                                                              : Icons
                                                                  .visibility_outlined,
                                                          color: const Color(
                                                              0xFF8BA7E8),
                                                          size: 20,
                                                        ),
                                                        onPressed: () =>
                                                            setState(() =>
                                                                _obscure =
                                                                    !_obscure),
                                                      ),
                                                      validator: (v) {
                                                        if (v == null ||
                                                            v.isEmpty) {
                                                          return 'Ingresa tu contraseña';
                                                        }
                                                        return null;
                                                      },
                                                    ),

                                                    const SizedBox(height: 22),

                                                    _ShimmerButton(
                                                      shimmerCtrl: _shimmerCtrl,
                                                      pulseAnim: _pulse,
                                                      loading: _loading,
                                                      onPressed: _login,
                                                      label: 'Iniciar Sesión',
                                                      icon: Icons
                                                          .arrow_forward_rounded,
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),

                                      // Error
                                      if (_error != null) ...[
                                        const SizedBox(height: 14),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 11),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF4B6E)
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: const Color(0xFFFF4B6E)
                                                    .withValues(alpha: 0.35)),
                                          ),
                                          child: Row(children: [
                                            const Icon(Icons.error_outline,
                                                color: Color(0xFFFF6B8A),
                                                size: 17),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(_error!,
                                                  style: const TextStyle(
                                                      color: Color(0xFFFF9BAF),
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w500)),
                                            ),
                                          ]),
                                        ),
                                      ],

                                      const SizedBox(height: 18),

                                      // Forgot password
                                      if (_step == 1)
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text('¿Olvidaste tu contraseña? ',
                                                style: TextStyle(
                                                    color:
                                                        const Color(0xFF8BA7E8)
                                                            .withValues(
                                                                alpha: 0.80),
                                                    fontSize: 13)),
                                            GestureDetector(
                                              onTap: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (_) =>
                                                          const ForgotPasswordScreen())),
                                              child: ShaderMask(
                                                shaderCallback: (b) =>
                                                    const LinearGradient(
                                                  colors: [
                                                    Color(0xFF7C8EFF),
                                                    Color(0xFF00C6FF)
                                                  ],
                                                ).createShader(b),
                                                child: const Text('Recuperar',
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w700)),
                                              ),
                                            ),
                                          ],
                                        ),

                                      const SizedBox(height: 22),

                                      Container(
                                        height: 1,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [
                                            Colors.transparent,
                                            Colors.white
                                                .withValues(alpha: 0.10),
                                            Colors.transparent,
                                          ]),
                                        ),
                                      ),

                                      const SizedBox(height: 18),

                                      // Trust badges
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _trustBadge(
                                              Icons.lock_rounded,
                                              'SSL Seguro',
                                              const Color(0xFF34D399)),
                                          _trustBadge(
                                              Icons.verified_user_rounded,
                                              'Encriptado',
                                              const Color(0xFF38BDF8)),
                                          _trustBadge(
                                              Icons.shield_rounded,
                                              'Protegido',
                                              const Color(0xFFA78BFA)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: size.height * 0.036),

                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                          width: 28,
                          height: 1,
                          color:
                              const Color(0xFF5A6E99).withValues(alpha: 0.55)),
                      const SizedBox(width: 10),
                      Text(
                        'Plataforma de Creación y Gestión de Préstamos',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color:
                              const Color(0xFFADBBE8).withValues(alpha: 0.60),
                          fontSize: 10.5,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                          width: 28,
                          height: 1,
                          color:
                              const Color(0xFF5A6E99).withValues(alpha: 0.55)),
                    ],
                  ),
                  const SizedBox(height: 28),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _blob(double size, Color color, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
              colors: [color.withValues(alpha: opacity), Colors.transparent]),
        ),
      );

  Widget _trustBadge(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.14),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Color.lerp(color, Colors.white, 0.55),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ]),
      );
}

// ── Dark Glow Field ───────────────────────────────────────────────────────────
class _GlowField extends StatefulWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final bool obscure;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  const _GlowField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.obscure = false,
    this.suffixIcon,
    this.validator,
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
  });

  @override
  State<_GlowField> createState() => _GlowFieldState();
}

class _GlowFieldState extends State<_GlowField>
    with SingleTickerProviderStateMixin {
  late final FocusNode _focus;
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeOutCubic);
    _focus.addListener(
        () => _focus.hasFocus ? _glowCtrl.forward() : _glowCtrl.reverse());
  }

  @override
  void dispose() {
    _focus.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF)
                  .withValues(alpha: 0.48 * _glowAnim.value),
              blurRadius: 22 * _glowAnim.value,
            ),
            BoxShadow(
              color: const Color(0xFF00C6FF)
                  .withValues(alpha: 0.28 * _glowAnim.value),
              blurRadius: 34 * _glowAnim.value,
              spreadRadius: -3,
            ),
          ],
        ),
        child: child,
      ),
      child: TextFormField(
        controller: widget.ctrl,
        focusNode: _focus,
        enabled: widget.enabled,
        keyboardType: widget.keyboardType,
        obscureText: widget.obscure,
        autocorrect: false,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onSubmitted,
        cursorColor: const Color(0xFF9DA8FF),
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: const TextStyle(color: Color(0xFF8BA7E8), fontSize: 14),
          floatingLabelStyle: const TextStyle(
              color: Color(0xFF9DA8FF),
              fontSize: 12,
              fontWeight: FontWeight.w600),
          prefixIcon:
              Icon(widget.icon, color: const Color(0xFF7C8EFF), size: 20),
          suffixIcon: widget.suffixIcon,
          filled: true,
          fillColor: const Color(0xFF0D1830).withValues(alpha: 0.72),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.12))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.12))),
          disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.12))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFF6C63FF), width: 1.8)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFFF4B6E))),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFFFF4B6E), width: 1.8)),
          errorStyle: const TextStyle(color: Color(0xFFFF8090), fontSize: 11.5),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
        validator: widget.validator,
      ),
    );
  }
}

// ── Shimmer Button ────────────────────────────────────────────────────────────
class _ShimmerButton extends StatelessWidget {
  final AnimationController shimmerCtrl;
  final Animation<double> pulseAnim;
  final bool loading;
  final VoidCallback onPressed;
  final String label;
  final IconData icon;

  const _ShimmerButton({
    super.key,
    required this.shimmerCtrl,
    required this.pulseAnim,
    required this.loading,
    required this.onPressed,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final btnH = (MediaQuery.of(context).size.height * 0.072).clamp(50.0, 66.0);
    return SizedBox(
      width: double.infinity,
      height: btnH,
      child: Stack(children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, __) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF5B54F5),
                    Color(0xFF3B82F6),
                    Color(0xFF00C6FF)
                  ],
                  stops: [0.0, 0.5, 1.0],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5B54F5)
                        .withValues(alpha: 0.50 + 0.20 * pulseAnim.value),
                    blurRadius: 26 + 12 * pulseAnim.value,
                    offset: const Offset(0, 8),
                    spreadRadius: -2,
                  ),
                  BoxShadow(
                    color: const Color(0xFF00C6FF).withValues(alpha: 0.24),
                    blurRadius: 22,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Top gloss highlight
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              height: 26,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.20),
                    Colors.white.withValues(alpha: 0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ),
        // Shimmer sweep
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: shimmerCtrl,
                builder: (_, __) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(shimmerCtrl.value * 4.0 - 2.5, -1),
                      end: Alignment(shimmerCtrl.value * 4.0 - 1.3, 1),
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.30),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: ElevatedButton(
            onPressed: loading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: Colors.white)),
                      const SizedBox(width: 8),
                      Icon(icon, color: Colors.white, size: 18),
                    ],
                  ),
          ),
        ),
      ]),
    );
  }
}

// ── Botón Face ID / huella ────────────────────────────────────────────────────
class _BiometricButton extends StatelessWidget {
  final String label;
  final bool checking;
  final VoidCallback onTap;

  const _BiometricButton({
    required this.label,
    required this.checking,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: checking ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.55)),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF6C63FF).withValues(alpha: 0.18),
              const Color(0xFF00C6FF).withValues(alpha: 0.10),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (checking)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: Color(0xFF9DA8FF)),
              )
            else
              Icon(
                  label == 'huella digital'
                      ? Icons.fingerprint_rounded
                      : Icons.face_retouching_natural_rounded,
                  color: const Color(0xFF9DA8FF),
                  size: 20),
            const SizedBox(width: 10),
            Text(
              checking ? 'Verificando…' : 'Ingresar con $label',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
