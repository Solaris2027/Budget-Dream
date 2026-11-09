"""Modèles Pydantic — Budget Dream API."""
from pydantic import BaseModel, Field


class CartItem(BaseModel):
    name: str = Field(..., examples=["Pâtes 500g"])
    qty: int = Field(..., gt=0, examples=[4])


class SimulationRequest(BaseModel):
    items: list[CartItem]


class StoreTotal(BaseModel):
    store: str
    total: float
    is_best: bool = False


class SimulationResponse(BaseModel):
    stores: list[StoreTotal]
    best_store: str
    best_total: float
    max_total: float
    savings: float
    currency: str = "EUR"


# ---------- Module M13 : crédit immobilier / consommation ----------

class CreditRequest(BaseModel):
    credit_type: str = Field(..., examples=["immo"], description="immo | conso")
    price: float = Field(..., examples=[200000])
    down_payment: float = Field(0.0, examples=[20000])
    annual_rate: float = Field(..., examples=[5.0], description="taux nominal annuel en %")
    years: int = Field(..., examples=[20])
    insurance_annual_pct: float = Field(0.10, examples=[0.10])
    property_type: str = Field("ancien", examples=["ancien"], description="ancien | neuf (frais de notaire)")
    income: float = Field(..., examples=[4500], description="revenus nets mensuels du foyer")
    existing_charges: float = Field(0.0, examples=[250])
    notary_pct: float | None = None          # override R8
    monthly_housing_charges: float | None = None  # override R9


class CreditResponse(BaseModel):
    credit_type: str
    price: float
    notary_fees: float
    down_payment: float
    capital: float
    annual_rate: float
    years: int
    monthly: float
    insurance_monthly: float
    monthly_with_insurance: float
    total_cost: float
    total_interests: float
    taeg_estimate: float
    monthly_housing_charges: float
    effort_total: float
    debt_ratio: float
    remainder_to_live: float
    verdict: str          # ok | tight | no
    verdict_label: str      # ✅ Faisable | ⚠️ Tendu | ❌ Hors budget
    levers: list[str]
    warnings: list[str]
