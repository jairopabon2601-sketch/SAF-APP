// ignore_for_file: use_build_context_synchronously

import '../screens/home/home_dependencies.dart';
import '../screens/home/credits_screen.dart';
import '../widgets/home/home_dialogs.dart';
import '../widgets/home/shimmer_header_overlay.dart';

// Cuentas sin foto propia: la columna no siempre queda vacía. Algunas traen
// "0" (valor por defecto) y otras el isotipo de SAF (asignado como
// placeholder genérico) en vez de una foto real — ambos casos se tratan
// como "sin foto" para mostrar el avatar de iniciales en su lugar.
bool isNoPhotoValue(String raw) =>
    raw == 'null' || raw == '0' || raw == 'saf_isotipo.png';

// Paleta por rol, compartida entre el formulario y las tarjetas del listado
// para que un mismo perfil se vea siempre del mismo color.
({List<Color> grad, IconData icon}) perfilTheme(String nombreOCodigo) {
  final n = nombreOCodigo.toLowerCase();
  if (n == '6' || n.contains('admin')) {
    return (
      // Mismo azul-índigo que "Super Admin" en Gestión de permisos.
      grad: const [Color(0xFF1E3A8A), Color(0xFF4F46E5)],
      icon: Icons.admin_panel_settings_rounded
    );
  }
  if (n == '5' ||
      n.contains('crédito') ||
      n.contains('credito') ||
      n.contains('contrat')) {
    return (
      grad: const [Color(0xFFD97706), Color(0xFFF59E0B)],
      icon: Icons.credit_card_rounded
    );
  }
  if (n == '1' || n.contains('ahorro') || n.contains('socio')) {
    return (
      grad: const [Color(0xFF059669), Color(0xFF10B981)],
      icon: Icons.savings_rounded
    );
  }
  return (
    grad: const [Color(0xFF4361EE), Color(0xFF00D2FF)],
    icon: Icons.shield_outlined
  );
}

extension HomeActions<T extends StatefulWidget> on HomeController<T> {
  void invalidateComputedCache() {
    cachedBalanceTotal = null;
    cachedIncomeTotal = null;
    cachedExpenseTotal = null;
    cachedFilteredSavers = null;
  }

  String advisorName(String codigoOSigla) {
    final sigla = creditAdvisorInitials(codigoOSigla).trim().toUpperCase();
    return advisorNames[sigla] ?? sigla;
  }

  // Avatar de asesor compartido por los filtros de Ahorros y Créditos:
  // intenta la foto real de tbl_asesores (ya viene en `advisors` vía
  // fetchAdvisors, la misma fuente que usa photoUrl para el perfil propio)
  // y si no hay foto o falla la carga, cae al avatar de iniciales con
  // degradado indigo. Sin sigla (p.ej. "Todos") muestra un ícono de grupo.
  Widget advisorAvatarMini(String sigla, {double size = 22}) {
    if (sigla.isEmpty || sigla == '0') {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: textSoft.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(size * 0.32),
        ),
        child: Icon(Icons.groups_rounded, size: size * 0.6, color: textSoft),
      );
    }
    final nombre = advisorName(sigla);
    final parts = nombre.trim().split(RegExp(r'\s+'));
    final i1 = parts.isNotEmpty && parts[0].isNotEmpty
        ? parts[0][0].toUpperCase()
        : 'A';
    final i2 = parts.length > 1
        ? parts[parts.length >= 3 ? 2 : 1][0].toUpperCase()
        : '';
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF818CF8),
            Color(0xFF4361EE),
            Color(0xFF3730A3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Center(
        child: Text('$i1$i2',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.41,
                letterSpacing: 0.3)),
      ),
    );

    final fila = advisors.firstWhere(
      (a) =>
          (a['sigla'] ?? '').toString().trim().toUpperCase() ==
          sigla.toUpperCase(),
      orElse: () => <String, dynamic>{},
    );
    var url = '';
    for (final k in [
      'foto',
      'imagen',
      'avatar',
      'photo',
      'fotografia',
      'foto_perfil',
      'imagen_perfil',
      'picture',
      'img'
    ]) {
      final raw = (fila[k] ?? '').toString().trim();
      if (raw.isNotEmpty && !isNoPhotoValue(raw)) {
        url = raw.startsWith('http')
            ? raw
            : 'https://www.jorgemario.co/ext/saf/img/icons/$raw';
        break;
      }
    }
    if (url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.32),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  String creditAdvisorCode(String sigla) {
    final buscada = sigla.trim().toUpperCase();
    if (buscada.isEmpty) return '';
    for (final asesor in advisors) {
      final itemSigla = (asesor['sigla'] ?? '').toString().trim().toUpperCase();
      if (itemSigla == buscada) {
        return (asesor['codigo_asesor'] ?? asesor['codigo'] ?? sigla)
            .toString()
            .trim();
      }
    }
    return sigla;
  }

  String creditAdvisorInitials(String codigoOSigla) {
    final buscado = codigoOSigla.trim().toUpperCase();
    if (buscado.isEmpty) return '';
    for (final asesor in advisors) {
      final codigo =
          (asesor['codigo_asesor'] ?? asesor['codigo'] ?? '').toString().trim();
      final sigla = (asesor['sigla'] ?? '').toString().trim();
      if (codigo == buscado || sigla.toUpperCase() == buscado) return sigla;
    }
    return codigoOSigla;
  }

  // Ahorradores tras aplicar el filtro de asesor (memoizado)
  List<Map<String, dynamic>> get filteredSavers {
    // Perfil asesor (1): siempre filtra por su propio codigoOrigen
    if (isAsesor) {
      const cacheKey = '__asesor__';
      if (cachedSavingsAdvisorFilter == cacheKey &&
          cachedFilteredSavers != null) {
        return cachedFilteredSavers!;
      }
      cachedSavingsAdvisorFilter = cacheKey;
      final myCode = codigoOrigen.trim();
      if (myCode.isEmpty || myCode == '0') {
        cachedFilteredSavers = savers;
      } else {
        cachedFilteredSavers = savers.where((a) {
          // Comparación directa por codigo_asesor numérico (más confiable)
          final itemCode = (a['codigo_asesor'] ?? '').toString().trim();
          if (itemCode == myCode) return true;
          // Fallback por sigla cuando advisors ya cargó
          if (advisors.isNotEmpty) {
            final myInitials =
                creditAdvisorInitials(myCode).trim().toUpperCase();
            final itemInitials = creditAdvisorInitials(
              (a['asesor'] ?? itemCode).toString(),
            ).trim().toUpperCase();
            return myInitials.isNotEmpty && myInitials == itemInitials;
          }
          return false;
        }).toList();
      }
      return cachedFilteredSavers!;
    }

    final selectedAdvisor = savingsAdvisorFilter == '0'
        ? '0'
        : creditAdvisorInitials(savingsAdvisorFilter).trim().toUpperCase();
    if (cachedSavingsAdvisorFilter == selectedAdvisor &&
        cachedFilteredSavers != null) {
      return cachedFilteredSavers!;
    }
    cachedSavingsAdvisorFilter = selectedAdvisor;
    if (selectedAdvisor == '0') {
      cachedFilteredSavers = savers;
    } else {
      cachedFilteredSavers = savers.where((a) {
        final itemAdvisor = creditAdvisorInitials(
          (a['asesor'] ?? a['codigo_asesor'] ?? '').toString(),
        ).trim().toUpperCase();
        return itemAdvisor == selectedAdvisor;
      }).toList();
    }
    return cachedFilteredSavers!;
  }

  // ── Computed (memoized) ─────────────────────────────────────────
  double get totalBalance {
    cachedBalanceTotal ??= accounts.fold<double>(
        0.0,
        (s, c) =>
            s +
            numberValue(c['saldo_actual'] ?? c['saldo'] ?? c['balance'] ?? 0));
    return cachedBalanceTotal!;
  }

  double get totalIncome {
    if (serverTotalsLoaded) return serverIncome;
    cachedIncomeTotal ??= movements
        .where(movementIsIncome)
        .fold<double>(0.0, (s, m) => s + numberValue(m['valor'] ?? 0));
    return cachedIncomeTotal!;
  }

  double get totalExpenses {
    if (serverTotalsLoaded) return serverExpenses;
    cachedExpenseTotal ??= movements
        .where((m) => !movementIsIncome(m))
        .fold<double>(0.0, (s, m) => s + numberValue(m['valor'] ?? 0));
    return cachedExpenseTotal!;
  }

  // ── User helpers ────────────────────────────────────────────────
  String get fullName {
    final u = repository.user;
    if (u == null) return 'Usuario';
    // Buscar en el objeto perfil primero (tbl_asesores, tbl_deudores, etc.)
    final p = u['perfil'];
    final perfil =
        p is Map ? Map<String, dynamic>.from(p) : <String, dynamic>{};
    for (final src in [perfil, u]) {
      final nombres = (src['nombres'] ?? src['nombre'] ?? '').toString().trim();
      final apellidos =
          (src['apellidos'] ?? src['apellido'] ?? '').toString().trim();
      if (nombres.isNotEmpty && apellidos.isNotEmpty) {
        return '$nombres $apellidos';
      }
      for (final k in [
        'nombre_completo',
        'fullname',
        'name',
        'nombres',
        'nombre'
      ]) {
        final v = (src[k] ?? '').toString().trim();
        if (v.isNotEmpty) return v;
      }
    }
    final email = (u['usuario'] ?? u['email'] ?? '').toString().trim();
    if (email.contains('@')) return email.split('@').first;
    if (email.isNotEmpty) return email;
    return 'Usuario';
  }

  String get photoUrl {
    final u = repository.user;
    if (u == null) return '';
    final p = u['perfil'];
    final perfil =
        p is Map ? Map<String, dynamic>.from(p) : <String, dynamic>{};
    for (final src in [perfil, u]) {
      for (final k in [
        'foto',
        'imagen',
        'avatar',
        'photo',
        'fotografia',
        'foto_perfil',
        'imagen_perfil',
        'picture',
        'img'
      ]) {
        final raw = (src[k] ?? '').toString().trim();
        // Las cuentas sin foto propia a veces guardan "0" (valor por
        // defecto de la columna) o el isotipo de SAF como placeholder
        // genérico, en vez de vacío/null — sin este filtro se arma una URL
        // que "carga" pero no es una foto real, en lugar de caer a iniciales.
        if (raw.isNotEmpty && !isNoPhotoValue(raw)) {
          final bust = photoCacheBust != null ? '?v=$photoCacheBust' : '';
          if (raw.startsWith('http')) return '$raw$bust';
          return 'https://www.jorgemario.co/ext/saf/img/icons/$raw$bust';
        }
      }
    }
    return '';
  }

  // Clave estable para la caché de la foto de perfil — a diferencia de
  // photoUrl (que trae un `?v=timestamp` que cambia con cada subida), esto
  // no cambia entre sesiones, así que main() puede precargar la foto en
  // memoria antes de runApp() sin depender de que photoUrl ya esté resuelto.
  String get photoCacheKey {
    final u = repository.user;
    return (u?['codigo_usuario'] ?? '').toString();
  }

  // ── Actions ─────────────────────────────────────────────────────
  void logout() async {
    await repository.logout();
    if (isMounted) Navigator.of(screenContext).pushReplacementNamed('/login');
  }

  void showProfileSheet() {
    final u = repository.user;
    final email = (u?['email'] ?? u?['correo'] ?? '').toString();
    showModalBottomSheet(
      context: screenContext,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => buildProfileSheet(email, onUploadPhoto: uploadPhoto),
    );
  }

  Future<({String? filename, String? error})> uploadPhoto(
      Uint8List bytes) async {
    try {
      final base64Image = base64Encode(bytes);
      final r = await repository
          .post('/ajax/actualizar_foto.php', {'foto': base64Image});
      if (r.statusCode != 200) {
        debugPrint('[SAF] uploadPhoto: HTTP ${r.statusCode} -> ${r.body}');
        return (filename: null, error: 'Error del servidor (${r.statusCode})');
      }
      final d = decodeJsonMap(r.body);
      if (d.isEmpty) {
        debugPrint('[SAF] uploadPhoto: respuesta no JSON -> ${r.body}');
        return (
          filename: null,
          error: 'El servidor devolvió una respuesta inválida'
        );
      }
      if (d['resultado'] != 1) {
        final mensaje =
            (d['mensaje'] ?? 'No se pudo actualizar la foto').toString();
        debugPrint('[SAF] uploadPhoto: $mensaje');
        return (filename: null, error: mensaje);
      }
      final filename = (d['foto'] ?? '').toString();
      if (filename.isEmpty) {
        return (filename: null, error: 'El servidor no devolvió el archivo');
      }
      final u = repository.user;
      if (u != null) {
        final perfil = u['perfil'];
        if (perfil is Map) {
          perfil['foto'] = filename;
        } else {
          u['foto'] = filename;
        }
      }
      photoCacheBust = DateTime.now().millisecondsSinceEpoch;
      await repository.persistUser();
      refresh(() {});
      return (filename: filename, error: null);
    } catch (e) {
      debugPrint('[SAF] uploadPhoto: $e');
      return (filename: null, error: 'Error de conexión: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUsuariosAdmin(
      {bool forceRefresh = false}) async {
    if (forceRefresh) repository.invalidateCache('/ajax/gestion_usuarios.php');
    final response = await repository.cachedPost(
        '/ajax/gestion_usuarios.php',
        {
          'accion': 'listar',
        },
        ttl: const Duration(minutes: 5));
    if (response.statusCode != 200) {
      throw Exception('El servidor no respondió correctamente');
    }
    final decoded = decodeJsonMap(response.body);
    if (decoded.isEmpty) {
      final raw = response.body
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      throw Exception(
        raw.isEmpty ? 'El servidor devolvió una respuesta vacía' : raw,
      );
    }
    if (decoded['success'] != true && decoded['resultado'] != 1) {
      throw Exception(
          decoded['mensaje']?.toString() ?? 'No se pudieron cargar usuarios');
    }
    final raw = decoded['datos'];
    if (raw is! List) {
      throw Exception('No fue posible leer el listado de usuarios');
    }
    final lista = raw.whereType<Map>().map((e) {
      // Normaliza claves: minúsculas + guión bajo en lugar de espacios
      // El SQL en tbl_conf_consultas usa aliases como "Tipo Usuario" con mayúsculas y espacios
      final m = <String, dynamic>{};
      for (final entry in e.entries) {
        final k = entry.key.toString().toLowerCase().replaceAll(' ', '_');
        m[k] = entry.value;
      }
      return m;
    }).toList();
    return lista;
  }

  void showUsersManagement() {
    List<Map<String, dynamic>> usuarios = [];
    bool loading = true;
    bool started = false;
    String error = '';
    String query = '';

    Future<void> reload(StateSetter setS, BuildContext ctx) async {
      setS(() {
        loading = true;
        error = '';
      });
      try {
        final data = await _fetchUsuariosAdmin(forceRefresh: true);
        if (ctx.mounted) {
          setS(() {
            usuarios = data;
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
            _fetchUsuariosAdmin().then<void>((data) {
              if (ctx.mounted) {
                setS(() {
                  usuarios = data;
                  loading = false;
                });
              }
            }).catchError((Object e) {
              if (ctx.mounted) {
                setS(() {
                  error = e.toString().replaceFirst('Exception: ', '');
                  loading = false;
                });
              }
            });
          }

          final filtrados = query.isEmpty
              ? usuarios
              : usuarios
                  .where((u) => u.values
                      .join(' ')
                      .toLowerCase()
                      .contains(query.toLowerCase()))
                  .toList();
          final activos = usuarios.where((u) {
            final e = (u['estado'] ?? u['activo'] ?? '').toString();
            return e.isEmpty || e == '1' || e.toLowerCase() == 'activo';
          }).length;

          return Dialog.fullscreen(
            backgroundColor: appBg,
            child: SafeArea(
              child: Column(
                children: [
                  // ── HEADER PREMIUM ──────────────────────────────
                  _buildUsersHeader(
                    ctx: ctx,
                    totalUsers: usuarios.length,
                    activeUsers: activos,
                    onBack: () => Navigator.pop(ctx),
                    onNew: () async {
                      final saved = await _showUserForm();
                      if (saved && ctx.mounted) await reload(setS, ctx);
                    },
                  ),
                  // ── SEARCH BAR ───────────────────────────────────
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (_, t, child) => Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: Transform.translate(
                          offset: Offset(0, 12 * (1 - t)), child: child),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: Row(children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: homeAccent.withValues(alpha: 0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(color: lineCol),
                            ),
                            child: TextField(
                              onChanged: (v) => setS(() => query = v.trim()),
                              style: TextStyle(color: textMain, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Buscar usuario, perfil o estado',
                                hintStyle: const TextStyle(
                                    color: Color(0xFFB0BBCC), fontSize: 13),
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(10),
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF4361EE),
                                        Color(0xFF00D2FF)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.search_rounded,
                                      color: Colors.white, size: 17),
                                ),
                                suffixIcon: query.isNotEmpty
                                    ? GestureDetector(
                                        onTap: () => setS(() => query = ''),
                                        child: Icon(Icons.close_rounded,
                                            color: textSoft, size: 18),
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  // ── RESULTS COUNT ────────────────────────────────
                  if (!loading && error.isEmpty)
                    TweenAnimationBuilder<double>(
                      key: ValueKey('userscount_${filtrados.length}'),
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      builder: (_, t, child) =>
                          Opacity(opacity: t.clamp(0.0, 1.0), child: child),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                        child: Row(children: [
                          Container(
                            width: 4,
                            height: 14,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4361EE), Color(0xFF00D2FF)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            query.isEmpty
                                ? '${usuarios.length} usuarios registrados'
                                : '${filtrados.length} de ${usuarios.length} resultados',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: textSoft,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  // ── LIST ─────────────────────────────────────────
                  Expanded(
                    child: loading
                        ? _usersLoadingSkeleton()
                        : error.isNotEmpty
                            ? _usersErrorState(error, () => reload(setS, ctx))
                            : filtrados.isEmpty
                                ? _usersEmptyState(query.isNotEmpty)
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 28),
                                    itemCount: filtrados.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (_, i) => _AdminUserTile(
                                      key: ValueKey(
                                          'usr_${filtrados[i]['codigo_usuario'] ?? i}'),
                                      user: filtrados[i],
                                      index: i,
                                      onEdit: () async {
                                        final saved =
                                            await _showUserForm(filtrados[i]);
                                        if (saved && ctx.mounted) {
                                          await reload(setS, ctx);
                                        }
                                      },
                                      onDelete: () async {
                                        final removed =
                                            await _confirmDeleteUser(
                                                filtrados[i]);
                                        if (removed && ctx.mounted) {
                                          await reload(setS, ctx);
                                        }
                                      },
                                    ),
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

  Widget _buildUsersHeader({
    required BuildContext ctx,
    required int totalUsers,
    required int activeUsers,
    required VoidCallback onBack,
    required VoidCallback onNew,
  }) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF060E35),
            Color(0xFF0D1B6E),
            Color(0xFF1435A8),
            Color(0xFF0077BB)
          ],
          stops: [0.0, 0.35, 0.70, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(children: [
        // Decorative orbs
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
                ))),
        Positioned(
            left: -20,
            bottom: -20,
            child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ))),
        Positioned(
            right: 60,
            bottom: -30,
            child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF00D2FF).withValues(alpha: 0.15),
                    Colors.transparent,
                  ]),
                ))),
        const Positioned.fill(child: ShimmerHeaderOverlay()),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
            child: Column(children: [
              // ── Fila única: back + icon + title + Nuevo ────────
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                _PressScale(
                  onTap: onBack,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16)),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 19),
                  ),
                ),
                const SizedBox(width: 11),
                // Ícono del módulo: cristal con brillo superior, para que no
                // se lea como un botón más de la fila.
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.white.withValues(alpha: 0.30),
                      Colors.white.withValues(alpha: 0.08),
                    ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.30)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: const Icon(Icons.manage_accounts_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Gestión de usuarios',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Row(children: [
                          Icon(Icons.lock_rounded,
                              size: 9,
                              color: Colors.white.withValues(alpha: 0.55)),
                          const SizedBox(width: 4),
                          Text('Acceso restringido',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.60),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.1)),
                        ]),
                      ]),
                ),
                const SizedBox(width: 8),
                _PressScale(
                  onTap: onNew,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF34D399), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25)),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF059669).withValues(alpha: 0.50),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 17),
                      SizedBox(width: 5),
                      Text('Nuevo',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.1)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              // ── Stats row ─────────────────────────────────────
              Row(children: [
                _userStatChip(Icons.people_alt_rounded, totalUsers, 'Total',
                    const Color(0xFF60A5FA),
                    index: 0),
                const SizedBox(width: 8),
                _userStatChip(Icons.check_circle_outline_rounded, activeUsers,
                    'Activos', const Color(0xFF34D399),
                    index: 1),
                const SizedBox(width: 8),
                _userStatChip(
                    Icons.lock_outline_rounded,
                    totalUsers - activeUsers,
                    'Inactivos',
                    const Color(0xFFFBBF24),
                    index: 2),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _userStatChip(IconData icon, int value, String label, Color color,
          {int index = 0}) =>
      Expanded(
        child: TweenAnimationBuilder<double>(
          key: ValueKey('userstat_${label}_$value'),
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
            padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
            decoration: BoxDecoration(
              // Vidrio oscuro con un halo del color propio de la métrica:
              // el número queda como protagonista sobre el header azul.
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.14),
                  Colors.white.withValues(alpha: 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: color.withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Stack(children: [
              // Resplandor difuso detrás del ícono.
              Positioned(
                left: -14,
                top: -18,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      color.withValues(alpha: 0.35),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
              Row(children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color,
                        Color.lerp(color, Colors.white, 0.35)!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: color.withValues(alpha: 0.55),
                          blurRadius: 9,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TweenAnimationBuilder<double>(
                          key: ValueKey('userstatval_${label}_$value'),
                          tween: Tween(begin: 0.0, end: value.toDouble()),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, __) => Text(v.round().toString(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.6,
                                  height: 1.05)),
                        ),
                        Text(label.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.62),
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5)),
                      ]),
                ),
              ]),
            ]),
          ),
        ),
      );

  Widget _usersLoadingSkeleton() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 400 + i * 60),
        curve: Curves.easeOut,
        builder: (_, t, __) => Opacity(
          opacity: t,
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: lineCol),
            ),
            child: Row(children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: lineCol,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16)),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: inputFill,
                      borderRadius: BorderRadius.circular(12))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Container(
                        height: 12,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: inputFill,
                            borderRadius: BorderRadius.circular(6))),
                    const SizedBox(height: 8),
                    Container(
                        height: 9,
                        width: 180,
                        decoration: BoxDecoration(
                            color: inputFill,
                            borderRadius: BorderRadius.circular(5))),
                  ])),
              Container(
                margin: const EdgeInsets.only(right: 12),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: inputFill, borderRadius: BorderRadius.circular(10)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _usersErrorState(String error, VoidCallback onRetry) => _stateEntrance(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFEE2E2), Color(0xFFFECDD3)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.cloud_off_rounded,
                    size: 34, color: Color(0xFFDC2626)),
              ),
              const SizedBox(height: 16),
              Text('Error de conexión',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: textMain)),
              const SizedBox(height: 6),
              Text(error,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSoft, fontSize: 12)),
              const SizedBox(height: 20),
              _PressScale(
                onTap: onRetry,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF0D1B4B), Color(0xFF1E3A8A)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: homeAccent.withValues(alpha: 0.30),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 7),
                    Text('Reintentar',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      );

  Widget _usersEmptyState(bool isSearch) => _stateEntrance(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                    isSearch
                        ? Icons.search_off_rounded
                        : Icons.people_outline_rounded,
                    size: 34,
                    color: homeAccent),
              ),
              const SizedBox(height: 16),
              Text(
                isSearch ? 'Sin resultados' : 'Sin usuarios',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: textMain),
              ),
              const SizedBox(height: 6),
              Text(
                isSearch
                    ? 'Intenta con otro término de búsqueda'
                    : 'Aún no hay usuarios registrados',
                textAlign: TextAlign.center,
                style: TextStyle(color: textSoft, fontSize: 12),
              ),
            ]),
          ),
        ),
      );

  // Entrada compartida (fade + scale) para los estados de error/vacío.
  Widget _stateEntrance(Widget child) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutBack,
        builder: (_, t, c) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.9 + 0.1 * t, child: c),
        ),
        child: child,
      );

  Future<bool> _confirmDeleteUser(Map<String, dynamic> user) async {
    final codigoUsuario =
        (user['codigo_usuario'] ?? user['codigo'] ?? '').toString();
    if (codigoUsuario.isEmpty) return false;
    final email = (user['usuario'] ?? user['email'] ?? '').toString();

    // El soft delete es reversible: si ya está inactivo, el botón reactiva.
    final estadoRaw =
        (user['estado'] ?? user['codigo_estado'] ?? user['activo'] ?? '')
            .toString();
    final activo = estadoRaw.isEmpty ||
        estadoRaw == '1' ||
        estadoRaw.toLowerCase() == 'activo' ||
        estadoRaw.toLowerCase() == 'true';

    final accionColor =
        activo ? const Color(0xFFDC2626) : const Color(0xFF059669);
    final accionTexto = activo ? 'Desactivar' : 'Activar';

    final confirmed = await showDialog<bool>(
      context: screenContext,
      builder: (ctx) => AppAnimatedDialog(
        child: Dialog(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: accionColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                    activo
                        ? Icons.delete_outline_rounded
                        : Icons.restart_alt_rounded,
                    color: accionColor,
                    size: 28),
              ),
              const SizedBox(height: 16),
              Text('$accionTexto usuario',
                  style: TextStyle(
                      color: textMain,
                      fontSize: 17,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                activo
                    ? '$email dejará de tener acceso al sistema. Podrás reactivarlo cuando quieras.'
                    : '$email volverá a tener acceso al sistema con sus mismas credenciales.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textSoft, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 22),
              Row(children: [
                // Neutro: el color fuerte se reserva para la acción principal,
                // si ambos van igual no se distingue cuál es cuál.
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, false),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: inputFill,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: lineCol),
                      ),
                      alignment: Alignment.center,
                      child: Text('Cancelar',
                          style: TextStyle(
                              color: textSoft,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, true),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: activo
                                ? const [Color(0xFF991B1B), Color(0xFFDC2626)]
                                : const [Color(0xFF047857), Color(0xFF10B981)]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(accionTexto,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );

    if (confirmed != true) return false;

    try {
      await _usuariosRequest({
        'accion': 'estado',
        'codigo_usuario': codigoUsuario,
        'activar': activo ? '0' : '1',
      });
      showResult(
          true,
          activo
              ? 'Usuario desactivado correctamente'
              : 'Usuario activado correctamente');
      return true;
    } catch (e) {
      showResult(false, friendlyError(e));
      return false;
    }
  }

  Future<Map<String, dynamic>> _usuariosRequest(
      Map<String, dynamic> body) async {
    final response = await repository.post('/ajax/gestion_usuarios.php', body);
    if (response.statusCode != 200) {
      throw Exception('El servidor no respondió correctamente');
    }
    final decoded = decodeJsonMap(response.body);
    if (decoded.isEmpty) {
      final raw = response.body
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      throw Exception(
        raw.isEmpty ? 'El servidor devolvió una respuesta vacía' : raw,
      );
    }
    if (decoded['success'] != true && decoded['resultado'] != 1) {
      throw Exception(
          decoded['mensaje']?.toString() ?? 'Operación no completada');
    }
    return decoded;
  }

  Future<bool> _showUserForm([Map<String, dynamic>? listadoUser]) async {
    final codigoUsuario = (listadoUser?['codigo_usuario'] ??
            listadoUser?['codigo'] ??
            listadoUser?['cod'] ??
            '')
        .toString();
    final editing = codigoUsuario.isNotEmpty;
    if (!isMounted) return false;

    bool loadingData = true;
    String loadError = '';
    List<Map<String, dynamic>> perfiles = [];
    final emailCtrl = TextEditingController();
    final nombresCtrl = TextEditingController();
    final apellidosCtrl = TextEditingController();
    final claveCtrl = TextEditingController();
    String perfil = '';
    bool saving = false;
    bool initStarted = false;

    final saved = await showDialog<bool>(
      context: screenContext,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          if (!initStarted) {
            initStarted = true;
            Future.microtask(() async {
              try {
                final cats = await _usuariosRequest({'accion': 'catalogos'});
                final data = cats['datos'] is Map
                    ? Map<String, dynamic>.from(cats['datos'] as Map)
                    : <String, dynamic>{};
                final loadedPerfiles =
                    (data['perfiles'] is List ? data['perfiles'] as List : [])
                        .whereType<Map>()
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList();

                Map<String, dynamic> detail = {};
                if (editing) {
                  final resp = await _usuariosRequest(
                      {'accion': 'detalle', 'codigo_usuario': codigoUsuario});
                  if (resp['datos'] is Map) {
                    detail = Map<String, dynamic>.from(resp['datos'] as Map);
                  }
                }

                final initEmail = (detail['usuario'] ??
                        listadoUser?['usuario'] ??
                        listadoUser?['email'] ??
                        '')
                    .toString();
                final initPerfil = (detail['codigo_perfil'] ?? '').toString();
                final initNombres = (detail['nombres'] ?? '').toString();
                final initApellidos = (detail['apellidos'] ?? '').toString();
                if (ctx.mounted) {
                  setS(() {
                    perfiles = loadedPerfiles;
                    emailCtrl.text = initEmail;
                    nombresCtrl.text = initNombres;
                    apellidosCtrl.text = initApellidos;
                    perfil = initPerfil;
                    loadingData = false;
                  });
                }
              } catch (e) {
                if (ctx.mounted) {
                  setS(() {
                    loadError = e.toString().replaceFirst('Exception: ', '');
                    loadingData = false;
                  });
                }
              }
            });
          }

          // ─── helpers ───────────────────────────────────────────────────
          // Cada campo lleva su propio par de colores para que los íconos no
          // se vean idénticos cuando varios están llenos a la vez.
          InputDecoration fieldDeco(String hint, IconData icon,
                  {bool active = false,
                  List<Color> tint = const [
                    Color(0xFF4361EE),
                    Color(0xFF00D2FF)
                  ]}) =>
              InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                    color: textSoft, fontSize: 14, fontWeight: FontWeight.w500),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(9),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: active
                        ? LinearGradient(
                            colors: tint,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight)
                        : null,
                    color: active ? null : inputFill,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: active
                        ? [
                            BoxShadow(
                                color: tint.first.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3))
                          ]
                        : null,
                  ),
                  child: Icon(icon,
                      color: active ? Colors.white : textSoft, size: 17),
                ),
                // Sin esto el prefixIcon del dropdown se sale de la caja.
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 52, minHeight: 52),
                filled: true,
                fillColor: active ? cardBgAlt : inputFill,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: lineCol)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: active
                            ? tint.first.withValues(alpha: 0.45)
                            : lineCol,
                        width: active ? 1.4 : 1)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: active ? tint.first : homeAccent, width: 1.8)),
              );

          Widget sectionLabel(String text, IconData icon,
                  {List<Color>? tint}) =>
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(children: [
                  Container(
                      width: 3,
                      height: 13,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: tint ?? const [homeAccent, homeCyan],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter),
                        borderRadius: BorderRadius.circular(2),
                      )),
                  const SizedBox(width: 8),
                  Icon(icon, size: 13, color: tint?.first ?? textSoft),
                  const SizedBox(width: 5),
                  Text(text,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: tint?.first ?? textSoft,
                          letterSpacing: 0.3)),
                ]),
              );

          // Ambos delegan en perfilTheme para que el formulario y las
          // tarjetas del listado nunca se desincronicen de color/ícono.
          IconData iconoPerfil(String codigo) => perfilTheme(codigo).icon;
          List<Color> colorPerfil(String codigo) => perfilTheme(codigo).grad;

          return AppAnimatedDialog(
            child: Dialog(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: homeAccent.withValues(alpha: 0.18),
                        blurRadius: 40,
                        offset: const Offset(0, 16)),
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8)),
                  ],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // ── HEADER ───────────────────────────────────────
                  Container(
                    clipBehavior: Clip.hardEdge,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF060E35),
                          Color(0xFF0D1B6E),
                          Color(0xFF1435A8),
                          Color(0xFF0077BB)
                        ],
                        stops: [0.0, 0.35, 0.70, 1.0],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Stack(children: [
                      Positioned(
                          right: -30,
                          top: -30,
                          child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(colors: [
                                    Colors.white.withValues(alpha: 0.10),
                                    Colors.transparent
                                  ])))),
                      Positioned(
                          left: -15,
                          bottom: -15,
                          child: Container(
                              width: 65,
                              height: 65,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      Colors.white.withValues(alpha: 0.05)))),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 20, 14, 20),
                        child: Row(children: [
                          Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.22),
                                      Colors.white.withValues(alpha: 0.08)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.25)),
                              ),
                              child: Icon(
                                  editing
                                      ? Icons.manage_accounts_rounded
                                      : Icons.person_add_alt_1_rounded,
                                  color: Colors.white,
                                  size: 26)),
                          const SizedBox(width: 14),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(
                                    editing
                                        ? 'Editar usuario'
                                        : 'Crear usuario',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.3)),
                                const SizedBox(height: 3),
                                Text(
                                    editing
                                        ? 'Modifica los datos del acceso'
                                        : 'Registra un nuevo acceso',
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.65),
                                        fontSize: 11.5)),
                              ])),
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx, false),
                            child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [
                                    Color(0xFF991B1B),
                                    Color(0xFFDC2626),
                                    Color(0xFFF43F5E)
                                  ]),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                        color: const Color(0xFFDC2626)
                                            .withValues(alpha: 0.45),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4))
                                  ],
                                ),
                                child: const Icon(Icons.close_rounded,
                                    color: Colors.white, size: 17)),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                  // ── CONTENT ──────────────────────────────────────
                  // Scrollable: con el teclado abierto el formulario no cabe
                  // en pantallas chicas y el Column reventaba por overflow.
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        if (loadingData)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 44),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(color: homeAccent),
                                  SizedBox(height: 14),
                                  Text('Cargando datos...',
                                      style: TextStyle(
                                          color: textSoft, fontSize: 13)),
                                ]),
                          )
                        else if (loadError.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 36, horizontal: 20),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      size: 38, color: Color(0xFFDC2626)),
                                  const SizedBox(height: 10),
                                  Text(loadError,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Color(0xFFDC2626),
                                          fontSize: 13)),
                                  const SizedBox(height: 16),
                                  appCancelButton('Cerrar',
                                      () => Navigator.pop(ctx, false)),
                                ]),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  sectionLabel('NOMBRES Y APELLIDOS',
                                      Icons.badge_outlined),
                                  TextField(
                                    controller: nombresCtrl,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    style: TextStyle(
                                        color: textMain,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                    decoration: fieldDeco('Nombres',
                                        Icons.person_outline_rounded),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: apellidosCtrl,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    style: TextStyle(
                                        color: textMain,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                    decoration: fieldDeco('Apellidos',
                                        Icons.people_outline_rounded),
                                  ),
                                  const SizedBox(height: 16),
                                  sectionLabel('ACCESO Y PERMISOS',
                                      Icons.admin_panel_settings_rounded,
                                      tint: perfil.isEmpty
                                          ? null
                                          : colorPerfil(perfil)),
                                  DropdownButtonFormField<String>(
                                    initialValue:
                                        perfil.isEmpty ? null : perfil,
                                    isExpanded: true,
                                    dropdownColor: dialogBg,
                                    borderRadius: BorderRadius.circular(14),
                                    style: TextStyle(
                                        color: textMain,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                    icon: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Color(0xFF7E8DB8)),
                                    hint: const Text('Seleccione un perfil',
                                        style: TextStyle(
                                            color: Color(0xFF8E9BBA),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500)),
                                    decoration: fieldDeco(
                                        'Seleccione un perfil',
                                        iconoPerfil(perfil),
                                        active: perfil.isNotEmpty,
                                        tint: colorPerfil(perfil)),
                                    items: perfiles
                                        .map((item) => DropdownMenuItem(
                                              value: (item['codigo'] ?? '')
                                                  .toString(),
                                              child: Text(
                                                  (item['nombre'] ?? '')
                                                      .toString(),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      color: textMain)),
                                            ))
                                        .toList(),
                                    onChanged: saving
                                        ? null
                                        : (v) => setS(() => perfil = v ?? ''),
                                  ),
                                  const SizedBox(height: 16),
                                  sectionLabel('CORREO ELECTRÓNICO',
                                      Icons.alternate_email_rounded),
                                  TextField(
                                    controller: emailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    style: TextStyle(
                                        color: textMain,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                    decoration: fieldDeco('Email usuario',
                                        Icons.alternate_email_rounded),
                                  ),
                                  const SizedBox(height: 16),
                                  sectionLabel(
                                      editing
                                          ? 'CONTRASEÑA (dejar vacío para no cambiarla)'
                                          : 'CONTRASEÑA',
                                      Icons.lock_outline_rounded),
                                  TextField(
                                    controller: claveCtrl,
                                    obscureText: true,
                                    style: TextStyle(
                                        color: textMain,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                    decoration: fieldDeco(
                                        editing
                                            ? 'Nueva contraseña (opcional)'
                                            : 'Contraseña',
                                        Icons.lock_outline_rounded),
                                  ),
                                  const SizedBox(height: 20),
                                  // ── BUTTONS ────────────────────────────────
                                  Row(children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: saving
                                            ? null
                                            : () => Navigator.pop(ctx, false),
                                        child: Container(
                                          height: 50,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF991B1B),
                                                Color(0xFFDC2626),
                                                Color(0xFFF43F5E)
                                              ],
                                              stops: [0.0, 0.55, 1.0],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            boxShadow: [
                                              BoxShadow(
                                                  color: const Color(0xFFDC2626)
                                                      .withValues(alpha: 0.40),
                                                  blurRadius: 14,
                                                  offset: const Offset(0, 5)),
                                            ],
                                          ),
                                          alignment: Alignment.center,
                                          child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.close_rounded,
                                                    color: Colors.white,
                                                    size: 18),
                                                SizedBox(width: 7),
                                                Text('Cancelar',
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 14)),
                                              ]),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: saving
                                            ? null
                                            : () async {
                                                final email =
                                                    emailCtrl.text.trim();
                                                final nombres =
                                                    nombresCtrl.text.trim();
                                                final apellidos =
                                                    apellidosCtrl.text.trim();
                                                final clave =
                                                    claveCtrl.text.trim();
                                                if (!email.contains('@') ||
                                                    perfil.isEmpty ||
                                                    nombres.isEmpty ||
                                                    apellidos.isEmpty ||
                                                    (!editing &&
                                                        clave.isEmpty)) {
                                                  showResult(false,
                                                      'Complete todos los campos antes de guardar');
                                                  return;
                                                }
                                                setS(() => saving = true);
                                                try {
                                                  await _usuariosRequest({
                                                    'accion': 'guardar',
                                                    'codigo_usuario':
                                                        codigoUsuario,
                                                    'usuario': email,
                                                    'codigo_perfil': perfil,
                                                    'nombres': nombres,
                                                    'apellidos': apellidos,
                                                    'clave': clave,
                                                  });
                                                  // Un usuario con perfil
                                                  // asesor crea/actualiza una
                                                  // fila en tbl_asesores —
                                                  // sin invalidar, la lista
                                                  // de asesores (cacheada 1h
                                                  // en memoria) queda vieja
                                                  // hasta el próximo hot
                                                  // restart.
                                                  repository.invalidateCache(
                                                      '/ajax/get_asesores.php');
                                                  if (ctx.mounted) {
                                                    Navigator.pop(ctx, true);
                                                  }
                                                  showResult(
                                                      true,
                                                      editing
                                                          ? 'Usuario actualizado exitosamente'
                                                          : 'Usuario registrado exitosamente');
                                                } catch (e) {
                                                  if (ctx.mounted) {
                                                    setS(() => saving = false);
                                                  }
                                                  showResult(
                                                      false, friendlyError(e));
                                                }
                                              },
                                        child: Container(
                                          height: 50,
                                          decoration: BoxDecoration(
                                            gradient: saving
                                                ? null
                                                : const LinearGradient(
                                                    colors: [
                                                        Color(0xFF0D1B4B),
                                                        Color(0xFF1E3A8A),
                                                        Color(0xFF3B82F6)
                                                      ],
                                                    stops: [
                                                        0.0,
                                                        0.5,
                                                        1.0
                                                      ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight),
                                            color: saving
                                                ? const Color(0xFFCBD5E1)
                                                : null,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            boxShadow: saving
                                                ? null
                                                : [
                                                    BoxShadow(
                                                        color: homeAccent
                                                            .withValues(
                                                                alpha: 0.40),
                                                        blurRadius: 14,
                                                        offset:
                                                            const Offset(0, 5)),
                                                  ],
                                          ),
                                          alignment: Alignment.center,
                                          child: saving
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2.5,
                                                          color: Colors.white))
                                              : const Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                      Icon(Icons.save_rounded,
                                                          color: Colors.white,
                                                          size: 18),
                                                      SizedBox(width: 8),
                                                      Text('Guardar',
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              fontSize: 14)),
                                                    ]),
                                        ),
                                      ),
                                    ),
                                  ]),
                                  const SizedBox(height: 18),
                                ]),
                          ),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
    // showDialog retorna apenas se llama Navigator.pop, pero AppAnimatedDialog
    // sigue animando la salida y reconstruye los TextField unos frames más.
    // Liberar los controllers de inmediato dispara "TextEditingController was
    // used after being disposed", así que se difiere hasta que termine.
    Future.delayed(const Duration(milliseconds: 400), () {
      emailCtrl.dispose();
      nombresCtrl.dispose();
      apellidosCtrl.dispose();
      claveCtrl.dispose();
    });
    return saved == true;
  }
}

// ════════════════════════════════════════════════════════════════════
//  ANIMATED USER TILE
// ════════════════════════════════════════════════════════════════════
class _AdminUserTile extends StatefulWidget {
  final Map<String, dynamic> user;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AdminUserTile({
    super.key,
    required this.user,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_AdminUserTile> createState() => _AdminUserTileState();
}

class _AdminUserTileState extends State<_AdminUserTile>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0.12, 0.22),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
  // Escala de entrada: acompaña al slide para que la tarjeta "aterrice"
  // en vez de solo deslizarse.
  late final Animation<double> _entranceScale = Tween<double>(
    begin: 0.94,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutBack));

  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    lowerBound: 0.97,
    upperBound: 1.0,
  )..value = 1.0;

  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    final delay = (widget.index * 60).clamp(0, 360);
    Future.delayed(Duration(milliseconds: delay), () {
      if (!_disposed && mounted) _entrance.forward();
    });
    _loopShimmer();
  }

  Future<void> _loopShimmer() async {
    await Future.delayed(Duration(milliseconds: 2000 + widget.index * 200));
    while (!_disposed) {
      await Future.delayed(const Duration(milliseconds: 4500));
      if (_disposed || !mounted) break;
      await _shimmer.forward(from: 0);
      if (_disposed || !mounted) break;
      _shimmer.value = 0;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _entrance.dispose();
    _press.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  // Iniciales a partir del nombre real: "Gabriel Padilla" → "GP".
  String _initialsFromName(String nombre) {
    final parts =
        nombre.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    if (parts.isNotEmpty && parts.first.length >= 2) {
      return parts.first.substring(0, 2).toUpperCase();
    }
    return parts.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }

  String _initials(String email) {
    final local = email.split('@').first;
    final parts =
        local.split(RegExp(r'[._\-0-9]+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].length >= 2) {
      return parts[0].substring(0, 2).toUpperCase();
    }
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }

  // El listado admin (gestion_usuarios.php) trae la foto real del perfil
  // ligado (asesor/deudor) bajo distintos nombres de columna según la
  // consulta guardada en tbl_conf_consultas — se prueban las mismas claves
  // que ya usa photoUrl para el perfil propio. "0" es el valor por defecto
  // cuando nunca se subió foto, así que se trata igual que vacío.
  String _photoUrlFor(Map<String, dynamic> user) {
    for (final k in [
      'foto',
      'imagen',
      'avatar',
      'photo',
      'fotografia',
      'foto_perfil',
      'imagen_perfil',
      'picture',
      'img'
    ]) {
      final raw = (user[k] ?? '').toString().trim();
      if (raw.isNotEmpty && !isNoPhotoValue(raw)) {
        return raw.startsWith('http')
            ? raw
            : 'https://www.jorgemario.co/ext/saf/img/icons/$raw';
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final email =
        (user['usuario'] ?? user['email'] ?? user['correo'] ?? 'Usuario')
            .toString();
    final tipo = (user['tipo_usuario'] ?? user['tipo'] ?? '').toString();
    final perfil = (user['perfil'] ?? user['nombre_perfil'] ?? '').toString();
    final estadoRaw =
        (user['estado'] ?? user['codigo_estado'] ?? user['activo'] ?? '')
            .toString();
    final activo = estadoRaw.isEmpty ||
        estadoRaw == '1' ||
        estadoRaw.toLowerCase() == 'activo' ||
        estadoRaw.toLowerCase() == 'true';
    // El nombre real (de tbl_asesores, vía el enriquecido de
    // gestion_usuarios.php) es el dato principal; el correo pasa a ser
    // secundario. Si no hay nombre, el correo lo sustituye como título.
    final nombreCompleto = [
      (user['nombres'] ?? '').toString().trim(),
      (user['apellidos'] ?? '').toString().trim(),
    ].where((p) => p.isNotEmpty).join(' ');
    final titulo = nombreCompleto.isNotEmpty ? nombreCompleto : email;
    final initials = nombreCompleto.isNotEmpty
        ? _initialsFromName(nombreCompleto)
        : _initials(email);
    final photoUrl = _photoUrlFor(user);

    // El color de la tarjeta lo marca el rol, no un azul genérico: así se
    // distingue de un vistazo quién es admin, asesor de créditos o de ahorros.
    final theme = perfilTheme(perfil.isNotEmpty ? perfil : tipo);
    final activeGrad = LinearGradient(
      colors: theme.grad,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    const inactiveGrad = LinearGradient(
      colors: [Color(0xFFCBD5E1), Color(0xFF94A3B8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _entranceScale,
          child: GestureDetector(
            onTapDown: (_) => _press.reverse(),
            onTapUp: (_) => _press.forward(),
            onTapCancel: () => _press.forward(),
            child: ScaleTransition(
              scale: _press,
              child: Container(
                decoration: BoxDecoration(
                  // Tinte del rol degradándose hacia el fondo normal de tarjeta.
                  gradient: LinearGradient(
                    colors: [
                      Color.alphaBlend(
                          theme.grad.first.withValues(
                              alpha:
                                  activo ? (isDarkTheme ? 0.13 : 0.055) : 0.0),
                          cardBg),
                      cardBg,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const [0.0, 0.55],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: activo
                          ? theme.grad.first
                              .withValues(alpha: isDarkTheme ? 0.55 : 0.38)
                          : lineCol,
                      width: activo ? 1.5 : 1),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (activo ? theme.grad.first : const Color(0xFF94A3B8))
                              .withValues(alpha: 0.13),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Row(children: [
                    // Left accent strip
                    Container(
                      width: 5,
                      decoration: BoxDecoration(
                        gradient: activo ? activeGrad : inactiveGrad,
                        boxShadow: activo
                            ? [
                                BoxShadow(
                                    color: theme.grad.first
                                        .withValues(alpha: 0.55),
                                    blurRadius: 10)
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Avatar con barrido shimmer + punto de estado encima
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: Stack(clipBehavior: Clip.none, children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(children: [
                            Builder(builder: (_) {
                              final initialsBox = Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  gradient: activo ? activeGrad : inactiveGrad,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              );
                              if (photoUrl.isEmpty) return initialsBox;
                              return Image.network(
                                photoUrl,
                                width: 46,
                                height: 46,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => initialsBox,
                              );
                            }),
                            Positioned.fill(
                              child: AnimatedBuilder(
                                animation: _shimmer,
                                builder: (_, __) => Align(
                                  alignment: Alignment.lerp(
                                    const Alignment(-2.5, -2.5),
                                    const Alignment(2.5, 2.5),
                                    _shimmer.value,
                                  )!,
                                  child: Transform.rotate(
                                    angle: pi / 4,
                                    child: Container(
                                      width: 14,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: [
                                          Colors.transparent,
                                          Colors.white.withValues(alpha: 0.45),
                                          Colors.transparent,
                                        ]),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ]),
                        ),
                        // Estado como punto sobre el avatar: libera una etiqueta
                        // entera de la fila y se lee de un golpe.
                        Positioned(
                          right: 0,
                          bottom: 2,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: activo
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF94A3B8),
                              shape: BoxShape.circle,
                              border: Border.all(color: cardBg, width: 2.2),
                              boxShadow: activo
                                  ? [
                                      BoxShadow(
                                          color: const Color(0xFF10B981)
                                              .withValues(alpha: 0.55),
                                          blurRadius: 6)
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    // Info column
                    Expanded(
                      child: Padding(
                        // Margen a la derecha: el texto deslizante no debe
                        // llegar a tocar los botones de acción.
                        padding: const EdgeInsets.fromLTRB(0, 12, 10, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nombre real como dato principal. Si no cabe se
                            // desliza en bucle en vez de cortarse con "…".
                            _MarqueeText(
                              titulo,
                              style: TextStyle(
                                color: textMain,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                            // El correo baja a secundario; si ya se usó como
                            // título (usuario sin nombre) no se repite.
                            if (nombreCompleto.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              _MarqueeText(
                                email,
                                style: TextStyle(
                                  color: textSoft,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            // Un solo chip con el rol (el "tipo" era siempre
                            // "Asesor" para todos, no aportaba nada).
                            if (perfil.isNotEmpty)
                              _roleChip(perfil, theme.grad, theme.icon)
                            else if (tipo.isNotEmpty)
                              _roleChip(tipo, theme.grad, theme.icon),
                          ],
                        ),
                      ),
                    ),
                    // Edit button — gradiente sólido, ícono blanco.
                    _PressScale(
                      onTap: widget.onEdit,
                      child: Container(
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4361EE), Color(0xFF00D2FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFF4361EE)
                                    .withValues(alpha: 0.45),
                                blurRadius: 12,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: Colors.white, size: 17),
                      ),
                    ),
                    // Desactivar / reactivar: el soft delete es reversible,
                    // así que un usuario inactivo muestra el botón para
                    // devolverle el acceso en vez de la papelera.
                    _PressScale(
                      onTap: widget.onDelete,
                      child: Builder(builder: (_) {
                        final accionGrad = activo
                            ? const [Color(0xFFEF4444), Color(0xFFF43F5E)]
                            : const [Color(0xFF059669), Color(0xFF10B981)];
                        return Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: accionGrad,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      accionGrad.first.withValues(alpha: 0.45),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: Icon(
                              activo
                                  ? Icons.delete_outline_rounded
                                  : Icons.restart_alt_rounded,
                              color: Colors.white,
                              size: 17),
                        );
                      }),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Chip del rol: ícono + texto sobre un degradado suave del color del perfil.
  Widget _roleChip(String text, List<Color> grad, IconData icon) => Container(
        padding: const EdgeInsets.fromLTRB(6, 3.5, 9, 3.5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              grad.first.withValues(alpha: isDarkTheme ? 0.28 : 0.14),
              grad.last.withValues(alpha: isDarkTheme ? 0.16 : 0.07),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: grad.first.withValues(alpha: 0.30)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: grad),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(icon, size: 9.5, color: Colors.white),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: isDarkTheme ? grad.last : grad.first,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1)),
          ),
        ]),
      );
}

// ── Botón con feedback de presión (escala) reutilizable ─────────────────────
class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressScale({required this.child, required this.onTap});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    lowerBound: 0.90,
    upperBound: 1.0,
  )..value = 1.0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => _ctrl.reverse(),
        onTapUp: (_) {
          _ctrl.forward();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.forward(),
        child: ScaleTransition(scale: _ctrl, child: widget.child),
      );
}

// ── Texto que se desliza si no cabe (marquesina) ────────────────────────────
/// Muestra el texto normal cuando cabe en el ancho disponible; si se
/// desbordaría (antes se cortaba con "…"), lo desplaza en bucle para poder
/// leerlo completo, con una pausa a cada extremo.
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _MarqueeText(this.text, {required this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> {
  final ScrollController _scroll = ScrollController();
  // Progreso 0..1 del recorrido, para desvanecer el degradado del lado al
  // que ya se llegó (si no, el final del texto nunca se ve completo).
  final ValueNotifier<double> _progress = ValueNotifier(0);
  bool _disposed = false;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    _progress.value = max <= 0 ? 0 : (_scroll.offset / max).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _disposed = true;
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _progress.dispose();
    super.dispose();
  }

  Future<void> _cycle() async {
    if (_running) return;
    _running = true;
    while (!_disposed) {
      await Future.delayed(const Duration(milliseconds: 1600));
      if (_disposed || !_scroll.hasClients) break;
      final max = _scroll.position.maxScrollExtent;
      if (max <= 0) continue;
      // Velocidad constante (~28 px/s) para que textos largos no corran más.
      await _scroll.animateTo(max,
          duration: Duration(milliseconds: (max * 36).round().clamp(900, 9000)),
          curve: Curves.easeInOut);
      if (_disposed || !_scroll.hasClients) break;
      // Pausa larga al final: es el momento en que se lee el tramo que
      // estaba oculto, así que el degradado derecho ya está apagado.
      await Future.delayed(const Duration(milliseconds: 1800));
      if (_disposed || !_scroll.hasClients) break;
      await _scroll.animateTo(0,
          duration: Duration(milliseconds: (max * 20).round().clamp(600, 5000)),
          curve: Curves.easeInOut);
    }
    _running = false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style),
        maxLines: 1,
        textDirection: Directionality.of(context),
      )..layout();

      // Si cabe, es un Text normal: sin scroll ni animación de fondo.
      if (painter.width <= constraints.maxWidth) {
        return Text(widget.text, maxLines: 1, style: widget.style);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed && mounted) _cycle();
      });

      final scroller = SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(widget.text, maxLines: 1, style: widget.style),
      );

      // Degradado en los bordes, pero solo del lado donde queda texto por
      // ver: al llegar al final el borde derecho se apaga y la última
      // palabra se lee nítida.
      return ValueListenableBuilder<double>(
        valueListenable: _progress,
        child: scroller,
        builder: (_, p, child) {
          final fadeLeft = (p * 4).clamp(0.0, 1.0);
          final fadeRight = ((1 - p) * 4).clamp(0.0, 1.0);
          return ShaderMask(
            shaderCallback: (rect) {
              final edge = (16 / rect.width).clamp(0.02, 0.3);
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.white.withValues(alpha: 1 - fadeLeft),
                  Colors.white,
                  Colors.white,
                  Colors.white.withValues(alpha: 1 - fadeRight),
                ],
                stops: [0.0, edge, 1.0 - edge, 1.0],
              ).createShader(rect);
            },
            blendMode: BlendMode.dstIn,
            child: child,
          );
        },
      );
    });
  }
}
