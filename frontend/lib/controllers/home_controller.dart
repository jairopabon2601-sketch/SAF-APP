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

  bool loadingData = true;
  List<Map<String, dynamic>> accounts = [];
  List<Map<String, dynamic>> movements = [];
  List<Map<String, dynamic>> savers = [];
  List<Map<String, dynamic>> creditStatistics = [];
  String savingsYearFilter = DateTime.now().year.toString();
  String savingsAdvisorFilter = '0';
  List<Map<String, dynamic>> credits = [];
  final Set<String> expandedCredits = {};

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
}
