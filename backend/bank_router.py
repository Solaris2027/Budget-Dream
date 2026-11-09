"""Routes API du module bancaire — Budget Dream V3 (module M11).

Sélection du provider : mock par défaut (zéro clé), powens si
BANK_MODE=powens + clés sandbox présentes dans l'environnement.

RGPD :
- Aucun identifiant bancaire ne transite jamais par ces routes.
- DELETE /api/bank/connections/{id} purge tout (révocation + données locales).
"""
import uuid

from fastapi import APIRouter, HTTPException, Query

from bank_config import CONFIG
from bank_store import BankStore
from bank_mock import MockBankProvider
from bank_powens import PowensProvider, PowensError
from bank_categorize import summarize
from bank_models import (
    CallbackRequest,
    WebviewRequest,
    BudgetSummaryResponse,
)

store = BankStore()
providers = {
    "mock": MockBankProvider(store),
    "powens": PowensProvider(store),
}
PROVIDER = providers[CONFIG.effective_mode]

router = APIRouter(prefix="/api/bank", tags=["banque (M11)"])


def _fail(err: Exception) -> HTTPException:
    if isinstance(err, KeyError):
        return HTTPException(status_code=404, detail=str(err))
    if isinstance(err, (PowensError, ValueError)):
        return HTTPException(status_code=502, detail=str(err))
    return HTTPException(status_code=500, detail=f"Erreur bancaire interne : {err}")


@router.get("/status")
def bank_status() -> dict:
    """Mode actif du module bancaire + disponibilité du provider réel."""
    return {
        "mode": PROVIDER.name,
        "configured_mode": CONFIG.mode,
        "powens_ready": CONFIG.powens_ready,
        "note": "mode mock = démo sans clé ; mode powens = agrégateur agréé ACPR",
    }


@router.get("/banks")
def list_banks():
    """Catalogue des banques connectables."""
    try:
        return PROVIDER.list_banks().model_dump()
    except Exception as e:  # noqa: BLE001
        raise _fail(e) from e


@router.post("/webview")
def start_webview(req: WebviewRequest):
    """Étape 1 : démarre une session de connexion bancaire.

    Renvoie webview_url à ouvrir (webview in-app ou navigateur externe).
    En mode powens, l'utilisateur s'authentifie chez sa banque avec SCA :
    Budget Dream ne voit jamais ses identifiants.
    """
    session_id = uuid.uuid4().hex
    try:
        return PROVIDER.start_webview(session_id, req.bank_id).model_dump()
    except Exception as e:  # noqa: BLE001
        raise _fail(e) from e


@router.post("/callback")
def finalize(req: CallbackRequest):
    """Étape 2 : finalise la connexion après le retour de webview.

    - mode mock   : crée la connexion de démonstration (2 comptes + ~45 tx).
    - mode powens : récupère la connexion via connection_uuid du deep link.
    """
    try:
        return PROVIDER.finalize_connection(
            req.session_id, callback_params={"connection_uuid": req.connection_id}
        ).model_dump()
    except Exception as e:  # noqa: BLE001
        raise _fail(e) from e


@router.get("/accounts")
def get_accounts():
    """Comptes synchronisés, toutes connexions confondues."""
    try:
        return PROVIDER.get_accounts().model_dump()
    except Exception as e:  # noqa: BLE001
        raise _fail(e) from e


@router.get("/transactions")
def get_transactions(
    account_id: str | None = Query(None, description="Filtrer par compte"),
    limit: int = Query(100, ge=1, le=500),
):
    """Transactions synchronisées, triées par date décroissante."""
    try:
        return PROVIDER.get_transactions(account_id, limit).model_dump()
    except Exception as e:  # noqa: BLE001
        raise _fail(e) from e


@router.post("/sync/{connection_id}")
def sync(connection_id: str):
    """Rafraîchit une connexion : nouvelles transactions depuis la banque."""
    try:
        return PROVIDER.sync(connection_id).model_dump()
    except Exception as e:  # noqa: BLE001
        raise _fail(e) from e


@router.delete("/connections/{connection_id}")
def disconnect(connection_id: str):
    """Révoque la connexion chez l'agrégateur et purge les données locales (RGPD)."""
    try:
        return PROVIDER.disconnect(connection_id)
    except Exception as e:  # noqa: BLE001
        raise _fail(e) from e


@router.get("/budget-summary", response_model=BudgetSummaryResponse)
def budget_summary(
    period_start: str = Query(..., description="AAAA-MM-JJ"),
    period_end: str = Query(..., description="AAAA-MM-JJ"),
):
    """Synthèse budgétaire automatique : catégories Budget Dream (M1)
    calculées depuis les transactions bancaires de la période."""
    try:
        txs = store.list_transactions(None)
        result = summarize(txs, period_start, period_end)
        result["mode"] = PROVIDER.name
        return BudgetSummaryResponse(**result)
    except Exception as e:  # noqa: BLE001
        raise _fail(e) from e
