// ignore_for_file: use_build_context_synchronously

import '../../controllers/home_actions.dart';
import '../../controllers/home_data_controller.dart';
import '../../widgets/home/home_dialogs.dart';
import 'package:pdf/widgets.dart' as pw;
import 'credits_screen.dart';
import 'home_dependencies.dart';
import 'movements_screen.dart';

extension HomeSavingsScreen<T extends StatefulWidget> on HomeController<T> {
  Future<void> _showConfigurarAhorroDialog() async {
    final formKey = GlobalKey<FormState>();
    final anioCtrl =
        TextEditingController(text: DateTime.now().year.toString());
    final tiempoCtrl = TextEditingController();
    DateTime? fechaInicio;
    DateTime? fechaFinal;
    String? selectedTipo;
    bool saving = false;

    final tipos = ['Fijo', 'Variable'];

    String fmtDisplay(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    String fmtApi(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    await showDialog(
      context: screenContext,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: min(480, MediaQuery.of(ctx).size.width - 40),
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D1B4B), Color(0xFF1E3A8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.settings_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Configurar Ahorro',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)),
                            Text('Nuevo período de ahorro',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: saving ? null : () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white60, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // Campos
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Año
                          buildSavingsField(
                            ctrl: anioCtrl,
                            label: 'Año',
                            icon: Icons.calendar_today_outlined,
                            keyboard: TextInputType.number,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Ingrese el año'
                                : null,
                          ),
                          const SizedBox(height: 14),

                          // Fecha Inicio
                          buildSavingsFieldLabel('Fecha Inicio'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final d = await showLightDatePicker(
                                ctx,
                                initialDate: fechaInicio ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (d != null) setS(() => fechaInicio = d);
                            },
                            child: buildDateContainer(
                                fechaInicio != null
                                    ? fmtDisplay(fechaInicio!)
                                    : null,
                                'dd/mm/aaaa'),
                          ),
                          const SizedBox(height: 14),

                          // Fecha Final
                          buildSavingsFieldLabel('Fecha Final'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final d = await showLightDatePicker(
                                ctx,
                                initialDate:
                                    fechaFinal ?? fechaInicio ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (d != null) setS(() => fechaFinal = d);
                            },
                            child: buildDateContainer(
                                fechaFinal != null
                                    ? fmtDisplay(fechaFinal!)
                                    : null,
                                'dd/mm/aaaa'),
                          ),
                          const SizedBox(height: 14),

                          // Tiempo en Mes
                          buildSavingsField(
                            ctrl: tiempoCtrl,
                            label: 'Tiempo en Mes',
                            icon: Icons.timelapse_rounded,
                            keyboard: TextInputType.number,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Ingrese el tiempo en meses'
                                : null,
                          ),
                          const SizedBox(height: 14),

                          // Tipo
                          buildSavingsFieldLabel('Tipo'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDialog<String>(
                                context: ctx,
                                builder: (dCtx) => SimpleDialog(
                                  backgroundColor: Colors.white,
                                  title: const Text('Seleccionar Tipo',
                                      style: TextStyle(
                                          color: homeNavy,
                                          fontWeight: FontWeight.w700)),
                                  children: tipos
                                      .map((t) => SimpleDialogOption(
                                            onPressed: () =>
                                                Navigator.pop(dCtx, t),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 4),
                                              child: Text(t,
                                                  style: const TextStyle(
                                                      color: homeNavy,
                                                      fontSize: 14)),
                                            ),
                                          ))
                                      .toList(),
                                ),
                              );
                              if (picked != null) {
                                setS(() => selectedTipo = picked);
                              }
                            },
                            child: Container(
                              height: 48,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F7FB),
                                border: Border.all(
                                  color: selectedTipo != null
                                      ? homeAccent.withValues(alpha: 0.6)
                                      : const Color(0xFFDDE3EF),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(children: [
                                Icon(Icons.category_outlined,
                                    size: 18,
                                    color: selectedTipo != null
                                        ? homeAccent
                                        : const Color(0xFF9CA3AF)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    selectedTipo ?? '[Seleccione una Opción]',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: selectedTipo != null
                                          ? homeNavy
                                          : const Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                                const Icon(Icons.expand_more_rounded,
                                    color: Color(0xFF9CA3AF), size: 20),
                              ]),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),

                // Botones
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: saving ? null : () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF8899BB),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFFDDE3EF)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cerrar',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: saving
                                ? null
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFF0D1B4B),
                                      Color(0xFF1E3A8A)
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                            color: saving ? const Color(0xFFCBD5E1) : null,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: saving
                                ? null
                                : [
                                    BoxShadow(
                                      color: homeNavy.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: saving
                                ? null
                                : () async {
                                    if (fechaInicio == null) {
                                      showResult(false,
                                          'Seleccione la fecha de inicio');
                                      return;
                                    }
                                    if (fechaFinal == null) {
                                      showResult(
                                          false, 'Seleccione la fecha final');
                                      return;
                                    }
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    if (selectedTipo == null) {
                                      showResult(false,
                                          'Seleccione el tipo de configuración');
                                      return;
                                    }
                                    setS(() => saving = true);
                                    try {
                                      final r = await repository.post(
                                        '/ajax/registrar_conf_cuota.php',
                                        {
                                          'anio': anioCtrl.text.trim(),
                                          'fecha_inicio': fmtApi(fechaInicio!),
                                          'fecha_final': fmtApi(fechaFinal!),
                                          'tiempo_mes': tiempoCtrl.text.trim(),
                                          'tipo': selectedTipo ?? '',
                                        },
                                      );
                                      final body = r.body.trim();
                                      final ok = r.statusCode == 200 &&
                                          body.contains(
                                              'Configuración Registrada');
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      if (isMounted) {
                                        showDialog(
                                          context: screenContext,
                                          builder: (_) => buildResultDialog(
                                            ok
                                                ? 'Configuración registrada exitosamente'
                                                : body.isNotEmpty
                                                    ? body
                                                    : 'No se pudo registrar',
                                            ok,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        setS(() => saving = false);
                                      }
                                      showResult(false, friendlyError(e));
                                    }
                                  },
                            icon: saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save_rounded, size: 18),
                            label: Text(saving ? 'Guardando...' : 'Grabar'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );

    Future.delayed(const Duration(milliseconds: 400), () {
      anioCtrl.dispose();
      tiempoCtrl.dispose();
    });
  }

  Widget buildDateContainer(String? value, String hint) => Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FB),
          border: Border.all(
            color: value != null
                ? homeAccent.withValues(alpha: 0.6)
                : const Color(0xFFDDE3EF),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined,
                size: 18,
                color: value != null ? homeAccent : const Color(0xFF9CA3AF)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value ?? hint,
                style: TextStyle(
                  fontSize: 14,
                  color: value != null ? homeNavy : const Color(0xFF6B7280),
                ),
              ),
            ),
            const Icon(Icons.expand_more_rounded,
                color: Color(0xFF9CA3AF), size: 20),
          ],
        ),
      );

  // ── Diálogo Crear Ahorro ─────────────────────────────────────────
  Future<void> _showCrearAhorroDialog() async {
    final formKey = GlobalKey<FormState>();
    String? selectedAhorrador;
    String ahorradorLabel = '';
    String? selectedAnioCodigo;
    DateTime? fechaIngreso;
    final valorCtrl = TextEditingController();
    bool saving = false;
    bool aniosLoaded = false;
    bool loadingAnios = false;
    List<Map<String, dynamic>> aniosOpts = [];

    // Usar debtors ya en memoria (construida desde savers)
    tryBuildDebtorsFromLocal();
    final ahorradorOpts = List<Map<String, dynamic>>.from(debtors);

    Future<void> loadAnios(StateSetter setS) async {
      setS(() => loadingAnios = true);
      try {
        // Carga años desde tbl_ahorro_anyos
        // CHAR(124) = '|' evita comillas en SQL (compatibilidad con magic_quotes)
        final r = await repository.post('/ajax/listado_select.php', {
          'tabla': 'tbl_ahorro_anyos',
          'valor': 'codigo_ahorro_anyo',
          'etiqueta': 'concat(fecha_inicio,CHAR(124),fecha_fin)',
          'filtro': '1',
          'campos_orden': 'fecha_fin DESC',
        });
        if (r.statusCode == 200) {
          final raw = jsonDecode(r.body);
          if (raw is List) {
            aniosOpts = raw.whereType<Map>().map((e) {
              final m = Map<String, dynamic>.from(e);
              final raw2 = m.values.last.toString(); // "2025-11-05|2026-10-05"
              final parts = raw2.split('|');
              final year = parts.length == 2 && parts[1].length >= 4
                  ? parts[1].substring(0, 4)
                  : raw2;
              m['_label'] = parts.length == 2
                  ? '$year (${parts[0]} hasta ${parts[1]})'
                  : raw2;
              return m;
            }).toList();
          }
        }
      } catch (e, st) {
        debugPrint('[SAF] loadAnios ERROR: $e\n$st');
      }
      setS(() {
        loadingAnios = false;
        aniosLoaded = true;
      });
    }

    await showDialog(
      context: screenContext,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        if (!aniosLoaded && !loadingAnios) loadAnios(setS);
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: min(480, MediaQuery.of(ctx).size.width - 40),
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ───────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D1B4B), Color(0xFF1E3A8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.savings_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Crear Ahorro',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                )),
                            Text('Registrar nuevo ahorro',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: saving ? null : () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white60, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // ── Campos ───────────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ahorrador — buscable
                          buildSavingsFieldLabel('Ahorrador'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final result = await _showAhorradorPicker(
                                  ctx, ahorradorOpts);
                              if (result != null) {
                                setS(() {
                                  selectedAhorrador = result['valor'];
                                  ahorradorLabel = result['nombre'];
                                });
                              }
                            },
                            child: Container(
                              height: 48,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F7FB),
                                border: Border.all(
                                  color: selectedAhorrador != null
                                      ? homeAccent.withValues(alpha: 0.6)
                                      : const Color(0xFFDDE3EF),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.person_search_rounded,
                                      size: 18,
                                      color: selectedAhorrador != null
                                          ? homeAccent
                                          : const Color(0xFF9CA3AF)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      ahorradorLabel.isNotEmpty
                                          ? ahorradorLabel
                                          : 'Seleccione un ahorrador...',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: ahorradorLabel.isNotEmpty
                                            ? homeNavy
                                            : const Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.keyboard_arrow_down_rounded,
                                      color: Color(0xFF9CA3AF), size: 20),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Año de Ahorro
                          buildSavingsFieldLabel('Año de Ahorro'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: loadingAnios || aniosOpts.isEmpty
                                ? null
                                : () async {
                                    final result =
                                        await _showAnioPicker(ctx, aniosOpts);
                                    if (result != null) {
                                      setS(() => selectedAnioCodigo =
                                          result['codigo']);
                                    }
                                  },
                            child: Container(
                              height: 48,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F7FB),
                                border: Border.all(
                                  color: selectedAnioCodigo != null
                                      ? homeAccent.withValues(alpha: 0.6)
                                      : const Color(0xFFDDE3EF),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined,
                                      size: 18,
                                      color: selectedAnioCodigo != null
                                          ? homeAccent
                                          : const Color(0xFF9CA3AF)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: loadingAnios
                                        ? const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color:
                                                            Color(0xFF9CA3AF)),
                                              ),
                                              SizedBox(width: 8),
                                              Text('Cargando...',
                                                  style: TextStyle(
                                                      color: Color(0xFF9CA3AF),
                                                      fontSize: 13)),
                                            ],
                                          )
                                        : Builder(builder: (_) {
                                            String label =
                                                'Seleccione un año...';
                                            if (selectedAnioCodigo != null) {
                                              final m = aniosOpts.firstWhere(
                                                (a) =>
                                                    (a['codigo_ahorro_anyo'] ??
                                                            a.values.first)
                                                        .toString() ==
                                                    selectedAnioCodigo,
                                                orElse: () =>
                                                    <String, dynamic>{},
                                              );
                                              label = m['_label']?.toString() ??
                                                  selectedAnioCodigo!;
                                            }
                                            return Text(
                                              label,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: selectedAnioCodigo !=
                                                        null
                                                    ? homeNavy
                                                    : const Color(0xFF6B7280),
                                              ),
                                            );
                                          }),
                                  ),
                                  const Icon(Icons.keyboard_arrow_down_rounded,
                                      color: Color(0xFF9CA3AF), size: 20),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Fecha de Ingreso
                          buildSavingsFieldLabel('Fecha de Ingreso'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final d = await showLightDatePicker(
                                ctx,
                                initialDate: fechaIngreso ?? DateTime.now(),
                                firstDate: DateTime(2015),
                                lastDate: DateTime(2035),
                              );
                              if (d != null) setS(() => fechaIngreso = d);
                            },
                            child: Container(
                              height: 48,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F7FB),
                                border: Border.all(
                                  color: fechaIngreso != null
                                      ? homeAccent.withValues(alpha: 0.6)
                                      : const Color(0xFFDDE3EF),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_month_outlined,
                                      size: 18,
                                      color: fechaIngreso != null
                                          ? homeAccent
                                          : const Color(0xFF9CA3AF)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      fechaIngreso != null
                                          ? '${fechaIngreso!.day.toString().padLeft(2, '0')}/${fechaIngreso!.month.toString().padLeft(2, '0')}/${fechaIngreso!.year}'
                                          : 'dd/mm/aaaa',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: fechaIngreso != null
                                            ? homeNavy
                                            : const Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.expand_more_rounded,
                                      color: Color(0xFF9CA3AF), size: 20),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Valor Pactado
                          buildSavingsField(
                            ctrl: valorCtrl,
                            label: 'Valor Pactado',
                            icon: Icons.attach_money_rounded,
                            keyboard: TextInputType.number,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Botones ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: saving ? null : () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF8899BB),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFFDDE3EF)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cerrar',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: saving
                                ? null
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFF0D1B4B),
                                      Color(0xFF1E3A8A)
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                            color: saving ? const Color(0xFFCBD5E1) : null,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: saving
                                ? null
                                : [
                                    BoxShadow(
                                      color: homeNavy.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: saving
                                ? null
                                : () async {
                                    if (selectedAhorrador == null) {
                                      showResult(false,
                                          'Seleccione un ahorrador para continuar');
                                      return;
                                    }
                                    if (fechaIngreso == null) {
                                      showResult(false,
                                          'Seleccione la fecha de ingreso');
                                      return;
                                    }
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    setS(() => saving = true);
                                    try {
                                      final fechaStr =
                                          '${fechaIngreso!.year}-${fechaIngreso!.month.toString().padLeft(2, '0')}-${fechaIngreso!.day.toString().padLeft(2, '0')}';
                                      final r = await repository.post(
                                        '/ajax/registrar_ahorro.php',
                                        {
                                          'codigo_ahorrador':
                                              selectedAhorrador!,
                                          'codigo_anio_ahorro':
                                              selectedAnioCodigo ?? '',
                                          'fecha_ingreso': fechaStr,
                                          'valor_pactado':
                                              valorCtrl.text.trim(),
                                        },
                                      );
                                      final ok = r.statusCode == 200 &&
                                          (r.body
                                                  .toLowerCase()
                                                  .contains('exitoso') ||
                                              r.body
                                                  .toLowerCase()
                                                  .contains('registrado') ||
                                              r.body
                                                  .toLowerCase()
                                                  .contains('creado') ||
                                              r.body
                                                  .contains('"resultado":1') ||
                                              r.body
                                                  .contains('"success":true'));
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      if (isMounted) {
                                        showDialog(
                                          context: screenContext,
                                          builder: (_) => buildResultDialog(
                                            ok
                                                ? 'Ahorro registrado exitosamente'
                                                : r.body.trim().isNotEmpty
                                                    ? r.body.trim()
                                                    : 'No se pudo registrar',
                                            ok,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        setS(() => saving = false);
                                      }
                                      showResult(false, friendlyError(e));
                                    }
                                  },
                            icon: saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save_rounded, size: 18),
                            label: Text(saving ? 'Guardando...' : 'Grabar'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );

    Future.delayed(const Duration(milliseconds: 400), valorCtrl.dispose);
  }

  Future<Map<String, dynamic>?> _showAnioPicker(
      BuildContext ctx, List<Map<String, dynamic>> lista) {
    return showDialog<Map<String, dynamic>>(
      context: ctx,
      builder: (aCtx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 120),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
              decoration: const BoxDecoration(
                color: homeNavy,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Año de Ahorro',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(aCtx),
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white60, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            ...lista.map((a) {
              final codigo =
                  (a['codigo_ahorro_anyo'] ?? a.values.first).toString();
              final label = a['_label']?.toString() ?? codigo;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () =>
                      Navigator.pop(aCtx, {'codigo': codigo, 'label': label}),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.event_available_rounded,
                            color: homeAccent, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(label,
                              style: const TextStyle(
                                  color: homeNavy,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: Color(0xFFCBD5E1), size: 18),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _showAhorradorPicker(
      BuildContext ctx, List<Map<String, dynamic>> lista) {
    String query = '';
    // El campo nombre en listado_select viene como "concat(nombres,' ',apellidos)"
    String nombre(Map<String, dynamic> e) {
      final keys = e.keys.where((k) =>
          k.toLowerCase().contains('concat') ||
          k.toLowerCase().contains('nombre') ||
          k.toLowerCase().contains('apellido'));
      for (final k in keys) {
        final v = e[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return e.values
          .lastWhere((v) => v != null && v.toString().isNotEmpty,
              orElse: () => '')
          .toString();
    }

    return showDialog<Map<String, dynamic>>(
      context: ctx,
      builder: (aCtx) => StatefulBuilder(
        builder: (aCtx, setA) {
          final filtered = lista.where((e) {
            if (query.isEmpty) return true;
            return nombre(e).toLowerCase().contains(query.toLowerCase());
          }).toList();

          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(aCtx).size.height * 0.65,
                maxWidth: min(420, MediaQuery.of(aCtx).size.width - 40),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
                    decoration: const BoxDecoration(
                      color: homeNavy,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(18)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_search_rounded,
                            color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Seleccionar ahorrador (${lista.length})',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(aCtx),
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white60, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      autofocus: true,
                      onChanged: (v) => setA(() => query = v.trim()),
                      style: const TextStyle(color: homeNavy, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Buscar ahorrador...',
                        hintStyle: const TextStyle(
                            color: Color(0xFFB0BBCC), fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Color(0xFF8899BB), size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF5F7FB),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFDDE3EF))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFDDE3EF))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: homeAccent, width: 1.5)),
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16),
                      itemBuilder: (_, i) {
                        final e = filtered[i];
                        final n = nombre(e);
                        final id = (e['codigo'] ??
                                e['valor'] ??
                                e['codigo_deudor'] ??
                                n)
                            .toString();
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () =>
                                Navigator.pop(aCtx, {'valor': id, 'nombre': n}),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: homeAccent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Center(
                                      child: Text(
                                        n.isNotEmpty ? n[0].toUpperCase() : '?',
                                        style: const TextStyle(
                                          color: homeAccent,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(n,
                                        style: const TextStyle(
                                          color: homeNavy,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        )),
                                  ),
                                  const Icon(Icons.chevron_right_rounded,
                                      color: Color(0xFFCBD5E1), size: 18),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
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

  // ── Diálogo Crear Ahorrador ──────────────────────────────────────
  Future<void> _showCrearAhorradorDialog() async {
    final formKey = GlobalKey<FormState>();
    String? selectedAsesor;
    String asesorLabel = '';
    final docCtrl = TextEditingController();
    final nombresCtrl = TextEditingController();
    final apellCtrl = TextEditingController();
    final dirCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    bool saving = false;

    await showDialog(
      context: screenContext,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: min(480, MediaQuery.of(ctx).size.width - 40),
              maxHeight: MediaQuery.of(ctx).size.height * 0.88,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header gradiente ──────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D1B4B), Color(0xFF1E3A8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person_add_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Crear Ahorrador',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                )),
                            Text('Registrar nuevo ahorrador',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                )),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: saving ? null : () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white60, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // ── Formulario ────────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Asesor — campo buscable
                          buildSavingsFieldLabel('Asesor'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final result = await _showAsesorPicker(ctx);
                              if (result != null) {
                                setS(() {
                                  selectedAsesor = result['valor'];
                                  asesorLabel = result['nombre'];
                                });
                              }
                            },
                            child: Container(
                              height: 48,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F7FB),
                                border: Border.all(
                                  color: selectedAsesor != null
                                      ? homeAccent.withValues(alpha: 0.6)
                                      : const Color(0xFFDDE3EF),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.person_search_rounded,
                                      size: 18,
                                      color: selectedAsesor != null
                                          ? homeAccent
                                          : const Color(0xFF9CA3AF)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      asesorLabel.isNotEmpty
                                          ? asesorLabel
                                          : 'Seleccione un asesor...',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: asesorLabel.isNotEmpty
                                            ? homeNavy
                                            : const Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.keyboard_arrow_down_rounded,
                                      color: Color(0xFF9CA3AF), size: 20),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // N° Documento
                          buildSavingsField(
                            ctrl: docCtrl,
                            label: 'N° Documento',
                            icon: Icons.badge_outlined,
                            keyboard: TextInputType.number,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Requerido'
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // Nombres + Apellidos en fila
                          Row(
                            children: [
                              Expanded(
                                child: buildSavingsField(
                                  ctrl: nombresCtrl,
                                  label: 'Nombres',
                                  icon: Icons.person_outline_rounded,
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Requerido'
                                          : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: buildSavingsField(
                                  ctrl: apellCtrl,
                                  label: 'Apellidos',
                                  icon: Icons.person_outline_rounded,
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Requerido'
                                          : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Dirección
                          buildSavingsField(
                            ctrl: dirCtrl,
                            label: 'Dirección',
                            icon: Icons.location_on_outlined,
                          ),
                          const SizedBox(height: 12),

                          // Teléfono
                          buildSavingsField(
                            ctrl: telCtrl,
                            label: 'Teléfono',
                            icon: Icons.phone_outlined,
                            keyboard: TextInputType.phone,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Botones ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: saving ? null : () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF8899BB),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFFDDE3EF)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cerrar',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: saving
                                ? null
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFF0D1B4B),
                                      Color(0xFF1E3A8A)
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                            color: saving ? const Color(0xFFCBD5E1) : null,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: saving
                                ? null
                                : [
                                    BoxShadow(
                                      color: homeNavy.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: saving
                                ? null
                                : () async {
                                    if (selectedAsesor == null) {
                                      showResult(false,
                                          'Seleccione un asesor para continuar');
                                      return;
                                    }
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    setS(() => saving = true);
                                    try {
                                      final r = await repository.post(
                                        '/ajax/registrar_ahorrador.php',
                                        {
                                          'codigo_asesor': selectedAsesor!,
                                          'documento': docCtrl.text.trim(),
                                          'nombres': nombresCtrl.text.trim(),
                                          'apellidos': apellCtrl.text.trim(),
                                          'direccion': dirCtrl.text.trim(),
                                          'telefono': telCtrl.text.trim(),
                                        },
                                      );
                                      final ok = r.statusCode == 200 &&
                                          (r.body
                                                  .toLowerCase()
                                                  .contains('exitoso') ||
                                              r.body
                                                  .toLowerCase()
                                                  .contains('registrado') ||
                                              r.body
                                                  .toLowerCase()
                                                  .contains('creado') ||
                                              r.body
                                                  .contains('"resultado":1') ||
                                              r.body
                                                  .contains('"success":true'));
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      if (isMounted) {
                                        showDialog(
                                          context: screenContext,
                                          builder: (_) => buildResultDialog(
                                            ok
                                                ? 'Ahorrador registrado exitosamente'
                                                : r.body.trim().isNotEmpty
                                                    ? r.body.trim()
                                                    : 'No se pudo registrar',
                                            ok,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        setS(() => saving = false);
                                      }
                                      showResult(false, friendlyError(e));
                                    }
                                  },
                            icon: saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save_rounded, size: 18),
                            label: Text(saving ? 'Guardando...' : 'Grabar'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );

    Future.delayed(const Duration(milliseconds: 400), () {
      docCtrl.dispose();
      nombresCtrl.dispose();
      apellCtrl.dispose();
      dirCtrl.dispose();
      telCtrl.dispose();
    });
  }

  Widget buildSavingsFieldLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: homeNavy,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget buildSavingsField({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        style: const TextStyle(color: homeNavy, fontSize: 14),
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF8899BB), fontSize: 13),
          prefixIcon: Icon(icon, color: homeAccent, size: 18),
          filled: true,
          fillColor: const Color(0xFFF5F7FB),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDDE3EF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDDE3EF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: homeAccent, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
          ),
        ),
      );

  Future<Map<String, dynamic>?> _showAsesorPicker(BuildContext ctx) {
    String query = '';
    return showDialog<Map<String, dynamic>>(
      context: ctx,
      builder: (aCtx) => StatefulBuilder(
        builder: (aCtx, setA) {
          final all = advisors.map((a) {
            final sigla = (a['sigla'] ?? a['codigo_asesor'] ?? '').toString();
            final nombre = [a['nombres'], a['apellidos']]
                .where((x) => x != null && x.toString().isNotEmpty)
                .join(' ')
                .trim();
            return {
              'valor': sigla,
              'nombre': nombre.isNotEmpty ? nombre : sigla
            };
          }).toList();

          final filtered = query.isEmpty
              ? all
              : all
                  .where((a) =>
                      a['nombre']!.toLowerCase().contains(query.toLowerCase()))
                  .toList();

          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(aCtx).size.height * 0.6,
                maxWidth: min(420, MediaQuery.of(aCtx).size.width - 40),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
                    decoration: const BoxDecoration(
                      color: homeNavy,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(18)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_search_rounded,
                            color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Seleccionar asesor',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(aCtx),
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white60, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      autofocus: true,
                      onChanged: (v) => setA(() => query = v.trim()),
                      style: const TextStyle(color: homeNavy, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Buscar asesor...',
                        hintStyle: const TextStyle(
                            color: Color(0xFFB0BBCC), fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Color(0xFF8899BB), size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF5F7FB),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFDDE3EF))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFDDE3EF))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: homeAccent, width: 1.5)),
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16),
                      itemBuilder: (_, i) {
                        final a = filtered[i];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => Navigator.pop(aCtx, a),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: homeAccent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Center(
                                      child: Text(
                                        a['nombre']!.isNotEmpty
                                            ? a['nombre']![0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: homeAccent,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(a['nombre']!,
                                        style: const TextStyle(
                                          color: homeNavy,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        )),
                                  ),
                                  const Icon(Icons.chevron_right_rounded,
                                      color: Color(0xFFCBD5E1), size: 18),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
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

  // ══════════════════════════════════════════════════════════════
  //  AHORRADORES TAB
  // ══════════════════════════════════════════════════════════════
  Widget buildSavingsScreen() {
    if (loadingData) return buildLoadingView();

    const navy = Color(0xFF0D1B4B);

    // Años disponibles: solo 2025 y año actual
    final currentYear = DateTime.now().year;
    final anios = ({currentYear.toString(), '2025'}).toList()
      ..sort((a, b) => b.compareTo(a));

    // Asesores: todos los conocidos (igual que la web) + cualquiera presente
    // en los datos, ordenados por nombre completo.
    final asesorSet = <String>{...advisorNames.keys};
    for (final a in savers) {
      final v = (a['asesor'] ?? '').toString().trim().toUpperCase();
      if (v.isNotEmpty) asesorSet.add(v);
    }
    final asesorOrdenados = asesorSet.toList()
      ..sort((a, b) =>
          advisorName(a).toLowerCase().compareTo(advisorName(b).toLowerCase()));
    final asesores = ['0', ...asesorOrdenados];

    final lista = filteredSavers;
    final total = lista.fold(
        0.0,
        (s, a) =>
            s +
            numberValue(
                a['total_ahorrado'] ?? a['valor_pactado'] ?? a['monto'] ?? 0));

    final enMoraCount = lista.where((a) {
      final cuotas = a['ahorros'];
      if (cuotas is! List) return false;
      final hoy = _hoyColombia();
      return cuotas.whereType<Map>().any((m) {
        final pagado = (m['estado_pago'] ?? '')
            .toString()
            .toLowerCase()
            .contains('pagado');
        if (pagado) return false;
        final fc = DateTime.tryParse((m['fecha_cuota'] ?? '').toString());
        if (fc == null) return false;
        return !DateTime(fc.year, fc.month, fc.day).isAfter(hoy);
      });
    }).length;
    final alDiaCount = lista.length - enMoraCount;

    Widget dropFilter({
      required String label,
      required IconData icon,
      required String value,
      required List<DropdownMenuItem<String>> items,
      required ValueChanged<String?> onChanged,
    }) =>
        Expanded(
            child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(children: [
            Icon(icon, size: 15, color: const Color(0xFF8899BB)),
            const SizedBox(width: 6),
            Expanded(
                child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              underline: const SizedBox(),
              dropdownColor: Colors.white,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: Color(0xFF8899BB)),
              style: const TextStyle(
                  color: navy, fontWeight: FontWeight.w600, fontSize: 13),
              items: items,
              onChanged: onChanged,
            )),
          ]),
        ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Botones de acción ────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            buildActionButton(
                icon: Icons.person_add_rounded,
                label: 'Agregar Ahorrador',
                color: navy,
                onTap: () => _showCrearAhorradorDialog()),
            buildActionButton(
                icon: Icons.savings_rounded,
                label: 'Agregar Ahorro',
                color: navy,
                onTap: () => _showCrearAhorroDialog()),
            buildActionButton(
                icon: Icons.settings_rounded,
                label: 'Configurar Ahorro',
                color: navy,
                onTap: () => _showConfigurarAhorroDialog()),
          ]),
        ),

        const SizedBox(height: 14),

        // ── Banner hero ───────────────────────────────────────
        AnimatedBuilder(
          animation: shimmer,
          builder: (_, __) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0F0A3C),
                  Color(0xFF1E1265),
                  Color(0xFF3730A3),
                  Color(0xFF4F46E5),
                ],
                stops: [0.0, 0.30, 0.65, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3730A3)
                      .withValues(alpha: 0.44 + 0.14 * shimmer.value),
                  blurRadius: 26 + 10 * shimmer.value,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(children: [
                Positioned(
                  right: -30,
                  top: -30,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        Colors.white.withValues(alpha: 0.14),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
                Positioned(
                  left: -20,
                  bottom: -20,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset((shimmer.value * 2 - 1) * 280, 0),
                    child: Transform.rotate(
                      angle: 0.42,
                      child: Container(
                        width: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.07),
                            Colors.white.withValues(alpha: 0),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Column(children: [
                    Row(children: [
                      Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                                width: 1,
                              )),
                          child: const Icon(Icons.savings_rounded,
                              color: Colors.white, size: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('${lista.length} Ahorradores',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20)),
                            Text('Total: ${formatCop(total)}',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.80),
                                    fontSize: 13)),
                          ])),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Sistema de',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.50),
                                    fontSize: 10)),
                            const Text('SAF',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5)),
                          ]),
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      _ahorMiniStat(Icons.check_circle_outline_rounded,
                          'Al día', '$alDiaCount', const Color(0xFF6EE7B7)),
                      Container(
                          width: 1,
                          height: 30,
                          color: Colors.white.withValues(alpha: 0.2)),
                      _ahorMiniStat(Icons.warning_amber_rounded, 'En mora',
                          '$enMoraCount', const Color(0xFFFCA5A5)),
                      Container(
                          width: 1,
                          height: 30,
                          color: Colors.white.withValues(alpha: 0.2)),
                      _ahorMiniStat(Icons.calendar_today_outlined, 'Año',
                          savingsYearFilter, Colors.white),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ── Filtros ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            dropFilter(
              label: 'Año',
              icon: Icons.calendar_today_outlined,
              value: savingsYearFilter,
              items: anios
                  .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                refresh(() { savingsYearFilter = v; savingsCurrentPage = 1; });
                reloadSavers();
              },
            ),
            const SizedBox(width: 10),
            dropFilter(
              label: 'Asesor',
              icon: Icons.person_outline_rounded,
              value: asesores.contains(savingsAdvisorFilter)
                  ? savingsAdvisorFilter
                  : '0',
              items: asesores
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s == '0' ? 'Todos' : advisorName(s),
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                refresh(() { savingsAdvisorFilter = v; savingsCurrentPage = 1; });
              },
            ),
          ]),
        ),

        const SizedBox(height: 14),

        // ── Lista ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3730A3), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.people_alt_rounded,
                  color: Colors.white, size: 15),
            ),
            const SizedBox(width: 9),
            const Expanded(
                child: Text('Lista de Ahorradores',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: navy))),
            if (lista.isNotEmpty)
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3730A3), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('${lista.length}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white))),
          ]),
        ),
        const SizedBox(height: 10),

        if (lista.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
                child: Text('No hay ahorradores para los filtros seleccionados',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF8899BB)))),
          )
        else
          Builder(builder: (_) {
            final totalPags = ((lista.length - 1) ~/ HomeController.savingsPageSize) + 1;
            final pag = savingsCurrentPage.clamp(1, totalPags);
            final desde = (pag - 1) * HomeController.savingsPageSize;
            final hasta = (desde + HomeController.savingsPageSize).clamp(0, lista.length);
            final pagina = lista.sublist(desde, hasta);
            return Column(children: [
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                itemCount: pagina.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final delay = (i * 0.08).clamp(0.0, 0.45);
                  final end = (i * 0.08 + 0.70).clamp(0.5, 1.0);
                  return TweenAnimationBuilder<double>(
                    key: ValueKey('saver_${desde + i}'),
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Interval(delay, end, curve: Curves.easeOutBack),
                    builder: (_, v, child) => Opacity(
                      opacity: v.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 24 * (1 - v.clamp(0.0, 1.0))),
                        child: child,
                      ),
                    ),
                    child: buildSaverCard(pagina[i]),
                  );
                },
              ),
              if (totalPags > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF8FAFF), Color(0xFFEEF2FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.07),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(children: [
                      // Prev button
                      GestureDetector(
                        onTap: pag > 1 ? () => refresh(() => savingsCurrentPage = pag - 1) : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: pag > 1
                                ? const LinearGradient(
                                    colors: [Color(0xFF3730A3), Color(0xFF4F46E5)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: pag > 1 ? null : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: pag > 1
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(Icons.chevron_left_rounded,
                              color: pag > 1 ? Colors.white : const Color(0xFF9CA3AF),
                              size: 22),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Page info
                      Expanded(
                        child: Column(children: [
                          Text('Página $pag de $totalPags',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0D1B4B))),
                          const SizedBox(height: 2),
                          Text('${lista.length} ahorradores · ${pagina.length} en esta página',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF8899BB),
                                  fontWeight: FontWeight.w500)),
                        ]),
                      ),
                      const SizedBox(width: 10),
                      // Next button
                      GestureDetector(
                        onTap: pag < totalPags
                            ? () => refresh(() => savingsCurrentPage = pag + 1)
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: pag < totalPags
                                ? const LinearGradient(
                                    colors: [Color(0xFF3730A3), Color(0xFF4F46E5)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: pag < totalPags ? null : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: pag < totalPags
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(Icons.chevron_right_rounded,
                              color: pag < totalPags ? Colors.white : const Color(0xFF9CA3AF),
                              size: 22),
                        ),
                      ),
                    ]),
                  ),
                )
              else
                const SizedBox(height: 20),
            ]);
          }),
      ],
    );
  }

  // ── Ahorros helpers ──────────────────────────────────────────
  static DateTime _hoyColombia() {
    final n = DateTime.now().toUtc().subtract(const Duration(hours: 5));
    return DateTime(n.year, n.month, n.day);
  }

  Widget _ahorMiniStat(
          IconData icon, String label, String value, Color color) =>
      Expanded(
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 10)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ],
            ),
          ),
        ]),
      );

  // ══════════════════════════════════════════════════════════════
  //  MOVIMIENTOS TAB — Gestión de Gastos (2 sub-tabs)
  // ══════════════════════════════════════════════════════════════

  List<Map<String, dynamic>> get filteredMovements {
    final usesAccountEndpoint = accountFilter.isNotEmpty &&
        selectedAccountMovementsName == accountFilter;
    final source = usesAccountEndpoint ? selectedAccountMovements : movements;
    final result = source.where((m) {
      if (accountFilter.isNotEmpty &&
          (m['cuenta_nombre'] ?? '') != accountFilter) {
        return false;
      }
      if (movementTypeFilter.isNotEmpty) {
        final t = (m['tipo_movimiento'] ?? '').toString();
        // tipo '1' (loan transfers) is also Ingreso, same as '3'
        final matchIngreso =
            movementTypeFilter == '3' && (t == '3' || t == '1');
        if (!matchIngreso && t != movementTypeFilter) return false;
      }
      final rawFecha = (m['fecha'] ?? '').toString();
      if (rawFecha.length >= 10) {
        final fecha = DateTime.tryParse(rawFecha.substring(0, 10));
        if (fecha != null) {
          if (filterFrom != null && fecha.isBefore(filterFrom!)) {
            return false;
          }
          if (filterTo != null && fecha.isAfter(filterTo!)) {
            return false;
          }
        }
      }
      return true;
    }).toList();

    // `listar_movimientos_cuenta.php` ya entrega exactamente el orden de la
    // web: fecha DESC, codigo ASC. No debe ordenarse de nuevo en la app.
    // Continúa con la normalización final; no se retorna antes porque el PHP
    // desplegado puede entregar invertidos los códigos del mismo día.

    // La tabla web usa fecha DESC y código ASC. El endpoint global puede
    // entregar código DESC, así que el orden se normaliza después de filtrar.
    final originalPosition = <Map<String, dynamic>, int>{
      for (var index = 0; index < result.length; index++) result[index]: index,
    };
    final reverseDailyBlock =
        accountFilter.isNotEmpty || movementTypeFilter.isNotEmpty;
    result.sort((a, b) {
      String dateOf(Map<String, dynamic> item) {
        final value =
            (item['fecha'] ?? item['fecha_movimiento'] ?? '').toString();
        return value.length >= 10 ? value.substring(0, 10) : value;
      }

      int? codeOf(Map<String, dynamic> item) => int.tryParse(
            (item['codigo'] ??
                        item['codigo_movimiento'] ??
                        item['codigo_cuenta_movimiento'] ??
                        item['id'])
                    ?.toString() ??
                '',
          );

      final dateComparison = dateOf(b).compareTo(dateOf(a));
      if (dateComparison != 0) return dateComparison;

      final codeA = codeOf(a);
      final codeB = codeOf(b);
      if (!reverseDailyBlock &&
          codeA != null &&
          codeB != null &&
          codeA != codeB) {
        return codeA.compareTo(codeB);
      }

      // El caché antiguo puede no incluir la PK. En ese caso se invierte
      // solamente el grupo de registros que comparte la misma fecha.
      return (originalPosition[b] ?? 0).compareTo(originalPosition[a] ?? 0);
    });

    // Conserva el ORDER BY de `listado_cuentas_movimientos`, la misma
    // consulta que utiliza la web.
    /*
        return idA.compareTo(idB); // ASC within same date — matches web
      });
    }

    */
    return result;
  }

  Future<void> showSavingsInstallmentDialog(
      Map<String, dynamic> ahorro, Map<String, dynamic> cuota) async {
    final estado = int.tryParse(cuota['estado']?.toString() ?? '0') ?? 0;
    final estadoPago = (cuota['estado_pago'] ?? '').toString().toLowerCase();
    final valorPagado = numberValue(cuota['valor_pagado'] ?? 0);
    final pagada =
        estado > 0 || estadoPago.contains('pagado') || valorPagado > 0;
    final mes = (cuota['nombre_mes'] ?? 'Cuota').toString();
    final fechaPago = (cuota['fecha_pago'] ??
            cuota['fecha_registro_pago'] ??
            cuota['fecha_cuota'] ??
            '')
        .toString();

    if (pagada) {
      await _showComprobanteAhorroDialog(
        ahorro: ahorro,
        cuota: cuota,
        mes: mes,
        fechaPago: fechaPago,
        valorPagado: valorPagado,
      );
      return;
    }

    final codigoCuota = cuota['codigo_cuota']?.toString() ?? '';
    if (codigoCuota.isEmpty) {
      await showDialog<void>(
          context: screenContext,
          builder: (_) =>
              buildResultDialog('La cuota no tiene un código válido.', false));
      return;
    }

    final pactado = numberValue(ahorro['valor_pactado'] ??
        ahorro['Valor_pactado'] ??
        ahorro['valor_Pactado'] ??
        0);
    final valorCtrl = TextEditingController(
        text: pactado > 0 ? pactado.round().toString() : '');
    final detalleCtrl = TextEditingController();
    DateTime fecha = _hoyColombia();
    bool saving = false;

    await showDialog<void>(
      context: screenContext,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        String fechaTexto() =>
            '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

        Future<void> guardar() async {
          final valor =
              numberValue(valorCtrl.text.replaceAll(RegExp(r'[^\d.]'), ''));
          if (valor <= 0) {
            await showDialog<void>(
                context: ctx,
                builder: (_) => buildResultDialog(
                    'Ingresa un valor de pago válido.', false));
            return;
          }
          setS(() => saving = true);
          try {
            final usuario =
                (repository.user?['codigo_usuario'] ?? '').toString().trim();
            final body = <String, dynamic>{
              'tabla': 'tbl_ahorradores_cuotas',
              'filtro': 'codigo_cuota=$codigoCuota',
              'modo': 'editar',
              'estado': '1',
              'valor_pagado': valor.toStringAsFixed(0),
              'fecha_pago': fechaTexto(),
              'fecha_registro_pago': fechaTexto(),
              'detalle': detalleCtrl.text.trim(),
            };
            if (usuario.isNotEmpty) body['usuario_registro_pago'] = usuario;

            final r = await repository
                .post('/ajax/actualizar_registro.php', body)
                .timeout(const Duration(seconds: 15));
            final respuesta = r.body.trim();
            final fallo = r.statusCode != 200 ||
                respuesta.toLowerCase().contains('error') ||
                respuesta.toLowerCase().contains('no se');
            if (fallo) {
              throw Exception(respuesta.isEmpty
                  ? 'El servidor no confirmó el pago.'
                  : respuesta);
            }

            repository.invalidateCache('/ajax/listado_ahorros.php');
            await fetchSavers();
            if (ctx.mounted) Navigator.pop(ctx);
            if (isMounted) {
              refresh(() {});
              await showDialog<void>(
                  context: screenContext,
                  builder: (_) => buildResultDialog(
                      'Cuota registrada correctamente.', true));
            }
          } catch (e) {
            if (ctx.mounted) {
              setS(() => saving = false);
              await showDialog<void>(
                  context: ctx,
                  builder: (_) => buildResultDialog(
                      'No fue posible registrar la cuota: $e', false));
            }
          }
        }

        return Theme(
          data: ThemeData.light(useMaterial3: true).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4F46E5),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF0D1B4B),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFF4F6FF),
              labelStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDDE3F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDDE3F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
              ),
              prefixIconColor: const Color(0xFF4F46E5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
          child: Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 0,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // ── Premium header ──────────────────────────────────────────
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF0F0A3C),
                        Color(0xFF1E1265),
                        Color(0xFF3730A3),
                        Color(0xFF4F46E5),
                      ],
                      stops: [0.0, 0.3, 0.65, 1.0],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(children: [
                    // Orb top-right
                    Positioned(right: -20, top: -20,
                      child: Container(width: 90, height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            const Color(0xFF818CF8).withValues(alpha: 0.25),
                            Colors.transparent,
                          ]),
                        ))),
                    // Orb bottom-left
                    Positioned(left: -10, bottom: -15,
                      child: Container(width: 60, height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            const Color(0xFF6366F1).withValues(alpha: 0.20),
                            Colors.transparent,
                          ]),
                        ))),
                    // Shimmer sweep
                    Positioned.fill(
                      child: OverflowBox(
                        maxWidth: double.infinity,
                        child: Transform.translate(
                          offset: const Offset(80, 0),
                          child: Transform.rotate(angle: 0.4,
                            child: Container(
                              width: 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.10),
                                  Colors.white.withValues(alpha: 0),
                                ]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Content
                    Center(child: Column(children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF818CF8), Color(0xFF4F46E5), Color(0xFF3730A3)],
                            stops: [0.0, 0.5, 1.0],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.50),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.savings_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 12),
                      Text('Registrar cuota',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.70),
                              letterSpacing: 1.2)),
                      const SizedBox(height: 2),
                      Text(mes,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5)),
                    ])),
                  ]),
                ),
              ),

              // ── Form fields ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Valor pagado
                  TextField(
                    controller: valorCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Color(0xFF0D1B4B), fontWeight: FontWeight.w600, fontSize: 15),
                    decoration: const InputDecoration(
                      labelText: 'Valor pagado',
                      prefixText: '\$ ',
                      prefixIcon: Icon(Icons.attach_money_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Fecha de pago — styled row
                  GestureDetector(
                    onTap: saving
                        ? null
                        : () async {
                            final elegida = await showLightDatePicker(
                              ctx,
                              initialDate: fecha,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (elegida != null) setS(() => fecha = elegida);
                          },
                    child: Container(
                      height: 54,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFDDE3F0)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_outlined,
                            color: Color(0xFF4F46E5), size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Fecha de pago',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF6B7280))),
                              Text(fechaTexto(),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0D1B4B))),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_calendar_rounded,
                            color: Color(0xFF4F46E5), size: 16),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Comentario
                  TextField(
                    controller: detalleCtrl,
                    minLines: 2,
                    maxLines: 3,
                    style: const TextStyle(color: Color(0xFF0D1B4B), fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Comentario (opcional)',
                      prefixIcon: Icon(Icons.comment_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Buttons
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: saving ? null : () => Navigator.pop(ctx),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: saving
                                ? null
                                : const LinearGradient(
                                    colors: [Color(0xFF991B1B), Color(0xFFDC2626), Color(0xFFEF4444)],
                                    stops: [0.0, 0.5, 1.0],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            color: saving ? const Color(0xFFE5E7EB) : null,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: saving ? null : [
                              BoxShadow(
                                color: const Color(0xFFDC2626).withValues(alpha: 0.40),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.close_rounded, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text('Cancelar',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: saving ? null : guardar,
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: saving
                                ? null
                                : const LinearGradient(
                                    colors: [Color(0xFF065F46), Color(0xFF059669), Color(0xFF34D399)],
                                    stops: [0.0, 0.55, 1.0],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            color: saving ? const Color(0xFFE5E7EB) : null,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: saving ? null : [
                              BoxShadow(
                                color: const Color(0xFF059669).withValues(alpha: 0.45),
                                blurRadius: 16,
                                offset: const Offset(0, 5),
                              ),
                              BoxShadow(
                                color: const Color(0xFF34D399).withValues(alpha: 0.20),
                                blurRadius: 28,
                                spreadRadius: -4,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Center(
                            child: saving
                                ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5, color: Colors.white))
                                : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Icon(Icons.save_rounded, color: Colors.white, size: 17),
                                    SizedBox(width: 7),
                                    Text('Registrar',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14)),
                                  ]),
                          ),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                ]),
              ),
            ]),
          ),
        );
      }),
    );

    valorCtrl.dispose();
    detalleCtrl.dispose();
  }

  Future<void> _showComprobanteAhorroDialog({
    required Map<String, dynamic> ahorro,
    required Map<String, dynamic> cuota,
    required String mes,
    required String fechaPago,
    required double valorPagado,
  }) async {
    final ahorrador =
        (ahorro['ahorrador'] ?? ahorro['nombre'] ?? 'Ahorrador').toString();
    final codigoCuota = (cuota['codigo_cuota'] ?? '').toString();
    final mesComprobante = _mesComprobante(cuota, mes);
    final fechaCorta =
        fechaPago.length >= 10 ? fechaPago.substring(0, 10) : fechaPago;
    final generado = _fechaHoraComprobante();
    bool verComprobante = false;
    bool generandoPdf = false;

    await showDialog<void>(
      context: screenContext,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        Future<void> descargar() async {
          setS(() => generandoPdf = true);
          try {
            final bytes = await _generarComprobanteAhorroPdf(
              ahorrador: ahorrador,
              mes: mesComprobante,
              fechaPago: fechaCorta,
              valorPagado: valorPagado,
              codigoCuota: codigoCuota,
              generado: generado,
            );
            final nombreSeguro = ahorrador
                .toLowerCase()
                .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
                .replaceAll(RegExp(r'^_|_$'), '');
            await Printing.sharePdf(
              bytes: bytes,
              filename:
                  'comprobante_${nombreSeguro.isEmpty ? 'ahorro' : nombreSeguro}_$codigoCuota.pdf',
            );
          } on MissingPluginException {
            if (isMounted) {
              showResult(false,
                  'La descarga de PDF requiere instalar la nueva versión de SAF. Cierra y reinstala la aplicación; el hot reload no carga este componente.');
            }
          } catch (e) {
            if (isMounted) {
              showResult(false,
                  'No fue posible generar el comprobante PDF. Intenta nuevamente.');
            }
          } finally {
            if (ctx.mounted) setS(() => generandoPdf = false);
          }
        }

        Widget premiumButton({
          required String label,
          required IconData icon,
          required List<Color> colors,
          required VoidCallback? onTap,
          bool loading = false,
        }) {
          final shadow = colors.first;
          return Opacity(
            opacity: onTap == null ? 0.55 : 1,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    stops: colors.length == 3
                        ? const [0.0, 0.55, 1.0]
                        : null,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: shadow.withValues(alpha: 0.42),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                    BoxShadow(
                      color: shadow.withValues(alpha: 0.18),
                      blurRadius: 24,
                      spreadRadius: -4,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (loading)
                    const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  else
                    Icon(icon, size: 17, color: Colors.white),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ),
                ]),
              ),
            ),
          );
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D1B4B).withValues(alpha: 0.30),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                    blurRadius: 60,
                    spreadRadius: -8,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Premium header ──────────────────────────────
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(18, 20, 14, 20),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF0F0A3C),
                              Color(0xFF1E1265),
                              Color(0xFF3730A3),
                              Color(0xFF4F46E5),
                            ],
                            stops: [0.0, 0.3, 0.65, 1.0],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Stack(children: [
                          // Orb top-right
                          Positioned(right: -18, top: -18,
                            child: Container(width: 80, height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(colors: [
                                  const Color(0xFF818CF8).withValues(alpha: 0.28),
                                  Colors.transparent,
                                ]),
                              ))),
                          // Orb bottom-left
                          Positioned(left: -12, bottom: -16,
                            child: Container(width: 55, height: 55,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                              ))),
                          // Shimmer
                          Positioned.fill(
                            child: OverflowBox(
                              maxWidth: double.infinity,
                              child: Transform.translate(
                                offset: const Offset(60, 0),
                                child: Transform.rotate(angle: 0.4,
                                  child: Container(width: 32,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: [
                                        Colors.white.withValues(alpha: 0),
                                        Colors.white.withValues(alpha: 0.10),
                                        Colors.white.withValues(alpha: 0),
                                      ]),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Content
                          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF818CF8), Color(0xFF4F46E5), Color(0xFF3730A3)],
                                  stops: [0.0, 0.5, 1.0],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4F46E5).withValues(alpha: 0.50),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.receipt_long_rounded,
                                  color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('Detalle del Ahorro',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.3)),
                                const SizedBox(height: 4),
                                Text(ahorrador,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.80),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(height: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF06B6D4).withValues(alpha: 0.20),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFF67E8F9).withValues(alpha: 0.40)),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.calendar_month_rounded,
                                        size: 10, color: Color(0xFF67E8F9)),
                                    const SizedBox(width: 4),
                                    Text(mesComprobante,
                                        style: const TextStyle(
                                            color: Color(0xFF67E8F9),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700)),
                                  ]),
                                ),
                              ]),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF991B1B), Color(0xFFDC2626), Color(0xFFF43F5E)],
                                    stops: [0.0, 0.5, 1.0],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFDC2626).withValues(alpha: 0.45),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.close_rounded,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                          ]),
                        ]),
                      ),
                    ),

                    // ── Verified badge ──────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFDCFCE7), Color(0xFFBBF7D0), Color(0xFFD1FAE5)],
                            stops: [0.0, 0.5, 1.0],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.30)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF059669).withValues(alpha: 0.10),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF065F46), Color(0xFF059669)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF059669).withValues(alpha: 0.40),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.verified_rounded,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Comprobante de cuota disponible',
                                  style: TextStyle(
                                      color: Color(0xFF064E3B),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800)),
                              SizedBox(height: 2),
                              Text('Consulta o descarga el soporte de pago',
                                  style: TextStyle(
                                      color: Color(0xFF065F46),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500)),
                            ]),
                          ),
                        ]),
                      ),
                    ),

                    // ── Detail table (expandable) ───────────────────
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: verComprobante
                          ? Container(
                              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF8FAFF), Color(0xFFEEF2FF)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.15)),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                // Table header
                                Container(
                                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF3730A3), Color(0xFF4F46E5)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                                  ),
                                  child: Row(children: [
                                    Container(
                                      width: 30, height: 30,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.description_outlined,
                                          color: Colors.white, size: 16),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text('Comprobante de Pago',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800)),
                                  ]),
                                ),
                                // Rows
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                                  child: Column(children: [
                                    _cuotaInfoRow('Ahorrador', ahorrador),
                                    _cuotaInfoRow('Mes', mesComprobante),
                                    _cuotaInfoRow('Fecha de Pago', fechaCorta),
                                    _cuotaInfoRow('Valor Pagado', formatCop(valorPagado)),
                                    _cuotaInfoRow('Código Cuota', codigoCuota),
                                  ]),
                                ),
                                // Footer
                                Container(
                                  margin: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: const Color(0xFF4F46E5).withValues(alpha: 0.18)),
                                  ),
                                  child: Row(children: [
                                    const Icon(Icons.schedule_rounded,
                                        size: 12, color: Color(0xFF4F46E5)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text('Generado: $generado',
                                          style: const TextStyle(
                                              fontSize: 9,
                                              color: Color(0xFF4338CA),
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ]),
                                ),
                              ]),
                            )
                          : const SizedBox.shrink(),
                    ),

                    // ── Action buttons ──────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          premiumButton(
                            label: verComprobante ? 'Comprobante visible' : 'Ver comprobante',
                            icon: Icons.visibility_rounded,
                            colors: const [Color(0xFF065F46), Color(0xFF059669), Color(0xFF10B981)],
                            onTap: () => setS(() => verComprobante = true),
                          ),
                          const SizedBox(height: 10),
                          premiumButton(
                            label: generandoPdf ? 'Generando...' : 'Descargar PDF',
                            icon: Icons.picture_as_pdf_rounded,
                            colors: const [Color(0xFF1E1265), Color(0xFF3730A3), Color(0xFF6366F1)],
                            loading: generandoPdf,
                            onTap: generandoPdf ? null : descargar,
                          ),
                          const SizedBox(height: 10),
                          premiumButton(
                            label: 'Cerrar',
                            icon: Icons.close_rounded,
                            colors: const [Color(0xFF7F1D1D), Color(0xFFDC2626), Color(0xFFF43F5E)],
                            onTap: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<Uint8List> _generarComprobanteAhorroPdf({
    required String ahorrador,
    required String mes,
    required String fechaPago,
    required double valorPagado,
    required String codigoCuota,
    required String generado,
  }) async {
    final documento = pw.Document(
      title: 'Comprobante de Pago',
      author: 'SAF',
      subject: 'Comprobante de cuota de ahorro',
    );

    pw.Widget fila(String etiqueta, String valor) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 150,
                child: pw.Text(etiqueta,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ),
              pw.Expanded(child: pw.Text(valor)),
            ],
          ),
        );

    documento.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Comprobante de Pago',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 18),
            fila('Ahorrador:', ahorrador),
            fila('Mes:', mes),
            fila('Fecha de Pago:', fechaPago),
            fila('Valor Pagado:', formatCop(valorPagado)),
            fila('Código Cuota:', codigoCuota),
            pw.SizedBox(height: 8),
            pw.Text('Documento generado: $generado',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ],
        ),
      ),
    );

    return documento.save();
  }

  String _mesComprobante(Map<String, dynamic> cuota, String fallback) {
    final fecha = DateTime.tryParse((cuota['fecha_cuota'] ?? '').toString());
    if (fecha == null) return fallback;
    const meses = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic'
    ];
    return '${meses[fecha.month - 1]}-${fecha.year}';
  }

  String _fechaHoraComprobante() {
    final ahora = DateTime.now().toUtc().subtract(const Duration(hours: 5));
    final hora12 = ahora.hour % 12 == 0 ? 12 : ahora.hour % 12;
    final periodo = ahora.hour < 12 ? 'a. m.' : 'p. m.';
    String dos(int valor) => valor.toString().padLeft(2, '0');
    return '${dos(ahora.day)}/${dos(ahora.month)}/${ahora.year}, '
        '$hora12:${dos(ahora.minute)}:${dos(ahora.second)} $periodo';
  }

  Widget _cuotaInfoRow(String label, String value) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE0E7FF)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 105,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value.isEmpty ? 'Sin información' : value,
                style: const TextStyle(
                    fontSize: 12,
                    color: homeNavy,
                    fontWeight: FontWeight.w800)),
          ),
        ]),
      );
}

class ExpandableSaverCard extends StatefulWidget {
  const ExpandableSaverCard({
    super.key,
    required this.data,
    required this.cop,
    required this.num,
    required this.onCuotaTap,
  });
  final Map<String, dynamic> data;
  final String Function(double) cop;
  final double Function(dynamic) num;
  final Future<void> Function(
      Map<String, dynamic> ahorro, Map<String, dynamic> cuota) onCuotaTap;

  @override
  State<ExpandableSaverCard> createState() => _ExpandableSaverCardState();
}

class _ExpandableSaverCardState extends State<ExpandableSaverCard>
    with TickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _shimmer = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  static const _purple = Color(0xFF4361EE);
  static const homeNavy = Color(0xFF0D1B4B);

  @override
  Widget build(BuildContext context) {
    final a = widget.data;
    final nombre = (a['ahorrador'] ?? a['nombre'] ?? 'Ahorrador').toString();
    final asesor = (a['asesor'] ?? '').toString();
    final total = widget.num(a['total_ahorrado'] ?? a['valor_pactado'] ?? 0);
    final pactado = widget.num(
        a['valor_pactado'] ?? a['Valor_pactado'] ?? a['valor_Pactado'] ?? 0);
    final neto = widget.num(a['neto_pagar'] ?? a['neto'] ?? 0);
    final rend = widget.num(a['porcentaje'] ?? 0);
    final fecha = (a['Fecha_ingreso'] ?? a['fecha_ingreso'] ?? '').toString();
    final cuotas = a['ahorros'];
    final List<Map<String, dynamic>> meses = cuotas is List
        ? cuotas
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : [];

    // En mora sólo si una cuota YA VENCIDA (fecha ≤ hoy en Colombia) no está
    // pagada. Las cuotas futuras vienen con mora=1 del API pero no cuentan.
    final hoy = _hoyColombia();
    final enMora = meses.any((m) {
      final pagado =
          (m['estado_pago'] ?? '').toString().toLowerCase().contains('pagado');
      if (pagado) return false;
      final fc = DateTime.tryParse((m['fecha_cuota'] ?? '').toString());
      if (fc == null) return false;
      return !DateTime(fc.year, fc.month, fc.day).isAfter(hoy); // fc ≤ hoy
    });

    final parts = nombre.trim().split(RegExp(r'\s+'));
    final i1 = parts.isNotEmpty && parts[0].isNotEmpty
        ? parts[0][0].toUpperCase()
        : 'A';
    final i2 = parts.length > 1
        ? parts[parts.length >= 3 ? 2 : 1][0].toUpperCase()
        : '';
    final initials = '$i1$i2';

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _expanded
                ? _purple.withValues(alpha: 0.25)
                : const Color(0xFFE8ECF4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _expanded
                  ? _purple.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: _expanded ? 20 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Accent top bar ──────────────────────────────────
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(17)),
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: enMora
                        ? [
                            const Color(0xFF991B1B),
                            const Color(0xFFDC2626),
                            const Color(0xFFF87171)
                          ]
                        : [
                            const Color(0xFF3730A3),
                            const Color(0xFF4361EE),
                            const Color(0xFF6366F1)
                          ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (enMora
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF4361EE))
                          .withValues(alpha: 0.55),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),

            // ── Cabecera ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Avatar
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: enMora
                          ? [
                              const Color(0xFFEF4444),
                              const Color(0xFFDC2626),
                              const Color(0xFF991B1B)
                            ]
                          : [
                              const Color(0xFF818CF8),
                              const Color(0xFF4361EE),
                              const Color(0xFF3730A3)
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: (enMora
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF4361EE))
                            .withValues(alpha: 0.45),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(initials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 0.5)),
                  ),
                ),
                const SizedBox(width: 11),
                // Nombre + badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: homeNavy,
                              height: 1.25,
                              letterSpacing: -0.2)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        if (asesor.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: _purple.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: _purple.withValues(alpha: 0.20)),
                            ),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _purple,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(asesor,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _purple.withValues(alpha: 0.9))),
                            ]),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: enMora
                                ? const Color(0xFFDC2626).withValues(alpha: 0.08)
                                : const Color(0xFF16A34A).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: enMora
                                  ? const Color(0xFFDC2626).withValues(alpha: 0.25)
                                  : const Color(0xFF16A34A).withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: enMora
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF16A34A),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              enMora ? 'En mora' : 'Al día',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: enMora
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF16A34A)),
                            ),
                          ]),
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Monto + chevron — columna derecha
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RotationTransition(
                      turns: Tween(begin: 0.0, end: 0.5).animate(_anim),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _expanded
                                ? [
                                    const Color(0xFF3730A3).withValues(alpha: 0.2),
                                    const Color(0xFF4F46E5).withValues(alpha: 0.3)
                                  ]
                                : [
                                    const Color(0xFFE8ECF4),
                                    const Color(0xFFF0F2FA)
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            size: 15,
                            color: _expanded
                                ? const Color(0xFF4361EE)
                                : const Color(0xFF8899BB)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedBuilder(
                      animation: _shimmer,
                      builder: (_, __) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF0F0A3C),
                              Color(0xFF3730A3),
                              Color(0xFF4361EE),
                              Color(0xFF6366F1),
                            ],
                            stops: [0.0, 0.35, 0.70, 1.0],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4361EE)
                                  .withValues(alpha: 0.38 + 0.18 * _shimmer.value),
                              blurRadius: 10 + 6 * _shimmer.value,
                              offset: const Offset(0, 3),
                            ),
                            BoxShadow(
                              color: const Color(0xFF3730A3)
                                  .withValues(alpha: 0.18 + 0.08 * _shimmer.value),
                              blurRadius: 16 + 6 * _shimmer.value,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(children: [
                            Positioned.fill(
                              child: Transform.translate(
                                offset: Offset(
                                    (_shimmer.value * 2 - 1) * 60, 0),
                                child: Transform.rotate(
                                  angle: 0.5,
                                  child: Container(
                                    width: 20,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: [
                                        Colors.white.withValues(alpha: 0),
                                        Colors.white.withValues(alpha: 0.15),
                                        Colors.white.withValues(alpha: 0),
                                      ]),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(widget.cop(total),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: Colors.white)),
                                Text('ahorrado',
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.white
                                            .withValues(alpha: 0.75))),
                              ],
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ],
                ),
              ]),
            ),

            // ── Detalle expandible ───────────────────────────────
            SizeTransition(
              sizeFactor: _anim,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFF0F3FF),
                      Color(0xFFF5F0FF),
                      Color(0xFFF8FAFF),
                    ],
                    stops: [0.0, 0.5, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(17)),
                ),
                child: Stack(children: [
                  Positioned(
                    right: -18,
                    bottom: -18,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          const Color(0xFF4361EE).withValues(alpha: 0.12),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                  Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: const Color(0xFFE8ECF4),
                    ),
                    const SizedBox(height: 14),

                    // 2×2 data grid
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(children: [
                        Expanded(
                            child: _detailChip(
                                Icons.calendar_today_outlined,
                                'Fecha ingreso',
                                fecha.length >= 10
                                    ? fecha.substring(0, 10)
                                    : fecha,
                                const Color(0xFF4361EE),
                                const Color(0xFF818CF8))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _detailChip(
                                Icons.savings_outlined,
                                'Valor pactado',
                                widget.cop(pactado),
                                const Color(0xFF7C3AED),
                                const Color(0xFFA78BFA))),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(children: [
                        Expanded(
                            child: _detailChip(
                                Icons.trending_up_rounded,
                                'Rendimiento',
                                '${rend.toStringAsFixed(1)}%',
                                const Color(0xFF059669),
                                const Color(0xFF34D399))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _detailChip(
                                Icons.account_balance_wallet_outlined,
                                'Neto a pagar',
                                widget.cop(neto),
                                const Color(0xFFD97706),
                                const Color(0xFFFBBF24))),
                      ]),
                    ),

                    // Cuotas mensuales — scroll horizontal
                    if (meses.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(children: [
                          Container(
                            width: 3,
                            height: 14,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4361EE), Color(0xFF6366F1)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 7),
                          const Text('Cuotas mensuales',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: homeNavy)),
                        ]),
                      ),
                      SizedBox(
                        height: 96,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                          itemCount: meses.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final interval = Interval(
                              (i * 0.07).clamp(0.0, 0.50),
                              (i * 0.07 + 0.55).clamp(0.40, 1.0),
                              curve: Curves.easeOutBack,
                            );
                            return TweenAnimationBuilder<double>(
                              key: ValueKey('mes_${a['codigo'] ?? ''}_$i'),
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 700),
                              curve: interval,
                              builder: (_, t, child) => Opacity(
                                opacity: t.clamp(0.0, 1.0),
                                child: Transform.translate(
                                  offset: Offset(0, 14 * (1 - t)),
                                  child: child,
                                ),
                              ),
                              child: _mesChip(a, meses[i]),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                  ],
                ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailChip(
      IconData icon, String label, String value, Color c1, Color c2) =>
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(15, 10, 12, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c1.withValues(alpha: 0.15), c2.withValues(alpha: 0.25)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c1.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                    color: c1.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: c1.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 11, color: c1),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          color: c1.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 6),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c1.withValues(alpha: 0.95))),
            ]),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c1, c2],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ]),
      );

  // Fecha actual en Colombia (UTC-5, sin horario de verano), sólo Y-M-D.
  static DateTime _hoyColombia() {
    final n = DateTime.now().toUtc().subtract(const Duration(hours: 5));
    return DateTime(n.year, n.month, n.day);
  }

  Widget _mesChip(Map<String, dynamic> ahorro, Map<String, dynamic> m) {
    final mes = (m['nombre_mes'] ?? '').toString();
    final estadoPago = (m['estado_pago'] ?? '').toString();
    final valor = widget.num(m['valor_pagado'] ?? m['valor'] ?? 0);
    final fc = DateTime.tryParse((m['fecha_cuota'] ?? '').toString());
    final vencida = fc != null &&
        !DateTime(fc.year, fc.month, fc.day).isAfter(_hoyColombia());

    final esPagado = estadoPago.toLowerCase().contains('pagado');
    final esNoPago = !esPagado && vencida;
    final esFuturo = !esPagado && !vencida;

    final icon = esPagado
        ? Icons.check_circle_rounded
        : esNoPago
            ? Icons.cancel_rounded
            : Icons.radio_button_unchecked_rounded;

    final List<Color> gradColors = esPagado
        ? [const Color(0xFF064E3B), const Color(0xFF059669), const Color(0xFF34D399)]
        : esNoPago
            ? [const Color(0xFF7F1D1D), const Color(0xFFDC2626), const Color(0xFFF87171)]
            : [
                const Color(0xFFEEF2FF),
                const Color(0xFFE0E7FF),
              ];

    final iconColor = esFuturo ? const Color(0xFF4F46E5) : Colors.white;
    final textColor = esFuturo ? const Color(0xFF3730A3) : Colors.white;
    final borderColor = esPagado
        ? const Color(0xFF059669).withValues(alpha: 0.50)
        : esNoPago
            ? const Color(0xFFDC2626).withValues(alpha: 0.50)
            : const Color(0xFF4F46E5).withValues(alpha: 0.20);

    final glowColor = esPagado
        ? const Color(0xFF059669)
        : esNoPago
            ? const Color(0xFFDC2626)
            : const Color(0xFF4361EE);

    Widget chipContent = AnimatedBuilder(
      animation: _shimmer,
      builder: (_, child) => Container(
        width: 88,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: (esPagado || esNoPago)
              ? [
                  BoxShadow(
                    color: glowColor.withValues(
                        alpha: (esPagado ? 0.30 : 0.25) +
                            (esPagado ? 0.20 : 0.12) * _shimmer.value),
                    blurRadius:
                        (esPagado ? 10.0 : 8.0) + 5 * _shimmer.value,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: child,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 88,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradColors,
              stops: esPagado || esNoPago ? const [0.0, 0.55, 1.0] : null,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Stack(children: [
            // Shimmer sweep for paid chips
            if (esPagado)
              Positioned.fill(
                child: OverflowBox(
                  maxWidth: double.infinity,
                  child: Transform.translate(
                    offset: Offset((_shimmer.value * 2 - 1) * 100, 0),
                    child: Transform.rotate(
                      angle: 0.5,
                      child: Container(
                        width: 24,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.20),
                            Colors.white.withValues(alpha: 0),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: esFuturo
                          ? const Color(0xFF4361EE).withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(mes,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: -0.2)),
                  const SizedBox(height: 2),
                  Text(
                    esFuturo ? '—' : widget.cop(valor),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: textColor.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => unawaited(widget.onCuotaTap(ahorro, m)),
        borderRadius: BorderRadius.circular(16),
        child: chipContent,
      ),
    );
  }
}
