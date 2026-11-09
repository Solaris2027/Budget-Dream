"""Règles de catégorisation automatique des transactions — Budget Dream V3.

Objectif : transformer les transactions brutes de la banque en catégories
du module Budget (M1), pour préremplir le budget réel de l'utilisateur.

Approche MVP volontairement DÉTERMINISTE (règles mots-clés), conforme au
choix du projet : pas de ML lourd, du code lisible et corrigeable par un solo.
Une couche d'apprentissage pourra être ajoutée en V4 si besoin.

⚠️ Les montants ne sont jamais modifiés : on ne fait qu'annoter une catégorie.
"""
import re

# Ordre = priorité de matching (le premier motif gagnant l'emporte).
# Chaque règle : (motif regex insensible à la casse, catégorie Budget Dream).
RULES: list[tuple[str, str]] = [
    # Revenus
    (r"\bsalaire|virement.*employeur|paie\b", "Revenus"),
    (r"\baides?|caf|pension|allocation\b", "Revenus"),
    # Logement
    (r"\bloyer|edf|engie|gaz|electricite|électricité|eau|free mobile|orange|sfr|bouygues telecom\b", "Logement"),
    (r"\bimmobilier|syndic|assurance.*habitat\b", "Logement"),
    # Courses (enseignes du moteur panier en priorité)
    (r"\bcarrefour|leclerc|intermarche|int. marché|lidl|aldi|super u|monoprix|franprix|casino|auchan| MATCH\b", "Courses"),
    # Restaurants / sorties
    (r"\brestaurant|mcdonald|burger|pizzeria|boulanger|cafe|café|bar\b|uber eats|deliveroo|just eat\b", "Restaurants"),
    # Transport
    (r"\bsncf|ratp|uber|bolt|essence|total.*(energie|access)|bp|aviation| parking|péage|vinci\b", "Transport"),
    # Abonnements récurrents
    (r"\bnetflix|spotify|prime video|disney|canal\+|apple\.com|google.*play|adobe|notion\b", "Abonnements"),
    # Santé
    (r"\bpharmacie|optique|dentiste|medecin|médecin|laboratoire|doctolib\b", "Santé"),
    # Loisirs
    (r"\bcinema|cinéma|fnac|decathlon|amazon|fnac\.com|king jouet|ikea|conforama\b", "Loisirs"),
    # Épargne
    (r"\blivret|epargne|épargne|virement.*livret|assurance vie\b", "Épargne"),
]

_FALLBACK = "Autres"


def categorize(label: str, amount: float) -> str:
    """Retourne la catégorie Budget Dream d'une transaction.

    - Les virements sortants vers soi-même (épargne) sont détectés par motif.
    - Un crédit (amount > 0) non reconnu est classé "Revenus" s'il dépasse
      un seuil plausible de salaire minimum, sinon "Autres".
    """
    text = (label or "").lower()
    for pattern, category in RULES:
        if re.search(pattern, text, flags=re.IGNORECASE):
            return category
    if amount > 0:
        # Revenu entrant non identifié : probable salaire/virement
        return "Revenus" if amount >= 500 else _FALLBACK
    return _FALLBACK


def summarize(transactions: list[dict], period_start: str, period_end: str) -> dict:
    """Agrège les transactions d'une période en synthèse budgétaire.

    `transactions` : liste de dicts avec clés label, amount, date (ISO).
    Retourne le format attendu par BudgetSummaryResponse.
    """
    income = 0.0
    expenses_by_cat: dict[str, float] = {}
    total_expenses = 0.0

    for tx in transactions:
        date = str(tx.get("date", ""))[:10]
        if not (period_start <= date <= period_end):
            continue
        amount = float(tx.get("amount", 0))
        if amount >= 0:
            income += amount
        else:
            cat = categorize(tx.get("label", ""), amount)
            expenses_by_cat[cat] = expenses_by_cat.get(cat, 0) + abs(amount)
            total_expenses += abs(amount)

    by_category = [
        {"category": cat, "total": round(total, 2), "share": round(total / total_expenses, 4) if total_expenses else 0.0}
        for cat, total in sorted(expenses_by_cat.items(), key=lambda kv: -kv[1])
    ]
    return {
        "period_start": period_start,
        "period_end": period_end,
        "income": round(income, 2),
        "expenses": round(total_expenses, 2),
        "net": round(income - total_expenses, 2),
        "by_category": by_category,
    }
