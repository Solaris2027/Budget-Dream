/// Modèles module M13 — crédit immobilier / consommation (Budget Dream).
///
/// Miroir du backend `credit.py` (règles métier R6–R10 du cahier des charges).

class CreditRequest {
  final String creditType; // immo | conso
  final double price;
  final double downPayment;
  final double annualRate; // taux nominal annuel en %
  final int years;
  final double insuranceAnnualPct;
  final String propertyType; // ancien | neuf
  final double income;
  final double existingCharges;

  const CreditRequest({
    required this.creditType,
    required this.price,
    this.downPayment = 0,
    required this.annualRate,
    required this.years,
    this.insuranceAnnualPct = 0.10,
    this.propertyType = 'ancien',
    required this.income,
    this.existingCharges = 0,
  });

  Map<String, dynamic> toJson() => {
        "credit_type": creditType,
        "price": price,
        "down_payment": downPayment,
        "annual_rate": annualRate,
        "years": years,
        "insurance_annual_pct": insuranceAnnualPct,
        "property_type": propertyType,
        "income": income,
        "existing_charges": existingCharges,
      };
}

class CreditResult {
  final double notaryFees;
  final double capital;
  final double monthly;
  final double insuranceMonthly;
  final double monthlyWithInsurance;
  final double totalCost;
  final double totalInterests;
  final double taegEstimate;
  final double effortTotal;
  final double debtRatio;
  final double remainderToLive;
  final String verdict; // ok | tight | no
  final String verdictLabel;
  final List<String> levers;
  final List<String> warnings;

  const CreditResult({
    required this.notaryFees,
    required this.capital,
    required this.monthly,
    required this.insuranceMonthly,
    required this.monthlyWithInsurance,
    required this.totalCost,
    required this.totalInterests,
    required this.taegEstimate,
    required this.effortTotal,
    required this.debtRatio,
    required this.remainderToLive,
    required this.verdict,
    required this.verdictLabel,
    required this.levers,
    required this.warnings,
  });

  factory CreditResult.fromJson(Map<String, dynamic> j) => CreditResult(
        notaryFees: (j["notary_fees"] as num).toDouble(),
        capital: (j["capital"] as num).toDouble(),
        monthly: (j["monthly"] as num).toDouble(),
        insuranceMonthly: (j["insurance_monthly"] as num).toDouble(),
        monthlyWithInsurance: (j["monthly_with_insurance"] as num).toDouble(),
        totalCost: (j["total_cost"] as num).toDouble(),
        totalInterests: (j["total_interests"] as num).toDouble(),
        taegEstimate: (j["taeg_estimate"] as num).toDouble(),
        effortTotal: (j["effort_total"] as num).toDouble(),
        debtRatio: (j["debt_ratio"] as num).toDouble(),
        remainderToLive: (j["remainder_to_live"] as num).toDouble(),
        verdict: j["verdict"] as String,
        verdictLabel: j["verdict_label"] as String,
        levers: (j["levers"] as List).cast<String>(),
        warnings: (j["warnings"] as List).cast<String>(),
      );
}
