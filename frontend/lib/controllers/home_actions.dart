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
    cachedIncomeTotal ??= movements.where((m) {
      final t = (m['tipo_movimiento'] ?? '').toString();
      return t == '3' || t == '1';
    }).fold<double>(0.0, (s, m) => s + numberValue(m['valor'] ?? 0));
    return cachedIncomeTotal!;
  }

  double get totalExpenses {
    if (serverTotalsLoaded) return serverExpenses;
    cachedExpenseTotal ??= movements
        .where((m) => (m['tipo_movimiento'] ?? '').toString() == '2')
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
      builder: (_) => buildProfileSheet(email),
    );
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

          final filtrados = usuarios.where((user) {
            if (query.isEmpty) return true;
            final text = user.values.join(' ').toLowerCase();
            return text.contains(query.toLowerCase());
          }).toList();

          return Dialog.fullscreen(
            backgroundColor: const Color(0xFFF5F7FC),
            child: SafeArea(
              child: Column(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0D1B4B), Color(0xFF1E3A8A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 6, 12, 12),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.arrow_back_rounded,
                                  color: Colors.white),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(
                                Icons.manage_accounts_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Gestión de usuarios',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    'Administración · Acceso restringido',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                final saved = await _showUserForm();
                                if (saved && ctx.mounted) {
                                  setS(() {
                                    loading = true;
                                    error = '';
                                  });
                                  try {
                                    final data = await _fetchUsuariosAdmin(
                                        forceRefresh: true);
                                    if (ctx.mounted) {
                                      setS(() {
                                        usuarios = data;
                                        loading = false;
                                      });
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      setS(() {
                                        error = e
                                            .toString()
                                            .replaceFirst('Exception: ', '');
                                        loading = false;
                                      });
                                    }
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.4),
                                      width: 1),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.person_add_alt_1_rounded,
                                        color: Colors.white, size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      'Nuevo',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: TextField(
                      onChanged: (value) => setS(() => query = value.trim()),
                      style: const TextStyle(color: homeNavy, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Buscar usuario, perfil o estado',
                        hintStyle: const TextStyle(color: Color(0xFFB0BBCC)),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Color(0xFF8899BB)),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: homeAccent, width: 1.5),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  Expanded(
                    child: loading
                        ? const Center(
                            child: CircularProgressIndicator(color: homeAccent),
                          )
                        : error.isNotEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(28),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.cloud_off_rounded,
                                        size: 44,
                                        color: Color(0xFF8899BB),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        error,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : filtrados.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No se encontraron usuarios',
                                      style:
                                          TextStyle(color: Color(0xFF8899BB)),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 4, 16, 24),
                                    itemCount: filtrados.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (_, index) => _adminUserCard(
                                      filtrados[index],
                                      () async {
                                        final saved = await _showUserForm(
                                            filtrados[index]);
                                        if (saved && ctx.mounted) {
                                          setS(() {
                                            loading = true;
                                            error = '';
                                          });
                                          try {
                                            final data =
                                                await _fetchUsuariosAdmin(
                                                    forceRefresh: true);
                                            if (ctx.mounted) {
                                              setS(() {
                                                usuarios = data;
                                                loading = false;
                                              });
                                            }
                                          } catch (e) {
                                            if (ctx.mounted) {
                                              setS(() {
                                                error = e
                                                    .toString()
                                                    .replaceFirst(
                                                        'Exception: ', '');
                                                loading = false;
                                              });
                                            }
                                          }
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

    // Estado mutable dentro del StatefulBuilder
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

    Future<List<Map<String, dynamic>>> loadOrigins(
        String tipoCodigo, StateSetter setS) async {
      if (tipoCodigo.isEmpty) return [];
      final response = await _usuariosRequest({
        'accion': 'origenes',
        'codigo_tipo_usuario': tipoCodigo,
      });
      final raw = response['datos'];
      return raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : [];
    }

    final saved = await showDialog<bool>(
      context: screenContext,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          // Inicializar datos la primera vez que se renderiza
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
                final loadedTipos =
                    (data['tipos'] is List ? data['tipos'] as List : [])
                        .whereType<Map>()
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList();

                Map<String, dynamic> detail = {};
                if (editing) {
                  final resp = await _usuariosRequest({
                    'accion': 'detalle',
                    'codigo_usuario': codigoUsuario,
                  });
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
                final initTipo =
                    (detail['codigo_tipo_usuario'] ?? '').toString();
                final initOrigen = (detail['codigo_origen'] ?? '').toString();

                List<Map<String, dynamic>> loadedOrigenes = [];
                if (initTipo.isNotEmpty) {
                  try {
                    loadedOrigenes = await loadOrigins(initTipo, setS);
                  } catch (_) {}
                }

                if (ctx.mounted) {
                  setS(() {
                    perfiles = loadedPerfiles;
                    tipos = loadedTipos;
                    emailCtrl.text = initEmail;
                    perfil = initPerfil;
                    tipo = initTipo;
                    origen = initOrigen;
                    origenes = loadedOrigenes;
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

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: EdgeInsets.zero,
            title: Container(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0D1B4B),
                    Color(0xFF1E40AF),
                    Color(0xFF0EA5E9)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      editing
                          ? Icons.manage_accounts_rounded
                          : Icons.person_add_alt_1_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          editing ? 'Editar usuario' : 'Crear usuario',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          editing
                              ? 'Modifica los datos del usuario'
                              : 'Registra un nuevo acceso',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.70),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            content: loadingData
                ? const SizedBox(
                    height: 120,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: homeAccent),
                          SizedBox(height: 16),
                          Text('Cargando datos...',
                              style: TextStyle(
                                  color: Color(0xFF8899BB), fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                : loadError.isNotEmpty
                    ? SizedBox(
                        height: 100,
                        child: Center(
                          child: Text(loadError,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFDC2626))),
                        ),
                      )
                    : SingleChildScrollView(
                        child: SizedBox(
                          width: 440,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 4),
                              TextField(
                                controller: emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: homeNavy),
                                decoration: _userInputDecoration(
                                  'Email usuario',
                                  Icons.alternate_email_rounded,
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: perfil.isEmpty ? null : perfil,
                                isExpanded: true,
                                dropdownColor: Colors.white,
                                style: const TextStyle(
                                    color: homeNavy, fontSize: 14),
                                decoration: _userInputDecoration(
                                  'Perfil',
                                  Icons.admin_panel_settings_outlined,
                                ),
                                items: perfiles
                                    .map((item) => DropdownMenuItem(
                                          value:
                                              (item['codigo'] ?? '').toString(),
                                          child: Text(
                                            (item['nombre'] ?? '').toString(),
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: homeNavy),
                                          ),
                                        ))
                                    .toList(),
                                onChanged: saving
                                    ? null
                                    : (value) =>
                                        setS(() => perfil = value ?? ''),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: tipo.isEmpty ? null : tipo,
                                isExpanded: true,
                                dropdownColor: Colors.white,
                                style: const TextStyle(
                                    color: homeNavy, fontSize: 14),
                                decoration: _userInputDecoration(
                                  'Tipo de usuario',
                                  Icons.badge_outlined,
                                ),
                                items: tipos
                                    .map((item) => DropdownMenuItem(
                                          value:
                                              (item['codigo'] ?? '').toString(),
                                          child: Text(
                                            (item['nombre'] ?? '').toString(),
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: homeNavy),
                                          ),
                                        ))
                                    .toList(),
                                onChanged: saving
                                    ? null
                                    : (value) async {
                                        final selected = value ?? '';
                                        setS(() {
                                          tipo = selected;
                                          origen = '';
                                          origenes = [];
                                          loadingOrigenes = selected.isNotEmpty;
                                        });
                                        if (selected.isEmpty) return;
                                        try {
                                          final result =
                                              await loadOrigins(selected, setS);
                                          if (ctx.mounted) {
                                            setS(() {
                                              origenes = result;
                                              loadingOrigenes = false;
                                            });
                                          }
                                        } catch (e) {
                                          if (ctx.mounted) {
                                            setS(() => loadingOrigenes = false);
                                            showResult(false, friendlyError(e));
                                          }
                                        }
                                      },
                              ),
                              const SizedBox(height: 12),
                              // Usuario asociado — searchable picker
                              GestureDetector(
                                onTap: (saving ||
                                        loadingOrigenes ||
                                        origenes.isEmpty)
                                    ? null
                                    : () async {
                                        final searchCtrl =
                                            TextEditingController();
                                        List<Map<String, dynamic>> filtered =
                                            List.from(origenes);
                                        final picked = await showDialog<
                                            Map<String, dynamic>>(
                                          context: ctx,
                                          builder: (dCtx) => StatefulBuilder(
                                              builder: (dCtx, setSrch) {
                                            return Dialog(
                                              backgroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          16)),
                                              insetPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 24,
                                                      vertical: 60),
                                              child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .fromLTRB(
                                                          16, 16, 16, 12),
                                                      decoration:
                                                          const BoxDecoration(
                                                        gradient:
                                                            LinearGradient(
                                                                colors: [
                                                              Color(0xFF0D1B4B),
                                                              Color(0xFF1E40AF),
                                                              Color(0xFF0EA5E9)
                                                            ]),
                                                        borderRadius:
                                                            BorderRadius.vertical(
                                                                top: Radius
                                                                    .circular(
                                                                        16)),
                                                      ),
                                                      child: Row(children: [
                                                        const Icon(
                                                            Icons
                                                                .person_search_rounded,
                                                            color: Colors.white,
                                                            size: 20),
                                                        const SizedBox(
                                                            width: 10),
                                                        const Expanded(
                                                            child: Text(
                                                                'Seleccionar Usuario',
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    fontSize:
                                                                        15))),
                                                        GestureDetector(
                                                            onTap: () =>
                                                                Navigator.pop(
                                                                    dCtx),
                                                            child: const Icon(
                                                                Icons
                                                                    .close_rounded,
                                                                color: Colors
                                                                    .white70,
                                                                size: 20)),
                                                      ]),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets
                                                          .fromLTRB(
                                                          12, 12, 12, 4),
                                                      child: TextField(
                                                        controller: searchCtrl,
                                                        autofocus: true,
                                                        decoration:
                                                            InputDecoration(
                                                          hintText:
                                                              'Buscar usuario...',
                                                          prefixIcon: const Icon(
                                                              Icons
                                                                  .search_rounded,
                                                              size: 18,
                                                              color: Color(
                                                                  0xFF6B7280)),
                                                          contentPadding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      12,
                                                                  vertical: 10),
                                                          border: OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                              borderSide:
                                                                  const BorderSide(
                                                                      color: Color(
                                                                          0xFFD1D5DB))),
                                                          enabledBorder: OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                              borderSide:
                                                                  const BorderSide(
                                                                      color: Color(
                                                                          0xFFD1D5DB))),
                                                          focusedBorder: OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                              borderSide:
                                                                  const BorderSide(
                                                                      color: Color(
                                                                          0xFF4361EE))),
                                                        ),
                                                        onChanged: (q) =>
                                                            setSrch(() {
                                                          filtered = origenes
                                                              .where((item) => (item[
                                                                          'nombre'] ??
                                                                      '')
                                                                  .toString()
                                                                  .toLowerCase()
                                                                  .contains(q
                                                                      .toLowerCase()))
                                                              .toList();
                                                        }),
                                                      ),
                                                    ),
                                                    Flexible(
                                                      child: ListView.builder(
                                                        shrinkWrap: true,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 4),
                                                        itemCount:
                                                            filtered.length,
                                                        itemBuilder: (_, i) {
                                                          final item =
                                                              filtered[i];
                                                          final nom =
                                                              (item['nombre'] ??
                                                                      '')
                                                                  .toString();
                                                          final cod =
                                                              (item['codigo'] ??
                                                                      '')
                                                                  .toString();
                                                          final isSelected =
                                                              cod == origen;
                                                          return InkWell(
                                                            onTap: () =>
                                                                Navigator.pop(
                                                                    dCtx, item),
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          16,
                                                                      vertical:
                                                                          12),
                                                              color: isSelected
                                                                  ? const Color(
                                                                      0xFFEEF2FF)
                                                                  : null,
                                                              child: Row(
                                                                  children: [
                                                                    Expanded(
                                                                        child: Text(
                                                                            nom,
                                                                            style: TextStyle(
                                                                                fontSize: 14,
                                                                                color: isSelected ? const Color(0xFF4361EE) : const Color(0xFF374151),
                                                                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400))),
                                                                    if (isSelected)
                                                                      const Icon(
                                                                          Icons
                                                                              .check_rounded,
                                                                          size:
                                                                              16,
                                                                          color:
                                                                              Color(0xFF4361EE)),
                                                                  ]),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                  ]),
                                            );
                                          }),
                                        );
                                        if (picked != null) {
                                          setS(() {
                                            origen = (picked['codigo'] ?? '')
                                                .toString();
                                          });
                                        }
                                      },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: const Color(0xFFD1D5DB)),
                                    borderRadius: BorderRadius.circular(10),
                                    color: (saving || loadingOrigenes)
                                        ? const Color(0xFFF9FAFB)
                                        : Colors.white,
                                  ),
                                  child: Row(children: [
                                    Icon(Icons.person_search_outlined,
                                        size: 18,
                                        color: origen.isNotEmpty
                                            ? const Color(0xFF4361EE)
                                            : const Color(0xFF9CA3AF)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: Text(
                                      loadingOrigenes
                                          ? 'Cargando usuarios...'
                                          : origen.isNotEmpty
                                              ? (origenes.firstWhere(
                                                          (e) =>
                                                              (e['codigo'] ??
                                                                      '')
                                                                  .toString() ==
                                                              origen,
                                                          orElse: () => {
                                                                'nombre':
                                                                    'Usuario seleccionado'
                                                              })['nombre'] ??
                                                      '')
                                                  .toString()
                                              : 'Usuario asociado',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: origen.isNotEmpty &&
                                                  !loadingOrigenes
                                              ? const Color(0xFF0D1B4B)
                                              : const Color(0xFF9CA3AF)),
                                    )),
                                    Icon(
                                        loadingOrigenes
                                            ? Icons.hourglass_empty_rounded
                                            : Icons.keyboard_arrow_down_rounded,
                                        size: 18,
                                        color: const Color(0xFF6B7280)),
                                  ]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
            actions: loadingData || loadError.isNotEmpty
                ? [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cerrar'),
                    ),
                  ]
                : [
                    TextButton(
                      onPressed:
                          saving ? null : () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF8899BB)),
                      child: const Text('Cancelar'),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: saving
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF0D1B4B), Color(0xFF1E3A8A)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: saving
                            ? null
                            : [
                                BoxShadow(
                                  color: homeAccent.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFCBD5E1),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: saving
                            ? null
                            : () async {
                                final email = emailCtrl.text.trim();
                                if (!email.contains('@') ||
                                    perfil.isEmpty ||
                                    tipo.isEmpty ||
                                    origen.isEmpty) {
                                  showResult(false,
                                      'Complete todos los campos antes de guardar');
                                  return;
                                }
                                setS(() => saving = true);
                                try {
                                  await _usuariosRequest({
                                    'accion': 'guardar',
                                    'codigo_usuario': codigoUsuario,
                                    'usuario': email,
                                    'codigo_perfil': perfil,
                                    'codigo_tipo_usuario': tipo,
                                    'codigo_origen': origen,
                                  });
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx, true);
                                  }
                                } catch (e) {
                                  if (ctx.mounted) setS(() => saving = false);
                                  showResult(false, friendlyError(e));
                                }
                              },
                        icon: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded, size: 18),
                        label: Text(saving ? 'Guardando...' : 'Guardar'),
                      ),
                    ),
                  ],
          );
        },
      ),
    );
    emailCtrl.dispose();
    return saved == true;
  }

  InputDecoration _userInputDecoration(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: homeAccent, size: 20),
        filled: true,
        fillColor: const Color(0xFFF0F2FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDCE2F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: homeAccent, width: 1.5),
        ),
      );

  Widget _adminUserCard(Map<String, dynamic> user, VoidCallback onEdit) {
    final email = (user['usuario'] ??
            user['email'] ??
            user['correo'] ??
            'Usuario sin correo')
        .toString();
    final tipo = (user['tipo_usuario'] ?? user['tipo'] ?? 'Usuario').toString();
    final perfil =
        (user['perfil'] ?? user['nombre_perfil'] ?? 'Sin perfil').toString();
    final estadoRaw = (user['estado'] ?? user['activo'] ?? '').toString();
    final activo = estadoRaw.isEmpty ||
        estadoRaw == '1' ||
        estadoRaw.toLowerCase() == 'activo' ||
        estadoRaw.toLowerCase() == 'true';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEF0F8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Borde izquierdo de color
          Container(
            width: 4,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: activo
                    ? [const Color(0xFF0D1B4B), const Color(0xFF1E3A8A)]
                    : [const Color(0xFFCBD5E1), const Color(0xFFCBD5E1)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: activo
                  ? const LinearGradient(
                      colors: [Color(0xFF0D1B4B), Color(0xFF1E3A8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: activo ? null : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.person_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: homeNavy,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      _userBadge(tipo, const Color(0xFF4361EE)),
                      _userBadge(perfil, const Color(0xFF4361EE)),
                      _userBadge(
                        activo ? 'Activo' : 'Inactivo',
                        activo
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Botón editar
          GestureDetector(
            onTap: onEdit,
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: homeAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.edit_rounded,
                color: homeAccent,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _userBadge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}
