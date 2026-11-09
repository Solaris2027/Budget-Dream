/// Modèles de données — Budget Dream app.

class CartItem {
  final String name;
  final int qty;

  const CartItem({required this.name, required this.qty});

  Map<String, dynamic> toJson() => {"name": name, "qty": qty};
}

class StoreTotal {
  final String store;
  final double total;
  final bool isBest;

  const StoreTotal({required this.store, required this.total, this.isBest = false});

  factory StoreTotal.fromJson(Map<String, dynamic> j) => StoreTotal(
        store: j["store"] as String,
        total: (j["total"] as num).toDouble(),
        isBest: j["is_best"] as bool? ?? false,
      );
}

class SimulationResult {
  final List<StoreTotal> stores;
  final String bestStore;
  final double bestTotal;
  final double maxTotal;
  final double savings;

  const SimulationResult({
    required this.stores,
    required this.bestStore,
    required this.bestTotal,
    required this.maxTotal,
    required this.savings,
  });

  factory SimulationResult.fromJson(Map<String, dynamic> j) => SimulationResult(
        stores: (j["stores"] as List).map((s) => StoreTotal.fromJson(s)).toList(),
        bestStore: j["best_store"] as String,
        bestTotal: (j["best_total"] as num).toDouble(),
        maxTotal: (j["max_total"] as num).toDouble(),
        savings: (j["savings"] as num).toDouble(),
      );
}

String eur(double v) => "${v.toStringAsFixed(2).replaceAll(".", ",")} €";
