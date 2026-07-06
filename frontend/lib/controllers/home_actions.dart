// ignore_for_file: use_build_context_synchronously

import '../screens/home/home_dependencies.dart';
import '../screens/home/credits_screen.dart';
import '../widgets/home/home_dialogs.dart';

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
      if (cachedSavingsAdvisorFilter == cacheKey && cachedFilteredSavers != null) {
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
            final myInitials = creditAdvisorInitials(myCode).trim().toUpperCase();
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
      cachedFilteredSavers = savers
          .where((a) {
            final itemAdvisor = creditAdvisorInitials(
              (a['asesor'] ?? a['codigo_asesor'] ?? '').toString(),
            ).trim().toUpperCase();
            return itemAdvisor == selectedAdvisor;
          })
          .toList();
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
        if (raw.isNotEmpty && raw != 'null') {
          if (raw.startsWith('http')) return raw;
          return 'https://www.jorgemario.co/ext/saf/img/icons/$raw';
        }
      }
    }
    return '';
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

  Future<String?> uploadPhoto(Uint8List bytes) async {
    try {
      final base64Image = base64Encode(bytes);
      final r = await repository.post(
          '/ajax/actualizar_foto.php', {'foto': base64Image});
      if (r.statusCode == 200) {
        final d = decodeJsonMap(r.body);
        if (d['resultado'] == 1) {
          final filename = (d['foto'] ?? '').toString();
          if (filename.isNotEmpty) {
            repository.user?['perfil']?['foto'] = filename;
            refresh(() {});
            return filename;
          }
        }
      }
    } catch (e) {
      debugPrint('[SAF] uploadPhoto: $e');
    }
    return null;
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
      setS(() { loading = true; error = ''; });
      try {
        final data = await _fetchUsuariosAdmin(forceRefresh: true);
        if (ctx.mounted) setS(() { usuarios = data; loading = false; });
      } catch (e) {
        if (ctx.mounted) setS(() { error = e.toString().replaceFirst('Exception: ', ''); loading = false; });
      }
    }

    showDialog(
      context: screenContext,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          if (!started) {
            started = true;
            _fetchUsuariosAdmin().then<void>((data) {
              if (ctx.mounted) setS(() { usuarios = data; loading = false; });
            }).catchError((Object e) {
              if (ctx.mounted) setS(() { error = e.toString().replaceFirst('Exception: ', ''); loading = false; });
            });
          }

          final filtrados = query.isEmpty
              ? usuarios
              : usuarios.where((u) => u.values.join(' ').toLowerCase().contains(query.toLowerCase())).toList();
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
                  Padding(
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
                              hintStyle: const TextStyle(color: Color(0xFFB0BBCC), fontSize: 13),
                              prefixIcon: Container(
                                margin: const EdgeInsets.all(10),
                                width: 34, height: 34,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF4361EE), Color(0xFF00D2FF)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.search_rounded, color: Colors.white, size: 17),
                              ),
                              suffixIcon: query.isNotEmpty
                                  ? GestureDetector(
                                      onTap: () => setS(() => query = ''),
                                      child: Icon(Icons.close_rounded, color: textSoft, size: 18),
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  // ── RESULTS COUNT ────────────────────────────────
                  if (!loading && error.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Row(children: [
                        Container(
                          width: 4, height: 14,
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
                  // ── LIST ─────────────────────────────────────────
                  Expanded(
                    child: loading
                        ? _usersLoadingSkeleton()
                        : error.isNotEmpty
                            ? _usersErrorState(error, () => reload(setS, ctx))
                            : filtrados.isEmpty
                                ? _usersEmptyState(query.isNotEmpty)
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                                    itemCount: filtrados.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (_, i) => _AdminUserTile(
                                      key: ValueKey('usr_${filtrados[i]['codigo_usuario'] ?? i}'),
                                      user: filtrados[i],
                                      index: i,
                                      onEdit: () async {
                                        final saved = await _showUserForm(filtrados[i]);
                                        if (saved && ctx.mounted) await reload(setS, ctx);
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
          colors: [Color(0xFF060E35), Color(0xFF0D1B6E), Color(0xFF1435A8), Color(0xFF0077BB)],
          stops: [0.0, 0.35, 0.70, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(children: [
        // Decorative orbs
        Positioned(right: -40, top: -40,
          child: Container(width: 130, height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                Colors.white.withValues(alpha: 0.09), Colors.transparent,
              ]),
            ))),
        Positioned(left: -20, bottom: -20,
          child: Container(width: 90, height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
            ))),
        Positioned(right: 60, bottom: -30,
          child: Container(width: 70, height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFF00D2FF).withValues(alpha: 0.15), Colors.transparent,
              ]),
            ))),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
            child: Column(children: [
              // ── Fila única: back + icon + title + Nuevo ────────
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                GestureDetector(
                  onTap: onBack,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.white.withValues(alpha: 0.25),
                      Colors.white.withValues(alpha: 0.10),
                    ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                  ),
                  child: const Icon(Icons.manage_accounts_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Gestión de usuarios',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('Administración · Acceso restringido',
                        style: TextStyle(color: Colors.white60, fontSize: 10.5, fontWeight: FontWeight.w500)),
                  ]),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onNew,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6EE7B7), Color(0xFF34D399), Color(0xFF059669)],
                        stops: [0.0, 0.5, 1.0],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF059669).withValues(alpha: 0.40),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('Nuevo', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              // ── Stats row ─────────────────────────────────────
              Row(children: [
                _userStatChip(Icons.people_alt_rounded, totalUsers.toString(), 'Total', const Color(0xFF60A5FA)),
                const SizedBox(width: 8),
                _userStatChip(Icons.check_circle_outline_rounded, activeUsers.toString(), 'Activos', const Color(0xFF34D399)),
                const SizedBox(width: 8),
                _userStatChip(Icons.lock_outline_rounded, (totalUsers - activeUsers).toString(), 'Inactivos', const Color(0xFFFBBF24)),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _userStatChip(IconData icon, String value, String label, Color color) =>
      Expanded(
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
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.60), fontSize: 9.5, fontWeight: FontWeight.w600)),
            ]),
          ]),
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
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                ),
              ),
              const SizedBox(width: 12),
              Container(width: 44, height: 44, decoration: BoxDecoration(color: inputFill, borderRadius: BorderRadius.circular(12))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(height: 12, width: double.infinity, decoration: BoxDecoration(color: inputFill, borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 8),
                Container(height: 9, width: 180, decoration: BoxDecoration(color: inputFill, borderRadius: BorderRadius.circular(5))),
              ])),
              Container(
                margin: const EdgeInsets.only(right: 12),
                width: 34, height: 34,
                decoration: BoxDecoration(color: inputFill, borderRadius: BorderRadius.circular(10)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _usersErrorState(String error, VoidCallback onRetry) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFEE2E2), Color(0xFFFECDD3)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.cloud_off_rounded, size: 34, color: Color(0xFFDC2626)),
        ),
        const SizedBox(height: 16),
        Text('Error de conexión', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textMain)),
        const SizedBox(height: 6),
        Text(error, textAlign: TextAlign.center, style: TextStyle(color: textSoft, fontSize: 12)),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0D1B4B), Color(0xFF1E3A8A)]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: homeAccent.withValues(alpha: 0.30), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
              SizedBox(width: 7),
              Text('Reintentar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),
        ),
      ]),
    ),
  );

  Widget _usersEmptyState(bool isSearch) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(isSearch ? Icons.search_off_rounded : Icons.people_outline_rounded,
              size: 34, color: homeAccent),
        ),
        const SizedBox(height: 16),
        Text(
          isSearch ? 'Sin resultados' : 'Sin usuarios',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textMain),
        ),
        const SizedBox(height: 6),
        Text(
          isSearch ? 'Intenta con otro término de búsqueda' : 'Aún no hay usuarios registrados',
          textAlign: TextAlign.center,
          style: TextStyle(color: textSoft, fontSize: 12),
        ),
      ]),
    ),
  );

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
    List<Map<String, dynamic>> tipos = [];
    final emailCtrl = TextEditingController();
    String perfil = '';
    String tipo = '';
    String origen = '';
    List<Map<String, dynamic>> origenes = [];
    bool loadingOrigenes = false;
    bool saving = false;
    bool initStarted = false;

    Future<List<Map<String, dynamic>>> loadOrigins(String tipoCodigo) async {
      if (tipoCodigo.isEmpty) return [];
      final response = await _usuariosRequest({'accion': 'origenes', 'codigo_tipo_usuario': tipoCodigo});
      final raw = response['datos'];
      return raw is List ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
    }

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
                final data = cats['datos'] is Map ? Map<String, dynamic>.from(cats['datos'] as Map) : <String, dynamic>{};
                final loadedPerfiles = (data['perfiles'] is List ? data['perfiles'] as List : []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
                final loadedTipos = (data['tipos'] is List ? data['tipos'] as List : []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

                Map<String, dynamic> detail = {};
                if (editing) {
                  final resp = await _usuariosRequest({'accion': 'detalle', 'codigo_usuario': codigoUsuario});
                  if (resp['datos'] is Map) detail = Map<String, dynamic>.from(resp['datos'] as Map);
                }

                final initEmail = (detail['usuario'] ?? listadoUser?['usuario'] ?? listadoUser?['email'] ?? '').toString();
                final initPerfil = (detail['codigo_perfil'] ?? '').toString();
                final initTipo = (detail['codigo_tipo_usuario'] ?? '').toString();
                final initOrigen = (detail['codigo_origen'] ?? '').toString();
                List<Map<String, dynamic>> loadedOrigenes = [];
                if (initTipo.isNotEmpty) {
                  try { loadedOrigenes = await loadOrigins(initTipo); } catch (_) {}
                }
                if (ctx.mounted) {
                  setS(() {
                    perfiles = loadedPerfiles; tipos = loadedTipos;
                    emailCtrl.text = initEmail; perfil = initPerfil;
                    tipo = initTipo; origen = initOrigen;
                    origenes = loadedOrigenes; loadingData = false;
                  });
                }
              } catch (e) {
                if (ctx.mounted) setS(() { loadError = e.toString().replaceFirst('Exception: ', ''); loadingData = false; });
              }
            });
          }

          // ─── helpers ───────────────────────────────────────────────────
          InputDecoration fieldDeco(String hint, IconData icon, {bool active = false}) => InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: textSoft, fontSize: 14, fontWeight: FontWeight.w500),
            prefixIcon: Container(
              margin: const EdgeInsets.all(9),
              width: 34, height: 34,
              decoration: BoxDecoration(
                gradient: active
                    ? const LinearGradient(
                        colors: [Color(0xFF4361EE), Color(0xFF00D2FF)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : null,
                color: active ? null : inputFill,
                borderRadius: BorderRadius.circular(10),
                boxShadow: active
                    ? [BoxShadow(color: homeAccent.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))]
                    : null,
              ),
              child: Icon(icon, color: active ? Colors.white : textSoft, size: 17),
            ),
            filled: true,
            fillColor: active ? cardBgAlt : inputFill,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: lineCol)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: active ? homeAccent.withValues(alpha: 0.45) : lineCol, width: active ? 1.4 : 1)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: homeAccent, width: 1.8)),
          );

          Widget sectionLabel(String text, IconData icon) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(width: 3, height: 13, decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [homeAccent, homeCyan], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                borderRadius: BorderRadius.circular(2),
              )),
              const SizedBox(width: 8),
              Icon(icon, size: 13, color: textSoft),
              const SizedBox(width: 5),
              Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textSoft, letterSpacing: 0.3)),
            ]),
          );

          // ─── picker de usuario asociado ──────────────────────────────
          Widget origenPicker() => GestureDetector(
            onTap: (saving || loadingOrigenes || origenes.isEmpty) ? null : () async {
              final searchCtrl = TextEditingController();
              List<Map<String, dynamic>> filtered = List.from(origenes);
              final picked = await showDialog<Map<String, dynamic>>(
                context: ctx,
                builder: (dCtx) => StatefulBuilder(builder: (dCtx, setSrch) {
                  return Dialog(
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: homeAccent.withValues(alpha: 0.15), blurRadius: 32, offset: const Offset(0, 12))],
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(18, 18, 14, 16),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFF060E35), Color(0xFF0D1B6E), Color(0xFF1435A8)],
                                begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: Row(children: [
                            Container(width: 36, height: 36, decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ), child: const Icon(Icons.person_search_rounded, color: Colors.white, size: 18)),
                            const SizedBox(width: 11),
                            const Expanded(child: Text('Seleccionar Usuario',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))),
                            appCloseX(() => Navigator.pop(dCtx)),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                          child: TextField(
                            controller: searchCtrl,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Buscar usuario...',
                              hintStyle: const TextStyle(color: Color(0xFFB0BCCF), fontSize: 13),
                              prefixIcon: Container(margin: const EdgeInsets.all(8), width: 30, height: 30,
                                decoration: BoxDecoration(gradient: const LinearGradient(colors: [homeAccent, homeCyan]), borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.search_rounded, color: Colors.white, size: 15)),
                              filled: true, fillColor: inputFill,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E7FF))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE0E7FF))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: homeAccent, width: 1.5)),
                            ),
                            onChanged: (q) => setSrch(() {
                              filtered = origenes.where((item) => (item['nombre'] ?? '').toString().toLowerCase().contains(q.toLowerCase())).toList();
                            }),
                          ),
                        ),
                        Flexible(child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final item = filtered[i];
                            final nom = (item['nombre'] ?? '').toString();
                            final cod = (item['codigo'] ?? '').toString();
                            final isSel = cod == origen;
                            return InkWell(
                              onTap: () => Navigator.pop(dCtx, item),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                                decoration: BoxDecoration(
                                  color: isSel ? homeAccent.withValues(alpha: 0.07) : null,
                                  border: Border(bottom: BorderSide(color: lineCol, width: i < filtered.length - 1 ? 1 : 0)),
                                ),
                                child: Row(children: [
                                  Container(width: 32, height: 32,
                                    decoration: BoxDecoration(
                                      gradient: isSel ? const LinearGradient(colors: [homeAccent, homeCyan]) : null,
                                      color: isSel ? null : const Color(0xFFEEF0F8),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Icon(Icons.person_rounded, size: 16, color: isSel ? Colors.white : textSoft)),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(nom, style: TextStyle(fontSize: 13, color: isSel ? homeAccent : textMid, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500))),
                                  if (isSel) const Icon(Icons.check_circle_rounded, size: 17, color: homeAccent),
                                ]),
                              ),
                            );
                          },
                        )),
                        const SizedBox(height: 8),
                      ]),
                    ),
                  );
                }),
              );
              if (picked != null) setS(() { origen = (picked['codigo'] ?? '').toString(); });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              decoration: BoxDecoration(
                color: inputFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: origen.isNotEmpty ? homeAccent.withValues(alpha: 0.5) : const Color(0xFFE0E7FF), width: origen.isNotEmpty ? 1.5 : 1),
              ),
              child: Row(children: [
                Container(width: 34, height: 34, decoration: BoxDecoration(
                  gradient: origen.isNotEmpty
                      ? const LinearGradient(colors: [homeAccent, homeCyan], begin: Alignment.topLeft, end: Alignment.bottomRight)
                      : null,
                  color: origen.isNotEmpty ? null : const Color(0xFFE7ECFB),
                  borderRadius: BorderRadius.circular(10),
                ), child: Icon(Icons.person_search_outlined, size: 17, color: origen.isNotEmpty ? Colors.white : const Color(0xFF7E8DB8))),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  loadingOrigenes ? 'Cargando usuarios...'
                      : origen.isNotEmpty
                          ? (origenes.firstWhere((e) => (e['codigo'] ?? '').toString() == origen, orElse: () => {'nombre': 'Usuario seleccionado'})['nombre'] ?? '').toString()
                          : origenes.isEmpty && !loadingOrigenes ? 'Seleccione primero el tipo' : 'Seleccione un usuario',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: origen.isNotEmpty ? FontWeight.w600 : FontWeight.w500,
                      color: origen.isNotEmpty && !loadingOrigenes ? textMain : textSoft),
                )),
                if (loadingOrigenes)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: homeAccent))
                else
                  Icon(Icons.keyboard_arrow_down_rounded, size: 20,
                      color: origen.isNotEmpty ? homeAccent : textSoft),
              ]),
            ),
          );

          return Dialog(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: homeAccent.withValues(alpha: 0.18), blurRadius: 40, offset: const Offset(0, 16)),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // ── HEADER ───────────────────────────────────────
                Container(
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF060E35), Color(0xFF0D1B6E), Color(0xFF1435A8), Color(0xFF0077BB)],
                      stops: [0.0, 0.35, 0.70, 1.0],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Stack(children: [
                    Positioned(right: -30, top: -30, child: Container(width: 100, height: 100,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [Colors.white.withValues(alpha: 0.10), Colors.transparent])))),
                    Positioned(left: -15, bottom: -15, child: Container(width: 65, height: 65,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)))),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 20, 14, 20),
                      child: Row(children: [
                        Container(width: 48, height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0.08)],
                                begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: Icon(editing ? Icons.manage_accounts_rounded : Icons.person_add_alt_1_rounded, color: Colors.white, size: 26)),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(editing ? 'Editar usuario' : 'Crear usuario',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                          const SizedBox(height: 3),
                          Text(editing ? 'Modifica los datos del acceso' : 'Registra un nuevo acceso',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11.5)),
                        ])),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx, false),
                          child: Container(width: 34, height: 34,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF991B1B), Color(0xFFDC2626), Color(0xFFF43F5E)]),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [BoxShadow(color: const Color(0xFFDC2626).withValues(alpha: 0.45), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 17)),
                        ),
                      ]),
                    ),
                  ]),
                ),
                // ── CONTENT ──────────────────────────────────────
                if (loadingData)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 44),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      CircularProgressIndicator(color: homeAccent),
                      SizedBox(height: 14),
                      Text('Cargando datos...', style: TextStyle(color: textSoft, fontSize: 13)),
                    ]),
                  )
                else if (loadError.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline_rounded, size: 38, color: Color(0xFFDC2626)),
                      const SizedBox(height: 10),
                      Text(loadError, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
                      const SizedBox(height: 16),
                      appCancelButton('Cerrar', () => Navigator.pop(ctx, false)),
                    ]),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      sectionLabel('CORREO ELECTRÓNICO', Icons.alternate_email_rounded),
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: textMain, fontSize: 14, fontWeight: FontWeight.w600),
                        decoration: fieldDeco('Email usuario', Icons.alternate_email_rounded, active: emailCtrl.text.isNotEmpty),
                      ),
                      const SizedBox(height: 16),
                      sectionLabel('ACCESO Y PERMISOS', Icons.admin_panel_settings_rounded),
                      DropdownButtonFormField<String>(
                        initialValue: perfil.isEmpty ? null : perfil,
                        isExpanded: true,
                        dropdownColor: dialogBg,
                        borderRadius: BorderRadius.circular(14),
                        style: TextStyle(color: textMain, fontSize: 14, fontWeight: FontWeight.w600),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF7E8DB8)),
                        hint: const Text('Seleccione un perfil',
                            style: TextStyle(color: Color(0xFF8E9BBA), fontSize: 14, fontWeight: FontWeight.w500)),
                        decoration: fieldDeco('Seleccione un perfil', Icons.shield_outlined, active: perfil.isNotEmpty),
                        items: perfiles.map((item) => DropdownMenuItem(
                          value: (item['codigo'] ?? '').toString(),
                          child: Text((item['nombre'] ?? '').toString(), overflow: TextOverflow.ellipsis, style: TextStyle(color: textMain)),
                        )).toList(),
                        onChanged: saving ? null : (v) => setS(() => perfil = v ?? ''),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: tipo.isEmpty ? null : tipo,
                        isExpanded: true,
                        dropdownColor: dialogBg,
                        borderRadius: BorderRadius.circular(14),
                        style: TextStyle(color: textMain, fontSize: 14, fontWeight: FontWeight.w600),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF7E8DB8)),
                        hint: const Text('Seleccione un tipo',
                            style: TextStyle(color: Color(0xFF8E9BBA), fontSize: 14, fontWeight: FontWeight.w500)),
                        decoration: fieldDeco('Seleccione un tipo', Icons.badge_outlined, active: tipo.isNotEmpty),
                        items: tipos.map((item) => DropdownMenuItem(
                          value: (item['codigo'] ?? '').toString(),
                          child: Text((item['nombre'] ?? '').toString(), overflow: TextOverflow.ellipsis, style: TextStyle(color: textMain)),
                        )).toList(),
                        onChanged: saving ? null : (v) async {
                          final selected = v ?? '';
                          setS(() { tipo = selected; origen = ''; origenes = []; loadingOrigenes = selected.isNotEmpty; });
                          if (selected.isEmpty) return;
                          try {
                            final result = await loadOrigins(selected);
                            if (ctx.mounted) setS(() { origenes = result; loadingOrigenes = false; });
                          } catch (e) {
                            if (ctx.mounted) { setS(() => loadingOrigenes = false); showResult(false, friendlyError(e)); }
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      sectionLabel('USUARIO ASOCIADO', Icons.person_search_rounded),
                      origenPicker(),
                      const SizedBox(height: 20),
                      // ── BUTTONS ────────────────────────────────
                      Row(children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: saving ? null : () => Navigator.pop(ctx, false),
                            child: appCancelButton('Cancelar', null, height: 50),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: saving ? null : () async {
                              final email = emailCtrl.text.trim();
                              if (!email.contains('@') || perfil.isEmpty || tipo.isEmpty || origen.isEmpty) {
                                showResult(false, 'Complete todos los campos antes de guardar');
                                return;
                              }
                              setS(() => saving = true);
                              try {
                                await _usuariosRequest({
                                  'accion': 'guardar', 'codigo_usuario': codigoUsuario,
                                  'usuario': email, 'codigo_perfil': perfil,
                                  'codigo_tipo_usuario': tipo, 'codigo_origen': origen,
                                });
                                if (ctx.mounted) Navigator.pop(ctx, true);
                                showResult(true, editing ? 'Usuario actualizado exitosamente' : 'Usuario registrado exitosamente');
                              } catch (e) {
                                if (ctx.mounted) setS(() => saving = false);
                                showResult(false, friendlyError(e));
                              }
                            },
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: saving
                                    ? null
                                    : const LinearGradient(colors: [Color(0xFF0D1B4B), Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                                        stops: [0.0, 0.5, 1.0], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                color: saving ? const Color(0xFFCBD5E1) : null,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: saving ? null : [
                                  BoxShadow(color: homeAccent.withValues(alpha: 0.40), blurRadius: 14, offset: const Offset(0, 5)),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: saving
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                  : const Row(mainAxisSize: MainAxisSize.min, children: [
                                      Icon(Icons.save_rounded, color: Colors.white, size: 18),
                                      SizedBox(width: 8),
                                      Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
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
          );
        },
      ),
    );
    emailCtrl.dispose();
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

  const _AdminUserTile({
    super.key,
    required this.user,
    required this.index,
    required this.onEdit,
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
    begin: const Offset(0, 0.30),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _entrance, curve: Curves.easeOut);

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

  String _initials(String email) {
    final local = email.split('@').first;
    final parts = local.split(RegExp(r'[._\-0-9]+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].length >= 2) return parts[0].substring(0, 2).toUpperCase();
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final email = (user['usuario'] ?? user['email'] ?? user['correo'] ?? 'Usuario').toString();
    final tipo = (user['tipo_usuario'] ?? user['tipo'] ?? '').toString();
    final perfil = (user['perfil'] ?? user['nombre_perfil'] ?? '').toString();
    final estadoRaw = (user['estado'] ?? user['activo'] ?? '').toString();
    final activo = estadoRaw.isEmpty || estadoRaw == '1' ||
        estadoRaw.toLowerCase() == 'activo' || estadoRaw.toLowerCase() == 'true';
    final initials = _initials(email);

    const activeGrad = LinearGradient(
      colors: [Color(0xFF0D1B4B), Color(0xFF1E3A8A), Color(0xFF3B82F6)],
      stops: [0.0, 0.5, 1.0],
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
        child: GestureDetector(
          onTapDown: (_) => _press.reverse(),
          onTapUp: (_) => _press.forward(),
          onTapCancel: () => _press.forward(),
          child: ScaleTransition(
            scale: _press,
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: lineCol),
                boxShadow: [
                  BoxShadow(
                    color: (activo ? const Color(0xFF4361EE) : const Color(0xFF94A3B8))
                        .withValues(alpha: 0.09),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
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
                    width: 4,
                    decoration: BoxDecoration(
                      gradient: activo ? activeGrad : inactiveGrad,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Avatar with shimmer sweep
                  ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Stack(children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: activo ? activeGrad : inactiveGrad,
                          borderRadius: BorderRadius.circular(13),
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
                      ),
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
                  const SizedBox(width: 12),
                  // Info column
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textMain,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Wrap(spacing: 5, runSpacing: 3, children: [
                            if (tipo.isNotEmpty) _tileBadge(tipo, const Color(0xFF4361EE)),
                            if (perfil.isNotEmpty) _tileBadge(perfil, const Color(0xFF7C3AED)),
                            _tileBadge(
                              activo ? 'Activo' : 'Inactivo',
                              activo ? const Color(0xFF059669) : const Color(0xFFDC2626),
                              dot: true,
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  // Edit button
                  GestureDetector(
                    onTap: widget.onEdit,
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        gradient: isDarkTheme
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        color: isDarkTheme
                            ? homeAccent.withValues(alpha: 0.18)
                            : null,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: homeAccent.withValues(alpha: isDarkTheme ? 0.35 : 0.20)),
                      ),
                      child: Icon(Icons.edit_rounded,
                          color: isDarkTheme ? const Color(0xFFA5B4FC) : homeAccent,
                          size: 17),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tileBadge(String text, Color color, {bool dot = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.20)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (dot) ...[
        Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
      ],
      Text(text, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w700)),
    ]),
  );
}
