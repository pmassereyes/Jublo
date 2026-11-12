# Jublo

App iPhone partagée par un couple (Pablo et Julie) : pense-bête, courses, wish list, agenda,
cagnotte, vacances envisagées, sorties à tester, compteur de retards, « ce mois-ci, j'aimerais
que tu… », corbeille, puis un assistant IA local.

## Feuille de route

- **Phase 1 (en cours)** : app locale, SwiftData, Listes et Corbeille fonctionnelles, autres
  onglets avec données d'exemple.
- **Phase 2** : synchronisation CloudKit entre les deux identifiants Apple via **CKSyncEngine**
  et une zone partagée en entier (CKShare de zone).
- **Phase 3 (assistant, faite avant la phase 2)** : discussion en lecture seule sur les listes,
  via une API au format « chat completions » d'OpenAI. Le fournisseur se choisit dans les
  réglages (Mistral, DeepSeek, Gemini, ou Ollama chez nous via `tailscale serve`). La
  passerelle FastAPI prévue au départ est abandonnée : Ollama parle déjà ce format. Prochaine
  étape possible : proposer des ajouts aux listes.

## Décisions d'architecture

- SwiftUI, **iOS 17 minimum**, Swift 6, offline-first, iPhone uniquement.
- **Aucune donnée privée** : tout est partagé entre les deux membres.
- **Persistance : SwiftData + CKSyncEngine (phase 2).** SwiftData ne sait pas synchroniser une
  base CloudKit partagée : même dans le SDK iOS 27, `ModelConfiguration.CloudKitDatabase` ne
  propose que `.automatic`, `.none` et `.private`. NSPersistentCloudKitContainer a été écarté.
  Il impose deux stores (privé et partagé), un rangement manuel de chaque nouvel objet, et ses
  écritures côté participant sont réputées fragiles. Julie écrit autant que Pablo.
- **Pas de dépendance externe** (SPM, CocoaPods, outils de génération) sans l'accord de Pablo.
  Le projet Xcode utilise des dossiers synchronisés : ajouter un fichier dans un dossier suffit.
  Seule exception déclarée dans le projet : `Jublo/Info.plist` (qui liste les polices) est
  exclu de la copie des ressources.

### Invariants de la phase 1 qui préparent la phase 2

Ne pas les casser :

1. `cloudKitDatabase: .none` dans `Persistance`. Avec `.automatic`, SwiftData activerait son
   miroir privé dès l'ajout du droit iCloud, en conflit avec CKSyncEngine.
2. **Toutes les écritures passent par `Depot`**. En phase 2, c'est là qu'on signalera les
   changements à CKSyncEngine. Les vues ne modifient jamais un modèle directement.
3. Chaque modèle a un `id: UUID` stable, futur nom d'enregistrement CloudKit.
4. Contraintes compatibles CloudKit : toutes les propriétés sont optionnelles ou ont une valeur
   par défaut, aucun `@Attribute(.unique)`, relations optionnelles.
5. Schéma versionné. `SchemaActuel` désigne la version courante (aujourd'hui `SchemaV2`), et
   `PlanMigrationJublo` liste les versions et les étapes de migration. Toute évolution passe
   par une nouvelle version : on copie le modèle modifié dans `SchemaVn`, on fige l'ancien, et
   on ajoute une étape et un test dans `MigrationTests`. Un modèle inchangé reste déclaré dans
   la dernière version où il a changé (`Cagnotte` et `Versement` sont dans `SchemaV1`).
   On ne modifie jamais une version publiée.
6. Montants en centimes (`Int`), énumérations stockées en `String` (`typeBrut`).

## Modèles

- Chaque élément porte `auteurId`, `creeLe`, `modifieLe`, `supprimeLe: Date?` et
  `supprimePar: String?`. C'est le protocole `Suppressible`.
- **Suppression douce** : `Depot.supprimer` remplit `supprimeLe` et `supprimePar`, et
  `Depot.restaurer` les remet à `nil`. Au lancement, `Depot.purger()` supprime définitivement
  les éléments supprimés depuis plus de 30 jours.
- **Un nouveau type `Suppressible` doit être ajouté à `Depot.elementsDansLaCorbeille()`** et à
  la `CorbeilleView`, sinon il n'est ni affiché ni purgé.
- **Versements de la cagnotte** : ils ne sont pas `Suppressible` et ne sont **jamais purgés**.
  Une annulation remplit `annuleLe` et `annulePar`, le versement reste dans l'historique et est
  exclu du solde. Une cagnotte supprimée qui a des versements n'est jamais purgée
  (`estPurgeable`).
- `Membre` (`pablo` / `julie`) est une énumération. `auteurId` stocke sa valeur brute.
- **Wish list par membre** : chaque envie a un destinataire (`pourId`, depuis la V2). Par
  défaut, c'est l'auteur ; on peut aussi noter une idée pour l'autre. Une envie sans
  `pourId`, créée avant la V2, est celle de son auteur (`destinataire`,
  `ElementListe.envies(pour:)`).

## Assistant

- `Core/Assistant/` : `ClientCompatibleOpenAI` (flux SSE, erreurs traduites en messages
  clairs), `Fournisseur` (préréglages : adresse, modèle modifiable), `ConfigurationAssistant`
  et `ContexteAssistant` (consignes envoyées avec chaque question : qui parle, date, listes hors
  corbeille, 40 éléments au plus par section). `Features/Assistant/` : `Discussion` (en
  mémoire, non partagée), `AssistantView`, `ReglagesAssistantView`.
- Réglages **propres à chaque iPhone** : fournisseur, adresse et modèle dans `UserDefaults`.
  La clé d'API est dans le trousseau, une par fournisseur, `ThisDeviceOnly`. Elle n'est
  jamais dans le code ni dans le dépôt, et Pablo ne la communique pas à Claude.
- HTTPS obligatoire, sauf `localhost` : pas d'exception ATS. Pour un modèle local, on passe
  par `tailscale serve`.
- L'écran prévient que les listes sont envoyées au fournisseur. Avant une publication sur
  l'App Store, il faudra le déclarer dans la fiche de confidentialité et demander l'accord
  de l'utilisateur (règle 5.1.2 d'Apple).
- Toute donnée ajoutée au contexte (agenda, cagnotte…) passe par `ContexteAssistant` et ses
  tests.

## Libellés

Jamais « toi » ni « elle » en dur. Tout libellé qui désigne une personne passe par
`Libelles` et dépend du membre courant (`Identite`). On affiche « toi » ou le prénom de
l'autre. En phase 1, le membre courant se choisit dans Nous › Debug. En phase 2, il sera
déduit de l'identité iCloud.

## Design system

- Couleurs dans `Ressources/Assets.xcassets`, chacune avec une variante sombre. On les
  utilise via les symboles générés (`Color.fond`, `.surface`, `.texte`, `.texteSecondaire`,
  `.separateur`, `.pablo`, `.pabloDoux`, `.julie`, `.julieDoux`, `.commun`).
  Valeurs claires : fond #F4F4F7, surface #FFFFFF, texte #1C1B29, texte secondaire #5E5F6E,
  séparateurs #E3E4EA, Pablo #C2461F / #FBE9E2, Julie #1F6B62 / #E2F1EE,
  contour des éléments communs #1C1B29.
- Polices embarquées dans `DesignSystem/Polices` (licence OFL) : Bricolage Grotesque pour
  les titres, DM Sans pour le texte. On les utilise via `Font.jublo…` (`Typographie.swift`),
  qui suivent la taille de texte choisie dans iOS.
- Cartes arrondies à 20 pt, boutons en pilule, zones tactiles d'au moins 44 pt
  (`Mesures`).

## Structure

```
Jublo/
├── App/             point d'entrée, TabView racine
├── Core/            Modeles/, Persistance/, Identite/, Assistant/ (aucune vue)
├── DesignSystem/    couleurs, typographie, composants réutilisables, polices
├── Features/        un dossier par fonctionnalité (Accueil, Listes, Agenda, Projets, Nous,
│                    Corbeille, Assistant)
└── Ressources/      asset catalog
JubloTests/          Swift Testing, base en mémoire, horloge injectée (`Banc`)
JubloUITests/        XCUITest : parcours Listes → corbeille sur base vierge
```

Navigation : TabView à 5 onglets (Accueil, Listes, Agenda, Projets, Nous). L'assistant et la
corbeille sont des écrans poussés.

## Commandes

```sh
# Compiler
xcodebuild -scheme Jublo -destination 'platform=iOS Simulator,name=iPhone 17' build
# Tous les tests (unitaires + interface)
xcodebuild -scheme Jublo -destination 'platform=iOS Simulator,name=iPhone 17' test
# Tests unitaires seuls
xcodebuild -scheme Jublo -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:JubloTests
```

Arguments de lancement (debug uniquement) :

| Argument | Effet |
|---|---|
| `-exemples` | remplit une base vide avec `DonneesDebug` |
| `-baseEnMemoire` | base vierge en mémoire (tests d'interface) |
| `-onglet listes` | ouvre un onglet (`accueil`, `listes`, `agenda`, `projets`, `nous`) |
| `-liste courses` | ouvre une liste (`penseBete`, `courses`, `wishList`) |
| `-membreCourant julie` | choisit le membre courant (clé `UserDefaults` d'`Identite`) |
| `-assistantSimule` | l'assistant répond sans fournisseur (`ServiceSimule`) |

Simulateurs installés : iOS 18.6 et iOS 27. Il n'y a pas de runtime iOS 17, donc on vérifie
uniquement que le code compile pour iOS 17 (pas d'API iOS 18+ sans `#available`).

## Distribution (TestFlight)

- Équipe `9DYNMC2YQK` (Pablo Masse-Reyes, individuelle, programme payant), signature
  automatique. Le projet est désormais modifié aussi par Xcode : `project.pbxproj` est la
  référence.
- Bundle identifier `com.pmassereyes.jublo`, **définitif** (validé par Pablo le 2026-11-09).
  Ne pas le changer. Conteneur iCloud prévu en phase 2 :
  `iCloud.com.pmassereyes.jublo`.
- Numéro de build = nombre de commits de la branche archivée (`git rev-list --count HEAD`),
  passé au moment de l'archivage. Version affichée : `MARKETING_VERSION`.
- Réglage de build `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` (pas de chiffrement
  propre à l'app).
- Manifeste de confidentialité `Ressources/PrivacyInfo.xcprivacy` : aucun suivi publicitaire,
  aucune donnée collectée, et `UserDefaults` déclaré avec la raison `CA92.1`. Toute nouvelle
  API à « raison requise » (horodatages de fichiers, espace disque, `systemUptime`…) doit y
  être déclarée, sinon App Store Connect refuse le build.
- Icône : `AppIcon.png` (1024 px, sans transparence). Deux cercles, Pablo et Julie.
- Testeurs : test interne (Julie est utilisatrice de l'App Store Connect de Pablo), donc pas
  de revue Apple.
- Phase 1 : chaque iPhone a sa propre base, sans synchronisation. Les données survivent aux
  mises à jour TestFlight grâce aux migrations du schéma.

Envoi d'un build (depuis `main` propre et poussé ; l'envoi utilise le compte connecté dans
Xcode, sans clé d'API) :

```sh
xcodebuild -scheme Jublo -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/Jublo.xcarchive archive \
  CURRENT_PROJECT_VERSION=$(git rev-list --count HEAD) -allowProvisioningUpdates
xcodebuild -exportArchive -archivePath build/Jublo.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export -allowProvisioningUpdates
```

Historique : build 20 (version 0.1) envoyé le 2026-11-09, premier build TestFlight.

## Conventions

- Code, noms et commentaires en français, comme le reste du projet.
- Petits commits, un par étape, avec un message clair en français.
- Dépôt : `git@github.com:pmassereyes/Jublo.git`, branche `main`. Le travail se fait sur une
  branche de phase (`phase-1`…), fusionnée dans `main` à la fin.
