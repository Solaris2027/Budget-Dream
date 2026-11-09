"""Modèles Pydantic du module bancaire — Budget Dream V3.

Alignés sur le module M11 (connexion bancaire) du cahier des charges v1.3
et sur l'abstraction BankProvider de la spec architecture.
"""
from pydantic import BaseModel, Field


# ---------- Catalogue de banques ----------

class BankInfo(BaseModel):
    id: str = Field(..., examples=["bnp"], description="Identifiant banque chez le fournisseur")
    name: str = Field(..., examples=["BNP Paribas"])
    logo_url: str | None = None
    country_code: str = "FR"


class BankListResponse(BaseModel):
    mode: str = Field(..., examples=["mock"], description="mock | powens")
    banks: list[BankInfo]


# ---------- Connexion (flux webview SCA) ----------

class WebviewRequest(BaseModel):
    bank_id: str | None = Field(None, examples=["bnp"], description="Pré-sélection optionnelle d'une banque")


class WebviewResponse(BaseModel):
    mode: str
    session_id: str = Field(..., description="Session de connexion côté Budget Dream")
    webview_url: str = Field(..., description="URL à ouvrir (webview agrégateur OU simulateur mock)")
    message: str


class CallbackRequest(BaseModel):
    session_id: str
    # En mode powens : connection_uuid renvoyé par la webview via deep link.
    # En mode mock : ignoré (la session simule elle-même la connexion).
    connection_id: str | None = None


class ConnectedAccount(BaseModel):
    provider_account_id: str
    label: str = Field(..., examples=["Compte courant"])
    iban_masked: str | None = Field(None, examples=["FR76•••• •••• •••• 1234"])
    balance: float
    currency: str = "EUR"
    type: str = "checking"  # checking | savings | card | other


class ConnectedTransaction(BaseModel):
    provider_transaction_id: str
    account_id: str
    label: str
    amount: float = Field(..., description="Négatif = dépense, positif = revenu")
    date: str = Field(..., description="ISO 8601, ex. 2026-10-12")
    category: str | None = Field(None, description="Catégorie Budget Dream auto-déduite")


class ConnectionStatus(BaseModel):
    connection_id: str
    bank_name: str
    status: str = "active"  # active | error | expired
    last_sync: str
    accounts: list[ConnectedAccount] = []


class ConnectResponse(BaseModel):
    mode: str
    connection: ConnectionStatus
    transactions_imported: int


# ---------- Consultation / synchronisation ----------

class AccountListResponse(BaseModel):
    mode: str
    accounts: list[ConnectedAccount]


class TransactionListResponse(BaseModel):
    mode: str
    transactions: list[ConnectedTransaction]
    total: int


class SyncResponse(BaseModel):
    connection_id: str
    status: str
    new_transactions: int
    last_sync: str


# ---------- Synthèse budgétaire automatique (lien avec module M1) ----------

class CategoryTotal(BaseModel):
    category: str
    total: float
    share: float = Field(..., description="Part des dépenses totales (0-1)")


class BudgetSummaryResponse(BaseModel):
    period_start: str
    period_end: str
    income: float
    expenses: float
    net: float
    by_category: list[CategoryTotal]
    mode: str
