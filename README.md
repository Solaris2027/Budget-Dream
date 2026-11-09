# Budget Dream — Starter Kit V3 💫

Application d'optimisation budgétaire et des achats pour particuliers (France).
Réalisez vos rêves : voiture, voyage, maison… en pilotant budget, courses et crédits.

**V3 = connexion bancaire réelle** via agrégateur agréé ACPR (Powens, ex-Linxo
Connect / Budget Insight), sans aucun statut réglementaire à votre charge :
pas d'agrément AISP, pas d'enregistrement ORIAS/SIAP — vous êtes client d'un
service (contrat commercial), l'agrégateur porte l'agrément (voir
Cadre_Reglementaire_Budget_Dream_v1.0.docx, chapitre 3).

## Architecture

```
budget-dream-starter/
├── backend/              API FastAPI (Python) — panier + crédit + banque V3
│   ├── main.py           Point d'entrée REST + montage du routeur bancaire
│   ├── models.py         Modèles Pydantic (articles, résultats, crédit)
│   ├── prices.py         Données prix de démo (4 enseignes)
│   ├── simulation.py     Moteur panier : promos par quantité, multi-enseignes (R1)
│   ├── credit.py         Moteur crédit M13 : mensualités, notaire, HCSF, verdict (R6–R10)
│   ├── bank_config.py    Config V3 : mode mock | powens via variables d'environnement
│   ├── bank_provider.py  Abstraction BankProvider (l'agrégateur est interchangeable)
│   ├── bank_mock.py      Provider démo : banques + transactions françaises simulées
│   ├── bank_powens.py    Provider Powens : webview SCA, comptes, transactions, sync
│   ├── bank_router.py    Routes /api/bank/* (M11)
│   ├── bank_categorize.py Catégorisation automatique -> catégories Budget (M1)
│   ├── bank_store.py     Persistance locale JSON (-> PostgreSQL en production)
│   └── requirements.txt
├── frontend/             Application mobile/web Flutter
│   └── budget_dream_app/
│       ├── pubspec.yaml
│       └── lib/
│           ├── main.dart                 Point d'entrée + navigation 7 onglets
│           ├── models/bank.dart          Modèles Dart banque (V3)
│           ├── services/api_service.dart Client API (fallback démo panier + crédit)
│           ├── services/bank_service.dart Client API bancaire (fallback démo V3)
│           └── screens/
│               ├── budget_screen.dart    📊 Budget du foyer + objectifs
│               ├── liste_screen.dart     📝 Liste de courses + suggestions
│               ├── simulation_screen.dart 🧮 Comparaison multi-enseignes
│               ├── banque_screen.dart    🏦 Connexion bancaire + budget auto (M11, V3)
│               ├── credit_screen.dart    🏠 Crédit immo/conso + verdict (M13)
│               ├── reves_screen.dart     💫 Mes rêves : réalisable ou pas ? (M16)
│               └── suivi_screen.dart     📈 Économies cumulées + Premium
└── README.md
```

## Prérequis

- **Git** : https://git-scm.com/downloads
- **Python 3.11+** : https://python.org
- **Flutter 3.x** : https://flutter.dev/docs/get-started/install (inclut Dart)
- Compte GitHub + Copilot (voir § "Activer Copilot" ci-dessous)

## 1. Lancer le backend en local

```bash
cd backend
python -m venv venv
source venv/bin/activate        # Windows : venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

Test : ouvrez http://localhost:8000/docs → documentation Swagger interactive.
Test rapide du module crédit (M13) — mensualité + verdict budgétaire :

```bash
curl -X POST http://localhost:8000/api/credit/simulate \
  -H "Content-Type: application/json" \
  -d '{"credit_type":"immo","price":200000,"down_payment":20000,
       "annual_rate":5.0,"years":20,"property_type":"ancien",
       "income":4500,"existing_charges":250}'
# -> verdict "tight" : endettement ~44 %, leviers proposés
```

Test rapide de la simulation :

```bash
curl -X POST http://localhost:8000/api/simulate \
  -H "Content-Type: application/json" \
  -d '{"items": [{"name": "Pâtes 500g", "qty": 4}, {"name": "Café moulu 250g", "qty": 2}]}'
```

## 2. Module bancaire V3 (M11) — mode MOCK (démo, zéro clé)

Par défaut (`BANK_MODE` non défini), le module tourne en **mock** : le flux DSP2
est simulé de bout en bout — connexion, 2 comptes réalistes, ~3 mois de
transactions françaises catégorisées, sync, purge RGPD.

```bash
# Parcours complet de démo (4 commandes) :
SID=$(curl -s -X POST http://localhost:8000/api/bank/webview \
  -H "Content-Type: application/json" -d '{"bank_id":"bnp"}' | python -c "import sys,json;print(json.load(sys.stdin)['session_id'])")
curl -s -X POST http://localhost:8000/api/bank/callback \
  -H "Content-Type: application/json" -d "{\"session_id\":\"$SID\"}" | python -m json.tool | head -20
curl -s "http://localhost:8000/api/bank/transactions?limit=5" | python -m json.tool
curl -s "http://localhost:8000/api/bank/budget-summary?period_start=2026-07-01&period_end=2026-10-31" | python -m json.tool
```

Dans l'app Flutter, l'onglet **Banque** reproduit le même parcours : bouton
« Connecter ma banque » -> comptes, solde total, budget automatique par
catégorie, transactions. L'app fonctionne aussi sans backend (démo intégrée).

## 3. Passer en mode POWENS (agrégateur réel, agréé AISP ACPR)

1. **Créer le compte sandbox** : https://portail.powens.com -> « S'inscrire »
   -> offre de développement gratuite. Récupérez `client_id` + `client_secret`.
2. **Configurer l'environnement** (voir `.env.example` à la racine de backend/) :

```bash
export BANK_MODE=powens
export POWENS_CLIENT_ID="votre_client_id"
export POWENS_CLIENT_SECRET="votre_secret"
export POWENS_API_BASE="https://sandbox-api.powens.com"   # ou votre domaine dédié
export POWENS_WEBVIEW_BASE="https://webview.powens.com"
export POWENS_REDIRECT_URI="budgetdream://bank/callback"
uvicorn main:app --reload --port 8000
```

3. **Flux de connexion réel** (déjà implémenté côté serveur dans `bank_powens.py`) :

```
App                    Backend Budget Dream              Powens (agréé ACPR)
 |-- POST /bank/webview --> crée session + token utilisateur -->
 |<-- webview_url ---------
 |-- ouvre webview -----------------------------------------> SCA chez la banque
 |     (l'utilisateur saisit ses identifiants CHEZ POWENS, jamais chez nous)
 |<-- deep link budgetdream://bank/callback?connection_uuid=... --
 |-- POST /bank/callback --> sync comptes + transactions <----
 |<-- comptes catégorisés --
```

⚠️ Les noms exacts de paramètres Powens évoluent : vérifiez `bank_powens.py`
contre la doc de votre compte sandbox (tout est centralisé dans ce fichier).
En mode powens, ajoutez `webview_flutter` au pubspec et ouvrez `webview_url`
in-app ; le deep link `POWENS_REDIRECT_URI` doit être déclaré côté
Android (AndroidManifest intent-filter) et iOS (Info.plist CFBundleURLTypes).

## 4. Lancer l'app Flutter

```bash
cd frontend/budget_dream_app
flutter pub get
flutter run                     # Chrome : flutter run -d chrome
```

L'app fonctionne même sans backend (données de démo intégrées) grâce aux
fallbacks de `api_service.dart` et `bank_service.dart`. Pour pointer vers
votre API locale : dans `lib/services/api_service.dart` ET
`lib/services/bank_service.dart`, décommentez `baseUrl = http://10.0.2.2:8000`
(Android émulateur) ou `http://localhost:8000` (Chrome/desktop).

## 5. Obtenir l'APP sur ton téléphone (Android + iPhone)

**Aucun outil à installer** : le build est automatique dans le cloud et livre
DEUX versions à chaque push :
- **Android** : onglet Actions -> Artifacts -> télécharge `budget-dream-apk`
- **iPhone** : `https://TON_PSEUDO.github.io/budget_dream/` -> Safari ->
  Partager -> « Sur l'écran d'accueil » (app Web gratuite)

Guide pas à pas complet (y compris envoyer le code avec le simple navigateur,
sans Git ni GitHub Desktop) : voir **MOBILE.md**.

## 6. Pousser sur GitHub (première fois)

```bash
# Dans le dossier budget_dream-starter
git init
git add .
git commit -m "feat: starter kit Budget Dream MVP (backend FastAPI + app Flutter)"

# Sur github.com : New repository → nom : budget_dream → NE PAS cocher README
git remote add origin https://github.com/VOTRE_PSEUDO/budget_dream.git
git branch -M main
git push -u origin main
```

## 7. Activer GitHub Copilot et bien l'utiliser

1. GitHub → Settings → Billing → **Copilot** (gratuit : *Copilot Free* 2000
   complétions/mois ; Pro ~10 $/mois ; gratuit pour étudiants).
2. VS Code → extensions → **GitHub Copilot** + **Copilot Chat**.
3. Dans VS Code : `Ctrl+Shift+P` → "Copilot" → sign in.

**Prompts efficaces pour ce projet** (à copier dans Copilot Chat) :

| Objectif | Prompt |
|----------|--------|
| Auth | « Ajoute une authentification JWT (inscription/login) à l'API FastAPI avec SQLite, fichier auth.py séparé » |
| Persistance | « Remplace les données en dur de prices.py par une table SQLAlchemy Product + endpoints CRUD » |
| Écran login | « Crée un écran de connexion Flutter avec flutter_login avant main.dart, token JWT stocké avec flutter_secure_storage » |
| Multi-magasins | « Étends simulation.py pour calculer la répartition optimale du panier sur 2 enseignes avec seuil minimal par magasin » |
| Tests | « Génère des tests pytest pour simulation.py couvrant les promos par quantité » |

Conseil : créez des **issues GitHub** par module du cahier des charges (M1 → M12)
et faites générer le code module par module — Copilot travaille beaucoup mieux par
petits lots précis que sur "fais-moi toute l'app".

## 8. Prochaines étapes (ordre recommandé V3)

- [ ] Compte sandbox Powens + passage en BANK_MODE=powens (§3 ci-dessus) ; APK mobile : voir MOBILE.md
- [ ] Webview in-app (webview_flutter) + deep link Android/iOS
- [ ] Backend : PostgreSQL + migrations (Alembic) en remplacement de bank_store.json
- [ ] Auth JWT (comptes utilisateurs) avant toute mise en ligne publique
- [ ] DPIA finale avant production (modèle rédigé dans le Cadre réglementaire v1.0)
- [ ] Abonnement Premium : RevenueCat (iOS/Android) + Stripe (web)
- [ ] CI/CD : GitHub Actions (tests pytest + `flutter analyze` à chaque push)

## Stack

Flutter 3 · FastAPI · Pydantic · httpx · Uvicorn · Powens (AISP agréé ACPR)
· (prod : PostgreSQL, Redis, Docker)
