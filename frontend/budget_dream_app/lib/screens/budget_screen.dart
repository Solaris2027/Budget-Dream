import 'package:flutter/material.dart';

import '../models/product.dart';

/// M1–M2 : tableau de bord budget du foyer.
class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  static const double _budget = 480.0;
  static const double _spent = 89.30;

  @override
  Widget build(BuildContext context) {
    final pct = _spent / _budget;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Dream'),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 12), child: Center(child: Text('Sophie · Famille Martin', style: TextStyle(fontSize: 12)))),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.green.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('💡 En optimisant votre panier cette semaine, vous pouvez économiser jusqu’à 38,45 €'),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Budget courses du mois', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(eur(_spent), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                  Text('sur ${eur(_budget)} — reste à vivre : ${eur(_budget - _spent)}'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: pct, minHeight: 10, borderRadius: BorderRadius.circular(99)),
                ],
              ),
            ),
          ),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Objectifs du foyer', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  ListTile(dense: true, leading: Text('🛒'), title: Text('Courses alimentaires'), trailing: Text('480 € max')),
                  ListTile(dense: true, leading: Text('💰'), title: Text('Épargne mensuelle'), trailing: Text('+200 €')),
                ],
              ),
            ),
          ),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dernières activités', style: TextStyle(fontWeight: FontWeight.bold)),
                  ListTile(dense: true, leading: Text('🛒'), title: Text('Panier validé — Leclerc'), trailing: Text('−84,20 €')),
                  ListTile(dense: true, leading: Text('🏷️'), title: Text('Promo détectée : café −30 %'), trailing: Text('−3,90 €', style: TextStyle(color: Colors.green))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
