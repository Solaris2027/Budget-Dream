import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/api_service.dart';

/// M4–M6 : simulation du panier + comparaison multi-enseignes + recommandation.
class SimulationScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cart;

  const SimulationScreen({super.key, required this.cart});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  SimulationResult? _result;
  bool _loading = false;

  Future<void> _run() async {
    setState(() => _loading = true);
    final cart = widget.cart
        .map((i) => CartItem(name: i["name"] as String, qty: i["qty"] as int))
        .toList();
    final res = await ApiService.simulate(cart);
    if (mounted) setState(() { _result = res; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Simulation du panier')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.cart.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('⬅️ Ajoutez d’abord des articles dans l’onglet Liste')),
              ),
            ),
          if (widget.cart.isNotEmpty)
            FilledButton.icon(
              onPressed: _loading ? null : _run,
              icon: const Icon(Icons.rocket_launch),
              label: Text(_loading ? 'Calcul en cours…' : 'Lancer la simulation'),
            ),
          const SizedBox(height: 12),
          if (r != null) ...[
            Card(
              child: Column(
                children: [
                  for (final s in r.stores)
                    Container(
                      decoration: s.isBest
                          ? BoxDecoration(border: Border.all(color: Colors.green, width: 2), borderRadius: BorderRadius.circular(12))
                          : null,
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        dense: true,
                        title: Text(s.store, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: s.isBest ? const Text('🏆 Option optimale', style: TextStyle(color: Colors.green)) : null,
                        trailing: Text(eur(s.total), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                ],
              ),
            ),
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '💰 Économie réalisable : ${eur(r.savings)} entre l’enseigne la plus chère (${eur(r.maxTotal)}) et ${r.bestStore} (${eur(r.bestTotal)}).',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
