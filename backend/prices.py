"""Données de démo — prix par enseigne (€/unité).
⚠️ À remplacer par une vraie source de données (cf. cahier des charges §7.1) :
   API officielles enseignes / scraping encadré / crowdsourcing.
"""

PRICES: dict[str, dict[str, float]] = {
    "Lait demi-écrémé 1L": {"Leclerc": 1.09, "Carrefour": 1.15, "Intermarché": 1.12, "Auchan": 1.19},
    "Pain de mie complet": {"Leclerc": 1.89, "Carrefour": 1.79, "Intermarché": 1.95, "Auchan": 1.85},
    "Œufs x12": {"Leclerc": 3.49, "Carrefour": 3.29, "Intermarché": 3.59, "Auchan": 3.39},
    "Pâtes 500g": {"Leclerc": 0.95, "Carrefour": 0.89, "Intermarché": 0.99, "Auchan": 0.92},
    "Café moulu 250g": {"Leclerc": 3.19, "Carrefour": 2.99, "Intermarché": 3.35, "Auchan": 3.25},
    "Lessive 40 doses": {"Leclerc": 8.90, "Carrefour": 9.50, "Intermarché": 8.75, "Auchan": 9.10},
    "Poulet entier": {"Leclerc": 5.20, "Carrefour": 5.45, "Intermarché": 5.10, "Auchan": 5.60},
    "Yaourts x8": {"Leclerc": 2.80, "Carrefour": 2.65, "Intermarché": 2.90, "Auchan": 2.75},
}

STORES: list[str] = ["Leclerc", "Carrefour", "Intermarché", "Auchan"]
