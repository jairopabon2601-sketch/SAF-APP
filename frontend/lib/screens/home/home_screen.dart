import 'package:flutter/material.dart';

import '../../controllers/home_actions.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/home_data_controller.dart';
import '../../widgets/home/home_app_bar.dart';
import '../../widgets/home/home_bottom_navigation.dart';
import 'credits_screen.dart';
import 'dashboard_screen.dart';
import 'home_constants.dart';
import 'movements_screen.dart';
import 'savings_screen.dart';
import 'statistics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends HomeController<HomeScreen>
    with WidgetsBindingObserver {
  // loadData() solo corría una vez, al montar la pantalla — si el usuario
  // dejaba la app en segundo plano un buen rato (sin que el proceso llegara
  // a morir del todo) y volvía, los totales de balance se quedaban en $0
  // hasta desloguear y volver a entrar. Ahora, al reanudar, si pasó más de
  // un minuto en background se vuelve a pedir todo — igual que el re-login.
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // El cliente pidió bajarle la velocidad al barrido de luz en general
    // (antes 1000ms de ida/vuelta se sentía muy rápido y saturaba la UX en
    // varias pantallas). 2600ms da un barrido notoriamente más calmado.
    shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    loadData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt != null &&
          DateTime.now().difference(pausedAt) > const Duration(minutes: 1)) {
        loadData();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    shimmer.dispose();
    filterDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hourColombia =
        DateTime.now().toUtc().subtract(const Duration(hours: 5)).hour;
    final greeting = hourColombia < 12
        ? 'Buenos días'
        : hourColombia < 18
            ? 'Buenas tardes'
            : 'Buenas noches';
    final firstName = fullName.split(' ').first;

    return Scaffold(
      backgroundColor: appBg,
      extendBody: true,
      bottomNavigationBar: buildHomeBottomNavigation(),
      body: RefreshIndicator(
        onRefresh: () async {
          // Antes solo volvía a pedir créditos — cuentas, movimientos,
          // ahorradores y los totales de balance (Inicio/Movimientos)
          // nunca se refrescaban, así que deslizar hacia abajo no arreglaba
          // el "$0" que queda tras un resume largo; solo desloguear y
          // volver a entrar disparaba loadData() de nuevo. Ahora el pull
          // to refresh llama exactamente lo mismo que ese re-login.
          await loadData();
          if (isMounted) refresh(() {});
        },
        color: const Color(0xFF4338CA),
        child: CustomScrollView(
          slivers: [
            buildHomeAppBar(),
            SliverToBoxAdapter(
              child: _buildTabContent(greeting, firstName),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(String greeting, String firstName) {
    switch (screenIndexAt(selectedIndex)) {
      case 0:
        return isAsesor
            ? buildAsesorDashboard(greeting, firstName)
            : isCreditsProfile
                ? buildCreditsDashboard(greeting, firstName)
                : buildDashboard(greeting, firstName);
      case 1:
        return buildCreditsScreen();
      case 2:
        return buildSavingsScreen();
      case 3:
        return buildMovementsScreen();
      case 4:
        return buildStatisticsScreen();
      default:
        return const SizedBox();
    }
  }
}
