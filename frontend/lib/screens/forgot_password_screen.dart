import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final ApiService _api = ApiService();

  bool _loading = false;

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
    final rng = math.Random(17);
    _particles = List.generate(
        30,
        (i) => _Particle(
              x: rng.nextDouble(),
              startY: rng.nextDouble(),
              radius: rng.nextDouble() * 2.2 + 0.7,
              speed: rng.nextDouble() * 0.055 + 0.02,
              alpha: rng.nextDouble() * 0.35 + 0.12,
              phase: rng.nextDouble() * math.pi * 2,
              color: _colors[i % _colors.length],
            ));

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 950))
      ..forward();
    _fadeIn = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.10), end: Offset.zero)
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
        vsync: this, duration: const Duration(milliseconds: 3200))
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
    super.dispose();
  }

  Future<void> _restablecer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final response = await _api.post('/ajax/restablecer_contrasenia.php', {
        'email': _emailCtrl.text.trim(),
        'codigo_tipo_usuario': '1',
      });
      if (!mounted) return;
      final data = _parseJson(response.body);
      final resultado = data['resultado'];
      final bool ok = resultado == 1 || resultado == '1' || resultado == true;
      final String msg = data['mensaje']?.toString() ??
          data['message']?.toString() ??
          (ok
              ? 'Contraseña enviada a tu correo.'
              : 'No se pudo restablecer la contraseña.');
      _showResult(ok, msg);
      if (ok) _emailCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      _showResult(false, _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _parseJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {};
  }

  String _friendlyError(dynamic e) {
    final raw = e.toString().replaceFirst('Exception: ', '').trim();
    if (RegExp(r'\b(400|401|403|404|500|502|503|504)\b').hasMatch(raw)) {
      return 'No se pudo completar la operación. Por favor intenta de nuevo.';
    }
    if (raw.toLowerCase().contains('socket') ||
        raw.toLowerCase().contains('connection') ||
        raw.toLowerCase().contains('network')) {
      return 'Sin conexión a internet. Verifica tu red e intenta de nuevo.';
    }
    if (raw.toLowerCase().contains('timeout')) {
      return 'La operación tardó demasiado. Por favor intenta de nuevo.';
    }
    if (raw.isEmpty || raw.length > 300) {
      return 'Ocurrió un error inesperado. Por favor intenta de nuevo.';
    }
    return raw;
  }

  void _showResult(bool ok, String msg) {
    if (!mounted) return;
    showDialog(context: context, builder: (_) => _resultDialog(msg, ok));
  }

  Widget _resultDialog(String msg, bool ok) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF6C63FF).withValues(alpha: 0.5),
                const Color(0xFF00C6FF).withValues(alpha: 0.3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(1.5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.5),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: const Color(0xFF07102A).withValues(alpha: 0.92),
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: ok
                              ? [
                                  const Color(0xFF059669),
                                  const Color(0xFF34D399)
                                ]
                              : [
                                  const Color(0xFFDC2626),
                                  const Color(0xFFEF4444)
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (ok
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFDC2626))
                                .withValues(alpha: 0.45),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        ok ? Icons.check_rounded : Icons.error_outline_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      ok ? '¡Operación exitosa!' : 'Algo salió mal',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(msg,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.65))),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        if (ok) Navigator.pop(context);
                      },
                      child: Container(
                        width: double.infinity,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: ok
                                ? [
                                    const Color(0xFF059669),
                                    const Color(0xFF34D399)
                                  ]
                                : [
                                    const Color(0xFFDC2626),
                                    const Color(0xFFEF4444)
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: (ok
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFDC2626))
                                  .withValues(alpha: 0.40),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('Aceptar',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        // Background
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

        // Aurora
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) =>
                CustomPaint(painter: _AuroraPainter(_particleCtrl.value)),
          ),
        ),

        // Dot grid
        Positioned.fill(
          child: Opacity(
              opacity: 0.04, child: CustomPaint(painter: _DotGridPainter())),
        ),

        // Blobs
        Positioned(
            top: -size.height * 0.12,
            left: -size.width * 0.32,
            child: _blob(size.width * 1.0, const Color(0xFF3A5BF5), 0.38)),
        Positioned(
            top: size.height * 0.06,
            right: -size.width * 0.28,
            child: _blob(size.width * 0.66, const Color(0xFF8B2FC9), 0.32)),
        Positioned(
            bottom: -size.height * 0.08,
            left: size.width * 0.08,
            child: _blob(size.width * 0.68, const Color(0xFF00B4D8), 0.18)),

        // Particles
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) => CustomPaint(
                painter: _ParticlePainter(_particles, _particleCtrl.value)),
          ),
        ),

        // Content
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: Column(children: [
                  SizedBox(height: size.height * 0.055),

                  // Icon with radar + orbit rings
                  AnimatedBuilder(
                    animation: Listenable.merge([_pulse, _float]),
                    builder: (_, __) {
                      return Transform.translate(
                        offset: Offset(0, _float.value),
                        child: SizedBox(
                          height: 164,
                          child: OverflowBox(
                            maxWidth: 320,
                            maxHeight: 320,
                            child:
                                Stack(alignment: Alignment.center, children: [
                              Container(
                                width: 150,
                                height: 150,
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
                              // Icon area (148x148)
                              SizedBox(
                                width: 164,
                                height: 164,
                                child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Glow
                                      Container(
                                        width: 130,
                                        height: 130,
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
                                      // Glass icon
                                      ClipOval(
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(
                                              sigmaX: 18, sigmaY: 18),
                                          child: Container(
                                            width: 120,
                                            height: 120,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: RadialGradient(colors: [
                                                Colors.white
                                                    .withValues(alpha: 0.14),
                                                Colors.white
                                                    .withValues(alpha: 0.05),
                                              ]),
                                              border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.22),
                                                  width: 1.2),
                                            ),
                                            child: const Icon(
                                              Icons.lock_reset_rounded,
                                              color: Colors.white,
                                              size: 58,
                                            ),
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

                  // SAF shimmer
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
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 14,
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

                  const SizedBox(height: 4),

                  Text(
                    'RECUPERACIÓN DE ACCESO',
                    style: TextStyle(
                      color: const Color(0xFF8BA7E8).withValues(alpha: 0.75),
                      fontSize: 9.5,
                      letterSpacing: 2.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  SizedBox(height: size.height * 0.036),

                  // Glassmorphism card
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
                            blurRadius: 34 + 16 * _pulse.value,
                            spreadRadius: -5,
                            offset: const Offset(0, 18),
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
                          child: Stack(children: [
                            // Inner glass highlight
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
                              padding:
                                  const EdgeInsets.fromLTRB(24, 28, 24, 28),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 54,
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
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '¿Olvidaste tu contraseña?',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                              SizedBox(height: 5),
                                              Text(
                                                'Te enviaremos una nueva contraseña\na tu correo registrado',
                                                style: TextStyle(
                                                    color: Color(0xFF8BA7E8),
                                                    fontSize: 12),
                                              ),
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
                                          Colors.white.withValues(alpha: 0.14),
                                          Colors.transparent,
                                        ]),
                                      ),
                                    ),

                                    const SizedBox(height: 22),

                                    // Email
                                    _GlowField(
                                      ctrl: _emailCtrl,
                                      label: 'Correo electrónico',
                                      icon: Icons.email_outlined,
                                      keyboardType: TextInputType.emailAddress,
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

                                    const SizedBox(height: 24),

                                    _ShimmerButton(
                                      shimmerCtrl: _shimmerCtrl,
                                      pulseAnim: _pulse,
                                      loading: _loading,
                                      onPressed: _restablecer,
                                      label: 'Restablecer contraseña',
                                    ),

                                    const SizedBox(height: 20),

                                    // Back to login
                                    Center(
                                      child: GestureDetector(
                                        onTap: () => Navigator.pop(context),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ShaderMask(
                                              shaderCallback: (b) =>
                                                  const LinearGradient(
                                                colors: [
                                                  Color(0xFF7C8EFF),
                                                  Color(0xFF00C6FF)
                                                ],
                                              ).createShader(b),
                                              child: const Icon(
                                                  Icons.arrow_back_rounded,
                                                  color: Colors.white,
                                                  size: 15),
                                            ),
                                            const SizedBox(width: 5),
                                            ShaderMask(
                                              shaderCallback: (b) =>
                                                  const LinearGradient(
                                                colors: [
                                                  Color(0xFF7C8EFF),
                                                  Color(0xFF00C6FF)
                                                ],
                                              ).createShader(b),
                                              child: const Text(
                                                'Volver al inicio de sesión',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: size.height * 0.04),
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
}

// ── Dark Glow Field ───────────────────────────────────────────────────────────
class _GlowField extends StatefulWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;

  const _GlowField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.textInputAction,
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
        keyboardType: widget.keyboardType,
        autocorrect: false,
        textInputAction: widget.textInputAction,
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

  const _ShimmerButton({
    required this.shimmerCtrl,
    required this.pulseAnim,
    required this.loading,
    required this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
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
                    color: const Color(0xFF00C6FF).withValues(alpha: 0.22),
                    blurRadius: 22,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
        ),
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
                : Text(label,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
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

class _AuroraPainter extends CustomPainter {
  final double t;
  const _AuroraPainter(this.t);

  void _band(
    Canvas canvas,
    Size size, {
    required double cx,
    required double cy,
    required double rx,
    required double ry,
    required Color c1,
    required Color c2,
    required double a,
  }) {
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
        a: 0.22);
    _band(canvas, size,
        cx: size.width * (0.75 + 0.11 * math.cos(t * math.pi * 2 * 0.6)),
        cy: size.height * (0.52 + 0.10 * math.sin(t * math.pi * 2 * 0.4)),
        rx: size.width * 0.90,
        ry: size.height * 0.22,
        c1: const Color(0xFF00B4D8),
        c2: const Color(0xFF0077B6),
        a: 0.15);
    _band(canvas, size,
        cx: size.width * (0.50 + 0.08 * math.sin(t * math.pi * 2 * 0.35)),
        cy: size.height * (0.80 + 0.07 * math.cos(t * math.pi * 2 * 0.9)),
        rx: size.width * 0.82,
        ry: size.height * 0.24,
        c1: const Color(0xFF8B2FC9),
        c2: const Color(0xFF6C63FF),
        a: 0.18);
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t;
}
