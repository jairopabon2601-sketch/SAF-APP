import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/push_notifications_service.dart';
import '../utils/responsive.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _floatCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _shimmerCtrl;
  late AnimationController _waveCtrl;

  late Animation<double> _floatAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _shimmerAnim;
  late Animation<double> _waveAnim;

  static const List<_PageData> _pages = [
    _PageData(
      icon: Icons.account_balance_rounded,
      title: 'Bienvenido a SAF',
      subtitle:
          'Plataforma financiera diseñada para simplificar tu vida económica con tecnología de vanguardia.',
      accent: [Color(0xFF4361EE), Color(0xFF00D2FF)],
      accentMid: Color(0xFF1E88E5),
      bgColors: [Color(0xFF03061A), Color(0xFF0A1540), Color(0xFF0D1860)],
      blobTop: Color(0xFF4361EE),
      blobBottom: Color(0xFF00C6FF),
    ),
    _PageData(
      icon: Icons.flash_on_rounded,
      title: 'Créditos Rápidos',
      subtitle:
          'Solicita préstamos al instante. Tu historial fortalece tu perfil y aumenta tu cupo disponible.',
      accent: [Color(0xFF9B27AF), Color(0xFFE040FB)],
      accentMid: Color(0xFFAB47BC),
      bgColors: [Color(0xFF0D0118), Color(0xFF210340), Color(0xFF2D0555)],
      blobTop: Color(0xFF7B1FA2),
      blobBottom: Color(0xFFCE93D8),
    ),
    _PageData(
      icon: Icons.analytics_rounded,
      title: 'Control Total',
      subtitle:
          'Visualiza pagos, historial y estado de cuenta en tiempo real. Tu información siempre al alcance.',
      accent: [Color(0xFF00BFA5), Color(0xFF1DE9B6)],
      accentMid: Color(0xFF00C9A7),
      bgColors: [Color(0xFF001511), Color(0xFF003028), Color(0xFF004038)],
      blobTop: Color(0xFF00897B),
      blobBottom: Color(0xFF80CBC4),
    ),
  ];

  @override
  void initState() {
    super.initState();

    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
    _waveCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 5))
      ..repeat();

    _floatAnim = Tween<double>(begin: -10, end: 10).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
    _pulseAnim = Tween<double>(begin: 0.94, end: 1.08).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _shimmerAnim = Tween<double>(begin: -2.0, end: 2.0).animate(
        CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));
    _waveAnim = Tween<double>(begin: 0, end: 2 * math.pi).animate(_waveCtrl);
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    _waveCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    // El diálogo de permiso de notificaciones debe salir apenas el usuario
    // entra por primera vez a la app, no después del login.
    unawaited(PushNotificationsService().requestPermissionAndListen());
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final page = _pages[_currentPage];

    return Scaffold(
      body: Stack(
        children: [
          // ── Animated background ─────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: page.bgColors,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ── Glow blob top-left ──────────────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            top: -size.height * 0.12,
            left: -size.width * 0.25,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: size.width * 0.95,
              height: size.width * 0.95,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  page.blobTop.withValues(alpha: 0.45),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // ── Glow blob bottom-right ──────────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            bottom: -size.height * 0.1,
            right: -size.width * 0.3,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: size.width * 0.85,
              height: size.width * 0.85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  page.blobBottom.withValues(alpha: 0.32),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // ── Wave painter ────────────────────────────────────────
          AnimatedBuilder(
            animation: _waveAnim,
            builder: (_, __) => CustomPaint(
              size: size,
              painter: _WavePainter(_waveAnim.value, page.accent.first),
            ),
          ),

          // ── Page content ────────────────────────────────────────
          Positioned.fill(
            bottom: 160,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (_, i) {
                switch (i) {
                  case 0: return _buildPage0(_pages[i], size);
                  case 1: return _buildPage1(_pages[i], size);
                  case 2: return _buildPage2(_pages[i], size);
                  default: return _buildPage0(_pages[i], size);
                }
              },
            ),
          ),

          // ── Bottom controls ─────────────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(context.sp(28), 0, context.sp(28), 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (i) {
                        final active = i == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 32 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: active
                                ? LinearGradient(colors: page.accent)
                                : null,
                            color: active
                                ? null
                                : Colors.white.withValues(alpha: 0.25),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 22),

                    // Shimmer gradient button
                    AnimatedBuilder(
                      animation: _shimmerAnim,
                      builder: (_, __) => SizedBox(
                        width: double.infinity,
                        height: (context.sh * 0.072).clamp(50.0, 66.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(
                              begin: Alignment(_shimmerAnim.value - 1, 0),
                              end: Alignment(_shimmerAnim.value + 1, 0),
                              colors: [
                                page.accent.first,
                                page.accentMid,
                                Colors.white.withValues(alpha: 0.25),
                                page.accentMid,
                                page.accent.last,
                              ],
                              stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: page.accent.first.withValues(alpha: 0.6),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _next,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentPage == _pages.length - 1
                                      ? 'Comenzar'
                                      : 'Siguiente',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Icon(Icons.arrow_forward_rounded,
                                    color: Colors.white, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    if (_currentPage < _pages.length - 1)
                      TextButton(
                        onPressed: _finish,
                        child: Text(
                          'Omitir',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.42),
                            fontSize: 14,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PAGE 0: Welcome ───────────────────────────────────────────
  Widget _buildPage0(_PageData page, Size size) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.sp(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ícono compacto + welcome card — mismo patrón que páginas 2 y 3
          AnimatedBuilder(
            animation: Listenable.merge([_floatAnim, _pulseAnim]),
            builder: (_, __) => Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Ícono con un anillo pulsante
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(
                      scale: _pulseAnim.value,
                      child: Container(
                        width: context.sp(108), height: context.sp(108),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: page.accent.first.withValues(alpha: 0.22),
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(0, _floatAnim.value * 0.8),
                      child: _iconCircle(page),
                    ),
                  ],
                ),
                const SizedBox(width: 18),
                // Welcome card visual
                Expanded(
                  child: Transform.translate(
                    offset: Offset(0, _floatAnim.value * 0.4),
                    child: _welcomeCardMock(page),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: size.height * 0.038),

          _gradientTitle(page, page.title),
          const SizedBox(height: 10),

          Text(
            page.subtitle,
            style: TextStyle(
              fontSize: 14.5,
              color: Colors.white.withValues(alpha: 0.62),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 22),

          // Features como lista — igual que página 3
          _featureRow(page, Icons.shield_rounded, 'Seguridad bancaria',
              'Cifrado de extremo a extremo'),
          const SizedBox(height: 12),
          _featureRow(page, Icons.bolt_rounded, 'Respuesta rápida',
              'Aprobación en minutos'),
          const SizedBox(height: 12),
          _featureRow(page, Icons.smartphone_rounded, 'Desde tu móvil',
              'Gestiona todo 24/7'),
          const SizedBox(height: 12),
          _featureRow(page, Icons.support_agent_rounded, 'Soporte humano',
              'Asistencia personalizada'),
        ],
      ),
    );
  }

  // ── PAGE 1: Credits ───────────────────────────────────────────
  Widget _buildPage1(_PageData page, Size size) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.sp(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          // Ícono + card en fila, sin superposición
          AnimatedBuilder(
            animation: Listenable.merge([_floatAnim, _pulseAnim]),
            builder: (_, __) => Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Ícono compacto con un anillo
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(
                      scale: _pulseAnim.value,
                      child: Container(
                        width: context.sp(108), height: context.sp(108),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: page.accent.first.withValues(alpha: 0.22),
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(0, _floatAnim.value * 0.8),
                      child: _iconCircle(page),
                    ),
                  ],
                ),
                const SizedBox(width: 18),
                // Credit card
                Expanded(
                  child: Transform.translate(
                    offset: Offset(0, _floatAnim.value * 0.4),
                    child: Transform.rotate(
                      angle: 0.04,
                      child: _creditCardMock(page),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: size.height * 0.038),

          _gradientTitle(page, page.title),
          const SizedBox(height: 10),

          Text(
            page.subtitle,
            style: TextStyle(
              fontSize: 14.5,
              color: Colors.white.withValues(alpha: 0.62),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 22),

          // Tasa inline compacta
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  page.accent.first.withValues(alpha: 0.18),
                  page.accent.last.withValues(alpha: 0.08),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: Border.all(color: page.accent.first.withValues(alpha: 0.32)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_offer_rounded, color: page.accent.last, size: 16),
                const SizedBox(width: 8),
                Text('Tasa desde  ',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                ShaderMask(
                  shaderCallback: (b) =>
                      LinearGradient(colors: page.accent).createShader(b),
                  child: const Text('0.8% mensual',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Steps
          _stepItem(page, '01', Icons.edit_note_rounded, 'Solicita',
              'Completa tu solicitud en minutos'),
          const SizedBox(height: 10),
          _stepItem(page, '02', Icons.check_circle_outline_rounded,
              'Aprobación', 'Respuesta inmediata automática'),
          const SizedBox(height: 10),
          _stepItem(page, '03', Icons.account_balance_wallet_rounded,
              'Recibe', 'Dinero directo a tu cuenta'),
        ],
      ),
    );
  }

  // ── PAGE 2: Control ───────────────────────────────────────────
  Widget _buildPage2(_PageData page, Size size) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.sp(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          // Ícono + chart en fila, sin superposición
          AnimatedBuilder(
            animation: Listenable.merge([_floatAnim, _pulseAnim]),
            builder: (_, __) => Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Ícono compacto
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(
                      scale: _pulseAnim.value,
                      child: Container(
                        width: context.sp(108), height: context.sp(108),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: page.accent.first.withValues(alpha: 0.22),
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(0, _floatAnim.value * 0.8),
                      child: _iconCircle(page),
                    ),
                  ],
                ),
                const SizedBox(width: 18),
                // Chart card
                Expanded(
                  child: Transform.translate(
                    offset: Offset(0, _floatAnim.value * 0.35),
                    child: _chartCardMock(page),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: size.height * 0.038),

          _gradientTitle(page, page.title),
          const SizedBox(height: 10),

          Text(
            page.subtitle,
            style: TextStyle(
              fontSize: 14.5,
              color: Colors.white.withValues(alpha: 0.62),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 22),

          // Feature list
          _featureRow(page, Icons.payments_rounded, 'Pagos al instante',
              'Gestiona y realiza pagos en segundos'),
          const SizedBox(height: 12),
          _featureRow(page, Icons.history_rounded, 'Historial completo',
              'Accede a todos tus movimientos'),
          const SizedBox(height: 12),
          _featureRow(page, Icons.notifications_active_rounded,
              'Alertas en tiempo real', 'Notificación de cada transacción'),
          const SizedBox(height: 12),
          _featureRow(page, Icons.lock_rounded, 'Datos protegidos',
              'Cifrado bancario de extremo a extremo'),
        ],
      ),
    );
  }

  // ── Shared widgets ────────────────────────────────────────────

  Widget _iconCircle(_PageData page) {
    final d = context.sp(96);
    return Container(
      width: d, height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: page.accent,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: page.accent.first.withValues(alpha: 0.7),
            blurRadius: 42,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Icon(page.icon, size: context.sp(44), color: Colors.white),
    );
  }

  Widget _gradientTitle(_PageData page, String text) => ShaderMask(
        shaderCallback: (b) => LinearGradient(
          colors: page.accent,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(b),
        child: Text(
          text,
          style: TextStyle(
            fontSize: context.sp(34),
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.15,
            letterSpacing: -0.5,
          ),
        ),
      );

  // Welcome card mockup para página 1
  Widget _welcomeCardMock(_PageData page) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              page.accent.first.withValues(alpha: 0.65),
              page.accent.last.withValues(alpha: 0.45),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: page.accent.first.withValues(alpha: 0.4),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('SAF',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
                Icon(Icons.verified_rounded,
                    color: Colors.white.withValues(alpha: 0.7), size: 16),
              ],
            ),
            const SizedBox(height: 12),
            Text('Bienvenido',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10)),
            const SizedBox(height: 2),
            const Text('Plataforma\nFinanciera',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.2)),
          ],
        ),
      );

  Widget _stepItem(_PageData page, String num, IconData icon, String title,
      String desc) =>
      Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: page.accent,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: page.accent.first.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(desc,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.48),
                        fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              color: page.accent.first.withValues(alpha: 0.2),
            ),
            child: Text(num,
                style: TextStyle(
                    color: page.accent.last,
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      );

  Widget _featureRow(_PageData page, IconData icon, String title, String desc) =>
      Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: page.accent.first.withValues(alpha: 0.16),
              border: Border.all(
                  color: page.accent.first.withValues(alpha: 0.42)),
            ),
            child: Icon(icon, color: page.accent.last, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(desc,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.48),
                        fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded,
              color: page.accent.last.withValues(alpha: 0.8), size: 19),
        ],
      );

  // Credit card mockup for page 1
  Widget _creditCardMock(_PageData page) => Container(
        width: 205, height: 118,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              page.accent.first.withValues(alpha: 0.65),
              page.accent.last.withValues(alpha: 0.45),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: page.accent.first.withValues(alpha: 0.4),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('SAF Credit',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
                Icon(Icons.credit_card_rounded,
                    color: Colors.white.withValues(alpha: 0.7), size: 18),
              ],
            ),
            const Spacer(),
            const Text('\$5.000.000',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text('Cupo disponible',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 9,
                    letterSpacing: 0.4)),
          ],
        ),
      );

  // Mini chart card mockup for page 2
  Widget _chartCardMock(_PageData page) => Container(
        width: 215, height: 108,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.07),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: page.accent.first.withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mis Pagos',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: page.accent.last)),
                    const SizedBox(width: 4),
                    Text('En vivo',
                        style: TextStyle(
                            color: page.accent.last,
                            fontSize: 9,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _miniBar(page, 0.50, 'E'),
                _miniBar(page, 0.70, 'F'),
                _miniBar(page, 0.45, 'M'),
                _miniBar(page, 0.85, 'A'),
                _miniBar(page, 0.65, 'M'),
                _miniBar(page, 1.00, 'J'),
              ],
            ),
          ],
        ),
      );

  Widget _miniBar(_PageData page, double factor, String label) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 42 * factor,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              gradient: LinearGradient(
                colors: [
                  page.accent.first.withValues(alpha: 0.5),
                  page.accent.last,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.38),
                  fontSize: 8)),
        ],
      );
}

// ── Wave background painter ────────────────────────────────────
class _WavePainter extends CustomPainter {
  final double phase;
  final Color color;
  const _WavePainter(this.phase, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    for (int w = 0; w < 3; w++) {
      final paint = Paint()
        ..color = color.withValues(alpha: 0.04 - w * 0.01)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      final path = Path();
      path.moveTo(0, size.height * (0.55 + w * 0.08));
      for (double x = 0; x <= size.width; x += 2) {
        final y = size.height * (0.55 + w * 0.08) +
            math.sin((x / size.width * 2.5 * math.pi) + phase + w) *
                (18.0 + w * 10);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.phase != phase || old.color != color;
}

// ── Data model ─────────────────────────────────────────────────
class _PageData {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> accent;
  final Color accentMid;
  final List<Color> bgColors;
  final Color blobTop;
  final Color blobBottom;

  const _PageData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.accentMid,
    required this.bgColors,
    required this.blobTop,
    required this.blobBottom,
  });
}
