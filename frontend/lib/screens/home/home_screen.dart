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

class _HomeScreenState extends HomeController<HomeScreen> {
  @override
  void initState() {
    super.initState();
    shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    loadData();
  }

  @override
  void dispose() {
    shimmer.dispose();
    filterDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Buenos días'
        : hour < 18
            ? 'Buenas tardes'
            : 'Buenas noches';
    final firstName = fullName.split(' ').first;

    return Scaffold(
      backgroundColor: homeBackground,
      extendBody: true,
      bottomNavigationBar: buildHomeBottomNavigation(),
      body: CustomScrollView(
        slivers: [
          buildHomeAppBar(),
          SliverToBoxAdapter(
            child: _buildTabContent(greeting, firstName),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      ),
    );
  }

  Widget _buildTabContent(String greeting, String firstName) {
    switch (selectedIndex) {
      case 0:
        return buildDashboard(greeting, firstName);
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
