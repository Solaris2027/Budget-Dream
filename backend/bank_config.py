"""Configuration du module bancaire — Budget Dream V3.

Principe clé (spec architecture §BankProvider) :
- Mode "mock"    -> MockBankProvider, aucune clé requise, tout tourne en local.
- Mode "powens"  -> PowensProvider (agrégateur agréé AISP, ex-Linxo Connect).
                   Il faut les identifiants sandbox du portail Powens.

⚠️ Sécurité (RGPD / DSP2) :
- Budget Dream ne JAMAIS stocker d'identifiants bancaires : l'utilisateur
  s'authentifie chez sa banque dans la webview de l'agrégateur (flux SCA).
- On ne conserve côté serveur qu'un identifiant de connexion fourni par
  l'agrégateur, révocable à tout moment (endpoint DELETE).
"""
import os
from dataclasses import dataclass, field
from pathlib import Path

# Répertoire de persistance locale (remplacé par PostgreSQL en production)
DATA_DIR = Path(os.getenv("BUDGET_DREAM_DATA_DIR", Path(__file__).parent / "data"))


@dataclass
class BankConfig:
    """Paramètres du module bancaire, surchargés par variables d'environnement."""

    # "mock" (défaut, zéro clé) ou "powens"
    mode: str = field(default_factory=lambda: os.getenv("BANK_MODE", "mock").lower())

    # --- Powens (agrégateur agréé AISP — ex-Linxo Connect / Budget Insight) ---
    powens_client_id: str | None = field(
        default_factory=lambda: os.getenv("POWENS_CLIENT_ID")
    )
    powens_client_secret: str | None = field(
        default_factory=lambda: os.getenv("POWENS_CLIENT_SECRET")
    )
    # API principale : sandbox = https://sandbox-api.powens.com (ou biapi.pro)
    powens_api_base: str = field(
        default_factory=lambda: os.getenv(
            "POWENS_API_BASE", "https://sandbox-api.powens.com"
        )
    )
    # Webview hébergée par Powens (flux SCA DSP2 — l'utilisateur ne voit jamais
    # nos serveurs pendant la saisie de ses identifiants bancaires)
    powens_webview_base: str = field(
        default_factory=lambda: os.getenv(
            "POWENS_WEBVIEW_BASE", "https://webview.powens.com"
        )
    )
    # Deep link de retour vers l'app mobile après SCA
    powens_redirect_uri: str = field(
        default_factory=lambda: os.getenv(
            "POWENS_REDIRECT_URI", "budgetdream://bank/callback"
        )
    )

    @property
    def powens_ready(self) -> bool:
        return bool(self.powens_client_id and self.powens_client_secret)

    @property
    def effective_mode(self) -> str:
        """Le mode powens n'est activable que si les clés sont présentes."""
        if self.mode == "powens" and self.powens_ready:
            return "powens"
        return "mock"


CONFIG = BankConfig()
