import '../screens/home/home_dependencies.dart';
import '../widgets/home/shimmer_header_overlay.dart';

/// Gestión de permisos por perfil (solo perfil 6 / super admin puede
/// invocar esta pantalla y guardar cambios — el backend también lo valida
/// de forma independiente en listar_permisos_perfil.php y
/// guardar_permisos_perfil.php, así que esto no es la única barrera).
extension HomePermissionsDialog<T extends StatefulWidget> on HomeController<T> {
  static const _perfiles = [
    (
      6,
      'Super Admin',
      Icons.shield_rounded,
      [Color(0xFF1E3A8A), Color(0xFF4F46E5)],
      Color(0x594F46E5),
    ),
    (
      5,
      'Asesor de Créditos',
      Icons.credit_card_rounded,
      [Color(0xFF92400E), Color(0xFFF59E0B)],
      Color(0x59F59E0B),
    ),
    (
      1,
      'Asesor de Ahorros',
      Icons.savings_rounded,
      [Color(0xFF065F46), Color(0xFF10B981)],
      Color(0x5910B981),
    ),
  ];
  static const _modulos = [
    ('creditos', 'Créditos', Icons.credit_card_rounded, Color(0xFF38BDF8)),
    ('ahorros', 'Ahorros', Icons.savings_rounded, Color(0xFF34D399)),
    ('movimientos', 'Movimientos', Icons.swap_horiz_rounded, Color(0xFFA78BFA)),
    ('usuarios', 'Gestión de Usuarios', Icons.manage_accounts_rounded,
        Color(0xFFFB7185)),
  ];

  void showGestionPermisos() {
    Map<int, Map<String, bool>> permisos = {};
    bool loading = true;
    bool started = false;
    Set<int> saving = {};
    String error = '';

    Future<void> cargar(StateSetter setS, BuildContext ctx) async {
      setS(() => loading = true);
      try {
        final r = await repository.post('/ajax/listar_permisos_perfil.php', {});
        if (!ctx.mounted) return;
        final d = decodeJsonMap(r.body);
        if (d['success'] == true && d['permisos'] is Map) {
          final raw = d['permisos'] as Map;
          setS(() {
            permisos = raw.map((perfil, mods) => MapEntry(
                  int.parse(perfil.toString()),
                  Map<String, bool>.from((mods as Map)
                      .map((k, v) => MapEntry(k.toString(), v == true || v == 'true'))),
                ));
            loading = false;
            error = '';
          });
        } else {
          setS(() {
            error = (d['msg'] ?? 'No se pudieron cargar los permisos.').toString();
            loading = false;
          });
        }
      } catch (e) {
        if (ctx.mounted) {
          setS(() {
            error = e.toString().replaceFirst('Exception: ', '');
            loading = false;
          });
        }
      }
    }

    showDialog(
      context: screenContext,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          if (!started) {
            started = true;
            cargar(setS, ctx);
          }

          Future<void> guardarPerfil(int codigoPerfil) async {
            setS(() => saving.add(codigoPerfil));
            try {
              final mods = permisos[codigoPerfil] ?? {};
              final r =
                  await repository.post('/ajax/guardar_permisos_perfil.php', {
                'codigo_perfil': codigoPerfil.toString(),
                for (final m in _modulos)
                  m.$1: (mods[m.$1] == true) ? '1' : '0',
              });
              final d = decodeJsonMap(r.body);
              final ok = d['success'] == true;
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    backgroundColor:
                        ok ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    content: Text(
                      (d['msg'] ?? (ok ? 'Permisos actualizados.' : 'No se pudo guardar.'))
                          .toString(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              }
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFFDC2626),
                    content: Text(e.toString().replaceFirst('Exception: ', ''),
                        style: const TextStyle(color: Colors.white)),
                  ),
                );
              }
            } finally {
              if (ctx.mounted) setS(() => saving.remove(codigoPerfil));
            }
          }

          return Dialog.fullscreen(
            backgroundColor: appBg,
            child: SafeArea(
              child: Column(
                children: [
                  _buildPermissionsHeader(
                    onBack: () => Navigator.pop(ctx),
                    totalPerfiles: _perfiles.length,
                    totalModulos: _modulos.length,
                  ),
                  Expanded(
                    child: loading
                        ? const Center(
                            child: CircularProgressIndicator(color: homeAccent))
                        : error.isNotEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.error_outline_rounded,
                                        color: textSoft, size: 40),
                                    const SizedBox(height: 12),
                                    Text(error,
                                        style: TextStyle(color: textSoft)),
                                    const SizedBox(height: 16),
                                    TextButton(
                                      onPressed: () => cargar(setS, ctx),
                                      child: const Text('Reintentar'),
                                    ),
                                  ],
                                ),
                              )
                            : ListView(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                                children: [
                                  for (var i = 0; i < _perfiles.length; i++)
                                    _PerfilPermisosCard(
                                      index: i,
                                      nombre: _perfiles[i].$2,
                                      icon: _perfiles[i].$3,
                                      gradient: _perfiles[i].$4,
                                      glow: _perfiles[i].$5,
                                      modulos: _modulos,
                                      valores: permisos[_perfiles[i].$1] ?? {},
                                      saving: saving.contains(_perfiles[i].$1),
                                      onToggle: (clave, valor) => setS(() {
                                        permisos[_perfiles[i].$1] ??= {};
                                        permisos[_perfiles[i].$1]![clave] = valor;
                                      }),
                                      onGuardar: () =>
                                          guardarPerfil(_perfiles[i].$1),
                                    ),
                                ],
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget _buildPermissionsHeader({
  required VoidCallback onBack,
  required int totalPerfiles,
  required int totalModulos,
}) {
  return Container(
    clipBehavior: Clip.hardEdge,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Color(0xFF060E35),
          Color(0xFF2E1065),
          Color(0xFF6D28D9),
          Color(0xFFC026D3),
        ],
        stops: [0.0, 0.35, 0.70, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Stack(children: [
      Positioned(
        right: -40,
        top: -40,
        child: Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              Colors.white.withValues(alpha: 0.09),
              Colors.transparent,
            ]),
          ),
        ),
      ),
      Positioned(
        left: -20,
        bottom: -20,
        child: Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ),
      Positioned(
        right: 60,
        bottom: -30,
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              const Color(0xFFE879F9).withValues(alpha: 0.18),
              Colors.transparent,
            ]),
          ),
        ),
      ),
      const Positioned.fill(child: ShimmerHeaderOverlay()),
      SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
          child: Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.white.withValues(alpha: 0.25),
                    Colors.white.withValues(alpha: 0.10),
                  ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.28)),
                ),
                child: const Icon(Icons.tune_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gestión de permisos',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('Qué módulos ve cada perfil',
                        style: TextStyle(
                            color: Colors.white60,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _permStatChip(Icons.badge_rounded, totalPerfiles, 'Perfiles',
                  const Color(0xFF60A5FA), index: 0),
              const SizedBox(width: 8),
              _permStatChip(Icons.widgets_rounded, totalModulos, 'Módulos',
                  const Color(0xFFE879F9), index: 1),
            ]),
          ]),
        ),
      ),
    ]),
  );
}

Widget _permStatChip(IconData icon, int value, String label, Color color,
        {int index = 0}) =>
    Expanded(
      child: TweenAnimationBuilder<double>(
        key: ValueKey('permstat_${label}_$value'),
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Interval(
          (index * 0.12).clamp(0.0, 0.4),
          (index * 0.12 + 0.6).clamp(0.5, 1.0),
          curve: Curves.easeOutBack,
        ),
        builder: (_, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TweenAnimationBuilder<double>(
                key: ValueKey('permstatval_${label}_$value'),
                tween: Tween(begin: 0.0, end: value.toDouble()),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => Text(v.round().toString(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5)),
              ),
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.60),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      ),
    );

class _PerfilPermisosCard extends StatefulWidget {
  final int index;
  final String nombre;
  final IconData icon;
  final List<Color> gradient;
  final Color glow;
  final List<(String, String, IconData, Color)> modulos;
  final Map<String, bool> valores;
  final bool saving;
  final void Function(String clave, bool valor) onToggle;
  final VoidCallback onGuardar;

  const _PerfilPermisosCard({
    required this.index,
    required this.nombre,
    required this.icon,
    required this.gradient,
    required this.glow,
    required this.modulos,
    required this.valores,
    required this.saving,
    required this.onToggle,
    required this.onGuardar,
  });

  @override
  State<_PerfilPermisosCard> createState() => _PerfilPermisosCardState();
}

class _PerfilPermisosCardState extends State<_PerfilPermisosCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('permcard_${widget.nombre}'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 450 + widget.index * 90),
      curve: Curves.easeOutBack,
      builder: (_, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
            offset: Offset(0, 24 * (1 - t).clamp(0.0, 1.0)), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: lineCol),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: widget.glow,
              blurRadius: 24,
              spreadRadius: -8,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barra superior con el color propio del perfil
            Container(
              height: 6,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.gradient.first,
                    widget.gradient.last,
                    Color.lerp(widget.gradient.last, Colors.white, 0.3)!,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: lineCol)),
              ),
              child: Row(children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(
                      milliseconds: 550 + widget.index * 90),
                  curve: Curves.elasticOut,
                  builder: (_, t, child) => Transform.scale(
                      scale: t.clamp(0.0, 1.3), child: child),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: widget.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                            color: widget.glow, blurRadius: 12, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.nombre,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: textMain)),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Column(
                children: [
                  for (var i = 0; i < widget.modulos.length; i++)
                    _ModuloTile(
                      delayMs: widget.index * 90 + i * 60 + 200,
                      icon: widget.modulos[i].$3,
                      color: widget.modulos[i].$4,
                      label: widget.modulos[i].$2,
                      checked: widget.valores[widget.modulos[i].$1] == true,
                      disabled: widget.saving,
                      onChanged: (v) => widget.onToggle(widget.modulos[i].$1, v),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: GestureDetector(
                onTapDown: (_) => setState(() => _pressed = true),
                onTapUp: (_) => setState(() => _pressed = false),
                onTapCancel: () => setState(() => _pressed = false),
                child: AnimatedScale(
                  scale: _pressed ? 0.97 : 1.0,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  child: Opacity(
                    opacity: widget.saving ? 0.65 : 1.0,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          colors: [
                            widget.gradient.first,
                            widget.gradient.last,
                            Color.lerp(widget.gradient.last, Colors.white, 0.22)!,
                          ],
                          stops: const [0.0, 0.65, 1.0],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.glow,
                            blurRadius: 20,
                            spreadRadius: -2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: widget.saving ? null : widget.onGuardar,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            child: Center(
                              child: widget.saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Guardar',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          letterSpacing: 0.2)),
                            ),
                          ),
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
    );
  }
}

class _ModuloTile extends StatelessWidget {
  final int delayMs;
  final IconData icon;
  final Color color;
  final String label;
  final bool checked;
  final bool disabled;
  final ValueChanged<bool> onChanged;

  const _ModuloTile({
    required this.delayMs,
    required this.icon,
    required this.color,
    required this.label,
    required this.checked,
    required this.disabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 320 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
            offset: Offset(-10 * (1 - t).clamp(0.0, 1.0), 0), child: child),
      ),
      child: GestureDetector(
        onTap: disabled ? null : () => onChanged(!checked),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: checked ? color.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: checked ? color.withValues(alpha: 0.35) : lineCol,
              width: checked ? 1.3 : 1,
            ),
          ),
          child: Row(children: [
            Icon(icon, size: 18, color: checked ? color : textSoft),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: checked ? textMain : textSoft)),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
                child: RotationTransition(
                  turns: Tween(begin: 0.15, end: 0.0).animate(anim),
                  child: child,
                ),
              ),
              child: checked
                  ? Icon(Icons.check_circle_rounded,
                      key: const ValueKey('on'), color: color, size: 22)
                  : Icon(Icons.radio_button_unchecked_rounded,
                      key: const ValueKey('off'), color: textSoft, size: 22),
            ),
          ]),
        ),
      ),
    );
  }
}
