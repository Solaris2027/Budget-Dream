import 'package:flutter/material.dart';

/// M3 : liste de courses (articles + quantités, suggestions rapides).
class ListeScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cart; // {"name": String, "qty": int}
  final void Function(String name, int qty) onAdd;

  const ListeScreen({super.key, required this.cart, required this.onAdd});

  @override
  State<ListeScreen> createState() => _ListeScreenState();
}

class _ListeScreenState extends State<ListeScreen> {
  final _ctrl = TextEditingController();
  int _qty = 4;

  static const suggestions = [
    'Lait demi-écrémé 1L', 'Pain de mie complet', 'Œufs x12', 'Pâtes 500g',
    'Café moulu 250g', 'Lessive 40 doses',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ma liste (${widget.cart.length})')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(child: TextField(controller: _ctrl, decoration: const InputDecoration(hintText: 'Ajouter un article…'))),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _qty,
                    items: [1, 2, 3, 4, 6].map((q) => DropdownMenuItem(value: q, child: Text('×$q'))).toList(),
                    onChanged: (q) => setState(() => _qty = q ?? 1),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: suggestions
                .map((s) => ActionChip(label: Text('+ $s'), onPressed: () => widget.onAdd(s, _qty)))
                .toList(),
          ),
          const SizedBox(height: 12),
          ...widget.cart.map((i) => Card(
                child: ListTile(
                  title: Text(i["name"] as String),
                  trailing: Text('×${i["qty"]}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              )),
          if (widget.cart.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Liste vide — touchez une suggestion ci-dessus 👆')),
            ),
        ],
      ),
    );
  }
}
