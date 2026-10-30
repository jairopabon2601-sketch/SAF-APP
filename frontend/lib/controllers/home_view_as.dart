import '../screens/home/home_dependencies.dart';
import 'home_actions.dart';
import 'home_data_controller.dart';

/// "Ver como…": el administrador consulta las cuentas y movimientos de otro
/// usuario activo sin cerrar sesión. Solo cambia el `usuario` que la app
/// envía a los endpoints de cuentas/movimientos (ver
/// HomeRepository.dataUserCode); sesión, permisos y menú siguen siendo los
/// del administrador.
extension HomeViewAs<T extends StatefulWidget> on HomeController<T> {
  bool get isViewingAs => repository.isViewingAs;

  String get viewAsName =>
      (repository.viewAsUser?['nombre'] ?? '').toString();

  Future<void> switchViewAs(Map<String, dynamic>? usuario) async {
    repository.viewAsUser = usuario;
    // Nada de lo cacheado del usuario anterior sirve: saldos, movimientos y
    // totales se piden de nuevo para el usuario elegido.
    repository.invalidateCache();
    refresh(() {
      accounts = [];
      movements = [];
      selectedAccountMovements = [];
      selectedAccountMovementsName = '';
      accountFilter = '';
      movementsPage = 1;
      serverIncome = 0;
      serverExpenses = 0;
      serverTotalsLoaded = false;
      serverTotalsIsFallback = false;
      movementsSettled = false;
      filteredTotalsLoaded = false;
      loadingData = true;
      invalidateComputedCache();
    });
    await loadData();
    if (isMounted) refresh(() => loadingData = false);
  }

  // ── Selector ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _fetchUsuariosViewAs() async {
    final r = await repository.cachedPost(
      '/ajax/gestion_usuarios.php',
      {'accion': 'listar'},
      ttl: const Duration(minutes: 5),
    );
    if (r.statusCode != 200) {
      throw Exception('El servidor no respondió correctamente');
    }
    final d = decodeJsonMap(r.body);
    final raw = d['datos'];
    if (raw is! List) throw Exception('No se pudo leer la lista de usuarios');
    return raw.whereType<Map>().map((e) {
      final m = <String, dynamic>{};
      for (final entry in e.entries) {
        m[entry.key.toString().toLowerCase().replaceAll(' ', '_')] =
            entry.value;
      }
      return m;
    }).toList();
  }

  void showViewAsPicker() {
    final own = repository.ownUserCode;
    showModalBottomSheet(
      context: screenContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _ViewAsSheet(
        ownCode: own,
        currentCode: isViewingAs ? repository.dataUserCode : '',
        loadUsers: _fetchUsuariosViewAs,
        onPick: (u) {
          Navigator.of(sheetCtx).pop();
          unawaited(switchViewAs(u));
        },
        onBackToMe: isViewingAs
            ? () {
                Navigator.of(sheetCtx).pop();
                unawaited(switchViewAs(null));
              }
            : null,
      ),
    );
  }

  // ── Barra "Viendo como" ─────────────────────────────────────────────────

  Widget buildViewAsBanner() => AnimatedSize(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(
                      begin: const Offset(0, -0.25), end: Offset.zero)
                  .animate(anim),
              child: child,
            ),
          ),
          child: isViewingAs
              ? _ViewAsBanner(
                  key: ValueKey('viewas_${repository.dataUserCode}'),
                  nombre: viewAsName,
                  onChange: showViewAsPicker,
                  onExit: () => unawaited(switchViewAs(null)),
                )
              : const SizedBox(width: double.infinity, key: ValueKey('viewas_off')),
        ),
      );
}

String _nombreUsuario(Map<String, dynamic> u) {
  final n = [
    (u['nombres'] ?? '').toString().trim(),
    (u['apellidos'] ?? '').toString().trim(),
  ].where((p) => p.isNotEmpty).join(' ');
  if (n.isNotEmpty) return n;
  return (u['usuario'] ?? u['email'] ?? u['correo'] ?? 'Usuario').toString();
}

bool _usuarioActivo(Map<String, dynamic> u) {
  final e = (u['estado'] ?? u['codigo_estado'] ?? u['activo'] ?? '')
      .toString()
      .toLowerCase();
  return e.isEmpty || e == '1' || e == 'activo' || e == 'true';
}

String _fotoUsuario(Map<String, dynamic> u) {
  for (final k in ['foto', 'imagen', 'avatar', 'foto_perfil', 'img']) {
    final raw = (u[k] ?? '').toString().trim();
    if (raw.isNotEmpty && !isNoPhotoValue(raw)) {
      return raw.startsWith('http')
          ? raw
          : 'https://www.jorgemario.co/ext/saf/img/icons/$raw';
    }
  }
  return '';
}

Widget _inicialAvatar(String nombre, double size) => Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF0E7490), Color(0xFF4361EE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
        style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.4),
      ),
    );

Widget _avatarUsuario(String nombre, String foto, double size) {
  if (foto.isEmpty) return _inicialAvatar(nombre, size);
  return ClipOval(
    child: Image.network(
      foto,
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheWidth: (size * 3).round(),
      errorBuilder: (_, __, ___) => _inicialAvatar(nombre, size),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _ViewAsBanner extends StatefulWidget {
  const _ViewAsBanner({
    super.key,
    required this.nombre,
    required this.onChange,
    required this.onExit,
  });

  final String nombre;
  final VoidCallback onChange;
  final VoidCallback onExit;

  @override
  State<_ViewAsBanner> createState() => _ViewAsBannerState();
}

class _ViewAsBannerState extends State<_ViewAsBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3800))
    ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF062A4F), Color(0xFF0B4A7E), Color(0xFF0E7490)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0891B2).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(children: [
          // Barrido de luz
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) {
                    final t = (_ctrl.value / 0.45).clamp(0.0, 1.0);
                    if (t <= 0 || t >= 1) return const SizedBox.shrink();
                    return Align(
                      alignment: Alignment(-1.6 + 3.2 * t, 0),
                      child: Transform.rotate(
                        angle: 0.35,
                        child: Container(
                          width: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.16),
                              Colors.white.withValues(alpha: 0),
                            ]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: const Icon(Icons.visibility_rounded,
                    color: Color(0xFFA5F3FC), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('VIENDO COMO',
                        style: TextStyle(
                            color: Color(0xFF7DD3FC),
                            fontSize: 9.5,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 1),
                    Text(widget.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              _BannerButton(
                icon: Icons.swap_horiz_rounded,
                onTap: widget.onChange,
                filled: false,
              ),
              const SizedBox(width: 6),
              _BannerButton(
                icon: Icons.undo_rounded,
                label: 'Mi usuario',
                onTap: widget.onExit,
                filled: true,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _BannerButton extends StatelessWidget {
  const _BannerButton({
    required this.icon,
    required this.onTap,
    required this.filled,
    this.label,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.symmetric(
              horizontal: label == null ? 8 : 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            gradient: filled
                ? const LinearGradient(
                    colors: [Color(0xFF6EE7B7), Color(0xFF34D399)])
                : null,
            color: filled ? null : Colors.white.withValues(alpha: 0.12),
            border: filled
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 16,
                color: filled ? const Color(0xFF064E3B) : Colors.white),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(label!,
                  style: const TextStyle(
                      color: Color(0xFF064E3B),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800)),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ViewAsSheet extends StatefulWidget {
  const _ViewAsSheet({
    required this.ownCode,
    required this.currentCode,
    required this.loadUsers,
    required this.onPick,
    this.onBackToMe,
  });

  final String ownCode;
  final String currentCode;
  final Future<List<Map<String, dynamic>>> Function() loadUsers;
  final void Function(Map<String, dynamic> usuario) onPick;
  final VoidCallback? onBackToMe;

  @override
  State<_ViewAsSheet> createState() => _ViewAsSheetState();
}

class _ViewAsSheetState extends State<_ViewAsSheet> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _error = '';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final data = await widget.loadUsers();
      if (!mounted) return;
      setState(() {
        _users = data
            .where(_usuarioActivo)
            .where((u) =>
                (u['codigo_usuario'] ?? '').toString() != widget.ownCode &&
                (u['codigo_usuario'] ?? '').toString().isNotEmpty)
            .toList()
          ..sort((a, b) => _nombreUsuario(a)
              .toLowerCase()
              .compareTo(_nombreUsuario(b).toLowerCase()));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtrados = q.isEmpty
        ? _users
        : _users
            .where((u) =>
                _nombreUsuario(u).toLowerCase().contains(q) ||
                (u['usuario'] ?? '').toString().toLowerCase().contains(q))
            .toList();
    final maxH = MediaQuery.of(context).size.height * 0.82;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Container(
          decoration: BoxDecoration(
            color: dialogBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF06173F),
                    Color(0xFF0E3A8A),
                    Color(0xFF0891B2)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.elasticOut,
                    builder: (_, v, child) =>
                        Transform.scale(scale: 0.6 + 0.4 * v, child: child),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28)),
                      ),
                      child: const Icon(Icons.manage_search_rounded,
                          color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ver como…',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        SizedBox(height: 2),
                        Text(
                            'Consulta las cuentas y movimientos de otro usuario sin cerrar tu sesión',
                            style: TextStyle(
                                color: Color(0xFFBAE6FD), fontSize: 11.5)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      hintText: 'Buscar usuario…',
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55)),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: Colors.white.withValues(alpha: 0.7)),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ]),
            ),
            if (widget.onBackToMe != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: widget.onBackToMe,
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        border: Border.all(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.4)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.undo_rounded,
                            color: Color(0xFF10B981), size: 18),
                        SizedBox(width: 10),
                        Text('Volver a mi usuario',
                            style: TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5)),
                      ]),
                    ),
                  ),
                ),
              ),
            Flexible(
              child: _loading
                  ? ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: 5,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, __) => Container(
                        height: 62,
                        decoration: BoxDecoration(
                          color: lineCol.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    )
                  : _error.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(_error,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Color(0xFFEF4444), fontSize: 13)),
                            const SizedBox(height: 10),
                            TextButton(
                                onPressed: _load,
                                child: const Text('Reintentar')),
                          ]),
                        )
                      : filtrados.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                  q.isEmpty
                                      ? 'No hay otros usuarios activos'
                                      : 'Ningún usuario coincide con la búsqueda',
                                  style:
                                      TextStyle(color: textSoft, fontSize: 13)),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.fromLTRB(16, 14, 16,
                                  20 + MediaQuery.of(context).padding.bottom),
                              itemCount: filtrados.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 9),
                              itemBuilder: (_, i) {
                                final u = filtrados[i];
                                final code =
                                    (u['codigo_usuario'] ?? '').toString();
                                return _ViewAsUserTile(
                                  key: ValueKey('viewas_u_$code'),
                                  usuario: u,
                                  index: i,
                                  selected: code == widget.currentCode,
                                  onTap: () => widget.onPick({
                                    'codigo_usuario': code,
                                    'nombre': _nombreUsuario(u),
                                    'usuario':
                                        (u['usuario'] ?? '').toString(),
                                  }),
                                );
                              },
                            ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ViewAsUserTile extends StatelessWidget {
  const _ViewAsUserTile({
    super.key,
    required this.usuario,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final Map<String, dynamic> usuario;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nombre = _nombreUsuario(usuario);
    final perfil =
        (usuario['perfil'] ?? usuario['nombre_perfil'] ?? '').toString();
    final login = (usuario['usuario'] ?? '').toString();
    final sub = [if (login.isNotEmpty) login, if (perfil.isNotEmpty) perfil]
        .join(' · ');
    final i = index < 12 ? index : 12;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 320 + i * 40),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
            offset: Offset(0, 14 * (1 - v)), child: child),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: selected
                  ? const Color(0xFF0891B2).withValues(alpha: 0.14)
                  : cardBg,
              border: Border.all(
                color: selected
                    ? const Color(0xFF38BDF8).withValues(alpha: 0.6)
                    : lineCol,
              ),
            ),
            child: Row(children: [
              _avatarUsuario(nombre, _fotoUsuario(usuario), 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: textMain,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    if (sub.isNotEmpty)
                      Text(sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: textSoft, fontSize: 11.5)),
                  ],
                ),
              ),
              if (selected)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('ACTUAL',
                      style: TextStyle(
                          color: Color(0xFF0891B2),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8)),
                )
              else
                Icon(Icons.visibility_outlined, color: textSoft, size: 19),
            ]),
          ),
        ),
      ),
    );
  }
}
