/// Client API Budget Dream — avec fallback hors-ligne (données de démo intégrées).
/// Pour utiliser l'API locale :
///   - Chrome / desktop : http://localhost:8000
///   - Émulateur Android : http://10.0.2.2:8000
///   - Appareil physique : http://<IP-de-votre-PC>:8000
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

import '../models/product.dart';
import '../models/credit.dart';

class ApiService {
  // Mettre à null pour forcer le mode démo hors-ligne.
  static String? baseUrl = null; // ex. "http://localhost:8000"

  static Future<SimulationResult> simulate(List<CartItem> cart) async {
    if (baseUrl != null) {
      try {
        final res = await http
            .post(
              Uri.parse("$baseUrl/api/simulate"),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({
                "items": cart.map((e) => e.toJson()).toList(),
              }),
            )
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          return SimulationResult.fromJson(jsonDecode(res.body));
        }
      } catch (_) {
        // API injoignable -> fallback démo ci-dessous
      }
    }
    return _demoSimulate(cart);
  }

  /// Module M13 : simulation de crédit immo/conso + verdict budgétaire.
  static Future<CreditResult> creditSimulate(CreditRequest req) async {
    if (baseUrl != null) {
      try {
        final res = await http
            .post(
              Uri.parse("$baseUrl/api/credit/simulate"),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode(req.toJson()),
            )
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          return CreditResult.fromJson(jsonDecode(res.body));
        }
      } catch (_) {
        // API injoignable -> fallback démo ci-dessous
      }
    }
    return _demoCredit(req);
  }

  /// Réplique locale du moteur crédit (mêmes règles R6–R10 que le backend).
  static CreditResult _demoCredit(CreditRequest req) {
    final notaryPct = req.creditType == "immo"
        ? (req.propertyType == "neuf" ? 0.025 : 0.075)
        : 0.0;
    final notary = double.parse((req.price * notaryPct).toStringAsFixed(2));
    var capital = req.price + notary - req.downPayment;
    if (capital < 0) capital = 0;

    double mensualite(double k, double tauxAnnuel, int ans) {
      final r = tauxAnnuel / 100 / 12;
      final n = ans * 12;
      if (k <= 0) return 0;
      if (r == 0) return k / n;
      return k * r / (1 - math.pow(1 + r, -n));
    }

    final monthly = double.parse(mensualite(capital, req.annualRate, req.years).toStringAsFixed(2));
    final insMonthly = double.parse((capital * req.insuranceAnnualPct / 100 / 12).toStringAsFixed(2));
    final mWithIns = double.parse((monthly + insMonthly).toStringAsFixed(2));
    final housing = req.creditType == "immo" ? 425.0 : 0.0;
    final effort = double.parse((mWithIns + housing + req.existingCharges).toStringAsFixed(2));
    final debtRatio = req.income > 0 ? effort / req.income : 1.0;
    final remainder = double.parse((req.income - effort).toStringAsFixed(2));

    String verdict, verdictLabel;
    if (debtRatio > 0.45 || remainder <= 0) {
      verdict = "no";
      verdictLabel = "❌ Hors budget";
    } else if (debtRatio > 0.35 || remainder < 300) {
      verdict = "tight";
      verdictLabel = "⚠️ Tendu";
    } else {
      verdict = "ok";
      verdictLabel = "✅ Faisable";
    }

    final levers = <String>[];
    if (verdict != "ok") {
      final longerYears = req.years + 5 > 25 ? 25 : req.years + 5;
      final mLonger = mensualite(capital, req.annualRate, longerYears);
      if (mLonger < monthly - 1) {
        levers.add("Allonger la durée à $longerYears ans : −${(monthly - mLonger).round()} €/mois");
      }
      final betterRate = req.annualRate - 0.7;
      if (betterRate > 0) {
        final mBetter = mensualite(capital, betterRate, req.years);
        levers.add("Négocier le taux à ${betterRate.toStringAsFixed(1)} % : −${(monthly - mBetter).round()} €/mois");
      }
      if (req.creditType == "immo") {
        final moreDown = req.downPayment + 10000;
        final cap2 = req.price + notary - moreDown;
        if (cap2 > 0) {
          final m3 = mensualite(cap2, req.annualRate, req.years);
          levers.add("Augmenter l'apport à ${(moreDown / 1000).round()} k€ : −${(monthly - m3).round()} €/mois");
        }
      }
    }

    return CreditResult(
      notaryFees: notary,
      capital: capital,
      monthly: monthly,
      insuranceMonthly: insMonthly,
      monthlyWithInsurance: mWithIns,
      totalCost: double.parse((mWithIns * req.years * 12).toStringAsFixed(2)),
      totalInterests: double.parse((mWithIns * req.years * 12 - capital).toStringAsFixed(2)),
      taegEstimate: double.parse((req.annualRate + req.insuranceAnnualPct + (notary / (capital > 0 ? capital : 1)) * 100 / req.years).toStringAsFixed(2)),
      effortTotal: effort,
      debtRatio: double.parse(debtRatio.toStringAsFixed(4)),
      remainderToLive: remainder,
      verdict: verdict,
      verdictLabel: verdictLabel,
      levers: levers,
      warnings: const [],
    );
  }

  /// Réplique locale du moteur (mêmes règles de promo que le backend).
  static SimulationResult _demoSimulate(List<CartItem> cart) {
    const prices = {
      "Lait demi-écrémé 1L": {"Leclerc": 1.09, "Carrefour": 1.15, "Intermarché": 1.12, "Auchan": 1.19},
      "Pain de mie complet": {"Leclerc": 1.89, "Carrefour": 1.79, "Intermarché": 1.95, "Auchan": 1.85},
      "Œufs x12": {"Leclerc": 3.49, "Carrefour": 3.29, "Intermarché": 3.59, "Auchan": 3.39},
      "Pâtes 500g": {"Leclerc": 0.95, "Carrefour": 0.89, "Intermarché": 0.99, "Auchan": 0.92},
      "Café moulu 250g": {"Leclerc": 3.19, "Carrefour": 2.99, "Intermarché": 3.35, "Auchan": 3.25},
      "Lessive 40 doses": {"Leclerc": 8.90, "Carrefour": 9.50, "Intermarché": 8.75, "Auchan": 9.10},
      "Poulet entier": {"Leclerc": 5.20, "Carrefour": 5.45, "Intermarché": 5.10, "Auchan": 5.60},
      "Yaourts x8": {"Leclerc": 2.80, "Carrefour": 2.65, "Intermarché": 2.90, "Auchan": 2.75},
    };
    const promos = {
      "Pâtes 500g": {"Carrefour": [4, 30.0, "pct"]},
      "Café moulu 250g": {"Intermarché": [2, 1.50, "eur"]},
      "Yaourts x8": {"Leclerc": [3, 20.0, "pct"]},
    };
    const stores = ["Leclerc", "Carrefour", "Intermarché", "Auchan"];

    double unit(String name, String store, int qty) {
      var p = prices[name]![store]!;
      final promo = promos[name]?[store];
      if (promo != null && qty >= (promo[0] as int)) {
        if (promo[2] == "pct") {
          p *= 1 - (promo[1] as double) / 100;
        } else {
          p = (p - (promo[1] as double) / qty).clamp(0.0, double.infinity);
        }
      }
      return p;
    }

    final known = cart.where((i) => prices.containsKey(i.name)).toList();
    final totals = <String, double>{};
    for (final s in stores) {
      totals[s] = known.fold(0.0, (t, i) => t + unit(i.name, s, i.qty) * i.qty);
    }
    final best = totals.entries.reduce((a, b) => a.value <= b.value ? a : b);
    final max = totals.values.reduce((a, b) => a > b ? a : b);
    return SimulationResult(
      stores: stores.map((s) => StoreTotal(store: s, total: totals[s]!, isBest: s == best.key)).toList(),
      bestStore: best.key,
      bestTotal: best.value,
      maxTotal: max,
      savings: max - best.value,
    );
  }
}
