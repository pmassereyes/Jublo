# Jublo

App iPhone partagée par un couple (Pablo et Julie) : pense-bête, courses, wish list, agenda,
cagnotte, vacances envisagées, sorties à tester, compteur de retards, « ce mois-ci, j'aimerais
que tu… », corbeille, puis un assistant IA local.

## Feuille de route

- **Phase 1 (faite)** : app locale, SwiftData, Listes et Corbeille fonctionnelles. **Jamais de
  données d'exemple dans l'app** (Pablo n'en veut pas). `DonneesDebug` ne sert qu'aux aperçus,
  aux captures et aux tests d'interface (`-exemples`).
- **Phase 2 (faite, partage validé sur les deux iPhones le 2026-11-24 avec la 0.4)** : synchronisation
  CloudKit entre les deux identifiants Apple via **CKSyncEngine** et une zone partagée en
  entier (CKShare de zone). Voir la section Synchronisation.
- **Phase 4 (faite le 2026-11-24, en service sur les deux iPhones avec la 0.4)** : le reste de l'app,
  jusque-là en « Bientôt » (schéma V4). Agenda partagé (onglet Agenda), cagnotte, vacances
  envisagées et sorties à tester (onglet Projets), « Ce mois-ci, j'aimerais que tu… » et
  compteur de retards (onglet Nous), résumé à l'accueil.
- **Phase 5 (code fait le 2026-11-24, version 0.4)** : raccourci Siri « Ajoute un rendez-vous
  dans Jublo » (voir la section Siri) et assistant étendu à l'agenda, aux projets et aux
  souhaits du mois. Aucun changement de schéma.
- **Phase 6 (build 64, version 0.5, envoyé le 2026-11-26, schéma V5)** : rappels en notification
  (pense-bête et agenda), notification chez l'autre (même app fermée) quand une liste ou
  l'agenda change, wish list « À offrir » / « Offert », cagnotte rattachée à un voyage. Voir
  la section Notifications.
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
2. **Toutes les écritures locales passent par `Depot`**, qui les signale à `Synchronisation`
   (`ObservateurChangements`). Les vues ne modifient jamais un modèle directement. Seule
   exception : `MiroirLocal` applique les changements reçus de CloudKit, sans repasser par
   `Depot`, pour ne pas les renvoyer.
3. Chaque modèle a un `id: UUID` stable, futur nom d'enregistrement CloudKit.
4. Contraintes compatibles CloudKit : toutes les propriétés sont optionnelles ou ont une valeur
   par défaut, aucun `@Attribute(.unique)`, relations optionnelles.
5. Schéma versionné. `SchemaActuel` désigne la version courante (aujourd'hui `SchemaV5`), et
   `PlanMigrationJublo` liste les versions et les étapes de migration (dans `SchemaV5.swift`). Toute évolution passe
   par une nouvelle version : on copie le modèle modifié dans `SchemaVn`, on fige l'ancien (dans
   `SchemaVn-1.swift`), et on ajoute une étape et un test de migration (`MigrationV5Tests`…).
   Un modèle inchangé reste déclaré dans la dernière version où il a changé : `Cagnotte` et
   `Versement` dans `SchemaV1`, `Sortie`, `Retard` et `Souhait` dans `SchemaV4`, `ElementListe`,
   `Evenement` et `Destination` dans `SchemaV5`. On ne modifie jamais une version publiée.
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
- **V4** (`Evenement`, `Destination`, `Sortie`, `Retard`, `Souhait`) : tous `Suppressible`,
  écrits par `Depot` (`ajouterEvenement`, `ajouterDestination`, `ajouterSortie`, `noterRetard`,
  `confierSouhait`…). Les formulaires d'édition passent par `Depot.modifier(_:_:)`, qui avance
  `modifieLe` et signale le changement.
- Agenda : `pourId` nil = « vous deux ». Un rendez-vous d'une journée entière reste à venir
  jusqu'au soir (`estAVenir`).
- Vacances et sorties : chacun note de 1 à 5 (`AvisDuCouple`), avec un champ par membre
  (`avisPablo`, `avisJulie`) pour que l'un ne l'emporte pas sur l'avis de l'autre.
- Souhait du mois : `mois` est une clé « 2026-11 » (`Souhait.cleMois`) ; l'auteur l'écrit, le
  destinataire (l'autre) le coche (`faitLe`). Retard : `retardataireId` (qui était en retard)
  est distinct d'`auteurId` (qui l'a noté) ; bilan mensuel dans `BilanRetards`.
- SwiftData ne filtre pas sur une propriété atteinte à travers un protocole : les
  `#Predicate` s'écrivent type par type (voir `MiroirLocal`, `Depot.elementsDansLaCorbeille`).
- **Wish list par membre** : chaque envie a un destinataire (`pourId`, depuis la V2). Par
  défaut, c'est l'auteur ; on peut aussi noter une idée pour l'autre. Une envie sans
  `pourId`, créée avant la V2, est celle de son auteur (`destinataire`,
  `ElementListe.envies(pour:)`). Dans la wish list, un élément coché est « Offert » et non
  « Fait » : les libellés viennent de `TypeListe` (`libelleEnAttente`, `libelleTermine`,
  `libelleCochePar`), y compris pour l'assistant.
- **Rappels (V5)** : `ElementListe.rappelLe` (pense-bête seulement, `Depot.programmerRappel`)
  et `Evenement.rappelBrut` (`RappelEvenement` : minutes, heures ou jours avant ; pour une
  journée entière, 9 h le jour même ou avant, 18 h la veille). Synchronisés : le rappel est le
  même sur les deux iPhones, mais chacun le programme pour soi (voir Notifications).
- **Cagnotte d'un voyage (V5)** : `Destination.cagnotteId`, un simple identifiant (pas de
  relation SwiftData) ; `Destination.cagnotte(parmi:)` ignore une cagnotte à la corbeille.
  `Depot.creerCagnotte(pour:par:)` reprend le nom et le budget du voyage. Une cagnotte n'est
  rattachée qu'à un voyage à la fois (l'écran ne propose que les cagnottes libres). La fiche
  du voyage verse directement dans la cagnotte : pas de lien vers `CagnotteView`, car
  l'ouvrir depuis `DestinationView` faisait boucler SwiftUI (100 % de CPU, cause non
  identifiée, vu le 2026-11-26 ; Projets › Cagnotte › détail, lui, fonctionne).

## Synchronisation (CloudKit)

- Conteneur `iCloud.com.pmassereyes.jublo` (créé, impossible à supprimer). Droits dans
  `Jublo/Jublo.entitlements` : CloudKit et `aps-environment`. `Info.plist` contient
  `CKSharingSupported` et le mode d'arrière-plan `remote-notification`.
- Une zone « Jublo ». Le **propriétaire** l'a dans sa base privée et la partage en entier
  (`CKShare(recordZoneID:)`, lecture-écriture). Le **participant** la voit dans sa base
  partagée. Le rôle (`Synchronisation.Role`), l'état de CKSyncEngine et les changements
  faits hors ligne sont dans `UserDefaults` (`sync.*`).
- Enregistrements : le nom est l'`id` (UUID) du modèle, le type est le nom du modèle. Les
  textes personnels (titres, noms, notes) sont dans `encryptedValues`. Les champs système
  sont gardés dans `MetadonneesSync`, propres à chaque appareil.
- Conflits : la version au `modifieLe` le plus récent l'emporte. En rejoignant un partage,
  les données locales du participant sont envoyées dans la zone ; les identifiants étant
  uniques, il n'y a pas de doublon. Quand le partage prend fin, chacun garde une copie
  locale.
- Invitation : Nous › Partage › « Inviter Julie », via la feuille de partage d'iOS. Le lien
  ouvre Jublo, puis `DelegueScene` appelle `Synchronisation.accepter`.
- Champs ajoutés par la V5 (`versionSchemaSync` 3) : `ElementListe.rappelLe`,
  `Evenement.rappelBrut`, `Destination.cagnotteId`, plus les 8 types de signaux (champs `le`
  et `par`, voir Notifications). **À déployer en production avant le premier build
  TestFlight de la 0.5.**
- **Ajouter un modèle ou un champ synchronisé** : le rendre `Synchronisable`, l'ajouter à
  `MiroirLocal` (`typesEnregistrement`, `fabriquer`, `modele`, `tousLesModeles`) et à
  `preparerSchema` (chaque champ optionnel rempli, sinon il n'est pas créé), **augmenter
  `Synchronisation.versionSchemaSync`**, puis **redéployer le schéma en production avant tout
  build TestFlight**. La production refuse les champs et les types inconnus.
- `versionSchemaSync` : un build plus ancien ignore les types qu'il ne connaît pas, mais le
  jeton de CKSyncEngine avance quand même. Au premier lancement d'un build plus récent,
  `Synchronisation` oublie donc l'état du moteur (en gardant rôle, métadonnées et changements
  en attente) pour relire toute la zone et renvoyer toute la base.
- Environnements : un build debug lancé depuis Xcode utilise l'environnement CloudKit de
  **développement**, TestFlight celui de **production**. Leurs données ne se croisent pas :
  pour tester le partage, les deux iPhones doivent être sur TestFlight.
- Passer d'un build debug à TestFlight (ou l'inverse) sur le même iPhone : au lancement,
  `Synchronisation` voit que l'environnement a changé (`sync.environnement`) et repart de
  zéro (rôle de propriétaire, renvoi de toute la base), en gardant les données locales. Un
  partage accepté dans un environnement est donc perdu dans l'autre.
- Déployer le schéma : lancer un build debug sur un iPhone connecté à iCloud (la connexion
  à iCloud échoue dans les simulateurs iOS 27.0 et 27.2), **avec `-baseEnMemoire`** pour ne
  toucher ni la vraie base ni l'état de synchronisation de l'iPhone, puis Nous ›
  Développement › « Préparer le schéma CloudKit ». Sans cet argument, la base de l'iPhone
  migre vers le schéma du build debug, et un build TestFlight plus ancien plante ensuite au
  lancement. Ensuite, dans la console CloudKit
  (icloud.developer.apple.com), vérifier que le schéma de développement liste
  `ElementListe`, `Cagnotte`, `Versement`, `Evenement`, `Destination`, `Sortie`, `Retard`,
  `Souhait`, les 8 types `Signal…Pour…` (`SignalPenseBetePourPablo`, `SignalCoursesPourJulie`…)
  et `cloudkit.share` (sans ce dernier, la production refuse le premier partage), puis conteneur Jublo › Schema › « Deploy Schema
  Changes ». Déploiements du 2026-11-24 : les 3 types de la V3 et `cloudkit.share`,
  puis les 5 types de la V4. Le 2026-11-26 : les 3 champs de la V5 et les 8 types de signaux.
- Build debug sur l'iPhone sans passer par l'interface d'Xcode (iPhone déverrouillé et
  branché, identifiant via `xcrun devicectl list devices`) :
  `xcodebuild -scheme Jublo -destination 'generic/platform=iOS' -derivedDataPath <dossier>
  -allowProvisioningUpdates build`, puis `xcrun devicectl device install app --device <id>
  <dossier>/Build/Products/Debug-iphoneos/Jublo.app` et `xcrun devicectl device process
  launch --device <id> com.pmassereyes.jublo -- -baseEnMemoire -onglet nous` (le `--` est
  obligatoire avant les arguments de l'app).
- Tests : aucun appel à iCloud (`Synchronisation(active: false)` avec `-baseEnMemoire` ou
  dans l'app hôte des tests unitaires). Le partage réel se teste sur les deux iPhones.

## Assistant

- `Core/Assistant/` : `ClientCompatibleOpenAI` (flux SSE, erreurs traduites en messages
  clairs), `Fournisseur` (préréglages : adresse, modèle modifiable), `ConfigurationAssistant`
  et `ContexteAssistant` (consignes envoyées avec chaque question : qui parle, date et heure,
  puis, hors corbeille et à 40 éléments au plus par section, les listes, l'agenda à venir et
  des 30 derniers jours, les cagnottes, vacances et sorties avec les avis de chacun, et les
  souhaits du mois et des mois précédents). Les retards ne sont pas envoyés. `DonneesAssistant`
  lit la base au moment de la question. `Features/Assistant/` : `Discussion` (en
  mémoire, non partagée), `AssistantView`, `ReglagesAssistantView`.
- Réglages **propres à chaque iPhone** : fournisseur, adresse et modèle dans `UserDefaults`.
  La clé d'API est dans le trousseau, une par fournisseur, `ThisDeviceOnly`. Elle n'est
  jamais dans le code ni dans le dépôt, et Pablo ne la communique pas à Claude.
- HTTPS obligatoire, sauf `localhost` : pas d'exception ATS. Pour un modèle local, on passe
  par `tailscale serve`.
- L'écran prévient que les listes, l'agenda, les projets et les souhaits sont envoyés au fournisseur. Avant une publication sur
  l'App Store, il faudra le déclarer dans la fiche de confidentialité et demander l'accord
  de l'utilisateur (règle 5.1.2 d'Apple).
- Toute donnée ajoutée au contexte passe par `ContexteAssistant` et ses tests
  (`ContexteAssistantTests`).

## Notifications

- `Core/Notifications/` : `Notificateur` (une instance, dans l'environnement), `Rappels`,
  `Signaux`, `Changement`, et `CentreNotifications` (protocole : `CentreSysteme` pour
  `UNUserNotificationCenter`, `CentreInerte` avec `-baseEnMemoire`, dans les tests et les
  aperçus). L'autorisation est demandée une fois le membre choisi, au lancement.
- **Rappels** : `Notificateur.replanifier()` lit la base et met les notifications programmées
  (identifiants `rappel.<uuid>`) en accord avec elle. Il est appelé après chaque
  enregistrement du contexte (`ModelContext.didSave`, donc aussi pour ce qui vient de
  CloudKit), après chaque formulaire de rappel, au retour au premier plan, au passage en
  arrière-plan et quand le membre change (`didSave` n'est vérifié que sur iOS 27 : les autres
  appels servent de filet). Pense-bête : sur les deux
  iPhones, sauf élément coché ou à la corbeille. Rendez-vous : chez le membre concerné, ou
  chez les deux (`Evenement.estPour`). 60 au plus (iOS en garde 64).
- **Notifications chez l'autre, même Jublo fermé** (« Julie a mis à jour les courses »),
  comme Notes, mais sans serveur à nous : ce sont des **push visibles envoyés par iCloud**.
  - Envoi : `Depot` signale chaque `Changement` d'une liste ou de l'agenda
    (`ObservateurChangements.aChange`). `Synchronisation` en tire une rubrique
    (`Signaux.rubrique`), envoie d'abord les données, puis réécrit un **signal** : un
    enregistrement à nom fixe (`signal-courses-julie`) de type `SignalCoursesPourJulie`, dans
    la zone partagée, jamais supprimé (une suppression notifierait aussi). Un signal par
    rubrique toutes les 10 minutes au plus (`CadenceSignaux` : un signal qui n'a pas pu
    partir ne compte pas), seulement si le partage est actif, sous sursis d'arrière-plan.
  - Réception : chaque iPhone s'abonne (`CKDatabaseSubscription`, filtrée sur le type
    `Signal…Pour<son prénom>`, dans la base de son rôle) avec un texte fixé à l'abonnement.
    iCloud affiche la notification sans réveiller Jublo. Le destinataire fait partie du type :
    on ne reçoit jamais ses propres signaux. Abonnements selon Nous › Cet iPhone
    (`notifications.listes`, `notifications.agenda`, `Notificateur.abonnementsVoulus`),
    réenregistrés quand l'empreinte change (`sync.abonnements`, oubliée au changement de rôle
    ou d'environnement) et retentés au retour au premier plan. Un refus d'iCloud s'affiche
    dans la carte Notifications (`Synchronisation.etatAbonnements`).
  - Règles : ni les suppressions dans les listes, ni les rendez-vous passés, ni un changement
    de rappel seul. Wish list : seulement une envie que l'auteur ajoute pour lui-même (une
    idée pour l'autre ou un cadeau offert gâcheraient la surprise).
  - Les titres ne passent jamais en clair : le texte ne dit pas quel élément a changé.
    `MiroirLocal` ignore les signaux (type inconnu, nom qui n'est pas un UUID).
  - Au premier plan, la notification n'est pas affichée (`willPresent`).
  - Non vérifié sur iPhone à l'écriture (2026-11-26) : à tester sur les deux iPhones en
    TestFlight. Nous › Développement › « Tester l'abonnement iCloud » (après « Préparer le
    schéma ») vérifie qu'iCloud accepte l'abonnement. Si la base partagée ignorait le filtre
    par type, Julie recevrait une notification par enregistrement : couper les deux réglages
    supprime les abonnements. Ordre de mise à jour : Pablo installe et ouvre la 0.5 d'abord
    (chaque iPhone renvoie toute sa base au premier lancement), puis Julie.
  - Les annonces détaillées calculées à la réception (« Julie a ajouté « Lait » »), qui
    demandaient que Jublo tourne en arrière-plan, ont été retirées : voir le commit `969585c`.
- **Réveil** : CloudKit envoie aussi une notification push silencieuse (celle de
  CKSyncEngine) ; `DelegueApplication.application(_:didReceiveRemoteNotification:)`
  synchronise (20 s au plus) puis reprogramme les rappels. iOS limite ces réveils, et ne les
  fait pas pour une app fermée depuis le sélecteur d'apps.
- Toucher une notification ouvre l'onglet (et la liste) concerné : `Navigation`, dans
  l'environnement, porte l'onglet de `RacineView` et la liste demandée à `ListesView`.

## Siri

- `Features/Siri/` : intention `AjouterRendezVous` (titre, date, « pour » : nous deux, moi,
  Pablo ou Julie) et `RaccourcisJublo` (phrases). Pour une app tierce, chaque phrase doit
  contenir le nom de l'app ; Siri demande ensuite « Quel rendez-vous ? » puis « C'est
  quand ? ». Une date à minuit pile donne une journée entière. À vérifier à la voix : dans
  l'app Raccourcis, une date choisie sans heure reçoit l'heure courante, pas minuit ; on ne
  sait pas encore ce que Siri fait de « demain » seul.
- L'intention tourne dans le processus de l'app, lancé en arrière-plan sans écran. Elle
  utilise le `Depot`, l'`Identite` et la `Synchronisation` de l'app, enregistrés dans
  `AppDependencyManager` par `JubloApp.init`. Sans membre choisi, elle refuse au lieu de signer
  au hasard. Après l'ajout, elle synchronise 5 s au plus (`synchroniser(auPlus:)`, via
  `Attente.auPlus`, une vraie course : pas de `withTaskGroup`, qui attendrait tout), car le
  `.task` de la scène qui démarre la synchronisation ne s'exécute pas.
- La logique testable est dans `RendezVousDicte` (`SiriTests`). Dans le simulateur, l'action
  se teste depuis l'app Raccourcis (nouveau raccourci › Éditeur › recherche « Jublo »). Siri à
  la voix ne se teste que sur un iPhone, avec un build TestFlight : un build debug lancé par
  Siri ouvrirait la vraie base dans l'environnement CloudKit de développement.
- L'astuce Siri de l'Agenda (`SiriTipView`) se masque par sa croix (`agenda.astuceSiri`).

## Libellés

Jamais « toi » ni « elle » en dur. Tout libellé qui désigne une personne passe par
`Libelles` et dépend du membre courant (`Identite`). On affiche « toi » ou le prénom de
l'autre. Le membre courant est choisi au premier lancement (`ChoixMembreView`), puis
modifiable dans Nous › Cet iPhone. Il reste un choix explicite, indépendant du compte
iCloud.

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
├── App/             point d'entrée, TabView racine, Navigation, délégué (push, notifications)
├── Core/            Modeles/, Persistance/, Identite/, Assistant/, Synchronisation/,
│                    Notifications/ (aucune vue)
├── DesignSystem/    couleurs, typographie, composants réutilisables, polices
├── Features/        un dossier par fonctionnalité (Accueil, Listes, Agenda, Projets, Nous,
│                    Corbeille, Assistant, Siri)
└── Ressources/      asset catalog
JubloTests/          Swift Testing, base en mémoire, horloge injectée (`Banc`), `CentreFactice`
JubloUITests/        XCUITest : parcours sur base vierge (listes, projets, rappels, assistant)
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
- Chaque iPhone garde sa base locale, synchronisée par CloudKit. Les données survivent aux
  mises à jour TestFlight grâce aux migrations du schéma. Si un build ajoute des champs
  CloudKit, il faut déployer le schéma en production **avant** de l'envoyer.

Envoi d'un build (depuis `main` propre et poussé ; l'envoi utilise le compte connecté dans
Xcode, sans clé d'API) :

```sh
xcodebuild -scheme Jublo -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/Jublo.xcarchive archive \
  CURRENT_PROJECT_VERSION=$(git rev-list --count HEAD) -allowProvisioningUpdates
xcodebuild -exportArchive -archivePath build/Jublo.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export -allowProvisioningUpdates
```

Historique : build 20 (version 0.1) envoyé le 2026-11-09, premier build TestFlight. Build 38
(version 0.2) envoyé le 2026-11-24, premier build avec la synchronisation CloudKit. Build 41
(0.2) le même jour : clavier des listes. Build 46 (version 0.3) le même jour : l'app complète
(schéma V4). Build 52 (version 0.4) le même jour : Siri et assistant étendu (sans changement
de schéma). Build 64 (version 0.5) le 2026-11-26 : rappels, notifications chez l'autre,
wish list « offert », cagnotte d'un voyage (schéma V5, déployé en production le même jour).

**Un build TestFlight expire 90 jours après son envoi** : il ne s'ouvre plus, mais les
données restent (sur l'iPhone et dans iCloud) et un build plus récent s'installe par-dessus.
Le build 64 expire vers le **2027-02-24** : envoyer un nouveau build vers mi-février 2027
(un commit suffit, le numéro de build étant le nombre de commits).

## Conventions

- Code, noms et commentaires en français, comme le reste du projet.
- Petits commits, un par étape, avec un message clair en français.
- Dépôt : `git@github.com:pmassereyes/Jublo.git`, branche `main`. Le travail se fait sur une
  branche de phase (`phase-1`…), fusionnée dans `main` à la fin.
