import 'package:flutter/material.dart';

import '../models/product.dart';

/// M16 — Mes rêves : voiture, voyage, bien immobilier, électroménager…
/// Budget Dream vérifie si le rêve est réalisable avec l'épargne actuelle
/// et la capacité d'épargne mensuelle détectée depuis le budget.
class RevesScreen extends StatefulWidget {
  const RevesScreen({super.key});

  @override
  State<RevesScreen> createState() => _RevesScreenState();
}

class _Dream {
  final String type;
  final double cost;
  final int delayMonths;
  final double currentSavings;
  _Dream(this.type, this.cost, this.delayMonths, this.currentSavings);
}

class _RevesScreenState extends State<RevesScreen> {
  static const double _capaEpargne = 200.0; // détectée du budget (démo)

  final _cost = TextEditingController(text: '12000');
  final _delay = TextEditingController(text: '24');
  final _save = TextEditingController(text: '5000');
  String _type = '🚗 Voiture';
  final List<_Dream> _dreams = [];

  void _add() {
    setState(() {
      _dreams.add(_Dream(
        _type,
        double.tryParse(_cost.text) ?? 0,
        int.tryParse(_delay.text) ?? 12,
        double.tryParse(_save.text) ?? 0,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes rêves')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ajouter un rêve ✨', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text('Budget Dream vérifie s’il est réalisable avec votre épargne et votre budget.',
                      style: TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _type,
                    decoration: const InputDecoration(labelText: 'Rêve'),
                    items: const [
                      DropdownMenuItem(value: '🚗 Voiture', child: Text('🚗 Voiture')),
                      DropdownMenuItem(value: '✈️ Voyage', child: Text('✈️ Voyage')),
                      DropdownMenuItem(value: '🏠 Bien immobilier', child: Text('🏠 Bien immobilier')),
                      DropdownMenuItem(value: '🔌 Électroménager', child: Text('🔌 Électroménager')),
                      DropdownMenuItem(value: '🎁 Autre', child: Text('🎁 Autre')),
                    ],
                    onChanged: (v) => setState(() => _type = v ?? '🚗 Voiture'),
                  ),
                  TextField(controller: _cost, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Coût (€)')),
                  TextField(controller: _delay, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Échéance souhaitée (mois)')),
                  TextField(controller: _save, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Épargne actuelle (€)')),
                  const SizedBox(height: 8),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(color: Colors.black87, fontSize: 13),
                      children: [
                        TextSpan(text: 'Capacité d’épargne mensuelle : '),
                        TextSpan(text: '200 €/mois', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                        TextSpan(text: '  (détectée depuis votre budget)'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Ajouter mon rêve'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_dreams.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Aucun rêve pour le moment — ajoutez-en un ✨',
                  style: TextStyle(color: Colors.black38))),
            ),
          ..._dreams.map(_dreamCard),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.notifications_active),
            label: const Text('Activer les alertes rêves'),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const AlertDialog(
                title: Text('Démo'),
                content: Text('En production (V2) : notification dès qu’un rêve devient réalisable '
                    '(épargne suffisante ou capacité mensuelle accrue).'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dreamCard(_Dream d) {
    final needed = (d.cost - d.currentSavings).clamp(0.0, double.infinity).toDouble();
    final months = needed <= 0 ? 0 : (needed / _capaEpargne).ceil();
    final ok = months <= d.delayMonths;
    final okColor = ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: const Color(0xFF7C3AED), width: 4))),
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(d.type, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: okColor.withOpacity(0.12), borderRadius: BorderRadius.circular(99)),
              child: Text(ok ? '✅ Réalisable' : '⏳ $months mois nécessaires',
                  style: TextStyle(color: okColor, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 6),
          Text('Coût : ${eur(d.cost)} · Épargne actuelle : ${eur(d.currentSavings)} · Épargne : ${_capaEpargne.toStringAsFixed(0)} €/mois',
              style: const TextStyle(fontSize: 12.5)),
          const SizedBox(height: 4),
          Text(
            ok
                ? 'Atteignable dans $months mois — avant votre échéance de ${d.delayMonths} mois 🎉'
                : 'Il faudrait épargner ${(needed / d.delayMonths).ceil()} €/mois pour tenir l’échéance, ou visez $months mois.',
            style: const TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
          if (d.type.contains('immobilier'))
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('💡 Utilisez l’onglet Crédit pour simuler le financement (taux, notaire, mensualités).',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            ),
        ]),
      ),
    );
  }
}
