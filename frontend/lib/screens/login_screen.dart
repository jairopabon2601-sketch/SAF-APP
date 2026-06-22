import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'forgot_password_screen.dart';

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

// ── Grid background ───────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.5;
    const s = 32.0;
    for (double x = 0; x < size.width; x += s) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += s) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}

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
  bool _obscure = true;
  bool _loading = false;
  String? _error;

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
        34,
        (i) => _Particle(
              x: rng.nextDouble(),
              startY: rng.nextDouble(),
              radius: rng.nextDouble() * 2.4 + 0.8,
              speed: rng.nextDouble() * 0.06 + 0.02,
              alpha: rng.nextDouble() * 0.40 + 0.15,
              phase: rng.nextDouble() * math.pi * 2,
              color: _colors[i % _colors.length],
            ));

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..forward();
    _fadeIn = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.10), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200))
      ..repeat(reverse: true);
    _float = Tween<double>(begin: -6.0, end: 6.0)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _particleCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 18))
          ..repeat();

    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
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
    if (email != null && mounted) {
      setState(() => _emailCtrl.text = email);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _api.login(_emailCtrl.text.trim(), _passwordCtrl.text);
      if (!mounted) return;
      if (r['success'] == true) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        setState(() =>
            _error = r['message'] as String? ?? 'Credenciales incorrectas');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error de conexión: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF03061A),
                  Color(0xFF080E35),
                  Color(0xFF10094A)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Grid
          Positioned.fill(
            child: Opacity(
                opacity: 0.03, child: CustomPaint(painter: _GridPainter())),
          ),

          // Blobs
          Positioned(
              top: -size.height * 0.12,
              left: -size.width * 0.35,
              child: _blob(size.width * 1.0, const Color(0xFF3A5BF5), 0.40)),
          Positioned(
              top: size.height * 0.05,
              right: -size.width * 0.3,
              child: _blob(size.width * 0.70, const Color(0xFF8B2FC9), 0.35)),
          Positioned(
              bottom: -size.height * 0.08,
              left: size.width * 0.1,
              child: _blob(size.width * 0.75, const Color(0xFF00B4D8), 0.22)),

          // Particles
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleCtrl,
              builder: (_, __) => CustomPaint(
                painter: _ParticlePainter(_particles, _particleCtrl.value),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideUp,
                  child: Column(
                    children: [
                      SizedBox(height: size.height * 0.055),

                      // ── Logo (float + pulse) ──────────────────────
                      AnimatedBuilder(
                        animation: Listenable.merge([_pulse, _float]),
                        builder: (_, __) => Transform.translate(
                          offset: Offset(0, _float.value),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 124,
                                height: 124,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF6C63FF)
                                        .withValues(alpha: 0.3 * _pulse.value),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6C63FF).withValues(
                                          alpha: 0.55 * _pulse.value),
                                      blurRadius: 55 + 15 * _pulse.value,
                                      spreadRadius: 2 + 4 * _pulse.value,
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFF00D2FF).withValues(
                                          alpha: 0.20 * _pulse.value),
                                      blurRadius: 80,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                              ),
                              ClipOval(
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                                  child: Container(
                                    width: 112,
                                    height: 112,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          Colors.white.withValues(alpha: 0.08),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.18),
                                        width: 1,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(20),
                                    child: const CustomPaint(
                                      painter: _SafLogoPainter(Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── SAF (animated shimmer) ────────────────────
                      AnimatedBuilder(
                        animation: _shimmerCtrl,
                        builder: (_, __) {
                          final shineX = _shimmerCtrl.value * 3.5 - 1.75;
                          return ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (b) => LinearGradient(
                              begin: Alignment(shineX - 1.0, -1),
                              end: Alignment(shineX + 1.0, 1),
                              colors: const [
                                Colors.white,
                                Color(0xFF9DB8FF),
                                Color(0xFFFFFFFF),
                                Color(0xFF9DB8FF),
                              ],
                              stops: const [0.0, 0.35, 0.65, 1.0],
                            ).createShader(b),
                            child: const Text(
                              'SAF',
                              style: TextStyle(
                                fontSize: 54,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 14,
                                color: Colors.white,
                                height: 1.0,
                              ),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: size.height * 0.042),

                      // ── Card ─────────────────────────────────────
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, child) => Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6C63FF).withValues(
                                    alpha: 0.35 + 0.20 * _pulse.value),
                                blurRadius: 28 + 18 * _pulse.value,
                                spreadRadius: -4,
                                offset: const Offset(0, 16),
                              ),
                              BoxShadow(
                                color: const Color(0xFF8B2FC9).withValues(
                                    alpha: 0.20 + 0.12 * _pulse.value),
                                blurRadius: 55 + 20 * _pulse.value,
                                spreadRadius: -10,
                                offset: const Offset(0, 26),
                              ),
                              BoxShadow(
                                color: const Color(0xFF00C6FF).withValues(
                                    alpha: 0.15 + 0.08 * _pulse.value),
                                blurRadius: 40,
                                spreadRadius: -14,
                                offset: const Offset(0, 30),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.30),
                                blurRadius: 22,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: child!,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Gradient top accent
                              Container(
                                height: 5,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF6C63FF),
                                      Color(0xFF00C6FF),
                                      Color(0xFF8B2FC9)
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                color: Colors.white,
                                padding:
                                    const EdgeInsets.fromLTRB(24, 26, 24, 30),
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
                                            height: 40,
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
                                                      .withValues(alpha: 0.6),
                                                  blurRadius: 10,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          const Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('Bienvenido de nuevo',
                                                  style: TextStyle(
                                                      color: Color(0xFF0D1B4B),
                                                      fontSize: 22,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      letterSpacing: 0.3)),
                                              SizedBox(height: 3),
                                              Text(
                                                  'Ingresa tus credenciales para continuar',
                                                  style: TextStyle(
                                                      color: Color(0xFF6B7DB3),
                                                      fontSize: 12.5)),
                                            ],
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 24),

                                      Container(
                                        height: 1,
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(colors: [
                                            Colors.transparent,
                                            Color(0xFFE0E4F5),
                                            Colors.transparent,
                                          ]),
                                        ),
                                      ),

                                      const SizedBox(height: 22),

                                      // ── Email ──────────────────
                                      _GlowField(
                                        ctrl: _emailCtrl,
                                        label: 'Correo electrónico',
                                        icon: Icons.email_outlined,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'Ingresa tu correo';
                                          }
                                          if (!v.contains('@')) {
                                            return 'Correo inválido';
                                          }
                                          return null;
                                        },
                                      ),

                                      const SizedBox(height: 14),

                                      // ── Password ───────────────
                                      _GlowField(
                                        ctrl: _passwordCtrl,
                                        label: 'Contraseña',
                                        icon: Icons.lock_outline_rounded,
                                        obscure: _obscure,
                                        textInputAction: TextInputAction.done,
                                        onSubmitted: (_) => _login(),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscure
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            color: const Color(0xFF6B7DB3),
                                            size: 20,
                                          ),
                                          onPressed: () => setState(
                                              () => _obscure = !_obscure),
                                        ),
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return 'Ingresa tu contraseña';
                                          }
                                          return null;
                                        },
                                      ),

                                      // Error
                                      if (_error != null) ...[
                                        const SizedBox(height: 14),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF4B6E)
                                                .withValues(alpha: 0.14),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: const Color(0xFFFF4B6E)
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Row(children: [
                                            const Icon(Icons.error_outline,
                                                color: Color(0xFFFF6B8A),
                                                size: 18),
                                            const SizedBox(width: 8),
                                            Expanded(
                                                child: Text(_error!,
                                                    style: const TextStyle(
                                                        color:
                                                            Color(0xFFFF9BAF),
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w500))),
                                          ]),
                                        ),
                                      ],

                                      const SizedBox(height: 20),

                                      // ── Button with shimmer ─────
                                      _ShimmerButton(
                                        shimmerCtrl: _shimmerCtrl,
                                        pulseAnim: _pulse,
                                        loading: _loading,
                                        onPressed: _login,
                                        label: 'Iniciar Sesión',
                                        icon: Icons.arrow_forward_rounded,
                                      ),

                                      const SizedBox(height: 20),

                                      // Forgot password
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Text(
                                            '¿Olvidaste tu contraseña? ',
                                            style: TextStyle(
                                              color: Color(0xFF8899BB),
                                              fontSize: 13,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const ForgotPasswordScreen(),
                                              ),
                                            ),
                                            child: ShaderMask(
                                              shaderCallback: (b) =>
                                                  const LinearGradient(
                                                colors: [
                                                  Color(0xFF5B54F5),
                                                  Color(0xFF00C6FF)
                                                ],
                                              ).createShader(b),
                                              child: const Text(
                                                'Recuperar',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
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

                      SizedBox(height: size.height * 0.038),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                              width: 36, height: 1,
                              color: const Color(0xFF7A8FCC)),
                          const SizedBox(width: 10),
                          const Text(
                            'Plataforma de Creación y Gestión de Préstamos',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFADBBE8),
                              fontSize: 11,
                              letterSpacing: 0.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                              width: 36, height: 1,
                              color: const Color(0xFF7A8FCC)),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: opacity), Colors.transparent],
          ),
        ),
      );
}

// ── Glow-on-focus text field ──────────────────────────────────────────────────

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
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _glowAnim =
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeOutCubic);
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focus.hasFocus) {
      _glowCtrl.forward();
    } else {
      _glowCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
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
                  .withValues(alpha: 0.44 * _glowAnim.value),
              blurRadius: 24 * _glowAnim.value,
            ),
            BoxShadow(
              color: const Color(0xFF00C6FF)
                  .withValues(alpha: 0.28 * _glowAnim.value),
              blurRadius: 36 * _glowAnim.value,
              spreadRadius: -3,
            ),
          ],
        ),
        child: child,
      ),
      child: TextFormField(
        controller: widget.ctrl,
        focusNode: _focus,
        keyboardType: widget.keyboardType,
        obscureText: widget.obscure,
        autocorrect: false,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onSubmitted,
        style: const TextStyle(color: Color(0xFF0D1B4B), fontSize: 15),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle:
              const TextStyle(color: Color(0xFF8899BB), fontSize: 14),
          floatingLabelStyle: const TextStyle(
              color: Color(0xFF6C63FF),
              fontSize: 12,
              fontWeight: FontWeight.w600),
          prefixIcon:
              Icon(widget.icon, color: const Color(0xFF6C63FF), size: 20),
          suffixIcon: widget.suffixIcon,
          filled: true,
          fillColor: const Color(0xFFF4F5FF),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE0E4F5))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE0E4F5))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFF6C63FF), width: 2.0)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFFF4B6E))),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFFFF4B6E), width: 2.0)),
          errorStyle: const TextStyle(color: Color(0xFFD32F2F)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
        validator: widget.validator,
      ),
    );
  }
}

// ── Shimmer button ────────────────────────────────────────────────────────────

class _ShimmerButton extends StatelessWidget {
  final AnimationController shimmerCtrl;
  final Animation<double> pulseAnim;
  final bool loading;
  final VoidCallback onPressed;
  final String label;
  final IconData icon;

  const _ShimmerButton({
    required this.shimmerCtrl,
    required this.pulseAnim,
    required this.loading,
    required this.onPressed,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Stack(
        children: [
          // Gradient background + pulse shadow
          Positioned.fill(
            child: AnimatedBuilder(
              animation: pulseAnim,
              builder: (_, __) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5B54F5), Color(0xFF00C6FF)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5B54F5)
                          .withValues(alpha: 0.45 + 0.2 * pulseAnim.value),
                      blurRadius: 24 + 10 * pulseAnim.value,
                      offset: const Offset(0, 8),
                      spreadRadius: -2,
                    ),
                    BoxShadow(
                      color:
                          const Color(0xFF00C6FF).withValues(alpha: 0.22),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                        begin: Alignment(
                            shimmerCtrl.value * 4.0 - 2.5, -1),
                        end:
                            Alignment(shimmerCtrl.value * 4.0 - 1.3, 1),
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.28),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Tap target + content
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
        ],
      ),
    );
  }
}
