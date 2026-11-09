import 'package:flutter/material.dart';

import '../models/credit.dart';
import '../models/product.dart';
import '../services/api_service.dart';

/// M13 — Investissement & grosses dépenses : simulation de crédit
/// immo / conso avec taux d'intérêt, notaire, charges et verdict budgétaire.
class CreditScreen extends StatefulWidget {
  const CreditScreen({super.key});

  @override
  State<CreditScreen> createState() => _CreditScreenState();
}

class _CreditScreenState extends State<CreditScreen> {
  final _price = TextEditingController(text: '200000');
  final _apport = TextEditingController(text: '20000');
  final _taux = TextEditingController(text: '5.0');
  final _ans = TextEditingController(text: '20');
  final _rev = TextEditingController(text: '4500');
  final _charges = TextEditingController(text: '250');

  String _type = 'immo';
  String _bien = 'ancien';
  CreditResult? _result;
  bool _loading = false;

  Future<void> _simulate() async {
    setState(() => _loading = true);
    final req = CreditRequest(
      creditType: _type,
      price: double.tryParse(_price.text.replaceAll(',', '.')) ?? 0,
      downPayment: _type == 'immo' ? (double.tryParse(_apport.text) ?? 0) : 0,
      annualRate: double.tryParse(_taux.text.replaceAll(',', '.')) ?? 1,
      years: int.tryParse(_ans.text) ?? 20,
      propertyType: _bien,
      income: double.tryParse(_rev.text) ?? 1,
      existingCharges: double.tryParse(_charges.text) ?? 0,
    );
    final res = await ApiService.creditSimulate(req);
    if (mounted) setState(() { _result = res; _loading = false; });
  }

  Color _verdictColor(String v) =>
      v == 'ok' ? const Color(0xFF16A34A) : (v == 'tight' ? const Color(0xFFEAB308) : const Color(0xFFEF4444));

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Investissement & grosses dépenses')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Simulation de crédit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'immo', label: Text('🏠 Immo')),
                      ButtonSegment(value: 'conso', label: Text('💳 Conso')),
                    ],
                    selected: {_type},
                    onSelectionChanged: (s) => setState(() => _type = s.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _price, keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: _type == 'immo' ? 'Prix du bien (€)' : 'Montant (€)')),
                  if (_type == 'immo')
                    TextField(controller: _apport, keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Apport (€)')),
                  TextField(controller: _taux, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Taux d’intérêt nominal (%/an)')),
                  TextField(controller: _ans, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Durée (années)')),
                  if (_type == 'immo')
                    DropdownButtonFormField<String>(
                      value: _bien,
                      decoration: const InputDecoration(labelText: 'Type de bien (frais de notaire)'),
                      items: const [
                        DropdownMenuItem(value: 'ancien', child: Text('Ancien (notaire ~7,5 %)')),
                        DropdownMenuItem(value: 'neuf', child: Text('Neuf (notaire ~2,5 %)')),
                      ],
                      onChanged: (v) => setState(() => _bien = v ?? 'ancien'),
                    ),
                  TextField(controller: _rev, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Revenus nets du foyer (€/mois)')),
                  TextField(controller: _charges, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Crédits / charges existantes (€/mois)')),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loading ? null : _simulate,
                    icon: const Icon(Icons.calculate),
                    label: Text(_loading ? 'Calcul…' : 'Puis-je l’acheter ?'),
                  ),
                ],
              ),
            ),
          ),
          if (r != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _verdictColor(r.verdict).withOpacity(0.12),
                border: Border.all(color: _verdictColor(r.verdict), width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(children: [
                Text(r.verdictLabel, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _verdictColor(r.verdict))),
                const SizedBox(height: 4),
                Text('Endettement : ${(r.debtRatio * 100).toStringAsFixed(1)} % — plafond HCSF 35 %',
                    style: const TextStyle(fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _kpi('Mensualité (avec assurance)', eur(r.monthlyWithInsurance)),
                  _kpi(_type == 'immo' ? 'Frais de notaire' : '—', _type == 'immo' ? eur(r.notaryFees) : '—'),
                  _kpi('Capital emprunté', eur(r.capital)),
                  _kpi('TAEG estimé', '${r.taegEstimate.toStringAsFixed(2).replaceAll(".", ",")} %'),
                  _kpi('Effort mensuel total', eur(r.effortTotal)),
                  _kpi('Reste à vivre', eur(r.remainderToLive)),
                  _kpi('Coût total du crédit', eur(r.totalCost)),
                ]),
              ),
            ),
            if (r.levers.isNotEmpty)
              Card(
                color: const Color(0xFFF5F3FF),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('💡 Leviers pour y arriver', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...r.levers.map((l) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text('• $l'),
                        )),
                  ]),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.handshake),
              label: const Text('Être mis en relation avec un courtier (ORIAS)'),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const AlertDialog(
                  title: Text('Courtage — M13a (V2)'),
                  content: Text('Démo : en production, cette action vous met en relation '
                      'avec un courtier partenaire immatriculé à l’ORIAS (catégorie COBSP, '
                      'sous surveillance ACPR). Budget Dream agit alors comme apporteur '
                      'd’affaires — voir cahier des charges §7.4.'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kpi(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      );
}
