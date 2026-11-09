"""Abstraction BankProvider — Budget Dream V3 (spec architecture §6/M11).

Toute la logique métier (routes FastAPI, écran Flutter) ne parle QU'À cette
interface. Changer d'agrégateur (Powens -> Tink, Bridge, agrément propre...)
ne touche donc qu'un fichier : c'est le garde-fou indépendance du projet.
"""
from abc import ABC, abstractmethod

from bank_models import (
    BankListResponse,
    ConnectResponse,
    AccountListResponse,
    SyncResponse,
    TransactionListResponse,
    WebviewResponse,
)


class BankProvider(ABC):
    """Contrat commun : mock (démo hors-ligne) et Powens (agrégateur agréé)."""

    name: str = "abstract"

    @abstractmethod
    def list_banks(self) -> BankListResponse:
        """Catalogue des banques connectables."""

    @abstractmethod
    def start_webview(self, session_id: str, bank_id: str | None) -> WebviewResponse:
        """Démarre une session de connexion et renvoie l'URL webview.

        En production (powens) : URL hébergée par l'agrégateur, l'utilisateur
        s'authentifie chez sa banque avec SCA — nous ne voyons rien.
        """

    @abstractmethod
    def finalize_connection(self, session_id: str, callback_params: dict) -> ConnectResponse:
        """Finalise la connexion après le retour de webview (deep link)."""

    @abstractmethod
    def get_accounts(self) -> AccountListResponse:
        """Comptes synchronisés (toutes connexions)."""

    @abstractmethod
    def get_transactions(self, account_id: str | None, limit: int) -> TransactionListResponse:
        """Transactions synchronisées, triées par date décroissante."""

    @abstractmethod
    def sync(self, connection_id: str) -> SyncResponse:
        """Rafraîchit une connexion auprès du fournisseur."""

    @abstractmethod
    def disconnect(self, connection_id: str) -> dict:
        """Révoque la connexion chez le fournisseur + purge locale (RGPD)."""
