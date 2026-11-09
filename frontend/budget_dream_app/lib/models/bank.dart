/// Modèles du module bancaire — Budget Dream V3 (M11).
/// Alignés sur backend/bank_models.py.

class BankInfo {
  final String id;
  final String name;
  final String? logoUrl;

  BankInfo({required this.id, required this.name, this.logoUrl});

  factory BankInfo.fromJson(Map<String, dynamic> j) => BankInfo(
        id: j['id'] as String,
        name: j['name'] as String,
        logoUrl: j['logo_url'] as String?,
      );
}

class ConnectedAccount {
  final String providerAccountId;
  final String label;
  final String? ibanMasked;
  final double balance;
  final String type; // checking | savings | card | other

  ConnectedAccount({
    required this.providerAccountId,
    required this.label,
    this.ibanMasked,
    required this.balance,
    required this.type,
  });

  factory ConnectedAccount.fromJson(Map<String, dynamic> j) => ConnectedAccount(
        providerAccountId: j['provider_account_id'] as String,
        label: j['label'] as String,
        ibanMasked: j['iban_masked'] as String?,
        balance: (j['balance'] as num).toDouble(),
        type: (j['type'] ?? 'other') as String,
      );
}

class ConnectedTransaction {
  final String id;
  final String accountId;
  final String label;
  final double amount; // négatif = dépense
  final String date; // ISO
  final String? category;

  ConnectedTransaction({
    required this.id,
    required this.accountId,
    required this.label,
    required this.amount,
    required this.date,
    this.category,
  });

  factory ConnectedTransaction.fromJson(Map<String, dynamic> j) =>
      ConnectedTransaction(
        id: j['provider_transaction_id'] as String,
        accountId: j['account_id'] as String,
        label: j['label'] as String,
        amount: (j['amount'] as num).toDouble(),
        date: (j['date'] ?? '') as String,
        category: j['category'] as String?,
      );
}

class BankStatus {
  final String mode; // mock | powens
  final bool powensReady;

  BankStatus({required this.mode, required this.powensReady});

  factory BankStatus.fromJson(Map<String, dynamic> j) => BankStatus(
        mode: (j['mode'] ?? 'mock') as String,
        powensReady: (j['powens_ready'] ?? false) as bool,
      );
}

class BudgetSummary {
  final double income;
  final double expenses;
  final double net;
  final List<CategoryTotal> byCategory;

  BudgetSummary({
    required this.income,
    required this.expenses,
    required this.net,
    required this.byCategory,
  });

  factory BudgetSummary.fromJson(Map<String, dynamic> j) => BudgetSummary(
        income: (j['income'] as num).toDouble(),
        expenses: (j['expenses'] as num).toDouble(),
        net: (j['net'] as num).toDouble(),
        byCategory: (j['by_category'] as List? ?? [])
            .map((c) => CategoryTotal.fromJson(c))
            .toList(),
      );
}

class CategoryTotal {
  final String category;
  final double total;
  final double share;

  CategoryTotal({required this.category, required this.total, required this.share});

  factory CategoryTotal.fromJson(Map<String, dynamic> j) => CategoryTotal(
        category: j['category'] as String,
        total: (j['total'] as num).toDouble(),
        share: (j['share'] as num).toDouble(),
      );
}
