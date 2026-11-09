/// Écran Banque — Budget Dream V3 (module M11 : connexion bancaire).
///
/// Flux DSP2 via agrégateur (mock en démo / Powens en prod) :
///   1. [Connecter ma banque] -> POST /api/bank/webview (session créée)
///   2. (mock) finalisation immédiate ; (powens) webview SCA puis deep link
///   3. Comptes + transactions importés, catégorisés automatiquement
///   4. Synthèse budgétaire alimentant le module Budget (M1)
///
/// Aucun identifiant bancaire n'est saisi dans l'app : conformité DSP2.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/bank.dart';
import '../services/bank_service.dart';

class BanqueScreen extends StatefulWidget {
  const BanqueScreen({super.key});

  @override
  State<BanqueScreen> createState() => _BanqueScreenState();
}

class _BanqueScreenState extends State<BanqueScreen> {
  static const violet = Color(0xFF7C3AED);
  static final euro = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 2);

  bool _loading = true;
  bool _connecting = false;
  BankStatus? _status;
  List<ConnectedAccount> _accounts = [];
  List<ConnectedTransaction> _transactions = [];
  BudgetSummary? _summary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await BankService.status();
      final accounts = await BankService.accounts();
      final transactions = await BankService.transactions(limit: 60);
      BudgetSummary? summary;
      if (accounts.isNotEmpty) {
        final now = DateTime.now();
        final start = DateTime(now.year, now.month - 2, 1).toIso8601String().substring(0, 10);
        final end = now.toIso8601String().substring(0, 10);
        summary = await BankService.budgetSummary(start, end);
      }
      if (!mounted) return;
      setState(() {
        _status = status;
        _accounts = accounts;
        _transactions = transactions;
        _summary = summary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "API bancaire injoignable (${e.toString().split(':').first})";
        _loading = false;
      });
    }
  }

  /// Connexion : en mode mock, session + finalisation immédiate.
  /// En mode powens, il faudra ouvrir la webview SCA puis rappeler finalize
  /// avec le connection_uuid du deep link (voir README V3, étape webview).
  Future<void> _connect() async {
    setState(() => _connecting = true);
    try {
      final sessionId = await BankService.startConnection(null);
      await Future.delayed(const Duration(milliseconds: 600)); // temps d'auth simulée
      await BankService.finalize(sessionId);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 Banque connectée — comptes et transactions importés')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connexion échouée : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Banque'),
        backgroundColor: violet,
        foregroundColor: Colors.white,
        actions: [
          if (_accounts.isNotEmpty) ...[
            IconButton(icon: const Icon(Icons.sync), tooltip: 'Synchroniser', onPressed: _sync),
            IconButton(icon: const Icon(Icons.link_off), tooltip: 'Déconnecter', onPressed: _disconnect),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _refresh)
              : _accounts.isEmpty
                  ? _EmptyState(mode: _status?.mode ?? 'mock', connecting: _connecting, onConnect: _connect)
                  : _buildConnected(context),
    );
  }

  // ---------- Vue connectée ----------
  Widget _buildConnected(BuildContext context) {
    final totalBalance = _accounts.fold<double>(0, (sum, a) => sum + a.balance);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Solde total
          Card(
            color: violet,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Solde total', style: TextStyle(color: Colors.white70)),
                  Text(euro.format(totalBalance),
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${_accounts.length} compte(s) — mode ${_status?.mode ?? "?"}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Comptes
          ..._accounts.map(_accountTile),
          const SizedBox(height: 12),

          // Synthèse budgétaire automatique (lien module M1)
          if (_summary != null) _summaryCard(_summary!),
          const SizedBox(height: 12),

          // Transactions catégorisées
          Text('Transactions récentes', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._transactions.take(30).map(_transactionTile),
        ],
      ),
    );
  }

  Widget _accountTile(ConnectedAccount a) {
    final isSavings = a.type == 'savings';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSavings ? Colors.green.shade50 : violet.withValues(alpha: 0.1),
          child: Icon(isSavings ? Icons.savings : Icons.account_balance,
              color: isSavings ? Colors.green : violet),
        ),
        title: Text(a.label),
        subtitle: a.ibanMasked != null ? Text(a.ibanMasked!) : null,
        trailing: Text(euro.format(a.balance),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }

  Widget _summaryCard(BudgetSummary s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Budget automatique (3 mois)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _kv('Revenus', euro.format(s.income), Colors.green),
                _kv('Dépenses', euro.format(s.expenses), Colors.red.shade400),
                _kv('Net', euro.format(s.net), s.net >= 0 ? Colors.green : Colors.red),
              ],
            ),
            const Divider(height: 24),
            ...s.byCategory.take(5).map((c) {
              final color = Colors.primaries[s.byCategory.indexOf(c) % Colors.primaries.length];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(c.category, style: const TextStyle(fontSize: 13)),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: c.share.clamp(0.0, 1.0),
                          backgroundColor: Colors.grey.shade200,
                          color: color,
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: Text(euro.format(c.total),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _kv(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      );

  Widget _transactionTile(ConnectedTransaction t) {
    final isIncome = t.amount >= 0;
    final cat = t.category ?? 'Autres';
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: isIncome ? Colors.green.shade50 : Colors.grey.shade100,
        child: Text(isIncome ? '＋' : '−',
            style: TextStyle(color: isIncome ? Colors.green : Colors.red.shade400, fontWeight: FontWeight.bold)),
      ),
      title: Text(t.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
      subtitle: Text('${_fmtDate(t.date)} · $cat', style: const TextStyle(fontSize: 12)),
      trailing: Text(
        '${isIncome ? "+" : ""}${euro.format(t.amount)}',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isIncome ? Colors.green : Colors.red.shade400,
        ),
      ),
    );
  }

  String _fmtDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return DateFormat('dd/MM').format(d);
    } catch (_) {
      return iso;
    }
  }

  // ---------- Actions ----------
  Future<void> _sync() async {
    if (_accounts.isEmpty) return;
    final connectionId = _accounts.first.providerAccountId.split('-ccp').first;
    try {
      final n = await BankService.sync(connectionId);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(n > 0 ? '✅ $n nouvelle(s) transaction(s)' : 'Déjà à jour')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Sync échouée : $e')));
      }
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnecter la banque ?'),
        content: const Text(
            'La connexion sera révoquée chez l\'agrégateur et toutes les données '
            'locales seront supprimées (conformité RGPD).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Déconnecter')),
        ],
      ),
    );
    if (confirmed != true || _accounts.isEmpty) return;
    try {
      await BankService.disconnect(_accounts.first.providerAccountId.split('-ccp').first);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Banque déconnectée, données purgées')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Échec : $e')));
      }
    }
  }
}

// ---------- États vides / erreur ----------
class _EmptyState extends StatelessWidget {
  final String mode;
  final bool connecting;
  final VoidCallback onConnect;

  const _EmptyState({required this.mode, required this.connecting, required this.onConnect});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Aucune banque connectée', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              mode == 'mock'
                  ? 'Mode démo : la connexion est simulée (aucune donnée réelle).\n'
                      'En production, l\'authentification se fait chez votre banque\n'
                      'via la webview sécurisée de l\'agrégateur agréé (SCA, DSP2).'
                  : 'Vous allez être redirigé vers la webview sécurisée\n'
                      'de l\'agrégateur agréé pour vous authentifier chez votre banque.\n'
                      'Budget Dream ne voit jamais vos identifiants.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
              onPressed: connecting ? null : onConnect,
              icon: connecting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.link),
              label: Text(connecting ? 'Connexion...' : 'Connecter ma banque'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
