"""Budget Dream API — point d'entrée FastAPI (V3 : + module bancaire)."""
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from models import SimulationRequest, SimulationResponse, CreditRequest, CreditResponse
from prices import PRICES, STORES
from simulation import simulate
from credit import simulate_credit
from bank_router import router as bank_router

app = FastAPI(
    title="Budget Dream API",
    description=(
        "API Budget Dream : simulation crédit (M13), optimisation panier (M3) "
        "et connexion bancaire via agrégateur agréé (M11) — mode mock ou Powens."
    ),
    version="0.3.0",
)

# Autorise l'app Flutter (Chrome dev, émulateurs) à appeler l'API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # À restreindre en production
    allow_methods=["*"],
    allow_headers=["*"],
)

# Module bancaire V3 (M11) : mock (démo) ou Powens (agrégateur agréé AISP)
app.include_router(bank_router)


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok", "service": "budget-dream-api", "version": "0.3.0"}


@app.get("/api/products")
def list_products() -> dict:
    """Catalogue de démo : articles + prix par enseigne."""
    return {"stores": STORES, "products": PRICES}


@app.post("/api/credit/simulate", response_model=CreditResponse)
def run_credit_simulation(req: CreditRequest) -> CreditResponse:
    """Module M13 : simulation de crédit immo/conso + verdict budgétaire.

    Exemple : maison 200 000 €, ancien, apport 20 000 €, taux 5 %, 20 ans,
    revenus 4 500 €, charges existantes 250 € -> verdict "tight" (endettement 41,7 %).
    """
    return simulate_credit(req)


@app.post("/api/simulate", response_model=SimulationResponse)
def run_simulation(req: SimulationRequest) -> SimulationResponse:
    """Simule le panier et compare les enseignes (promos par quantité incluses)."""
    try:
        return simulate(req.items)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
