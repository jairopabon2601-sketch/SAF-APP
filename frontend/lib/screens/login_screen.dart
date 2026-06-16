import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

// ── SAF Logo Painter ────────────────────────────────────────────────────────
class _SafLogoPainter extends CustomPainter {
  final Color color;
  const _SafLogoPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width * 0.38;
    final nodeR = size.width * 0.115;
    final ringW = size.width * 0.07;

    final gapAngle = 2 * math.asin(nodeR / r) + 0.06;

    final angles = [
      -math.pi * 3 / 4,
      -math.pi / 4,
       math.pi / 4,
       math.pi * 3 / 4,
    ];

    final ringPaint = Paint()
      ..color = color
      ..strokeWidth = ringW
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    for (int i = 0; i < angles.length; i++) {
      final start = angles[i] + gapAngle / 2;
      var   sweep = (angles[(i + 1) % angles.length] - gapAngle / 2) - start;
      if (sweep < 0) sweep += math.pi * 2;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        start, sweep, false, ringPaint,
      );
    }

    final dotPaint = Paint()..color = color..style = PaintingStyle.fill;
    for (final a in angles) {
      canvas.drawCircle(
        Offset(cx + r * math.cos(a), cy + r * math.sin(a)),
        nodeR, dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_SafLogoPainter old) => old.color != color;
}

// ── Login Screen ────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey             = GlobalKey<FormState>();
  final _emailController     = TextEditingController();
  final _passwordController  = TextEditingController();
  final ApiService _api      = ApiService();

  bool    _obscurePassword = true;
  bool    _isLoading       = false;
  String? _errorMessage;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeIn;
  late Animation<Offset>   _slideUp;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeIn   = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp  = Tween<Offset>(begin: const Offset(0, 0.10), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final result = await _api.login(
        _emailController.text.trim(), _passwordController.text);
      if (!mounted) return;
      if (result['success'] == true || result['token'] != null) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        setState(() => _errorMessage = result['message'] ?? 'Credenciales incorrectas');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Error de conexión. Verifica tu red.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Deep background ─────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF03061A), Color(0xFF080E35), Color(0xFF10094A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ── Large ambient glow top-left ─────────────────────────
          Positioned(
            top: -size.height * 0.12,
            left: -size.width * 0.35,
            child: _blob(size.width * 1.0, const Color(0xFF3A5BF5), 0.40),
          ),
          // Glow top-right (purple)
          Positioned(
            top: size.height * 0.05,
            right: -size.width * 0.3,
            child: _blob(size.width * 0.70, const Color(0xFF8B2FC9), 0.35),
          ),
          // Glow bottom cyan
          Positioned(
            bottom: -size.height * 0.08,
            left: size.width * 0.1,
            child: _blob(size.width * 0.75, const Color(0xFF00B4D8), 0.22),
          ),

          // ── Subtle grid/pattern overlay ─────────────────────────
          Positioned.fill(
            child: Opacity(
              opacity: 0.03,
              child: CustomPaint(painter: _GridPainter()),
            ),
          ),

          // ── Main content ────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideUp,
                  child: Column(
                    children: [
                      SizedBox(height: size.height * 0.06),

                      // ── Logo: glass circle + white icon ─────────
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow ring
                          Container(
                            width: 118,
                            height: 118,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF6C63FF).withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6C63FF).withValues(alpha: 0.55),
                                  blurRadius: 55,
                                  spreadRadius: 6,
                                ),
                                BoxShadow(
                                  color: const Color(0xFF00D2FF).withValues(alpha: 0.25),
                                  blurRadius: 80,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                          ),
                          // Frosted glass circle
                          ClipOval(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                width: 112,
                                height: 112,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.08),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.18),
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

                      const SizedBox(height: 20),

                      // ── SAF title ────────────────────────────────
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          colors: [Color(0xFFFFFFFF), Color(0xFF9DB8FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
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
                      ),

                      const SizedBox(height: 8),

                      // ── Tagline ──────────────────────────────────
                      Text(
                        'SAF es una sociedad con créditos muy rápidos.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFFB0C4EE),
                          height: 1.5,
                          letterSpacing: 0.3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      SizedBox(height: size.height * 0.045),

                      // ── Premium glass card ───────────────────────
                      ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.10),
                                  Colors.white.withValues(alpha: 0.04),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 40,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ── Card header ──────────────────
                                  Row(
                                    children: [
                                      // Gradient accent line
                                      Container(
                                        width: 4,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(2),
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF6C63FF), Color(0xFF00D2FF)],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF6C63FF).withValues(alpha: 0.6),
                                              blurRadius: 10,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      const Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Bienvenido de nuevo',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          SizedBox(height: 3),
                                          Text(
                                            'Ingresa tus credenciales para continuar',
                                            style: TextStyle(
                                              color: Color(0xFF7B8EC8),
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 28),

                                  // ── Divider ──────────────────────
                                  Container(
                                    height: 1,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Colors.white.withValues(alpha: 0.12),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // ── Email ─────────────────────────
                                  _field(
                                    controller: _emailController,
                                    label: 'Correo electrónico',
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
                                      if (!v.contains('@')) return 'Correo inválido';
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 14),

                                  // ── Password ──────────────────────
                                  _field(
                                    controller: _passwordController,
                                    label: 'Contraseña',
                                    icon: Icons.lock_outline_rounded,
                                    obscure: _obscurePassword,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: const Color(0xFF6B7DB3),
                                        size: 20,
                                      ),
                                      onPressed: () => setState(
                                          () => _obscurePassword = !_obscurePassword),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
                                      return null;
                                    },
                                  ),

                                  // ── Error message ─────────────────
                                  if (_errorMessage != null) ...[
                                    const SizedBox(height: 14),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF4B6E).withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFFF4B6E).withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline,
                                              color: Color(0xFFFF6B8A), size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(_errorMessage!,
                                              style: const TextStyle(
                                                color: Color(0xFFFF9BAF),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 28),

                                  // ── Login button ──────────────────
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF5B54F5), Color(0xFF00C6FF)],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF5B54F5).withValues(alpha: 0.60),
                                            blurRadius: 28,
                                            offset: const Offset(0, 10),
                                            spreadRadius: -4,
                                          ),
                                          BoxShadow(
                                            color: const Color(0xFF00C6FF).withValues(alpha: 0.25),
                                            blurRadius: 20,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _login,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          disabledBackgroundColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 22, height: 22,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    'Iniciar Sesión',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w700,
                                                      letterSpacing: 1.2,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Icon(Icons.arrow_forward_rounded,
                                                      color: Colors.white, size: 18),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: size.height * 0.04),

                      // Footer
                      const Text(
                        'Plataforma de Creación y Gestión de Préstamos',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF6B7DB3),
                          fontSize: 12,
                          letterSpacing: 0.3,
                          fontWeight: FontWeight.w500,
                        ),
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
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: opacity), Colors.transparent],
          ),
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      autocorrect: false,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF5A6A9A), fontSize: 14),
        floatingLabelStyle: const TextStyle(
          color: Color(0xFF00C6FF),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF6C63FF), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF4B6E)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF4B6E), width: 1.8),
        ),
        errorStyle: const TextStyle(color: Color(0xFFFF9BAF)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      validator: validator,
    );
  }
}

// ── Subtle background grid ──────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.5;
    const spacing = 32.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(_GridPainter old) => false;
}
