import '../../controllers/home_actions.dart';
import '../../controllers/home_data_controller.dart';
import '../../screens/home/home_dependencies.dart';
import 'cached_avatar.dart';
import 'home_dialogs.dart';

extension HomeAppBar<T extends StatefulWidget> on HomeController<T> {
  SliverAppBar buildHomeAppBar() => SliverAppBar(
        expandedHeight: 0,
        floating: true,
        snap: true,
        automaticallyImplyLeading: false,
        backgroundColor: homeNavy,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            const _AnimatedSafLogo(),
            const SizedBox(width: 10),
            const Text(
              'SAF',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            // ── Toggle tema claro/oscuro ──
            GestureDetector(
              onTap: () async {
                final dark = !isDarkTheme;
                await setThemeDark(dark);
                refresh(() {});
                // Persistir en el servidor para sincronizar con SAF-WEB
                unawaited(saveThemeToServer(dark));
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.10),
                  border: Border.all(
                      color: (isDarkTheme
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFFA78BFA))
                          .withValues(alpha: 0.45)),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) =>
                      RotationTransition(turns: anim, child: FadeTransition(opacity: anim, child: child)),
                  child: Icon(
                    isDarkTheme
                        ? Icons.wb_sunny_rounded
                        : Icons.dark_mode_rounded,
                    key: ValueKey(isDarkTheme),
                    size: 19,
                    color: isDarkTheme
                        ? const Color(0xFFFBBF24) // sol amarillo
                        : const Color(0xFFA78BFA), // luna moradita
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: showProfileSheet,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: homeCyan.withValues(alpha: 0.8), width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: homeAccent.withValues(alpha: 0.35),
                        blurRadius: 8)
                  ],
                ),
                child: ClipOval(
                  child: CachedAvatarImage(
                    url: photoUrl,
                    cacheKey: photoCacheKey,
                    fallback: buildAvatarFallback(fullName.split(' ').first),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      );
}

// ── Pulsing status dot ───────────────────────────────────────────────────────

class SafPulsingStatusDot extends StatefulWidget {
  const SafPulsingStatusDot({super.key});
  @override
  State<SafPulsingStatusDot> createState() => _SafPulsingStatusDotState();
}

class _SafPulsingStatusDotState extends State<SafPulsingStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_pulse),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.8, end: 1.15).animate(_pulse),
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: Color(0xFF6EE7B7),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ── Animated SAF logo ────────────────────────────────────────────────────────

class _AnimatedSafLogo extends StatefulWidget {
  const _AnimatedSafLogo();
  @override
  State<_AnimatedSafLogo> createState() => _AnimatedSafLogoState();
}

class _AnimatedSafLogoState extends State<_AnimatedSafLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rotate;
  late final Animation<double> _glowAlpha;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
    _rotate = _ctrl;
    _glowAlpha = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.18), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.18, end: 0.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => SizedBox(
        width: 42,
        height: 42,
        child: Stack(alignment: Alignment.center, children: [
          // Pulsing outer glow ring
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: _glowAlpha.value),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),
          // Rotating logo inside frosted circle
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Transform.rotate(
                angle: _rotate.value * 2 * pi,
                child: const CustomPaint(painter: SafLogoPainter(Colors.white)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
