import '../../controllers/home_data_controller.dart';
import '../../screens/home/home_dependencies.dart';

extension HomeBottomNavigation<T extends StatefulWidget> on HomeController<T> {
  Widget buildHomeBottomNavigation() {
    return _SafAnimatedBottomNavigationBar(
      selectedIndex: selectedIndex,
      colors: homeNavigationColors,
      onTap: (i) {
        refresh(() => selectedIndex = i);
        if (i == 4 && statisticsData.isEmpty && !statisticsLoading) {
          fetchStatistics();
        }
      },
    );
  }
}

// ── Animated Bottom Navigation Bar ───────────────────────────────────────────

class _SafAnimatedBottomNavigationBar extends StatefulWidget {
  final int selectedIndex;
  final List<Color> colors;
  final ValueChanged<int> onTap;

  const _SafAnimatedBottomNavigationBar({
    required this.selectedIndex,
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
  static const _items = <(IconData, IconData, String)>[
    (Icons.home_rounded, Icons.home_outlined, 'Inicio'),
    (Icons.credit_card_rounded, Icons.credit_card_outlined, 'Créditos'),
    (Icons.savings_rounded, Icons.savings_outlined, 'Ahorros'),
    (Icons.swap_horiz_rounded, Icons.swap_horiz_outlined, 'Movimientos'),
    (Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Estadística'),
  ];

  late final List<AnimationController> _bounceCtrls;
  late final List<Animation<double>> _bounceAnims;

  @override
  void initState() {
    super.initState();
    _bounceCtrls = List.generate(
      _items.length,
      (_) => AnimationController(
          vsync: this, duration: const Duration(milliseconds: 520)),
    );
    _bounceAnims = _bounceCtrls.map((c) {
      return TweenSequence<double>([
        TweenSequenceItem(
            tween: Tween(begin: 1.0, end: 0.78)
                .chain(CurveTween(curve: Curves.easeIn)),
            weight: 18),
        TweenSequenceItem(
            tween: Tween(begin: 0.78, end: 1.22)
                .chain(CurveTween(curve: Curves.easeOut)),
            weight: 36),
        TweenSequenceItem(
            tween: Tween(begin: 1.22, end: 0.94)
                .chain(CurveTween(curve: Curves.easeIn)),
            weight: 24),
        TweenSequenceItem(
            tween: Tween(begin: 0.94, end: 1.0)
                .chain(CurveTween(curve: Curves.easeOut)),
            weight: 22),
      ]).animate(c);
    }).toList();
    // Trigger initial tab
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = _items.length;
    final selColor = widget.colors[widget.selectedIndex];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B4B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D1B4B).withValues(alpha: 0.85),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
          // Dynamic glow matching selected tab color
          BoxShadow(
            color: selColor.withValues(alpha: 0.18),
            blurRadius: 50,
            spreadRadius: -4,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Stack(
            children: [
              // ── Sliding gradient pill ───────────────────────────────
              TweenAnimationBuilder<double>(
                tween: Tween(end: widget.selectedIndex.toDouble()),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeInOutCubic,
                builder: (_, v, __) {
                  final c = widget.colors[widget.selectedIndex];
                  return Align(
                    alignment: Alignment(
                      -1.0 + (2.0 * v / (n - 1)),
                      0,
                    ),
                    child: FractionallySizedBox(
                      widthFactor: 1 / n,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 7),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                c.withValues(alpha: 0.26),
                                c.withValues(alpha: 0.11),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: c.withValues(alpha: 0.40),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: c.withValues(alpha: 0.28),
                                blurRadius: 16,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // ── Tab items ───────────────────────────────────────────
              Row(
                children: List.generate(n, (i) {
                  final selected = i == widget.selectedIndex;
                  final color = widget.colors[i];
                  final item = _items[i];

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => widget.onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedBuilder(
                        animation: _bounceAnims[i],
                        builder: (_, __) => Transform.scale(
                          scale: selected ? _bounceAnims[i].value : 1.0,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 6),

                              // Icon
                              SizedBox(
                                width: 26,
                                height: 26,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  transitionBuilder: (child, anim) =>
                                      ScaleTransition(
                                          scale: anim, child: child),
                                  child: Icon(
                                    selected ? item.$1 : item.$2,
                                    key: ValueKey('${i}_$selected'),
                                    color: selected
                                        ? color
                                        : Colors.white.withValues(alpha: 0.32),
                                    size: selected ? 23 : 20,
                                    shadows: selected
                                        ? [
                                            Shadow(
                                              color:
                                                  color.withValues(alpha: 0.90),
                                              blurRadius: 14,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 3),

                              // Label
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 260),
                                style: TextStyle(
                                  color: selected
                                      ? color
                                      : Colors.white.withValues(alpha: 0.28),
                                  fontSize: selected ? 9.5 : 9.0,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  letterSpacing: selected ? 0.3 : 0,
                                ),
                                child: Text(item.$3),
                              ),

                              const SizedBox(height: 4),

                              // Glowing dot indicator
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 320),
                                curve: Curves.easeInOutCubic,
                                width: selected ? 20 : 0,
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: selected
                                      ? LinearGradient(colors: [
                                          color.withValues(alpha: 0.05),
                                          color,
                                          color.withValues(alpha: 0.05),
                                        ])
                                      : null,
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: color.withValues(alpha: 0.9),
                                            blurRadius: 10,
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
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
