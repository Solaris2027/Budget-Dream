"""Provider MOCK — Budget Dream V3.

Simule fidèlement le flux DSP2 d'un agrégateur, sans aucune clé :
1. start_webview       -> renvoie une URL "simulateur" locale.
2. finalize_connection -> crée une connexion avec 2 comptes réalistes
                          (compte courant + Livret A) et 3 mois de
                          transactions françaises déterministes.
3. sync                -> ajoute de nouvelles transactions (mois suivant).

Usage : démo, développement, tests automatisés, screens vidéo.
Aucune donnée réelle, aucune donnée sensible : tout est généré.
"""
import hashlib
from datetime import date, timedelta

from bank_models import (
    AccountListResponse,
    BankInfo,
    BankListResponse,
    ConnectResponse,
    ConnectionStatus,
    ConnectedAccount,
    ConnectedTransaction,
    SyncResponse,
    TransactionListResponse,
    WebviewResponse,
)
from bank_provider import BankProvider
from bank_store import BankStore
from bank_categorize import categorize

# Catalogue de banques françaises de démo
MOCK_BANKS = [
    {"id": "bnp", "name": "BNP Paribas", "country_code": "FR"},
    {"id": "ca", "name": "Crédit Agricole", "country_code": "FR"},
    {"id": "sg", "name": "Société Générale", "country_code": "FR"},
    {"id": "lcl", "name": "LCL", "country_code": "FR"},
    {"id": "poste", "name": "La Banque Postale", "country_code": "FR"},
    {"id": "ing", "name": "ING (banque en ligne)", "country_code": "FR"},
]

# Marchands / libellés déterministes : (motif, montant moyen, catégorie)
_EXPENSE_PATTERNS = [
    ("CARREFOUR MARKET", 42.5, "Courses"),
    ("E.LECLERC", 68.3, "Courses"),
    ("LIDL", 31.2, "Courses"),
    ("EDF", 54.9, "Logement"),
    ("LOYER IMMOBILIER", 780.0, "Logement"),
    ("SNCF CONNECT", 46.0, "Transport"),
    ("UBER TRIP", 12.4, "Transport"),
    ("NETFLIX.COM", 13.49, "Abonnements"),
    ("SPOTIFY FRANCE", 10.99, "Abonnements"),
    ("PHARMACIE CENTRALE", 18.7, "Santé"),
    ("BRASSERIE DU COIN", 24.5, "Restaurants"),
    ("UBER EATS", 19.9, "Restaurants"),
    ("DECATHLON", 35.0, "Loisirs"),
    ("AMAZON.FR", 27.8, "Loisirs"),
    ("FREE MOBILE", 19.99, "Logement"),
]


class MockBankProvider(BankProvider):
    name = "mock"

    def __init__(self, store: BankStore):
        self.store = store

    # ----- Catalogue -----
    def list_banks(self) -> BankListResponse:
        return BankListResponse(
            mode=self.name,
            banks=[BankInfo(**b) for b in MOCK_BANKS],
        )

    # ----- Session webview simulée -----
    def start_webview(self, session_id: str, bank_id: str | None) -> WebviewResponse:
        bank = next((b for b in MOCK_BANKS if b["id"] == bank_id), None)
        self.store.save_session(session_id, {"bank_id": bank["id"] if bank else None})
        return WebviewResponse(
            mode=self.name,
            session_id=session_id,
            webview_url=f"/simulate-bank-auth?session={session_id}",
            message=(
                "Mode MOCK : la connexion est simulée. "
                f"{('Banque pré-sélectionnée : ' + bank['name']) if bank else 'Aucune banque pré-sélectionnée'}. "
                "Appelez POST /api/bank/callback avec ce session_id pour finaliser."
            ),
        )

    # ----- Finalisation : génération déterministe -----
    def finalize_connection(self, session_id: str, callback_params: dict) -> ConnectResponse:
        session = self.store.get_session(session_id)
        if session is None:
            raise KeyError("session inconnue")

        bank_id = session.get("bank_id") or "bnp"
        bank_name = next(b["name"] for b in MOCK_BANKS if b["id"] == bank_id)
        connection_id = f"mock-{hashlib.sha1(session_id.encode()).hexdigest()[:10]}"

        accounts = [
            ConnectedAccount(
                provider_account_id=f"{connection_id}-ccp",
                label="Compte courant",
                iban_masked=f"FR76•••• •••• •••• {hashlib.sha1(bank_id.encode()).hexdigest()[:4].upper()}",
                balance=round(1280.0 + (int(connection_id[-1], 16) * 37), 2),
                type="checking",
            ),
            ConnectedAccount(
                provider_account_id=f"{connection_id}-livret",
                label="Livret A",
                iban_masked=None,
                balance=4200.0,
                type="savings",
            ),
        ]

        # 3 mois de transactions déterministes sur le compte courant
        txs: list[ConnectedTransaction] = []
        today = date.today()
        for month_back in range(3):
            month_date = today.replace(day=1) - timedelta(days=30 * month_back)
            # Salaire le 28 du mois précédent
            salary_day = (month_date - timedelta(days=4)).isoformat()
            txs.append(ConnectedTransaction(
                provider_transaction_id=f"{connection_id}-sal-{month_back}",
                account_id=accounts[0].provider_account_id,
                label="VIREMENT SALAIRE EMPLOYEUR",
                amount=2450.0,
                date=salary_day,
                category="Revenus",
            ))
            seed = int(hashlib.sha1(f"{connection_id}-{month_back}".encode()).hexdigest()[:8], 16)
            for i, (label, base_amount, _cat) in enumerate(_EXPENSE_PATTERNS):
                jitter = ((seed >> i) % 21 - 10) / 100.0  # ±10 % déterministe
                amount = round(base_amount * (1 + jitter), 2)
                day = 2 + (i * 2) % 26
                tx_date = month_date.replace(day=min(day, 28)).isoformat()
                txs.append(ConnectedTransaction(
                    provider_transaction_id=f"{connection_id}-{month_back}-{i}",
                    account_id=accounts[0].provider_account_id,
                    label=label,
                    amount=-amount,
                    date=tx_date,
                    category=categorize(label, -amount),
                ))

        # Alimentation du Livret A (épargne) : 100 €/mois
        for month_back in range(3):
            month_date = today.replace(day=1) - timedelta(days=30 * month_back)
            txs.append(ConnectedTransaction(
                provider_transaction_id=f"{connection_id}-ep-{month_back}",
                account_id=accounts[1].provider_account_id,
                label="VIREMENT LIVRET EPARGNE",
                amount=100.0,
                date=month_date.replace(day=5).isoformat(),
                category="Épargne",
            ))

        status = ConnectionStatus(
            connection_id=connection_id,
            bank_name=bank_name,
            status="active",
            last_sync=date.today().isoformat(),
            accounts=accounts,
        )
        self.store.save_connection(status, [t.model_dump() for t in txs])
        self.store.delete_session(session_id)
        return ConnectResponse(mode=self.name, connection=status, transactions_imported=len(txs))

    # ----- Consultation -----
    def get_accounts(self) -> AccountListResponse:
        accounts: list[ConnectedAccount] = []
        for conn in self.store.list_connections():
            accounts.extend(ConnectedAccount(**a) for a in conn["accounts"])
        return AccountListResponse(mode=self.name, accounts=accounts)

    def get_transactions(self, account_id: str | None, limit: int) -> TransactionListResponse:
        txs = self.store.list_transactions(account_id)
        txs.sort(key=lambda t: t["date"], reverse=True)
        limited = txs[:limit]
        return TransactionListResponse(
            mode=self.name,
            transactions=[ConnectedTransaction(**t) for t in limited],
            total=len(txs),
        )

    # ----- Synchronisation : ajoute le "mois suivant" -----
    def sync(self, connection_id: str) -> SyncResponse:
        conn = self.store.get_connection(connection_id)
        if conn is None:
            raise KeyError("connexion inconnue")
        existing = {t["provider_transaction_id"] for t in self.store.list_transactions(None)}
        today = date.today()
        new_txs: list[dict] = []
        seed = int(hashlib.sha1(f"{connection_id}-sync-{today}".encode()).hexdigest()[:8], 16)
        for i, (label, base_amount, _cat) in enumerate(_EXPENSE_PATTERNS):
            tid = f"{connection_id}-sync-{today.isoformat()}-{i}"
            if tid in existing:
                continue
            jitter = ((seed >> i) % 21 - 10) / 100.0
            amount = round(base_amount * (1 + jitter), 2)
            new_txs.append({
                "provider_transaction_id": tid,
                "account_id": conn["accounts"][0]["provider_account_id"],
                "label": label,
                "amount": -amount,
                "date": today.isoformat(),
                "category": categorize(label, -amount),
            })
        self.store.append_transactions(new_txs)
        conn["last_sync"] = today.isoformat()
        self.store.update_connection(conn)
        return SyncResponse(
            connection_id=connection_id,
            status="active",
            new_transactions=len(new_txs),
            last_sync=conn["last_sync"],
        )

    def disconnect(self, connection_id: str) -> dict:
        self.store.delete_connection(connection_id)
        return {"connection_id": connection_id, "revoked": True, "local_data_purged": True}
