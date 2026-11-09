"""Moteur de simulation de crédit — Budget Dream (module M13).

Implémente les règles métier R6–R10 du cahier des charges v1.1 :
- R6 : mensualité par annuités constantes  M = K.t / (1 − (1+t)^−n)
- R7 : garde-fous HCSF — taux d'endettement plafonné à 35 %, durée max 25 ans
- R8 : frais de notaire estimatifs (~7,5 % ancien / ~2,5 % neuf), ajustables
- R9 : charges mensuelles du logement par défaut (425 €), ajustables
- R10 : verdict budgétaire ✅ faisable / ⚠️ tendu / ❌ hors budget

⚠️ Le TAEG est une ESTIMATION pédagogique (hors frais de dossier/garantie
détaillés) : pour une communication commerciale il faudra un calcul
réglementaire exact (résolution par itération sur le taux actuariel).
"""

from models import CreditRequest, CreditResponse

# Plafonds réglementaires / garde-fous
MAX_DEBT_RATIO = 0.35        # recommandation HCSF
MAX_DURATION_YEARS = 25      # 27 avec différé travaux — hors MVP
MIN_LIVING_REMAINDER = 300.0  # reste à vivre minimal souhaité (€/mois)

# Charges mensuelles du logement par défaut (R9) — valeur ajustables par l'utilisateur
DEFAULT_HOUSING_CHARGES = 425.0

# Frais de notaire (R8)
NOTARY_PCT = {"ancien": 0.075, "neuf": 0.025}


def monthly_payment(capital: float, annual_rate_pct: float, years: int) -> float:
    """R6 — mensualité d'annuités constantes (hors assurance)."""
    t = annual_rate_pct / 100 / 12
    n = years * 12
    if t == 0:
        return round(capital / n, 2)
    return round(capital * t / (1 - (1 + t) ** -n), 2)


def simulate_credit(req: CreditRequest) -> CreditResponse:
    warnings: list[str] = []
    if req.years > MAX_DURATION_YEARS:
        warnings.append(f"Durée {req.years} ans > plafon recommandé {MAX_DURATION_YEARS} ans (HCSF).")

    # --- Capital emprunté & frais (R8) ---
    notary_pct = req.notary_pct if req.notary_pct is not None else NOTARY_PCT.get(req.property_type, 0.075)
    notary_fees = round(req.price * notary_pct, 2) if req.credit_type == "immo" else 0.0
    capital = req.price + notary_fees - req.down_payment
    if capital <= 0:
        capital = 0.0
        warnings.append("Apport supérieur au prix + frais : capital nul.")

    # --- Mensualités (R6) ---
    monthly = monthly_payment(capital, req.annual_rate, req.years)
    insurance_monthly = round(capital * req.insurance_annual_pct / 100 / 12, 2)
    monthly_with_ins = round(monthly + insurance_monthly, 2)
    total_cost = round(monthly_with_ins * req.years * 12, 2)
    total_interests = round(total_cost - capital, 2)

    # --- TAEG estimé (pédagogique, hors frais de dossier/garantie) ---
    taeg_est = round(req.annual_rate + req.insurance_annual_pct + (notary_fees / max(capital, 1)) * 100 / req.years, 2)

    # --- Charges logement (R9) ---
    housing = req.monthly_housing_charges if req.monthly_housing_charges is not None else (DEFAULT_HOUSING_CHARGES if req.credit_type == "immo" else 0.0)

    # --- Verdict budgétaire (R10) ---
    effort = round(monthly_with_ins + housing + req.existing_charges, 2)
    debt_ratio = round(effort / req.income, 4) if req.income else 1.0
    remainder = round(req.income - effort, 2)
    if debt_ratio > 0.45 or remainder <= 0:
        verdict, verdict_label = "no", "❌ Hors budget"
    elif debt_ratio > MAX_DEBT_RATIO or remainder < MIN_LIVING_REMAINDER:
        verdict, verdict_label = "tight", "⚠️ Tendu"
    else:
        verdict, verdict_label = "ok", "✅ Faisable"

    # --- Leviers automatiques (R10) ---
    levers: list[str] = []
    if verdict != "ok":
        longer = monthly_payment(capital, req.annual_rate, min(req.years + 5, MAX_DURATION_YEARS))
        if longer < monthly:
            levers.append(f"Allonger la durée à {min(req.years + 5, MAX_DURATION_YEARS)} ans : −{round(monthly - longer, 0):.0f} €/mois")
        for better in (req.annual_rate - 0.7,):
            if better > 0:
                m2 = monthly_payment(capital, better, req.years)
                levers.append(f"Négocier le taux à {better:.1f} % : −{round(monthly - m2, 0):.0f} €/mois")
        if req.credit_type == "immo":
            more = req.down_payment + 10000
            cap2 = req.price + notary_fees - more
            if cap2 > 0:
                m3 = monthly_payment(cap2, req.annual_rate, req.years)
                levers.append(f"Augmenter l'apport à {more/1000:.0f} k€ : −{round(monthly - m3, 0):.0f} €/mois")

    return CreditResponse(
        credit_type=req.credit_type,
        price=req.price,
        notary_fees=notary_fees,
        down_payment=req.down_payment,
        capital=capital,
        annual_rate=req.annual_rate,
        years=req.years,
        monthly=monthly,
        insurance_monthly=insurance_monthly,
        monthly_with_insurance=monthly_with_ins,
        total_cost=total_cost,
        total_interests=total_interests,
        taeg_estimate=taeg_est,
        monthly_housing_charges=housing,
        effort_total=effort,
        debt_ratio=debt_ratio,
        remainder_to_live=remainder,
        verdict=verdict,
        verdict_label=verdict_label,
        levers=levers,
        warnings=warnings,
    )
