import '../screens/home/home_dependencies.dart';
import 'home_actions.dart';

extension HomeDataController<T extends StatefulWidget> on HomeController<T> {
  Future<void> fetchMenuOptions() async {
    // Asesor (perfil 1): ve Inicio y Ahorradores
    if (isAsesor) {
      if (isMounted) {
        refresh(() {
          allowedScreenIndices = [0, 2];
          selectedIndex = 0;
          menuOptionsLoaded = true;
        });
      }
      return;
    }
    // Admin siempre ve todos los tabs
    if (isAdmin) {
      if (isMounted) {
        refresh(() {
          allowedScreenIndices = [0, 1, 2, 3];
          menuOptionsLoaded = true;
        });
      }
      return;
    }
    try {
      final r = await repository.post('/ajax/cargar_opciones.php', {});
      if (r.statusCode == 200) {
        final d = decodeJsonMap(r.body);
        if (d['resultado'] == 1 && d['opciones'] is List) {
          final opciones = d['opciones'] as List;
          final allowed = <int>[0]; // Inicio siempre visible
          for (final op in opciones.whereType<Map>()) {
            final n = (op['nombre'] ?? '').toString().toLowerCase()
                .replaceAll('é', 'e').replaceAll('á', 'a')
                .replaceAll('ó', 'o').replaceAll('í', 'i')
                .replaceAll('ú', 'u');
            if ((n.contains('credito') || n.contains('prestamo')) && !allowed.contains(1)) {
              allowed.add(1);
            }
            if (n.contains('ahorro') && !allowed.contains(2)) allowed.add(2);
            if ((n.contains('gasto') || n.contains('movimiento')) && !allowed.contains(3)) {
              allowed.add(3);
            }
          }
          allowed.sort();
          if (isMounted) {
            refresh(() {
              allowedScreenIndices = allowed;
              menuOptionsLoaded = true;
              if (selectedIndex >= allowed.length) selectedIndex = 0;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[SAF] menuOptions: $e');
    }
    // Fallback: si la red falla no dejamos el skeleton colgado
    if (isMounted && !menuOptionsLoaded) {
      refresh(() => menuOptionsLoaded = true);
    }
  }

  Future<void> loadData() async {
    await repository.init();
    final u = repository.user;
    final codigoUsuario = u?['codigo_usuario']?.toString() ?? '';
    final anio = DateTime.now().year.toString();

    // Determinar rol y origen del usuario
    final codigoPerfil = u?['codigo_perfil']?.toString() ?? '';
    final origenValue = u?['codigo_origen']?.toString() ?? '';
    if (isMounted) {
      refresh(() {
        isAdmin = (codigoPerfil == '6');
        isAsesor = (codigoPerfil == '1');
        isCreditsProfile = (codigoPerfil == '5');
        codigoOrigen = origenValue;
      });
    }

    // Cargar opciones de menú según perfil (no bloquea el resto)
    unawaited(fetchMenuOptions());

    // Tema sincronizado con la web: la preferencia guardada en el servidor
    // (por usuario) manda sobre la copia local del dispositivo.
    unawaited(syncThemeFromServer());

    // Show cached data immediately so the screen isn't blank.
    // Local reads run in parallel — they're independent SharedPreferences
    // lookups with no reason to wait on each other one by one.
    final cached = await Future.wait([
      repository.loadLocalData('cuentas'),
      repository.loadLocalData('movimientos'),
      repository.loadLocalData('ahorradores'),
      repository.loadLocalData('creditos'),
      repository.loadLocalData('creditos_lista'),
      repository.loadLocalData('totales'),
    ]);
    final cachedCuentas = cached[0];
    final cachedMovs = cached[1];
    final cachedAhorradores = cached[2];
    final cachedCreditos = cached[3];
    final cachedCreditosLista = cached[4];
    final cachedTotales = cached[5];

    if (cachedCuentas != null) {
      accounts = cachedCuentas;
      invalidateComputedCache();
    }
    if (cachedMovs != null) {
      movements = cachedMovs;
      invalidateComputedCache();
    }
    if (cachedAhorradores != null) savers = cachedAhorradores;
    if (cachedCreditos != null) creditStatistics = cachedCreditos;
    if (cachedCreditosLista != null) credits = cachedCreditosLista;
    if (cachedTotales != null && cachedTotales.isNotEmpty) {
      serverExpenses = numberValue(cachedTotales.first['gastos']);
      serverIncome = numberValue(cachedTotales.first['ingresos']);
      serverTotalsLoaded = true;
    }

    final hasCachedData = cachedCuentas != null;
    if (hasCachedData && isMounted) refresh(() => loadingData = false);

    // Fetch fresh data from network. fetchAccounts corre junto al resto:
    // nada aquí depende realmente de que las cuentas terminen primero
    // (el endpoint global de movimientos no las necesita), así que
    // serializarlo solo agregaba una ida y vuelta de red innecesaria.
    await Future.wait([
      fetchAccounts(codigoUsuario),
      _fetchMovimientosTodasCuentas(codigoUsuario),
      fetchSavers(anio),
      fetchCredits(codigoUsuario),
      _fetchTotalesResumen(codigoUsuario),
    ]);
    // Con credits ya cargada, construir deudores al instante
    tryBuildDebtorsFromLocal();
    // Tasas y fuentes en paralelo; deudores via API en background (no bloquea)
    unawaited(fetchDebtors());
    await Future.wait([fetchRates(), fetchSources(), fetchAdvisors()]);

    if (isMounted) refresh(() => loadingData = false);
  }

  Future<void> fetchAccounts(String filtro) async {
    try {
      final r = await repository
          .cachedPost('/ajax/listar_cuentas_gasto.php', {'filtro': filtro});
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        List<dynamic>? list;
        if (d is List) {
          list = d;
        } else if (d is Map) {
          for (final k in ['cuentas', 'datos', 'data', 'resultado_datos']) {
            if (d[k] is List) {
              list = d[k] as List;
              break;
            }
          }
        }
        if (list != null) {
          accounts = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          invalidateComputedCache();
          unawaited(repository.saveLocalData('cuentas', accounts));
        }
      }
    } catch (e) {
      debugPrint('[SAF] cuentas: $e');
    }
  }

  Future<void> _fetchMovimientosTodasCuentas(String usuario,
      {String? desde, String? hasta}) async {
    final dStr = desde ?? '';
    final hStr = hasta ?? '';

    // Use global endpoint: single JOIN query, globally sorted by fecha DESC, codigo DESC
    bool globalOk = false;
    try {
      final globalAll = <Map<String, dynamic>>[];
      var pagina = 1;
      var totalPaginas = 1;
      do {
        final r =
            await repository.post('/ajax/listar_movimientos_usuario.php', {
          'usuario': usuario,
          'desde': dStr,
          'hasta': hStr,
          'pagina': pagina.toString(),
        }).timeout(const Duration(seconds: 15));
        if (r.statusCode != 200) break;
        final d = decodeJsonMap(r.body);
        if (d['resultado'] != 1 && d['resultado'] != '1') break;
        final raw = d['movimientos'];
        if (raw is! List) break;
        globalOk = true; // valid response received
        for (final item in raw.whereType<Map>()) {
          globalAll.add(Map<String, dynamic>.from(item));
        }
        if (raw.isEmpty) break;
        totalPaginas = int.tryParse(d['total_paginas']?.toString() ?? '1') ?? 1;
        pagina++;
      } while (pagina <= totalPaginas);

      if (globalOk) {
        movements = globalAll;
        invalidateComputedCache();
        unawaited(repository.saveLocalData('movimientos', movements));
        return;
      }
    } catch (e) {
      debugPrint('[SAF] listar_movimientos_usuario fallback: $e');
    }

    // Fallback: per-account fetch (order may differ from web within same date)
    final all = <Map<String, dynamic>>[];
    const batchSize = 3;
    for (var i = 0; i < accounts.length; i += batchSize) {
      final batch = accounts.skip(i).take(batchSize);
      await Future.wait(batch.map((cuenta) async {
        final codigo = cuenta['codigo']?.toString() ?? '';
        if (codigo.isEmpty) return;
        try {
          final movimientos = await fetchAccountMovements(codigo, usuario,
              desde: dStr, hasta: hStr);
          for (final m in movimientos) {
            final mov = Map<String, dynamic>.from(m);
            mov['codigo_cuenta'] = codigo;
            mov['cuenta_nombre'] = cuenta['nombre'];
            mov['cuenta_color'] = cuenta['color'];
            all.add(mov);
          }
        } catch (e) {
          debugPrint('[SAF] mov cuenta $codigo: $e');
        }
      }));
    }
    all.sort((a, b) {
      final fechaA = (a['fecha'] ?? '').toString();
      final fechaB = (b['fecha'] ?? '').toString();
      final dA = fechaA.length >= 10 ? fechaA.substring(0, 10) : fechaA;
      final dB = fechaB.length >= 10 ? fechaB.substring(0, 10) : fechaB;
      final cmpFecha = dB.compareTo(dA);
      if (cmpFecha != 0) return cmpFecha;
      final idA = int.tryParse(
              (a['codigo_movimiento'] ?? a['codigo'] ?? a['id'] ?? '0')
                  .toString()) ??
          0;
      final idB = int.tryParse(
              (b['codigo_movimiento'] ?? b['codigo'] ?? b['id'] ?? '0')
                  .toString()) ??
          0;
      return idB.compareTo(idA);
    });
    movements = all;
    invalidateComputedCache();
    unawaited(repository.saveLocalData('movimientos', movements));
  }

  Future<List<Map<String, dynamic>>> fetchAccountMovements(
      String codigoCuenta, String usuario,
      {String? desde, String? hasta}) async {
    final resultado = <Map<String, dynamic>>[];
    var pagina = 1;
    var totalPaginas = 1;

    do {
      final body = <String, dynamic>{
        'codigo_cuenta': codigoCuenta,
        'pagina': pagina.toString(),
        'usuario': usuario,
      };
      if (desde != null) body['desde'] = desde;
      if (hasta != null) body['hasta'] = hasta;

      final r = await repository
          .post('/ajax/listar_movimientos_cuenta.php', body)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) break;

      final d = decodeJsonMap(r.body);
      final raw = d['movimientos'] ?? d['datos'] ?? d['data'];
      if (raw is! List || raw.isEmpty) break;

      resultado.addAll(
          raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
      totalPaginas = int.tryParse(d['total_paginas']?.toString() ?? '1') ?? 1;
      pagina++;
    } while (pagina <= totalPaginas);

    if (resultado.isNotEmpty) {
      debugPrint('[SAF] mov cuenta $codigoCuenta sample: ${resultado.first}');
    }
    return resultado;
  }

  Future<void> loadSelectedAccountMovements() async {
    final selectedName = accountFilter;
    if (selectedName.isEmpty) {
      refresh(() {
        selectedAccountMovements = [];
        selectedAccountMovementsName = '';
        selectedAccountMovementsLoading = false;
      });
      return;
    }

    final account = accounts.firstWhere(
      (item) => (item['nombre'] ?? '').toString() == selectedName,
      orElse: () => <String, dynamic>{},
    );
    final accountCode =
        (account['codigo'] ?? account['codigo_cuenta'] ?? '').toString();
    final userCode = (repository.user?['codigo_usuario'] ?? '').toString();
    if (accountCode.isEmpty || userCode.isEmpty) return;

    refresh(() {
      selectedAccountMovements = [];
      selectedAccountMovementsName = selectedName;
      selectedAccountMovementsLoading = true;
    });

    try {
      final rows = await fetchAccountMovements(
        accountCode,
        userCode,
        desde: filterFrom != null ? _dateFmt(filterFrom!) : null,
        hasta: filterTo != null ? _dateFmt(filterTo!) : null,
      );
      final enriched = rows.map((row) {
        return <String, dynamic>{
          ...row,
          'codigo_cuenta': accountCode,
          'cuenta_nombre': selectedName,
          'cuenta_color': account['color'],
        };
      }).toList();
      if (!isMounted || accountFilter != selectedName) return;
      refresh(() {
        selectedAccountMovements = enriched;
        selectedAccountMovementsName = selectedName;
        selectedAccountMovementsLoading = false;
        movementsPage = 1;
      });
    } catch (error) {
      debugPrint('[SAF] movimientos cuenta $accountCode: $error');
      if (!isMounted || accountFilter != selectedName) return;
      refresh(() => selectedAccountMovementsLoading = false);
    }
  }

  String _dateFmt(DateTime d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${p(d.month)}-${p(d.day)}';
  }

  Future<void> onDateFilterChanged() async {
    final usuario = (repository.user?['codigo_usuario'] ?? '').toString();
    if (usuario.isEmpty) return;
    if (isMounted) refresh(() => movementsPage = 1);
    final desde = filterFrom;
    final hasta = filterTo;
    await _fetchMovimientosTodasCuentas(
      usuario,
      desde: desde != null ? _dateFmt(desde) : null,
      hasta: hasta != null ? _dateFmt(hasta) : null,
    );
    if (isMounted) refresh(() {});
    unawaited(fetchFilteredTotals());
  }

  Future<void> fetchFilteredTotals() async {
    final usuario = (repository.user?['codigo_usuario'] ?? '').toString();
    if (usuario.isEmpty) return;
    String pad2(int n) => n.toString().padLeft(2, '0');
    String fmt(DateTime d) => '${d.year}-${pad2(d.month)}-${pad2(d.day)}';
    // Igual que la web: solo condiciona por fecha si el usuario eligió fechas
    String filtro = 'm.usuario="$usuario"';
    if (filterFrom != null && filterTo != null) {
      filtro += ' and m.fecha between "${fmt(filterFrom!)}" and "${fmt(filterTo!)}"';
    } else if (filterFrom != null) {
      filtro += ' and m.fecha >= "${fmt(filterFrom!)}"';
    } else if (filterTo != null) {
      filtro += ' and m.fecha <= "${fmt(filterTo!)}"';
    }
    if (movementTypeFilter.isNotEmpty) {
      // tipo '1' (loan transfers) is also Ingreso, same as '3'
      filtro += movementTypeFilter == '3'
          ? ' and m.tipo_movimiento in (1,3)'
          : ' and m.tipo_movimiento=$movementTypeFilter';
    }
    if (accountFilter.isNotEmpty) {
      final cuenta = accounts.firstWhere(
          (c) => (c['nombre'] ?? '') == accountFilter,
          orElse: () => {});
      final cod = (cuenta['codigo'] ?? '').toString();
      if (cod.isNotEmpty) filtro += ' and m.codigo_cuenta="$cod"';
    }
    try {
      final r = await repository.post('/ajax/listado_json_campos.php', {
        'codigo_consulta': 'json_total_gastos_ingresos',
        'filtro': filtro,
        'agrupacion': '',
      });
      if (r.statusCode == 200) {
        final d = decodeJsonMap(r.body);
        if (d['resultado'] == 1 &&
            d['datos'] is List &&
            (d['datos'] as List).isNotEmpty) {
          final row =
              Map<String, dynamic>.from((d['datos'] as List).first as Map);
          double g = 0.0, ing = 0.0;
          for (final k in row.keys) {
            final kl = k.toString().toLowerCase();
            if (kl.contains('gasto')) g = numberValue(row[k]);
            if (kl.contains('ingreso')) ing = numberValue(row[k]);
          }
          if (isMounted) {
            refresh(() {
              filteredExpenses = g;
              filteredIncome = ing;
              filteredTotalsLoaded = true;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[SAF] fetchTotalesFiltrados: $e');
    }
  }

  Future<void> _fetchTotalesResumen(String usuario) async {
    // Sin rango de fechas: totales históricos, igual que la web.
    // Para acotar por período están los filtros de fecha de Movimientos.
    final filtro = 'm.usuario="$usuario"';
    try {
      final r = await repository.post('/ajax/listado_json_campos.php', {
        'codigo_consulta': 'json_total_gastos_ingresos',
        'filtro': filtro,
        'agrupacion': '',
      });
      if (r.statusCode == 200) {
        final d = decodeJsonMap(r.body);
        if (d['resultado'] == 1 &&
            d['datos'] is List &&
            (d['datos'] as List).isNotEmpty) {
          final row =
              Map<String, dynamic>.from((d['datos'] as List).first as Map);
          double g = 0.0, ing = 0.0;
          for (final k in row.keys) {
            final kl = k.toString().toLowerCase();
            if (kl.contains('gasto')) g = numberValue(row[k]);
            if (kl.contains('ingreso')) ing = numberValue(row[k]);
          }
          if (isMounted) {
            refresh(() {
              serverExpenses = g;
              serverIncome = ing;
              serverTotalsLoaded = true;
              invalidateComputedCache();
            });
          }
          unawaited(repository.saveLocalData('totales', [
            {'gastos': g, 'ingresos': ing},
          ]));
        }
      }
    } catch (e) {
      debugPrint('[SAF] fetchTotales: $e');
    }
  }

  Future<void> _fetchTotalesCreditos({
    String asesorCodigo = '',
    String estado = '',
  }) async {
    final condiciones = <String>[];
    final asesorNum = int.tryParse(asesorCodigo);
    final estadoNum = int.tryParse(estado);
    if (asesorNum != null && asesorNum > 0) {
      condiciones.add('d.codigo_asesor=$asesorNum');
    }
    if (estadoNum != null && estadoNum > 0) {
      condiciones.add('c.codigo_estado=$estadoNum');
    }

    try {
      final r = await repository.post('/ajax/listado_json_campos.php', {
        'codigo_consulta': 'json_total_creditos_valores',
        'filtro': condiciones.join(' AND '),
        'agrupacion': '',
      });
      if (r.statusCode == 200) {
        final d = decodeJsonMap(r.body);
        if (d['resultado'] == 1 &&
            d['datos'] is List &&
            (d['datos'] as List).isNotEmpty) {
          final row =
              Map<String, dynamic>.from((d['datos'] as List).first as Map);
          // Los valores vienen formateados: "$388,207,190" o "$388.207.190"
          double parseFmt(dynamic v) {
            final s = v.toString().replaceAll(RegExp(r'[^\d]'), '');
            return double.tryParse(s) ?? 0.0;
          }

          final pagado = parseFmt(row['pagado'] ?? row['total_pagado'] ?? 0);
          final pendiente =
              parseFmt(row['pendiente'] ?? row['total_pendiente'] ?? 0);
          if (isMounted) {
            refresh(() {
              creditsPaidTotal = pagado;
              creditsPendingTotal = pendiente;
              creditsDataLoaded = true;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('[SAF] fetchTotalesCreditos: $e');
    }
    // Fallback: marcar como cargado aunque no haya datos, para no quedar en skeleton
    if (isMounted) refresh(() => creditsDataLoaded = true);
  }

  Future<void> fetchSavers([String? anio, String? asesor]) async {
    try {
      final previousSavers = List<Map<String, dynamic>>.from(savers);
      final now =
          DateTime.now().toUtc().subtract(const Duration(hours: 5));
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final r = await repository.cachedPost('/ajax/listado_ahorros.php', {
        'anio_ahorro': anio ?? savingsYearFilter,
        // La pantalla filtra por sigla localmente. Para no reemplazar la
        // colección completa con un solo asesor, las recargas normales traen
        // todos los registros del año.
        'filtro_asesor': isAsesor
            ? codigoOrigen
            : (asesor == null ? '0' : creditAdvisorCode(asesor)),
      });
      final loadedSavers = <Map<String, dynamic>>[];
      if (r.statusCode == 200) {
        final d = decodeJsonMap(r.body);
        final list = d['ahorradores'];
        if (list is List) {
          loadedSavers.addAll(list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList());
        }
      }

      // listado_ahorros.php solo incluye personas con un ahorro asociado.
      // Fusionamos el catálogo para mostrar también los recién registrados.
      final catalogResponse =
          await repository.cachedPost('/ajax/listado_select.php', {
        'tabla': 'tbl_ahorradores',
        'valor': 'codigo',
        'etiqueta':
            'concat(nombres,CHAR(124),apellidos,CHAR(124),codigo_asesor)',
        'filtro': '1',
        'campos_orden': 'nombres,apellidos',
      });
      if (catalogResponse.statusCode == 200) {
        final rawCatalog = jsonDecode(catalogResponse.body);
        if (rawCatalog is List) {
          for (final raw in rawCatalog.whereType<Map>()) {
            final item = Map<String, dynamic>.from(raw);
            final codigo = (item['codigo'] ??
                    (item.values.isNotEmpty ? item.values.first : ''))
                .toString()
                .trim();
            final encoded =
                (item.values.isNotEmpty ? item.values.last : '').toString();
            final parts = encoded.split('|');
            final nombre = parts.take(2).join(' ').trim().toUpperCase();
            final codigoAsesor =
                parts.length > 2 ? parts[2].trim() : '';
            Map<String, dynamic>? previous;
            for (final saver in previousSavers) {
              if ((saver['codigo_ahorrador'] ?? '').toString() == codigo ||
                  (saver['ahorrador'] ?? '')
                          .toString()
                          .trim()
                          .toUpperCase() ==
                      nombre) {
                previous = saver;
                break;
              }
            }
            final loadedIndex = loadedSavers.indexWhere((saver) =>
                (saver['codigo_ahorrador'] ?? '').toString() == codigo ||
                (saver['ahorrador'] ?? '')
                        .toString()
                        .trim()
                        .toUpperCase() ==
                    nombre);
            if (loadedIndex >= 0) {
              loadedSavers[loadedIndex]['codigo_ahorrador'] = codigo;
              loadedSavers[loadedIndex]['codigo_asesor'] = codigoAsesor;
              if ((loadedSavers[loadedIndex]['asesor'] ?? '')
                  .toString()
                  .trim()
                  .isEmpty) {
                loadedSavers[loadedIndex]['asesor'] =
                    creditAdvisorInitials(codigoAsesor);
              }
            } else if (nombre.isNotEmpty) {
              final previousDate = (previous?['Fecha_ingreso'] ??
                      previous?['fecha_ingreso'] ??
                      '')
                  .toString();
              final parsedPreviousDate = DateTime.tryParse(previousDate);
              final validPreviousDate = parsedPreviousDate != null &&
                  !DateTime(
                    parsedPreviousDate.year,
                    parsedPreviousDate.month,
                    parsedPreviousDate.day,
                  ).isAfter(DateTime(now.year, now.month, now.day));
              loadedSavers.add({
                'codigo_ahorrador': codigo,
                'ahorrador': nombre,
                'asesor': creditAdvisorInitials(codigoAsesor),
                'total_ahorrado': 0,
                'Valor_pactado': 0,
                'neto_pagar': 0,
                'Fecha_ingreso': validPreviousDate ? previousDate : today,
                'ahorros': <dynamic>[],
                'sin_ahorro': true,
              });
            }
          }
        }
      }

      savers = loadedSavers;
      cachedFilteredSavers = null;
      unawaited(repository.saveLocalData('ahorradores', savers));
    } catch (e) {
      debugPrint('[SAF] ahorradores: $e');
    }
  }

  Future<void> reloadSavers() async {
    refresh(() => loadingData = true);
    await fetchSavers();
    refresh(() => loadingData = false);
  }

  Future<void> fetchCredits(String filtro) async {
    final estadoSeleccionado = creditStatusFilter;
    // No-admin: siempre filtra por su propio codigo_origen (ID de asesor)
    final asesorCodigo = isAdmin
        ? creditAdvisorCode(creditAdvisorFilter)
        : codigoOrigen;

    // Lista de créditos — endpoint dedicado con JSON + paginación
    try {
      final r = await repository.post('/ajax/get_creditos_lista.php', {
        'estado': estadoSeleccionado,
        // La web conserva la sigla (JP, VB, etc.), mientras este endpoint
        // dedicado filtra por codigo_asesor numérico.
        'asesor': asesorCodigo,
        'pagina': creditsPage.toString(),
        'por_pagina': creditsPageSize.toString(),
        if (creditsBuscar.isNotEmpty) 'buscar': creditsBuscar,
      });
      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        if (decoded is Map && decoded['datos'] is List) {
          creditsTotal = int.tryParse(decoded['total']?.toString() ?? '0') ?? 0;
          credits = (decoded['datos'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          unawaited(repository.saveLocalData('creditos_lista', credits));
        }
      }
    } catch (e) {
      debugPrint('[SAF] creditos lista: $e');
    }

    // La cabecera de la web usa json_total_creditos_valores. El cálculo
    // incluido en get_creditos_lista.php puede diferir por ajustes de cuotas,
    // por lo que nunca debe sobrescribir estos totales oficiales.
    await _fetchTotalesCreditos(
      asesorCodigo: asesorCodigo,
      estado: estadoSeleccionado,
    );

    // Estadística por fuente — endpoint dedicado con campos fijos
    try {
      final r = await repository.cachedPost(
          '/ajax/get_estadistica_fuente.php', {},
          ttl: const Duration(minutes: 10));
      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        if (decoded is List && decoded.isNotEmpty) {
          creditStatistics = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          unawaited(repository.saveLocalData('creditos', creditStatistics));
          return;
        }
      }
      debugPrint(
          '[SAF] get_estadistica_fuente status=${r.statusCode} body=${r.body.substring(0, r.body.length.clamp(0, 300))}');
    } catch (e) {
      debugPrint('[SAF] estadistica fuente: $e');
    }

    // Fallback 1: calcular desde credits ya cargada
    final local = _buildEstadisticaFromLocal();
    if (local.isNotEmpty) {
      creditStatistics = local;
      return;
    }

    // Fallback 2: query original json_total_creditos_valores (campos variables pero nunca vacío)
    try {
      final r = await repository.cachedPost('/ajax/listado_json_campos.php',
          {'codigo_consulta': 'json_total_creditos_valores', 'filtro': filtro});
      if (r.statusCode == 200) {
        final d = decodeJsonMap(r.body);
        final list = d['datos'];
        if (list is List && list.isNotEmpty) {
          final raw = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          debugPrint(
              '[SAF] json_total_creditos_valores keys: ${raw.first.keys.toList()}');
          debugPrint('[SAF] json_total_creditos_valores first: ${raw.first}');
          creditStatistics = raw;
          unawaited(repository.saveLocalData('creditos', creditStatistics));
        }
      }
    } catch (e) {
      debugPrint('[SAF] creditos stat fallback: $e');
    }
  }

  /// Llama get_estadistica_fuente.php con los filtros activos y actualiza creditStatistics.
  Future<void> applyStatisticsFilters() async {
    if (!isMounted) return;
    refresh(() => sourceStatisticsLoading = true);
    String fmt(DateTime? d) => d == null
        ? ''
        : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    try {
      repository.invalidateCache('/ajax/get_estadistica_fuente.php');
      final r = await repository.post('/ajax/get_estadistica_fuente.php', {
        'estado': sourceStatisticsStatus,
        'fecha_desde': fmt(sourceStatisticsFrom),
        'fecha_hasta': fmt(sourceStatisticsTo),
        'fuente': sourceStatisticsAccount,
      }).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        if (decoded is List && isMounted) {
          refresh(() {
            creditStatistics = decoded
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            sourceStatisticsLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('[SAF] aplicarFiltros: $e');
    }
    if (isMounted) refresh(() => sourceStatisticsLoading = false);
  }

  /// Agrega credits por fuente para obtener salidas. Entradas = 0 (sin data de pagos).
  List<Map<String, dynamic>> _buildEstadisticaFromLocal() {
    if (credits.isEmpty) return [];
    const fuenteKeys = [
      'fuente',
      'nombre_fuente',
      'cuenta',
      'nombre_cuenta',
      'origen',
      'nombre_origen',
      'nombre',
      'fuente_nombre',
    ];
    const valorKeys = [
      'monto',
      'valor_prestamo',
      'valor_credito',
      'valor',
      'prestado',
      'total'
    ];
    final first = credits.first;
    final allKeys = first.keys.toList();
    debugPrint('[SAF] creditosLista keys: $allKeys  first: $first');

    final fk =
        fuenteKeys.firstWhere((k) => allKeys.contains(k), orElse: () => '');
    // Intenta campo de valor conocido; si no, usa el primero con valor numérico > 0
    var vk = valorKeys.firstWhere((k) => allKeys.contains(k), orElse: () => '');
    if (vk.isEmpty) {
      vk = allKeys.firstWhere((k) => numberValue(first[k]) > 0,
          orElse: () => '');
    }
    if (vk.isEmpty) return [];

    final mapa = <String, double>{};
    for (final c in credits) {
      final fuente = fk.isNotEmpty
          ? (c[fk] ?? 'Sin fuente').toString().trim()
          : 'Sin fuente';
      mapa[fuente] = (mapa[fuente] ?? 0) + numberValue(c[vk]);
    }
    final result = mapa.entries
        .map((e) =>
            {'fuente': e.key, 'total_salidas': e.value, 'total_entradas': 0.0})
        .toList();
    result.sort((a, b) =>
        (b['total_salidas'] as double).compareTo(a['total_salidas'] as double));
    debugPrint(
        '[SAF] fallback estadistica: ${result.length} fuentes, total=${result.fold(0.0, (s, r) => s + (r["total_salidas"] as double))}');
    return result;
  }

  // Carga la estadística de la sub-pestaña activa.
  Future<void> fetchStatistics() async {
    final codigo = statisticsTabs[statisticsSubTab].$2;
    refresh(() {
      statisticsLoading = true;
      statisticsData = [];
    });
    try {
      final r = await repository.cachedPost('/ajax/listado_json_campos.php',
          {'codigo_consulta': codigo, 'filtro': '', 'agrupacion': ''},
          ttl: const Duration(minutes: 10));
      if (r.statusCode == 200) {
        final d = decodeJsonMap(r.body);
        final list = d['datos'] ?? d['resultado_datos'] ?? d['data'];
        if (list is List) {
          statisticsData = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[SAF] estadistica: $e');
    } finally {
      if (isMounted) refresh(() => statisticsLoading = false);
    }
  }

  // Construye debtors desde datos ya en memoria (sin red).
  void tryBuildDebtorsFromLocal() {
    if (debtors.isNotEmpty) return;

    // Campos de nombre conocidos, en orden de preferencia
    const nameKeys = [
      'cliente',
      'deudor',
      'etiqueta',
      'nombre_deudor',
      'deudor_nombre',
      'nombre_completo',
      'fullname',
      'nombre',
      'nombres',
    ];
    // Valores que claramente NO son nombres de persona
    final notName = RegExp(
        r'^(activ|pagad|pendient|inactiv|mensual|quincenal|semanal|diario|fijo|variable|\d)',
        caseSensitive: false);

    String extractName(Map<String, dynamic> c) {
      // 1. Campos conocidos
      for (final k in nameKeys) {
        final v = c[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      // 2. Nombres + apellidos concatenados
      final n =
          '${c['nombres'] ?? c['nombre'] ?? ''} ${c['apellidos'] ?? c['apellido'] ?? ''}'
              .trim();
      if (n.isNotEmpty) return n;
      // 3. Escanear todos los strings: buscar el más largo que parezca nombre
      String best = '';
      for (final v in c.values) {
        if (v is! String) continue;
        final s = v.trim();
        if (s.length > best.length &&
            s.contains(' ') &&
            s.length > 5 &&
            !notName.hasMatch(s) &&
            !s.contains('<') &&
            !s.contains('/')) {
          best = s;
        }
      }
      return best;
    }

    for (final source in [credits, savers]) {
      if (source.isEmpty) continue;
      final seen = <String>{};
      final lista = <Map<String, dynamic>>[];
      for (final c in source) {
        final label = extractName(c);
        final id = (c['valor'] ??
                c['codigo_deudor'] ??
                c['id_deudor'] ??
                c['codigo'] ??
                c['id'] ??
                label)
            .toString();
        if (label.isNotEmpty && seen.add(id)) {
          lista.add({'valor': id, 'etiqueta': label});
        }
      }
      if (lista.isNotEmpty) {
        lista.sort((a, b) =>
            a['etiqueta'].toString().compareTo(b['etiqueta'].toString()));
        debtors = lista;
        debugPrint(
            '[SAF] deudores desde local: ${lista.length} — primer item: ${lista.first}');
        return;
      }
    }
    debugPrint(
        '[SAF] tryBuildDebtorsFromLocal: creditosLista=${credits.length}, ahorradores=${savers.length}');
    if (credits.isNotEmpty) {
      debugPrint('[SAF] creditosLista[0] keys: ${credits.first.keys.toList()}');
    }
  }

  Future<void> fetchDebtors() async {
    try {
      final r = await repository
          .cachedPost('/ajax/get_deudores.php', {},
              ttl: const Duration(minutes: 10))
          .timeout(const Duration(seconds: 8));

      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        List<dynamic>? list;
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map) {
          for (final k in [
            'datos',
            'data',
            'resultado',
            'resultado_datos',
            'items',
            'deudores'
          ]) {
            if (decoded[k] is List) {
              list = decoded[k] as List;
              break;
            }
          }
        }
        if (list != null && list.isNotEmpty) {
          debtors = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          return;
        }
      }
      debugPrint(
          '[SAF] get_deudores.php status=${r.statusCode} body=${r.body.substring(0, r.body.length.clamp(0, 200))}');
    } catch (e) {
      debugPrint('[SAF] deudores fetch: $e');
    }

    // Fallback: extraer desde creditosLista (campo real: 'cliente')
    if (debtors.isEmpty && credits.isNotEmpty) {
      final seen = <String>{};
      final lista = <Map<String, dynamic>>[];
      for (final c in credits) {
        final label = [
              c['cliente'],
              c['nombre_deudor'],
              c['deudor_nombre'],
              c['nombre_completo'],
              c['deudor'],
              c['nombre'],
              c['nombres']
            ]
                .firstWhere((v) => v != null && v.toString().trim().isNotEmpty,
                    orElse: () => null)
                ?.toString()
                .trim() ??
            '';
        final id = (c['codigo_deudor'] ??
                c['id_deudor'] ??
                c['codigo'] ??
                c['id'] ??
                label)
            .toString();
        if (label.isNotEmpty && seen.add(id)) {
          lista.add({'valor': id, 'etiqueta': label});
        }
      }
      if (lista.isNotEmpty) {
        lista.sort((a, b) =>
            a['etiqueta'].toString().compareTo(b['etiqueta'].toString()));
        debtors = lista;
      }
    }
  }

  Future<void> fetchRates() async {
    try {
      final r = await repository.cachedPost('/ajax/listado_json_campos.php',
          {'codigo_consulta': 'json_tasas', 'filtro': '', 'agrupacion': ''},
          ttl: const Duration(hours: 1));
      if (r.statusCode == 200) {
        final d = decodeJsonMap(r.body);
        final list = d['datos'] ?? d['data'] ?? d['tasas'];
        if (list is List) {
          rates = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[SAF] tasas: $e');
    }
  }

  Future<void> fetchSources() async {
    try {
      final r = await repository.cachedPost('/ajax/listado_json_campos.php',
          {'codigo_consulta': 'json_fuentes', 'filtro': '', 'agrupacion': ''},
          ttl: const Duration(hours: 1));
      if (r.statusCode == 200) {
        List? list;
        try {
          final raw = jsonDecode(r.body);
          if (raw is List) {
            list = raw;
          } else if (raw is Map) {
            final d = Map<String, dynamic>.from(raw);
            list = d['datos'] ?? d['data'] ?? d['fuentes'] ??
                d.values.whereType<List>().firstOrNull;
          }
        } catch (_) {}
        if (list != null && list.isNotEmpty) {
          sources = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[SAF] fuentes: $e');
    }
  }

  Future<void> fetchPending() async {
    if (pendingLoading) return;
    if (isMounted) refresh(() => pendingLoading = true);
    Map<String, dynamic>? payload;
    Object? lastError;
    try {
      for (var intento = 1; intento <= 3; intento++) {
        try {
          final r = await repository.post('/ajax/get_pendientes_lista.php', {
            // Pendientes tiene su propio listado. No debe heredar los
            // filtros invisibles de la pestaña Aprobados.
            'asesor': '',
            'estado': '',
            'pagina': pendingPage.toString(),
            'por_pagina': creditsPageSize.toString(),
          }).timeout(const Duration(seconds: 12));
          if (r.statusCode != 200) {
            throw Exception('Servidor respondió ${r.statusCode}');
          }
          final decoded = jsonDecode(r.body);
          if (decoded is! Map || decoded['datos'] is! List) {
            throw const FormatException('Respuesta de pendientes no válida');
          }
          payload = Map<String, dynamic>.from(decoded);
          break;
        } catch (e) {
          lastError = e;
          if (intento < 3) {
            await Future<void>.delayed(Duration(milliseconds: 350 * intento));
          }
        }
      }
      if (payload == null) throw lastError ?? Exception('No hubo respuesta');

      final datos = payload['datos'] as List;
      if (isMounted) {
        refresh(() {
          pendingTotal =
              int.tryParse(payload!['total']?.toString() ?? '0') ?? 0;
          pendingRequests = datos
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          pendingLoaded = true;
          pendingError = null;
        });
      }
    } catch (e) {
      debugPrint('[SAF] pendientes lista: $e');
      if (isMounted) {
        refresh(() {
          pendingError =
              'No fue posible cargar las solicitudes. Intenta nuevamente.';
        });
      }
    } finally {
      if (isMounted) refresh(() => pendingLoading = false);
    }
  }

  /// Lee la preferencia de tema del servidor (compartida con SAF-WEB) y la
  /// aplica. Silencioso: si no hay red o el endpoint no existe, se conserva
  /// la copia local (SharedPreferences).
  Future<void> syncThemeFromServer() async {
    final usuario = (repository.user?['codigo_usuario'] ?? '').toString();
    if (usuario.isEmpty) return;
    try {
      final r = await repository.post('/ajax/preferencia_tema.php', {
        'accion': 'get',
        'usuario': usuario,
      }).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return;
      final d = decodeJsonMap(r.body);
      if (d['success'] != true) return;
      final dark = d['tema_oscuro'] == 1 || d['tema_oscuro'] == '1';
      if (dark != isDarkTheme) {
        await setThemeDark(dark);
        if (isMounted) refresh(() {});
      }
    } catch (e) {
      debugPrint('[SAF] preferencia tema: $e');
    }
  }

  /// Guarda la preferencia en el servidor para que la web la cargue igual.
  Future<void> saveThemeToServer(bool dark) async {
    final usuario = (repository.user?['codigo_usuario'] ?? '').toString();
    if (usuario.isEmpty) return;
    try {
      await repository.post('/ajax/preferencia_tema.php', {
        'accion': 'set',
        'usuario': usuario,
        'tema_oscuro': dark ? '1' : '0',
      }).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[SAF] guardar tema: $e');
    }
  }

  Future<void> fetchAdvisors() async {
    try {
      final r = await repository.cachedPost('/ajax/get_asesores.php', {},
          ttl: const Duration(hours: 1));
      if (r.statusCode == 200) {
        final decoded = jsonDecode(r.body);
        if (decoded is List && decoded.isNotEmpty) {
          advisors = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          // Invalida el cache del filtro de ahorradores para que el fallback
          // por sigla pueda aplicarse ahora que advisors ya está disponible
          if (isAsesor) cachedFilteredSavers = null;
        }
      }
    } catch (e) {
      debugPrint('[SAF] asesores: $e');
    }
  }
}
