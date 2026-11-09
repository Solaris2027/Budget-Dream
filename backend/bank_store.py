"""Persistance locale du module bancaire — Budget Dream V3.

Stockage JSON simple (backend/data/bank_store.json) :
- suffisant pour le starter et la démo ;
- interface volontairement étroite (save/get/list/delete) pour être
  remplacée proprement par PostgreSQL + SQLAlchemy en production,
  conformément à la spec architecture (schéma bank_connections,
  bank_accounts, bank_transactions).

⚠️ RGPD : ce fichier ne contient AUCUN identifiant bancaire utilisateur —
uniquement des identifiants techniques côté fournisseur + montants/libellés
nécessaires au budget. Supprimé intégralement par DELETE /api/bank/...
"""
import json
import threading
import time
from pathlib import Path

from bank_config import DATA_DIR


class BankStore:
    def __init__(self, path: Path | None = None):
        self.path = path or (DATA_DIR / "bank_store.json")
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._lock = threading.Lock()
        self._data = {"sessions": {}, "connections": {}, "transactions": [], "meta": {}}
        self._load()

    # ----- Meta (tokens agrégateur — STRICTEMENT côté serveur) -----
    def save_meta(self, key: str, value: str) -> None:
        with self._lock:
            self._data["meta"][key] = value
            self._flush()

    def get_meta(self, key: str) -> str | None:
        return self._data.get("meta", {}).get(key)

    # ----- IO -----
    def _load(self) -> None:
        if self.path.exists():
            try:
                self._data = json.loads(self.path.read_text(encoding="utf-8"))
            except (json.JSONDecodeError, OSError):
                # Fichier corrompu : on repart propre plutôt que de crasher
                self._data = {"sessions": {}, "connections": {}, "transactions": [], "meta": {}}

    def _flush(self) -> None:
        tmp = self.path.with_suffix(".tmp")
        tmp.write_text(json.dumps(self._data, ensure_ascii=False, indent=1), encoding="utf-8")
        tmp.replace(self.path)

    # ----- Sessions (en attente de webview) -----
    def save_session(self, session_id: str, payload: dict) -> None:
        with self._lock:
            self._data["sessions"][session_id] = {**payload, "created_at": time.time()}
            self._flush()

    def get_session(self, session_id: str) -> dict | None:
        return self._data["sessions"].get(session_id)

    def delete_session(self, session_id: str) -> None:
        with self._lock:
            self._data["sessions"].pop(session_id, None)
            self._flush()

    # ----- Connexions -----
    def save_connection(self, status, transactions: list[dict]) -> None:
        with self._lock:
            self._data["connections"][status.connection_id] = status.model_dump()
            self._data["transactions"].extend(transactions)
            self._flush()

    def get_connection(self, connection_id: str) -> dict | None:
        return self._data["connections"].get(connection_id)

    def list_connections(self) -> list[dict]:
        return list(self._data["connections"].values())

    def update_connection(self, conn: dict) -> None:
        with self._lock:
            self._data["connections"][conn["connection_id"]] = conn
            self._flush()

    def delete_connection(self, connection_id: str) -> None:
        with self._lock:
            self._data["connections"].pop(connection_id, None)
            self._data["transactions"] = [
                t for t in self._data["transactions"]
                if not t["provider_transaction_id"].startswith(connection_id)
            ]
            self._flush()

    # ----- Transactions -----
    def list_transactions(self, account_id: str | None) -> list[dict]:
        if account_id is None:
            return list(self._data["transactions"])
        return [t for t in self._data["transactions"] if t["account_id"] == account_id]

    def append_transactions(self, txs: list[dict]) -> None:
        if not txs:
            return
        with self._lock:
            self._data["transactions"].extend(txs)
            self._flush()
