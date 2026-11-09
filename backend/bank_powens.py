"""Provider POWENS (agrégateur agréé AISP) — Budget Dream V3.

Powens = marque unifiée Budget Insight + Linxo Connect, agréée AISP par
l'ACPR. Budget Dream n'exerce AUCUNE activité réglementée : il est client
d'un service (contrat commercial), ce qui nous évite tout enregistrement
ACPR/ORIAS/SIAP — contrairement à la voie "agent AISP".

Flux DSP2 implémenté (webview hébergée, SCA chez la banque) :
1. POST {api}/auth/token/init           -> token utilisateur Powens
2. URL webview  {webview}/connect?...   -> l'utilisateur s'authentifie
   chez SA banque (nous ne voyons JAMAIS ses identifiants)
3. Deep link de retour ?connection_uuid=... -> finalisation
4. GET /connections, /accounts, /transactions -> synchronisation
5. DELETE /connections/{id} -> révocation (RGPD)

⚠️ Les noms exacts de champs évoluant chez l'agrégateur, tous les chemins
sont centralisés ici et vérifiables en 1 seul fichier. À valider contre la
doc officielle de votre compte sandbox avant la mise en production.
"""
import uuid

import httpx

from bank_config import CONFIG
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

TIMEOUT = httpx.Timeout(30.0)


class PowensError(RuntimeError):
    """Erreur côté agrégateur (réseau, refus API, contrat absent...)."""


class PowensProvider(BankProvider):
    name = "powens"

    def __init__(self, store: BankStore):
        self.store = store

    # ---------- HTTP helpers ----------

    def _headers(self, bearer: str | None = None) -> dict:
        headers = {"Content-Type": "application/json"}
        if bearer:
            headers["Authorization"] = f"Bearer {bearer}"
        return headers

    def _create_user_token(self) -> str:
        """Crée (ou réutilise) l'utilisateur Powens et renvoie son access_token.

        Le token reste STRICTEMENT côté serveur (jamais envoyé au mobile) :
        c'est lui qui donne accès aux données de comptes chez l'agrégateur.
        """
        cached = self.store.get_meta("powens_user_token")
        if cached:
            return cached
        resp = httpx.post(
            f"{CONFIG.powens_api_base}/auth/token/init",
            json={
                "client_id": CONFIG.powens_client_id,
                "client_secret": CONFIG.powens_client_secret,
            },
            headers=self._headers(),
            timeout=TIMEOUT,
        )
        if resp.status_code != 200:
            raise PowensError(f"auth/token/init {resp.status_code}: {resp.text[:200]}")
        token = resp.json().get("access_token")
        if not token:
            raise PowensError("access_token absent de la réponse Powens")
        self.store.save_meta("powens_user_token", token)
        return token

    # ---------- BankProvider ----------

    def list_banks(self) -> BankListResponse:
        token = self._create_user_token()
        resp = httpx.get(
            f"{CONFIG.powens_api_base}/banks",
            headers=self._headers(token),
            params={"limit": 200, "country_code": "FR"},
            timeout=TIMEOUT,
        )
        if resp.status_code != 200:
            raise PowensError(f"banks {resp.status_code}: {resp.text[:200]}")
        banks = [
            BankInfo(
                id=str(b.get("id")),
                name=b.get("name", "?"),
                logo_url=b.get("logo") or b.get("url_logo"),
                country_code=b.get("country_code", "FR"),
            )
            for b in resp.json().get("banks", [])
        ]
        return BankListResponse(mode=self.name, banks=banks)

    def start_webview(self, session_id: str, bank_id: str | None) -> WebviewResponse:
        token = self._create_user_token()
        # La session mémorise le token serveur pour la finalisation ;
        # le mobile ne reçoit QUE l'URL webview publique.
        self.store.save_session(session_id, {"bearer": token, "bank_id": bank_id})
        params = [
            f"client_id={CONFIG.powens_client_id}",
            f"redirect_uri={CONFIG.powens_redirect_uri}",
            f"bearer={token}",
        ]
        if bank_id:
            params.append(f"bank_id={bank_id}")
        url = f"{CONFIG.powens_webview_base}/connect?" + "&".join(params)
        return WebviewResponse(
            mode=self.name,
            session_id=session_id,
            webview_url=url,
            message=(
                "Ouvrez cette URL dans une webview in-app (webview_flutter) ou un "
                "navigateur externe. Au retour, le deep link "
                f"{CONFIG.powens_redirect_uri} transmet connection_uuid : "
                "appelez POST /api/bank/callback avec session_id + connection_uuid."
            ),
        )

    def finalize_connection(self, session_id: str, callback_params: dict) -> ConnectResponse:
        session = self.store.get_session(session_id)
        if session is None:
            raise KeyError("session inconnue")
        connection_uuid = callback_params.get("connection_uuid") or callback_params.get("connection_id")
        if not connection_uuid:
            raise ValueError("connection_uuid manquant dans le deep link")
        bearer = session.get("bearer") or self._create_user_token()

        # Détail de la connexion côté agrégateur
        resp = httpx.get(
            f"{CONFIG.powens_api_base}/connections/{connection_uuid}",
            headers=self._headers(bearer),
            timeout=TIMEOUT,
        )
        if resp.status_code != 200:
            raise PowensError(f"connections/{connection_uuid} {resp.status_code}: {resp.text[:200]}")
        conn = resp.json()

        status = ConnectionStatus(
            connection_id=str(connection_uuid),
            bank_name=conn.get("bank", {}).get("name", "Banque"),
            status="active" if conn.get("state") in (None, 0, "0") else "error",
            last_sync=conn.get("last_update", "")[:10] or "",
            accounts=[],
        )

        # Comptes rattachés à cette connexion
        resp = httpx.get(
            f"{CONFIG.powens_api_base}/accounts",
            headers=self._headers(bearer),
            params={"connection_id": connection_uuid, "limit": 50},
            timeout=TIMEOUT,
        )
        if resp.status_code == 200:
            for acc in resp.json().get("accounts", []):
                status.accounts.append(ConnectedAccount(
                    provider_account_id=str(acc.get("id")),
                    label=acc.get("name", "Compte"),
                    iban_masked=(acc.get("iban") or "")[:4] + "••••" if acc.get("iban") else None,
                    balance=float(acc.get("balance", 0)),
                    currency=acc.get("currency", "EUR"),
                    type=self._map_account_type(acc.get("type")),
                ))

        # Première importation des transactions (90 jours glissants)
        txs = self._fetch_transactions(bearer, status.accounts, limit=500)
        self.store.save_connection(status, txs)
        self.store.delete_session(session_id)
        return ConnectResponse(mode=self.name, connection=status, transactions_imported=len(txs))

    def get_accounts(self) -> AccountListResponse:
        accounts: list[ConnectedAccount] = []
        for conn in self.store.list_connections():
            accounts.extend(ConnectedAccount(**a) for a in conn["accounts"])
        return AccountListResponse(mode=self.name, accounts=accounts)

    def get_transactions(self, account_id: str | None, limit: int) -> TransactionListResponse:
        txs = self.store.list_transactions(account_id)
        txs.sort(key=lambda t: t["date"], reverse=True)
        return TransactionListResponse(
            mode=self.name,
            transactions=[ConnectedTransaction(**t) for t in txs[:limit]],
            total=len(txs),
        )

    def sync(self, connection_id: str) -> SyncResponse:
        conn = self.store.get_connection(connection_id)
        if conn is None:
            raise KeyError("connexion inconnue")
        bearer = self.store.get_meta("powens_user_token") or self._create_user_token()

        # Demande de synchronisation chez l'agrégateur
        resp = httpx.post(
            f"{CONFIG.powens_api_base}/connections/{connection_id}/sync",
            headers=self._headers(bearer),
            timeout=TIMEOUT,
        )
        # 2xx attendu ; certaines versions renvoient 202 (sync asynchrone)
        if resp.status_code not in (200, 202):
            raise PowensError(f"sync {resp.status_code}: {resp.text[:200]}")

        before = {t["provider_transaction_id"] for t in self.store.list_transactions(None)}
        accounts = [ConnectedAccount(**a) for a in conn["accounts"]]
        fetched = self._fetch_transactions(bearer, accounts, limit=500)
        new_txs = [t for t in fetched if t["provider_transaction_id"] not in before]
        self.store.append_transactions(new_txs)
        conn["last_sync"] = fetched[0]["date"] if fetched else conn.get("last_sync", "")
        self.store.update_connection(conn)
        return SyncResponse(
            connection_id=connection_id,
            status=conn["status"],
            new_transactions=len(new_txs),
            last_sync=conn["last_sync"],
        )

    def disconnect(self, connection_id: str) -> dict:
        bearer = self.store.get_meta("powens_user_token")
        if bearer:
            # Révocation chez l'agrégateur (l'utilisateur peut aussi le faire
            # directement chez sa banque — DSP2 lui en donne le droit)
            try:
                httpx.delete(
                    f"{CONFIG.powens_api_base}/connections/{connection_id}",
                    headers=self._headers(bearer),
                    timeout=TIMEOUT,
                )
            except httpx.HTTPError:
                pass  # la purge locale reste garantie
        self.store.delete_connection(connection_id)
        return {"connection_id": connection_id, "revoked": True, "local_data_purged": True}

    # ---------- internes ----------

    def _fetch_transactions(self, bearer: str, accounts: list[ConnectedAccount], limit: int) -> list[dict]:
        """Importe les transactions récentes, catégorisées à la française."""
        out: list[dict] = []
        for acc in accounts:
            resp = httpx.get(
                f"{CONFIG.powens_api_base}/transactions",
                headers=self._headers(bearer),
                params={"account_id": acc.provider_account_id, "limit": min(limit, 500)},
                timeout=TIMEOUT,
            )
            if resp.status_code != 200:
                continue  # un compte illisible ne bloque pas les autres
            for tx in resp.json().get("transactions", []):
                label = tx.get("original_wording") or tx.get("simplified_wording") or tx.get("wording", "?")
                amount = float(tx.get("value", 0))
                out.append({
                    "provider_transaction_id": str(tx.get("id") or uuid.uuid4()),
                    "account_id": acc.provider_account_id,
                    "label": label,
                    "amount": amount,
                    "date": str(tx.get("date", ""))[:10],
                    "category": categorize(label, amount),
                })
        return out

    @staticmethod
    def _map_account_type(powens_type) -> str:
        mapping = {1: "checking", 2: "card", 3: "savings", 4: "savings", 5: "other"}
        if isinstance(powens_type, int):
            return mapping.get(powens_type, "other")
        return "other"
