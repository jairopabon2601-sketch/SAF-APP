import 'dart:async';

import 'package:flutter/material.dart';

import '../repositories/home_repository.dart';

/// Estado compartido por las secciones de la pantalla principal.
///
/// Las vistas viven en archivos independientes y operan sobre este
/// controlador mediante extensiones importables, sin utilizar `part of`.
abstract class HomeController<T extends StatefulWidget> extends State<T>
    with SingleTickerProviderStateMixin {
  late final AnimationController shimmer;

  final HomeRepository repository = HomeRepository();

  bool balanceVisible = true;
  int selectedIndex = 0;
  int movementSubTab = 0;
  int creditSubTab = 0;

  int statisticsSubTab = 6;
  final Map<String, String> statisticsFilters = {};
  bool statisticsLoading = false;
  List<Map<String, dynamic>> statisticsData = [];
  int statisticsPage = 0;
  Timer? filterDebounce;

  String accountFilter = '';
  String movementTypeFilter = '';
  DateTime? filterFrom;
  DateTime? filterTo;
  int movementsPage = 1;
  List<Map<String, dynamic>> selectedAccountMovements = [];
  String selectedAccountMovementsName = '';
  bool selectedAccountMovementsLoading = false;

  double serverExpenses = 0;
  double serverIncome = 0;
  bool serverTotalsLoaded = false;
  double filteredExpenses = 0;
  double filteredIncome = 0;
  bool filteredTotalsLoaded = false;

  String creditStatusFilter = '';
  String creditAdvisorFilter = '';
  String creditsBuscar = '';
  bool queryingCredits = false;
  int creditsPage = 1;
  int creditsTotal = 0;
  double creditsPaidTotal = 0;
  double creditsPendingTotal = 0;

  List<Map<String, dynamic>> pendingRequests = [];
  int pendingPage = 1;
  int pendingTotal = 0;
  bool pendingLoading = false;
  bool pendingLoaded = false;
  String? pendingError;

  List<Map<String, dynamic>> debtors = [];
  List<Map<String, dynamic>> rates = [];
  List<Map<String, dynamic>> sources = [];
  List<Map<String, dynamic>> advisors = [];

  String sourceStatisticsStatus = '';
  DateTime? sourceStatisticsFrom;
  DateTime? sourceStatisticsTo;
  String sourceStatisticsAccount = '0';
  bool sourceStatisticsLoading = false;

  double simulationMonths = 12;
  double simulationAmount = 1000000;
  double simulationRate = 10;
  DateTime? simulationFrom;
  DateTime? simulationTo;

  bool isAdmin = false;
  bool isAsesor = false;         // perfil 1: solo ve sus propios ahorradores
  bool isCreditsProfile = false; // perfil 5: créditos y movimientos
  String codigoOrigen = ''; // ID del asesor/perfil vinculado (codigo_origen del login)

  // Indices de pantalla visibles según perfil (0=Inicio,1=Créditos,2=Ahorros,3=Movimientos)
  List<int> allowedScreenIndices = [0, 1, 2, 3];
  bool menuOptionsLoaded = false;
  bool creditsDataLoaded = false; // true cuando creditsPaidTotal/Pending están listos

  /// Convierte índice de tab visible → índice de pantalla real.
  int screenIndexAt(int displayIndex) {
    if (displayIndex < 0 || displayIndex >= allowedScreenIndices.length) return 0;
    return allowedScreenIndices[displayIndex];
  }

  bool loadingData = true;
  List<Map<String, dynamic>> accounts = [];
  List<Map<String, dynamic>> movements = [];
  List<Map<String, dynamic>> savers = [];
  List<Map<String, dynamic>> creditStatistics = [];
  String savingsYearFilter = DateTime.now().year.toString();
  String savingsAdvisorFilter = '0';
  int savingsCurrentPage = 1;
  static const int savingsPageSize = 10;
  List<Map<String, dynamic>> credits = [];
  final Set<String> expandedCredits = {};
  final Set<String> expandedPending = {};

  double? cachedBalanceTotal;
  double? cachedIncomeTotal;
  double? cachedExpenseTotal;
  List<Map<String, dynamic>>? cachedFilteredSavers;
  String? cachedSavingsAdvisorFilter;

  BuildContext get screenContext => context;
  bool get isMounted => mounted;

  void refresh(VoidCallback callback) {
    if (mounted) {
      setState(callback);
    }
  }

  Widget skelBox(double w, double h, {double r = 10}) => AnimatedBuilder(
        animation: shimmer,
        builder: (_, __) {
          final c = Color.lerp(
              const Color(0xFFCED7EE), const Color(0xFFDDE5F5), shimmer.value)!;
          return Container(
            width: w == double.infinity ? null : w,
            height: h,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(r),
            ),
          );
        },
      );
}
