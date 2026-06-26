import 'dart:math' as math;
import '../../controllers/home_data_controller.dart';
import '../../screens/home/home_dependencies.dart';

const _allNavItems = <(IconData, IconData, String)>[
  (Icons.home_rounded, Icons.home_outlined, 'Inicio'),
  (Icons.credit_card_rounded, Icons.credit_card_outlined, 'Créditos'),
  (Icons.savings_rounded, Icons.savings_outlined, 'Ahorros'),
  (Icons.swap_horiz_rounded, Icons.swap_horiz_outlined, 'Movimientos'),
];

extension HomeBottomNavigation<T extends StatefulWidget> on HomeController<T> {
  Widget buildHomeBottomNavigation() {
    final visibleItems = allowedScreenIndices
        .where((i) => i < _allNavItems.length)
        .map((i) => _allNavItems[i])
        .toList();
    final visibleColors = allowedScreenIndices
        .where((i) => i < homeNavigationColors.length)
        .map((i) => homeNavigationColors[i])
        .toList();

    return _SafAnimatedBottomNavigationBar(
      key: ValueKey(allowedScreenIndices.join(',')),
      selectedIndex: selectedIndex,
      items: visibleItems,
      colors: visibleColors,
      onTap: (i) {
        final screenIdx = screenIndexAt(i);
        refresh(() => selectedIndex = i);
        if (screenIdx == 4 && statisticsData.isEmpty && !statisticsLoading) {
          fetchStatistics();
        }
      },
    );
  }
}

// ── Animated Bottom Navigation Bar ───────────────────────────────────────────

class _SafAnimatedBottomNavigationBar extends StatefulWidget {
  final int selectedIndex;
  final List<(IconData, IconData, String)> items;
  final List<Color> colors;
  final ValueChanged<int> onTap;

  const _SafAnimatedBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_SafAnimatedBottomNavigationBar> createState() =>
      _SafAnimatedBottomNavigationBarState();
}

class _SafAnimatedBottomNavigationBarState
    extends State<_SafAnimatedBottomNavigationBar>
    with TickerProviderStateMixin {

  // Per-tab: bounce scale + tilt wobble share the same controller
  late final List<AnimationController> _bounceCtrls;
  late final List<Animation<double>> _bounceAnims;
  late final List<Animation<double>> _tiltAnims;

  // Continuous: pulsing glow on selected icon
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  // One-shot: particle burst on tap
  late final AnimationController _particleCtrl;
  int _burstIndex = 0;

  @override
  void initState() {
    super.initState();

    _bounceCtrls = List.generate(
      widget.items.length,
      (_) => AnimationController(
          vsync: this, duration: const Duration(milliseconds: 540)),
    );

    _bounceAnims = _bounceCtrls.map((c) {
      return TweenSequence<double>([
        TweenSequenceItem(
            tween: Tween(begin: 1.0, end: 0.70)
                .chain(CurveTween(curve: Curves.easeIn)),
            weight: 18),
        TweenSequenceItem(
            tween: Tween(begin: 0.70, end: 1.30)
                .chain(CurveTween(curve: Curves.easeOut)),
            weight: 36),
        TweenSequenceItem(
            tween: Tween(begin: 1.30, end: 0.92)
                .chain(CurveTween(curve: Curves.easeIn)),
            weight: 24),
        TweenSequenceItem(
            tween: Tween(begin: 0.92, end: 1.0)
                .chain(CurveTween(curve: Curves.easeOut)),
            weight: 22),
      ]).animate(c);
    }).toList();

    // Wobble tilt synced to the same bounce controller
    _tiltAnims = _bounceCtrls.map((c) {
      return TweenSequence<double>([
        TweenSequenceItem(
            tween: Tween(begin: 0.0, end: -0.25)
                .chain(CurveTween(curve: Curves.easeIn)),
            weight: 20),
        TweenSequenceItem(
            tween: Tween(begin: -0.25, end: 0.20)
                .chain(CurveTween(curve: Curves.easeOut)),
            weight: 35),
        TweenSequenceItem(
            tween: Tween(begin: 0.20, end: -0.08)
                .chain(CurveTween(curve: Curves.easeIn)),
            weight: 25),
        TweenSequenceItem(
            tween: Tween(begin: -0.08, end: 0.0)
                .chain(CurveTween(curve: Curves.easeOut)),
            weight: 20),
      ]).animate(c);
    }).toList();

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);

    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 560));

    _bounceCtrls[widget.selectedIndex].forward();
  }

  @override
  void didUpdateWidget(_SafAnimatedBottomNavigationBar old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      _bounceCtrls[widget.selectedIndex].forward(from: 0);
    }
  }

  @override
  void dispose() {
    for (final c in _bounceCtrls) {
      c.dispose();
    }
    _glowCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  void _handleTap(int i) {
    setState(() => _burstIndex = i);
    _particleCtrl.forward(from: 0);
    widget.onTap(i);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.items.length;
    final selColor = widget.colors[widget.selectedIndex];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B4B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D1B4B).withValues(alpha: 0.92),
            blurRadius: 36,
            offset: const Offset(0, -8),
          ),
          BoxShadow(
            color: selColor.withValues(alpha: 0.26),
            blurRadius: 64,
            spreadRadius: -4,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── Sliding pill with shimmer ───────────────────────
                  _buildPill(n),
                  // ── Tab items ───────────────────────────────────────
                  _buildTabRow(n),
                  // ── Particle burst overlay ──────────────────────────
                  AnimatedBuilder(
                    animation: _particleCtrl,
                    builder: (_, __) {
                      final v = _particleCtrl.value;
                      return v > 0 && v < 1
                          ? _buildParticleBurst(
                              _burstIndex, v, constraints.maxWidth, n)
                          : const SizedBox.shrink();
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Pill ──────────────────────────────────────────────────────────────────

  Widget _buildPill(int n) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.selectedIndex.toDouble()),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
      builder: (_, v, __) {
        final c = widget.colors[widget.selectedIndex];
        return Align(
          alignment: Alignment(-1.0 + (2.0 * v / (n - 1)), 0),
          child: FractionallySizedBox(
            widthFactor: 1 / n,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Stack(children: [
                // Base gradient pill
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        c.withValues(alpha: 0.34),
                        c.withValues(alpha: 0.13),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: c.withValues(alpha: 0.55),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: c.withValues(alpha: 0.38),
                        blurRadius: 22,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  // ── Tab row ───────────────────────────────────────────────────────────────

  Widget _buildTabRow(int n) {
    return Row(
      children: List.generate(n, (i) {
        final selected = i == widget.selectedIndex;
        final color = widget.colors[i];
        final item = widget.items[i];

        return Expanded(
          child: GestureDetector(
            onTap: () => _handleTap(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedBuilder(
              animation: _bounceAnims[i],
              builder: (_, __) => Transform.scale(
                scale: selected ? _bounceAnims[i].value : 1.0,
                child: Transform.rotate(
                  angle: selected ? _tiltAnims[i].value : 0.0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 6),

                      // ── Icon + pulsing glow halo ──────────────────
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: Stack(alignment: Alignment.center, children: [
                          if (selected)
                            AnimatedBuilder(
                              animation: _glowAnim,
                              builder: (_, __) => Container(
                                width: 30 + _glowAnim.value * 10,
                                height: 30 + _glowAnim.value * 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withValues(
                                          alpha: 0.22 + _glowAnim.value * 0.32),
                                      blurRadius: 16 + _glowAnim.value * 12,
                                      spreadRadius: _glowAnim.value * 3,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, anim) =>
                                ScaleTransition(scale: anim, child: child),
                            child: Icon(
                              selected ? item.$1 : item.$2,
                              key: ValueKey('${i}_$selected'),
                              color: selected
                                  ? color
                                  : Colors.white.withValues(alpha: 0.28),
                              size: selected ? 24 : 20,
                              shadows: selected
                                  ? [
                                      Shadow(
                                        color: color.withValues(alpha: 0.95),
                                        blurRadius: 18,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ]),
                      ),

                      const SizedBox(height: 2),

                      // ── Label with slide-up effect ────────────────
                      AnimatedPadding(
                        duration: const Duration(milliseconds: 270),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.only(bottom: selected ? 0 : 4),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 260),
                          style: TextStyle(
                            color: selected
                                ? color
                                : Colors.white.withValues(alpha: 0.26),
                            fontSize: selected ? 9.5 : 8.5,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w400,
                            letterSpacing: selected ? 0.4 : 0,
                          ),
                          child: Text(item.$3),
                        ),
                      ),

                      const SizedBox(height: 3),

                      // ── Glowing indicator dot ─────────────────────
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeInOutCubic,
                        width: selected ? 24 : 0,
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: selected
                              ? LinearGradient(colors: [
                                  color.withValues(alpha: 0.04),
                                  color,
                                  color.withValues(alpha: 0.04),
                                ])
                              : null,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.95),
                                    blurRadius: 14,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                      ),

                      const SizedBox(height: 2),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── Particle burst ────────────────────────────────────────────────────────

  Widget _buildParticleBurst(
      int tabIndex, double progress, double totalWidth, int n) {
    final tabW = totalWidth / n;
    final cx = tabW * tabIndex + tabW / 2;
    const cy = 34.0;
    const count = 10;
    final color = widget.colors[tabIndex];
    final ease = Curves.easeOut.transform(progress);
    final opacity = (1.0 - ease * 1.3).clamp(0.0, 1.0);
    final spread = ease * 38.0;

    return Stack(
      children: List.generate(count, (i) {
        final angle = (i / count) * 2 * math.pi;
        // Flatten vertically so particles spread sideways more than up/down
        final px = cx + math.cos(angle) * spread;
        final py = cy + math.sin(angle) * spread * 0.5;
        final sz = 5.0 + (i % 3) * 1.5; // vary sizes

        return Positioned(
          left: px - sz / 2,
          top: py - sz / 2,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: sz,
              height: sz,
              decoration: BoxDecoration(
                color: i.isEven ? color : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.9),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
