# 📱 Budget Dream sur ton téléphone — Guide Mobile

Objectif : avoir **Budget Dream sur ton téléphone**, **sans installer aucun
outil de développement sur ton PC**.

| Ton téléphone | Ce que tu obtiens | Comment |
|---|---|---|
| **Android** | APK installé (vraie app) | onglet Actions → Artifacts → `budget-dream-apk` |
| **iPhone** | App Web sur l'écran d'accueil | Safari → `https://PSEUDO.github.io/budget_dream/` → Partager → Sur l'écran d'accueil |

Les deux sortent du **même build automatique GitHub** (workflow inclus dans le
starter : APK + App Web à chaque push). Aucune installation sur le PC n'est
nécessaire pour l'un ni pour l'autre.

---

## Étape 0 — Envoyer le code sur GitHub (5 min, zéro installation)

**Avec le navigateur uniquement** (pas besoin de Git ni de GitHub Desktop) :

1. Sur le PC : https://github.com/new → nom : `budget_dream` → **Public** →
   NE PAS cocher "Add a README" → **Create repository**
2. Sur la page du dépôt vide, clique le lien **"uploading an existing file"**
3. Ouvre l'Explorateur Windows dans le dossier `starter` (celui qui contient
   `.github`, `backend`, `frontend`, `MOBILE.md`) → **Ctrl+A** pour tout
   sélectionner → **glisse-dépose** les fichiers dans la zone GitHub
4. Attends que la liste affiche ~43 fichiers → bouton **"Commit changes"**
5. Le build démarre seul → onglet **Actions** → "Build APK Android + App Web"

> 💡 Alternative clics : **GitHub Desktop** (https://desktop.github.com) fait
> la même chose en 5 clics si l'installation passe (File → Add local
> repository → Create Repository → Publish). Si l'installateur échoue, la
> méthode navigateur ci-dessus marche toujours.
>
> 🔧 Si le dossier `.github` n'apparaît pas dans les fichiers uploadés :
> sur GitHub → Add file → Create new file → nomme-le
> `.github/workflows/build-apk.yml` → colle le contenu du fichier → Commit.

---

## 🤖 Android — installer l'APK (15 min de build)

1. Onglet **Actions** → run "Build APK Android + App Web" → attendre le rond vert ✅
2. Ouvre le run → en bas, **Artifacts** → télécharge **`budget-dream-apk`**
3. Dézippe → transfère `app-release.apk` sur le téléphone (Drive, e-mail, câble)
4. Touche l'APK → autorise les **sources inconnues** → Installer → c'est ta vraie app 🎉

---

## 🍎 iPhone — installer l'App Web (gratuite)

Un **APK ne s'installe PAS sur iPhone** : Apple exige une app iOS officielle
(Mac + Xcode + compte Apple Developer 99 $/an — voir "Et une vraie app iOS ?"
plus bas). En attendant, la version Web fait le travail :

1. Après le premier push : onglet **Actions** → le job **"Publication Web
   (iPhone)"** passe vert ✅ (il crée automatiquement ton site GitHub Pages)
2. Sur l'**iPhone** : ouvre **Safari** (important : pas Chrome) → va à
   `https://VOTRE_PSEUDO.github.io/budget_dream/`
   *(ton pseudo GitHub en minuscules, ex. https://solaris2027.github.io/budget_dream/)*
3. Bouton **Partager** (le carré avec une flèche vers le haut) → descends →
   **"Sur l'écran d'accueil"** → **Ajouter**
4. ✨ **Budget Dream** apparaît sur ton écran d'accueil : icône, plein écran,
   ça se lance comme une app native

**Notes iPhone :**
- L'app tourne en **mode démo** (banque simulée) immédiatement — quand le
  backend sera déployé en HTTPS public, la connexion bancaire réelle
  fonctionnera aussi depuis la version Web (M11 via agrégateur).
- Si Safari affiche une page 404 : attends 2 min après le build, ou vérifie
  Settings (du dépôt) → Pages → Source = "GitHub Actions".

---

## Brancher l'app à ton backend (optionnel, plus tard)

Par défaut `baseUrl = null` → démo intégrée. Pour brancher ton API locale :

1. trouve l'IP de ton PC (`ipconfig`, ex. `192.168.1.42`) ;
2. dans `lib/services/api_service.dart` ET `lib/services/bank_service.dart` :
   `static String? baseUrl = "http://192.168.1.42:8000";`
3. backend lancé sur le PC + téléphone sur le **même Wi-Fi** ;
4. push → nouvel APK / nouveau site. (Le workflow active déjà le HTTP non
   chiffré en dev ; en production on passera en HTTPS.)

---

## Et une vraie app iOS native ?

Nécessite : un **Mac** (Xcode obligatoire) + compte **Apple Developer**
(99 $/an) — prévu au budget année 1 du Plan d'Action Solo, au moment de la
mise sur l'App Store. L'app Web est la voie de lancement ; la version native
vient quand la traction justifie l'investissement.

---

## Récap

| Besoin | Solution | Coût |
|---|---|---|
| Tester aujourd'hui sur n'importe quel téléphone | POC HTML dans le navigateur | 0 € |
| App sur **iPhone** dès ce soir | App Web + "Sur l'écran d'accueil" | 0 € |
| App **Android** (vraie app) | APK via Actions | 0 € |
| Brancher ton backend local | baseUrl + même Wi-Fi | 0 € |
| Backend toujours accessible | déploiement Render/Fly (plus tard) | 0 € |
| Vraie app iOS native + App Store | Mac + Apple Developer | 99 $/an |
