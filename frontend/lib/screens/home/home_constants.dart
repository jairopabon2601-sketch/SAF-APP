import 'dart:convert';

import 'package:flutter/material.dart';

const homeNavy = Color(0xFF0D1B4B);
const homeAccent = Color(0xFF4361EE);
const homeCyan = Color(0xFF00D2FF);
const homeBackground = Color(0xFFF0F2FA);

const statisticsPageSize = 10;
const movementsPageSize = 25;
const creditsPageSize = 20;

const dialogTextStyle = TextStyle(fontSize: 13, color: Color(0xFF374151));
const dialogHintStyle = TextStyle(fontSize: 13, color: Color(0xFF9CA3AF));

const homeNavigationColors = [
  Color(0xFF60A5FA),
  Color(0xFF34D399),
  Color(0xFFA78BFA),
  Color(0xFF38BDF8),
  Color(0xFFFBBF24),
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
