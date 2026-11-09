import 'package:flutter/material.dart';

import 'screens/budget_screen.dart';
import 'screens/liste_screen.dart';
import 'screens/simulation_screen.dart';
import 'screens/credit_screen.dart';
import 'screens/banque_screen.dart';
import 'screens/reves_screen.dart';
import 'screens/suivi_screen.dart';

void main() => runApp(const BudgetDreamApp());

class BudgetDreamApp extends StatelessWidget {
  const BudgetDreamApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Budget Dream',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C3AED)),
          useMaterial3: true,
        ),
        home: const HomeShell(),
      );
}

/// Coquille principale : navigation 7 onglets
/// (Budget / Liste / Panier / Banque / Crédit / Rêves / Suivi)
/// — V3 : onglet Banque (M11) branché sur l'agrégateur (mock ou Powens).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final List<Map<String, dynamic>> _cart = []; // [{"name":..., "qty":...}]

  void addToCart(String name, int qty) => setState(() {
        _cart.add({"name": name, "qty": qty});
      });

  @override
  Widget build(BuildContext context) {
    final screens = [
      const BudgetScreen(),
      ListeScreen(cart: _cart, onAdd: addToCart),
      SimulationScreen(cart: _cart),
      const BanqueScreen(),
      const CreditScreen(),
      const RevesScreen(),
      const SuiviScreen(),
    ];
    return Scaffold(
      body: screens[_index],
      // BottomNavigationBar compact : 7 onglets tiennent sur les petits
      // écrans mobiles (NavigationBar M3 déborde au-delà de 5 libellés).
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Budget'),
          BottomNavigationBarItem(icon: Icon(Icons.edit_note), label: 'Liste'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calculate_outlined),
              activeIcon: Icon(Icons.calculate),
              label: 'Panier'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_outlined),
              activeIcon: Icon(Icons.account_balance),
              label: 'Banque'),
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Crédit'),
          BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome_outlined),
              activeIcon: Icon(Icons.auto_awesome),
              label: 'Rêves'),
          BottomNavigationBarItem(
              icon: Icon(Icons.trending_up), label: 'Suivi'),
        ],
      ),
    );
  }
}
