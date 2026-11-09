"""Moteur de simulation de panier — Budget Dream.

Implémente la règle métier R1 du cahier des charges : le moteur applique la
mécanique RÉELLE de l'offre à la quantité demandée (ex. promo "dès 4 unités"
appliquée uniquement si la quantité demandée atteint le seuil).
"""

from models import CartItem, SimulationResponse, StoreTotal
from prices import PRICES, STORES

# Promotions par quantité : {article: {enseigne: {qty, type, val}}}
# type "pct" = remise en %, type "eur" = remise en € (étalée sur le lot)
PROMOS: dict[str, dict[str, dict]] = {
    "Pâtes 500g": {"Carrefour": {"qty": 4, "type": "pct", "val": 30}},
    "Café moulu 250g": {"Intermarché": {"qty": 2, "type": "eur", "val": 1.50}},
    "Yaourts x8": {"Leclerc": {"qty": 3, "type": "pct", "val": 20}},
}


def unit_price(name: str, store: str, qty: int) -> float:
    """Prix unitaire réellement applicable pour `qty` articles chez `store`."""
    p = PRICES[name][store]
    promo = PROMOS.get(name, {}).get(store)
    if promo and qty >= promo["qty"]:
        if promo["type"] == "pct":
            p *= 1 - promo["val"] / 100
        else:  # "eur" : remise étalée sur le lot
            p = max(0.0, p - promo["val"] / qty)
    return round(p, 4)


def simulate(items: list[CartItem]) -> SimulationResponse:
    """Compare le panier sur toutes les enseignes et retourne le meilleur scénario."""
    known = [it for it in items if it.name in PRICES]
    if not known:
        raise ValueError("Aucun article reconnu dans le catalogue de démo.")

    totals = {
        store: round(sum(unit_price(it.name, store, it.qty) * it.qty for it in known), 2)
        for store in STORES
    }
    best_store = min(totals, key=totals.get)
    max_total = max(totals.values())

    return SimulationResponse(
        stores=[StoreTotal(store=s, total=t, is_best=(s == best_store)) for s, t in totals.items()],
        best_store=best_store,
        best_total=totals[best_store],
        max_total=max_total,
        savings=round(max_total - totals[best_store], 2),
    )
