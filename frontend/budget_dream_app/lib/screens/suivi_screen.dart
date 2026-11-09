import 'package:flutter/material.dart';

import '../models/product.dart';

/// M7 : historique, économies cumulées, écran Premium.
class SuiviScreen extends StatelessWidget {
  const SuiviScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suivi & économies')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Vos économies cumulées', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(eur(127.60), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.green)),
                  const Text('depuis janvier grâce aux comparaisons et promotions'),
                ],
              ),
            ),
          ),
          const Card(
            child: Column(
              children: [
                ListTile(dense: true, leading: Text('🛒'), title: Text('Leclerc — 24 sept.'), trailing: Text('84,20 €')),
                ListTile(dense: true, leading: Text('🛒'), title: Text('Carrefour — 17 sept.'), trailing: Text('96,75 €')),
                ListTile(dense: true, leading: Text('🛒'), title: Text('Intermarché — 10 sept.'), trailing: Text('78,10 €')),
              ],
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⭐ Premium — 3,99 €/mois', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('✓ Comparaison illimitée (9 enseignes)\n✓ Multi-magasins automatique\n✓ Alertes baisse de prix'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const AlertDialog(title: Text('Démo'), content: Text('Écran d’achat : 3,99 €/mois ou 39,99 €/an — essai 7 jours (à brancher sur RevenueCat/Stripe).')),
                    ),
                    child: const Text('Passer Premium'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
