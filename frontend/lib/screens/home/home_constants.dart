import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const homeNavy = Color(0xFF0D1B4B);
const homeAccent = Color(0xFF4361EE);
const homeCyan = Color(0xFF00D2FF);
const homeBackground = Color(0xFFF0F2FA);

// ── Tema claro/oscuro ────────────────────────────────────────────
// Preferencia persistida por dispositivo; se carga antes de runApp.
final ValueNotifier<bool> appThemeDark = ValueNotifier<bool>(false);

bool get isDarkTheme => appThemeDark.value;

Future<void> loadThemePreference() async {
  final prefs = await SharedPreferences.getInstance();
  appThemeDark.value = prefs.getBool('dark_mode') ?? false;
}

Future<void> setThemeDark(bool dark) async {
  appThemeDark.value = dark;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('dark_mode', dark);
}

// Tokens semánticos: mismos roles que las variables CSS de SAF-WEB.
// Superficies
Color get appBg => isDarkTheme ? const Color(0xFF070A1C) : homeBackground;
Color get cardBg => isDarkTheme ? const Color(0xFF10162F) : Colors.white;
Color get cardBgAlt => isDarkTheme ? const Color(0xFF161D3E) : const Color(0xFFF8F9FC);
Color get dialogBg => isDarkTheme ? const Color(0xFF121838) : Colors.white;
Color get inputFill => isDarkTheme ? const Color(0xFF1A2148) : const Color(0xFFF5F6FA);
Color get lineCol => isDarkTheme ? const Color(0xFF272F5C) : const Color(0xFFE2E8F0);
// Texto
Color get textMain => isDarkTheme ? const Color(0xFFE9EDFF) : const Color(0xFF0D1B4B);
Color get textMid => isDarkTheme ? const Color(0xFFB9C3E8) : const Color(0xFF374151);
Color get textSoft => isDarkTheme ? const Color(0xFF8C99C6) : const Color(0xFF8899BB);
// Botón primario sólido (navy en claro, índigo visible en oscuro)
Color get btnPrimary => isDarkTheme ? const Color(0xFF4F46E5) : homeNavy;
// Chip índigo suave (fondo de badges/etiquetas)
Color get chipIndigo => isDarkTheme
    ? const Color(0xFF4F46E5).withValues(alpha: 0.22)
    : const Color(0xFFE0E7FF);
// Gradiente sutil para cards (resalta sobre el fondo oscuro)
List<Color> get cardSheen => isDarkTheme
    ? const [Color(0xFF171F44), Color(0xFF0F1531)]
    : const [Color(0xFFFDFEFF), Color(0xFFF2F5FF)];

const statisticsPageSize = 10;
const movementsPageSize = 25;
const creditsPageSize = 20;

TextStyle get dialogTextStyle => TextStyle(fontSize: 13, color: textMid);
TextStyle get dialogHintStyle => TextStyle(fontSize: 13, color: textSoft);

const homeNavigationColors = [
  Color(0xFF60A5FA),   // Inicio     — azul
  Color(0xFF34D399),   // Créditos   — verde
  Color(0xFFA78BFA),   // Ahorros    — morado
  Color(0xFFF59E0B),   // Movimientos — ámbar
  Color(0xFFFBBF24),   // Estadísticas — amarillo
];

const Map<String, String> advisorNames = {
  'AH': 'Angie Hernandez',
  'DT': 'Duvan Tapias',
  'JP': 'Jairo Pabón',
  'MD': 'Manuel De la Cruz',
  'RV': 'Rafael Vanegas',
  'SAF': 'SAF .',
  'VB': 'Victor Barros',
};

const List<(String, String, List<(String, String, bool)>)> statisticsTabs = [
  (
    'Pagan Puntual',
    'json_est_pagan_puntual',
    [
      ('Cliente', 'cliente', false),
      ('Créditos', 'cantidad', true),
      ('A tiempo', 'puntuales', true),
      ('% Puntual', 'porcentaje', true),
    ]
  ),
  (
    'Más Créditos',
    'json_est_mas_creditos',
    [
      ('Cliente', 'cliente', false),
      ('Cantidad', 'cantidad', true),
      ('Monto Total', 'monto', true),
    ]
  ),
  (
    'Mayor Monto',
    'json_est_mayor_monto',
    [
      ('Cliente', 'cliente', false),
      ('Créditos', 'cantidad', true),
      ('Monto Total', 'monto', true),
    ]
  ),
  (
    'Mayor Antigüedad',
    'json_est_mayor_antiguedad',
    [
      ('Cliente', 'cliente', false),
      ('Primer Crédito', 'fecha', false),
      ('Antigüedad', 'antiguedad', true),
    ]
  ),
  (
    'Más Retrasos',
    'json_est_mas_retrasos',
    [
      ('Cliente', 'cliente', false),
      ('Créditos', 'cantidad', true),
      ('Retrasos', 'retrasos', true),
    ]
  ),
  (
    'Nuevos Clientes',
    'json_est_nuevos_clientes',
    [
      ('Cliente', 'cliente', false),
      ('Fecha Ingreso', 'fecha', false),
      ('Primer Monto', 'monto', true),
    ]
  ),
  (
    'Mejor Scoring',
    'listado_mejor_scoring',
    [
      ('Cliente', 'cliente', false),
      ('Cantidad de Créditos', 'cantidad_creditos', true),
      ('Puntaje Total', 'puntaje_total', true),
      ('Índice Promedio', 'indice_promedio', true),
    ]
  ),
  (
    'Pagos Anticipados',
    'json_est_pagos_anticipados',
    [
      ('Cliente', 'cliente', false),
      ('Créditos', 'cantidad', true),
      ('Anticipados', 'anticipados', true),
    ]
  ),
];

Color parseHexColor(String hex) {
  final clean = hex.replaceFirst('#', '');
  final padded = clean.length == 6 ? 'FF$clean' : clean;
  return Color(int.tryParse(padded, radix: 16) ?? 0xFF4361EE);
}

double numberValue(dynamic value) => value == null
    ? 0
    : value is num
        ? value.toDouble()
        : double.tryParse(value.toString()) ?? 0;

/// Espejo de getMovIsIncome de SAF-WEB (utils/formatters.ts).
/// tipo_movimiento: 1=ingreso préstamo, 2=gasto, 3=ingreso normal.
/// Algunos endpoints devuelven el tipo en `tipo` en vez de `tipo_movimiento`.
bool movementIsIncome(Map<String, dynamic> m) {
  final tipo = (m['tipo_movimiento'] ?? m['tipo'] ?? '').toString().trim();
  if (tipo == '1' || tipo == '3') return true;
  if (tipo == '2') return false;
  // El endpoint puede devolver el tipo como texto ("Ingreso", "Gasto")
  // en `tipo` o en `tipo_nombre`, igual que contempla la web.
  final texto = '$tipo ${m['tipo_nombre'] ?? ''}'.toLowerCase();
  if (texto.contains('ingreso')) return true;
  if (texto.contains('gasto')) return false;
  if (numberValue(m['ingreso']) > 0) return true;
  if (numberValue(m['gasto']) > 0) return false;
  return false;
}

Map<String, dynamic> decodeJsonMap(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {}
  return {};
}

String formatCop(double amount) {
  final negative = amount < 0;
  final digits = amount.abs().toInt().toString();
  final formatted = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      formatted.write('.');
    }
    formatted.write(digits[index]);
  }
  return '${negative ? '-' : ''}\$ $formatted';
}

Future<DateTime?> showLightDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) =>
    showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (ctx, child) => Theme(
        data: (isDarkTheme ? ThemeData.dark() : ThemeData.light()).copyWith(
          colorScheme: isDarkTheme
              ? const ColorScheme.dark(
                  primary: Color(0xFF6366F1),
                  onPrimary: Colors.white,
                  surface: Color(0xFF121838),
                  onSurface: Color(0xFFE9EDFF),
                  onSurfaceVariant: Color(0xFFB9C3E8),
                )
              : const ColorScheme.light(
                  primary: Color(0xFF4F46E5),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Color(0xFF0D1B4B),
                  onSurfaceVariant: Color(0xFF4A5578),
                ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor:
                  isDarkTheme ? const Color(0xFF8B9CF9) : const Color(0xFF4F46E5),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: dialogBg,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
          ),
        ),
        child: child!,
      ),
    );

// ── Cierre estándar: X y botones Cancelar/Cerrar en gradiente rojo ──
const List<Color> closeRedGradient = [
  Color(0xFF991B1B),
  Color(0xFFDC2626),
  Color(0xFFF43F5E),
];

Widget appCloseX(VoidCallback? onTap, {double size = 32}) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: closeRedGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(size * 0.28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFDC2626).withValues(alpha: 0.45),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(Icons.close_rounded,
            color: Colors.white, size: size * 0.55),
      ),
    );

Widget appCancelButton(String label, VoidCallback? onTap,
        {double height = 42, double hPad = 18}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: hPad),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: closeRedGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFDC2626).withValues(alpha: 0.40),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ),
    );

/// Header estándar para los diálogos de formulario (Nuevo Movimiento,
/// Transferir, Configurar Ahorro, Crear Ahorrador, etc.): gradiente de 3
/// paradas, ícono en caja con borde/glow, título+subtítulo y botón de
/// cerrar. Unifica el estilo — antes cada diálogo definía su propio header
/// con distinto número de paradas de color y sin borde/sombra en el ícono.
Widget appDialogHeader({
  required IconData icon,
  required String title,
  required String subtitle,
  required List<Color> gradientColors,
  VoidCallback? onClose,
}) {
  final grad = gradientColors.length >= 3
      ? gradientColors
      : [
          gradientColors.first,
          Color.lerp(gradientColors.first, gradientColors.last, 0.5)!,
          gradientColors.last,
        ];
  return ClipRRect(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
    child: Stack(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: grad,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
              boxShadow: [
                BoxShadow(
                    color: Colors.white.withValues(alpha: 0.10),
                    blurRadius: 10),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontSize: 11)),
              ],
            ),
          ),
          appCloseX(onClose),
        ]),
      ),
      // Orbe decorativo — mismo lenguaje visual que el resto de la app
      Positioned(
        right: -18,
        top: -18,
        child: IgnorePointer(
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                Colors.white.withValues(alpha: 0.14),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ),
    ]),
  );
}

IconData accountIcon(String accountType) {
  final normalized = accountType.toLowerCase();
  if (normalized.contains('efectivo') || normalized.contains('caja')) {
    return Icons.payments_rounded;
  }
  if (normalized.contains('banco') ||
      normalized.contains('ahorro') ||
      normalized.contains('corriente')) {
    return Icons.account_balance_rounded;
  }
  if (normalized.contains('nequi') ||
      normalized.contains('daviplata') ||
      normalized.contains('digital')) {
    return Icons.phone_android_rounded;
  }
  if (normalized.contains('tarjeta')) {
    return Icons.credit_card_rounded;
  }
  return Icons.account_balance_wallet_rounded;
}
