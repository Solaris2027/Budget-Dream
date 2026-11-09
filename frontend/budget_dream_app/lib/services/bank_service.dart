/// Service bancaire — Budget Dream V3 (module M11).
///
/// Parle à l'API backend (/api/bank/*) — qui elle-même parle au provider
/// (mock en démo, Powens en production). Aucune logique bancaire ici :
/// l'abstraction BankProvider côté serveur garantit qu'un changement
/// d'agrégateur n'affecte ni cet écran ni le reste de l'app.
///
/// ⚠️ DSP2 : l'app ne collecte JAMAIS d'identifiants bancaires. En mode
/// powens, l'authentification se fait dans la webview de l'agrégateur (SCA).
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bank.dart';

class BankService {
  /// Même convention qu'ApiService : null = mode démo hors-ligne.
  static String? baseUrl; // ex. "http://localhost:8000"

  static const Duration _timeout = Duration(seconds: 8);

  /// État de la connexion en mode démo hors-ligne (baseUrl == null) :
  /// permet de tester tout le parcours de l'écran Banque sans backend.
  static bool _demoConnected = false;

  static bool get _offline => baseUrl == null;

  // ---------- Status ----------
  static Future<BankStatus> status() async {
    if (baseUrl != null) {
      try {
        final res = await http
            .get(Uri.parse("$baseUrl/api/bank/status"))
            .timeout(_timeout);
        if (res.statusCode == 200) return BankStatus.fromJson(jsonDecode(res.body));
      } catch (_) {}
    }
    return BankStatus(mode: 'mock', powensReady: false);
  }

  // ---------- Connexion (webview -> callback) ----------
  /// Démarre la session et, en mode mock, finalise directement.
  /// En mode powens, l'app ouvrira [webviewUrl] puis appellera
  /// [finalize] avec le connection_uuid du deep link.
  static Future<String> startConnection(String? bankId) async {
    if (_offline) {
      _demoConnected = true;
      return 'demo-session';
    }
    final res = await http
        .post(
          Uri.parse("$baseUrl/api/bank/webview"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"bank_id": bankId}),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) throw Exception("webview: ${res.statusCode}");
    return (jsonDecode(res.body) as Map<String, dynamic>)['session_id'] as String;
  }

  static Future<void> finalize(String sessionId, {String? connectionId}) async {
    if (_offline) return; // déjà "connecté" côté démo
    final res = await http
        .post(
          Uri.parse("$baseUrl/api/bank/callback"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"session_id": sessionId, "connection_id": connectionId}),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception("callback: ${res.statusCode} ${res.body}");
    }
  }

  // ---------- Consultation ----------
  static Future<List<ConnectedAccount>> accounts() async {
    if (_offline) return _demoConnected ? _demoAccounts() : [];
    try {
      final res = await http
          .get(Uri.parse("$baseUrl/api/bank/accounts"))
          .timeout(_timeout);
      if (res.statusCode != 200) return [];
      final list = (jsonDecode(res.body)['accounts'] as List? ?? []);
      return list.map((e) => ConnectedAccount.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<ConnectedTransaction>> transactions({int limit = 50}) async {
    try {
      final res = await http
          .get(Uri.parse("$baseUrl/api/bank/transactions?limit=$limit"))
          .timeout(_timeout);
      if (res.statusCode != 200) return _demoTransactions();
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['transactions'] as List? ?? [];
      if (list.isEmpty) return _demoTransactions();
      return list.map((e) => ConnectedTransaction.fromJson(e)).toList();
    } catch (_) {
      return _demoTransactions();
    }
  }

  static Future<int> sync(String connectionId) async {
    if (_offline) return 3; // démo : 3 nouvelles transactions simulées
    final res = await http
        .post(Uri.parse("$baseUrl/api/bank/sync/$connectionId"))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception("sync: ${res.statusCode}");
    return (jsonDecode(res.body)['new_transactions'] as num).toInt();
  }

  static Future<void> disconnect(String connectionId) async {
    if (_offline) {
      _demoConnected = false;
      return;
    }
    final res = await http
        .delete(Uri.parse("$baseUrl/api/bank/connections/$connectionId"))
        .timeout(_timeout);
    if (res.statusCode != 200) throw Exception("disconnect: ${res.statusCode}");
  }

  // ---------- Synthèse budgétaire automatique ----------
  static Future<BudgetSummary?> budgetSummary(
      String periodStart, String periodEnd) async {
    if (_offline) return _demoSummary();
    try {
      final res = await http
          .get(Uri.parse(
              "$baseUrl/api/bank/budget-summary?period_start=$periodStart&period_end=$periodEnd"))
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      return BudgetSummary.fromJson(jsonDecode(res.body));
    } catch (_) {
      return null;
    }
  }

  // ---------- Démo hors-ligne (API injoignable) ----------
  static List<ConnectedAccount> _demoAccounts() => const [
        ConnectedAccount(
            providerAccountId: 'demo-ccp',
            label: 'Compte courant',
            ibanMasked: 'FR76•••• •••• •••• 1234',
            balance: 1428.00,
            type: 'checking'),
        ConnectedAccount(
            providerAccountId: 'demo-livret',
            label: 'Livret A',
            balance: 4200.00,
            type: 'savings'),
      ];

  static BudgetSummary _demoSummary() => BudgetSummary(
        income: 2450.0,
        expenses: 904.79,
        net: 1545.21,
        byCategory: [
          CategoryTotal(category: 'Logement', total: 780.0, share: 0.8621),
          CategoryTotal(category: 'Courses', total: 68.3, share: 0.0755),
          CategoryTotal(category: 'Santé', total: 18.7, share: 0.0207),
          CategoryTotal(category: 'Abonnements', total: 13.49, share: 0.0149),
          CategoryTotal(category: 'Transport', total: 12.4, share: 0.0137),
        ],
      );
  static List<ConnectedTransaction> _demoTransactions() {
    final now = DateTime.now();
    final d = (int days) => now.subtract(Duration(days: days)).toIso8601String().substring(0, 10);
    const demo = [
      ["VIREMENT SALAIRE EMPLOYEUR", 2450.0, "Revenus"],
      ["E.LECLERC", -68.3, "Courses"],
      ["LOYER IMMOBILIER", -780.0, "Logement"],
      ["NETFLIX.COM", -13.49, "Abonnements"],
      ["UBER TRIP", -12.4, "Transport"],
      ["PHARMACIE CENTRALE", -18.7, "Santé"],
    ];
    return List.generate(demo.length, (i) => ConnectedTransaction(
          id: "demo-$i",
          accountId: "demo",
          label: demo[i][0] as String,
          amount: demo[i][1] as double,
          date: d(i * 3 + 1),
          category: demo[i][2] as String,
        ));
  }
}
