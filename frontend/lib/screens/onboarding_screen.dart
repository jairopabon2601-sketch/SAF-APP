import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.account_balance_rounded,
      title: 'Bienvenido a SAF',
      subtitle:
          'Plataforma de Creación y Gestión de Préstamos diseñada para simplificar tu vida financiera.',
      accent: [Color(0xFF6C63FF), Color(0xFF00D2FF)],
      bgColors: [Color(0xFF060818), Color(0xFF0D1B4B), Color(0xFF1A1060)],
      blobTop: Color(0xFF4361EE),
      blobBottom: Color(0xFF00D2FF),
    ),
    _OnboardingPage(
      icon: Icons.flash_on_rounded,
      title: 'Créditos Rápidos',
      subtitle:
          'Solicita préstamos de forma inmediata. Cada pago puntual mejora tu perfil crediticio y aumenta tu cupo.',
      accent: [Color(0xFFBE2FBE), Color(0xFF7B2FBE)],
      bgColors: [Color(0xFF110620), Color(0xFF2D0845), Color(0xFF3B0F6A)],
      blobTop: Color(0xFF7B2FBE),
      blobBottom: Color(0xFFBE2FBE),
    ),
    _OnboardingPage(
      icon: Icons.bar_chart_rounded,
      title: 'Control Total',
      subtitle:
          'Monitorea tus pagos, historial y estado de cuenta en tiempo real desde cualquier lugar.',
      accent: [Color(0xFF00C9A7), Color(0xFF00D2FF)],
      bgColors: [Color(0xFF001814), Color(0xFF003D33), Color(0xFF005248)],
      blobTop: Color(0xFF00C9A7),
      blobBottom: Color(0xFF00D2FF),
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final page = _pages[_currentPage];

    return Scaffold(
      body: Stack(
        children: [
          // ── Animated background per page ────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 450),
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

          // ── Animated glow blobs ─────────────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOut,
            top: -size.height * 0.08,
            left: -size.width * 0.25,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 450),
              width: size.width * 0.75,
              height: size.width * 0.75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    page.blobTop.withValues(alpha: 0.38),
                    Colors.transparent
                  ],
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOut,
            bottom: -size.height * 0.05,
            right: -size.width * 0.2,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 450),
              width: size.width * 0.65,
              height: size.width * 0.65,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    page.blobBottom.withValues(alpha: 0.28),
                    Colors.transparent
                  ],
                ),
              ),
            ),
          ),

          // ── Page content ────────────────────────────────────────
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) => _buildPage(_pages[i], size),
          ),

          // ── Bottom controls ─────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
                child: Column(
                  children: [
                    // Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _currentPage ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: i == _currentPage
                                ? LinearGradient(colors: page.accent)
                                : null,
                            color: i == _currentPage
                                ? null
                                : Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: page.accent),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: page.accent.first.withValues(alpha: 0.5),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _currentPage == _pages.length - 1
                                ? 'Comenzar'
                                : 'Siguiente',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (_currentPage < _pages.length - 1)
                      TextButton(
                        onPressed: _finish,
                        child: Text(
                          'Omitir',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 14,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page, Size size) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: size.height * 0.04),

          // Icon
          Container(
            width: 118,
            height: 118,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: page.accent,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: page.accent.first.withValues(alpha: 0.6),
                  blurRadius: 55,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: Icon(page.icon, size: 54, color: Colors.white),
          ),

          SizedBox(height: size.height * 0.055),

          // Title
          ShaderMask(
            shaderCallback: (b) =>
                LinearGradient(colors: page.accent).createShader(b),
            child: Text(
              page.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.2,
              ),
            ),
          ),

          const SizedBox(height: 18),

          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.55),
              height: 1.65,
            ),
          ),

          SizedBox(height: size.height * 0.2),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> accent;
  final List<Color> bgColors;
  final Color blobTop;
  final Color blobBottom;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.bgColors,
    required this.blobTop,
    required this.blobBottom,
  });
}
