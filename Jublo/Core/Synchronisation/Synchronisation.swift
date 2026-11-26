import CloudKit
import Foundation
import Observation
import OSLog
import SwiftData

/// Synchronisation CloudKit avec CKSyncEngine.
///
/// Toutes les données vivent dans une zone « Jublo ». Le propriétaire l'a dans sa base privée et
/// la partage en entier (CKShare de zone) ; l'autre membre la voit dans sa base partagée.
/// - Envoi : `Depot` signale chaque écriture (`ObservateurChangements`) et le moteur l'envoie.
/// - Réception : `MiroirLocal` applique les changements ; la version modifiée en dernier l'emporte.
@MainActor
@Observable
final class Synchronisation {
    enum Role: Codable, Equatable {
        /// La zone est dans ma base privée, partagée ou non.
        case proprietaire
        /// La zone appartient à l'autre membre et m'est partagée.
        case participant(proprietaire: String)
    }

    enum Etat: Equatable {
        case inactive(String)
        case enCours
        case aJour(Date)
        case erreur(String)
    }

    enum EtatPartage: Equatable {
        case aucun
        case invitationEnvoyee
        case actif
        case participant
    }

    enum ErreurPartage: LocalizedError {
        case pasProprietaire
        case creation

        var errorDescription: String? {
            switch self {
            case .pasProprietaire: "Seul celui qui a créé le partage peut inviter."
            case .creation: "Le partage n'a pas pu être créé."
            }
        }
    }

    static let identifiantConteneur = "iCloud.com.pmassereyes.jublo"
    static let nomZone = "Jublo"

    /// Instance de l'app, pour accepter une invitation depuis le délégué de scène.
    private(set) static weak var courante: Synchronisation?

    private(set) var role: Role
    private(set) var etat: Etat
    /// Partage de la zone, côté propriétaire.
    private(set) var partage: CKShare?
    /// Faux dans les tests et les aperçus : aucun appel à iCloud.
    let active: Bool

    @ObservationIgnored private let miroir: MiroirLocal
    @ObservationIgnored private let stockage: UserDefaults
    @ObservationIgnored private var moteur: CKSyncEngine?
    @ObservationIgnored private let demarreur = Demarreur()
    /// Changements reçus de l'autre iPhone dans les listes et l'agenda (notifications).
    @ObservationIgnored var surReception: (([ChangementRecu]) -> Void)?
    /// Vrai tant que le moteur, parti sans état sauvegardé (premier partage, réinstallation,
    /// nouveau schéma), n'a pas fini de relire la zone : rien n'est alors annoncé.
    @ObservationIgnored private var lectureInitiale = false

    private enum Cle {
        static let role = "sync.role"
        static let etatMoteur = "sync.etatMoteur"
        static let enAttente = "sync.enAttente"
        static let environnement = "sync.environnement"
        static let versionSchema = "sync.versionSchema"
    }

    /// Version des types et des champs synchronisés : à augmenter à chaque type ou champ
    /// CloudKit ajouté. Un build plus ancien ignore ce qu'il ne connaît pas, mais le jeton de
    /// CKSyncEngine avance quand même : au premier lancement d'un build plus récent, on relit
    /// donc toute la zone (voir `relireSiSchemaPlusRecent`).
    /// 1 : listes et cagnotte (build 38). 2 : agenda, vacances, sorties, retards, souhaits.
    /// 3 : rappels (`ElementListe.rappelLe`, `Evenement.rappelBrut`) et cagnotte d'un voyage
    /// (`Destination.cagnotteId`).
    static let versionSchemaSync = 3

    /// Environnement CloudKit de ce build : un build debug lancé depuis Xcode parle à
    /// l'environnement de développement, TestFlight à celui de production.
    nonisolated static var environnementCourant: String {
        #if DEBUG
        "developpement"
        #else
        "production"
        #endif
    }

    init(
        contexte: ModelContext,
        stockage: UserDefaults = .standard,
        active: Bool = true,
        environnement: String = Synchronisation.environnementCourant
    ) {
        let miroir = MiroirLocal(contexte: contexte)
        Self.oublierAutreEnvironnement(environnement, stockage: stockage, miroir: miroir)
        Self.relireSiSchemaPlusRecent(stockage: stockage)
        self.miroir = miroir
        self.stockage = stockage
        self.active = active
        role = stockage.data(forKey: Cle.role).flatMap { try? JSONDecoder().decode(Role.self, from: $0) } ?? .proprietaire
        etat = active ? .inactive("Connexion à iCloud…") : .inactive("Synchronisation désactivée.")
        if active {
            Self.courante = self
        }
    }

    var conteneurCloudKit: CKContainer {
        CKContainer(identifier: Self.identifiantConteneur)
    }

    var zone: CKRecordZone.ID {
        switch role {
        case .proprietaire:
            CKRecordZone.ID(zoneName: Self.nomZone, ownerName: CKCurrentUserDefaultName)
        case .participant(let proprietaire):
            CKRecordZone.ID(zoneName: Self.nomZone, ownerName: proprietaire)
        }
    }

    var etatPartage: EtatPartage {
        if case .participant = role { return .participant }
        guard let partage else { return .aucun }
        let accepte = partage.participants.contains { $0.role != .owner && $0.acceptanceStatus == .accepted }
        return accepte ? .actif : .invitationEnvoyee
    }

    // MARK: - Démarrage

    /// Démarre la synchronisation si iCloud est disponible. Sans effet si elle tourne déjà.
    func demarrer() async {
        guard active else { return }
        await demarreur.demarrer(saufSi: { self.moteur != nil }) {
            await self.lancerMoteur()
        }
    }

    /// Récupère puis envoie les changements (ouverture de l'app, tirer pour rafraîchir).
    func synchroniserMaintenant() async {
        guard active else { return }
        guard let moteur else {
            // Le démarrage se termine par une synchronisation.
            await demarrer()
            return
        }
        await synchroniser(moteur)
    }

    /// Synchronise sans attendre plus de `delai` (raccourci Siri : la réponse ne doit pas traîner).
    /// La synchronisation continue ensuite tant que l'app tourne.
    func synchroniser(auPlus delai: Duration) async {
        guard active else { return }
        await Attente.auPlus(delai) { await self.synchroniserMaintenant() }
    }

    /// Récupère puis envoie les changements d'un moteur, sans jamais rien démarrer : le
    /// démarrage l'appelle, et ne doit pas s'attendre lui-même.
    private func synchroniser(_ moteur: CKSyncEngine) async {
        do {
            try await moteur.fetchChanges()
            if moteur === self.moteur {
                lectureInitiale = false
            }
            try await moteur.sendChanges()
            if moteur === self.moteur {
                etat = .aJour(.now)
            }
        } catch {
            // Un moteur remplacé entre-temps ne touche plus à l'état affiché.
            if moteur === self.moteur {
                etat = .erreur(Self.message(error))
            }
        }
    }

    /// Lance un moteur pour le rôle courant. S'il est remplacé pendant une attente
    /// (réinitialisation), il est abandonné : l'appel qui a réinitialisé en relance un autre.
    private func lancerMoteur() async {
        let statut: CKAccountStatus
        do {
            statut = try await conteneurCloudKit.accountStatus()
        } catch {
            etat = .inactive("iCloud est injoignable pour le moment.")
            return
        }
        guard statut == .available else {
            etat = .inactive(statut == .noAccount
                ? "Connecte-toi à iCloud dans Réglages pour synchroniser vos listes."
                : "iCloud n'est pas disponible sur cet iPhone pour le moment.")
            return
        }

        let etatSauve = lireEtatMoteur()
        let base = role == .proprietaire ? conteneurCloudKit.privateCloudDatabase : conteneurCloudKit.sharedCloudDatabase
        let moteur = CKSyncEngine(CKSyncEngine.Configuration(database: base, stateSerialization: etatSauve, delegate: self))
        self.moteur = moteur
        lectureInitiale = etatSauve == nil
        if etatSauve == nil {
            // Premier démarrage dans cette zone : on la crée (propriétaire) et on envoie toute la base.
            if role == .proprietaire {
                moteur.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zone))])
            }
            moteur.state.add(pendingRecordZoneChanges: miroir.tousLesModeles().map { .saveRecord(identifiant($0.id)) })
        }
        rejouerChangementsEnAttente(moteur)
        if role == .proprietaire {
            let existant = try? await conteneurCloudKit.privateCloudDatabase.record(for: identifiantPartage) as? CKShare
            guard moteur === self.moteur else { return }
            partage = existant
        }
        await synchroniser(moteur)
    }

    // MARK: - Partage

    /// Partage de la zone (propriétaire), créé au besoin.
    func preparerPartage() async throws -> CKShare {
        guard role == .proprietaire else { throw ErreurPartage.pasProprietaire }
        if let partage { return partage }
        let base = conteneurCloudKit.privateCloudDatabase
        _ = try await base.modifyRecordZones(saving: [CKRecordZone(zoneID: zone)], deleting: [])
        if let existant = try? await base.record(for: identifiantPartage) as? CKShare {
            partage = existant
            return existant
        }
        let nouveau = CKShare(recordZoneID: zone)
        nouveau[CKShare.SystemFieldKey.title] = "Jublo"
        nouveau.publicPermission = .none
        let resultat = try await base.modifyRecords(saving: [nouveau], deleting: [])
        guard let enregistre = try resultat.saveResults[nouveau.recordID]?.get() as? CKShare else {
            throw ErreurPartage.creation
        }
        partage = enregistre
        return enregistre
    }

    /// Partage modifié depuis la feuille de partage d'iOS (invitation, participants).
    func partageMisAJour(_ partage: CKShare?) {
        self.partage = partage
    }

    /// Accepte une invitation (lien ouvert sur l'iPhone de l'autre). Les données locales de cet
    /// iPhone rejoignent la zone partagée ; les identifiants étant uniques, sans doublon.
    func accepter(_ metadonnees: CKShare.Metadata) async {
        guard active, metadonnees.participantRole != .owner else { return }
        let zonePartagee = metadonnees.share.recordID.zoneID
        guard zonePartagee.zoneName == Self.nomZone else {
            etat = .erreur("Cette invitation ne concerne pas Jublo.")
            return
        }
        do {
            _ = try await conteneurCloudKit.accept(metadonnees)
        } catch {
            etat = .erreur("Impossible d'accepter l'invitation : \(Self.message(error))")
            return
        }
        await reinitialiser(role: .participant(proprietaire: zonePartagee.ownerName))
        await demarrer()
    }

    /// Quitte le partage (participant). Les listes restent sur cet iPhone, dans sa propre zone.
    func quitterPartage() async throws {
        guard case .participant = role else { return }
        _ = try await conteneurCloudKit.sharedCloudDatabase.modifyRecordZones(saving: [], deleting: [zone])
        await reinitialiser(role: .proprietaire)
        await demarrer()
    }

    private var identifiantPartage: CKRecord.ID {
        CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zone)
    }

    // MARK: - État

    private func identifiant(_ id: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: id.uuidString, zoneID: zone)
    }

    /// Repart de zéro pour un autre rôle ou un autre compte. Les données locales sont gardées.
    private func reinitialiser(role nouveau: Role) async {
        if let moteur {
            await moteur.cancelOperations()
        }
        moteur = nil
        stockage.removeObject(forKey: Cle.etatMoteur)
        stockage.removeObject(forKey: Cle.enAttente)
        miroir.oublierTout()
        partage = nil
        role = nouveau
        stockage.set(try? JSONEncoder().encode(nouveau), forKey: Cle.role)
    }

    /// Les deux environnements CloudKit ne partagent ni zones, ni enregistrements, ni partages.
    /// Quand un build d'un autre environnement a synchronisé sur cet iPhone (build debug
    /// installé par-dessus TestFlight, ou l'inverse), on repart de zéro : rôle de propriétaire,
    /// premier envoi de toute la base. Les données locales sont gardées.
    private static func oublierAutreEnvironnement(_ environnement: String, stockage: UserDefaults, miroir: MiroirLocal) {
        // Avant cette clé, seuls des builds debug ont synchronisé.
        let precedent = stockage.string(forKey: Cle.environnement)
            ?? (stockage.data(forKey: Cle.etatMoteur) != nil ? "developpement" : nil)
        if let precedent, precedent != environnement {
            for cle in [Cle.role, Cle.etatMoteur, Cle.enAttente] {
                stockage.removeObject(forKey: cle)
            }
            miroir.oublierTout()
        }
        stockage.set(environnement, forKey: Cle.environnement)
    }

    /// Premier lancement d'un build qui synchronise de nouveaux types ou champs : on oublie
    /// l'état du moteur pour relire toute la zone, ce que l'ancien build a ignoré compris.
    /// Le rôle, les métadonnées et les changements en attente sont gardés ; le démarrage
    /// renvoie aussi toute la base locale, et la version la plus récente l'emporte.
    private static func relireSiSchemaPlusRecent(stockage: UserDefaults) {
        // Avant cette clé, un état du moteur vient d'un build de la version 1.
        let precedente = stockage.object(forKey: Cle.versionSchema) as? Int
            ?? (stockage.data(forKey: Cle.etatMoteur) != nil ? 1 : nil)
        if let precedente, precedente < versionSchemaSync {
            stockage.removeObject(forKey: Cle.etatMoteur)
        }
        stockage.set(versionSchemaSync, forKey: Cle.versionSchema)
    }

    private func lireEtatMoteur() -> CKSyncEngine.State.Serialization? {
        stockage.data(forKey: Cle.etatMoteur).flatMap {
            try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: $0)
        }
    }

    /// Changements faits pendant que le moteur ne tournait pas (iCloud indisponible).
    private func rejouerChangementsEnAttente(_ moteur: CKSyncEngine) {
        let enAttente = stockage.stringArray(forKey: Cle.enAttente) ?? []
        guard !enAttente.isEmpty else { return }
        let changements: [CKSyncEngine.PendingRecordZoneChange] = enAttente.compactMap { cle in
            guard let id = UUID(uuidString: String(cle.dropFirst())) else { return nil }
            return cle.hasPrefix("-") ? .deleteRecord(identifiant(id)) : .saveRecord(identifiant(id))
        }
        moteur.state.add(pendingRecordZoneChanges: changements)
        stockage.removeObject(forKey: Cle.enAttente)
    }

    static func message(_ erreur: Error) -> String {
        guard let erreur = erreur as? CKError else { return erreur.localizedDescription }
        switch erreur.code {
        case .notAuthenticated:
            return "Connecte-toi à iCloud dans Réglages."
        case .networkUnavailable, .networkFailure:
            return "Pas de connexion : les changements partiront plus tard."
        case .quotaExceeded:
            return "Ton stockage iCloud est plein."
        case .participantMayNeedVerification:
            return "Ouvre l'invitation avec le compte iCloud qui l'a reçue."
        case .badContainer, .missingEntitlement:
            return "Le conteneur iCloud de l'app n'est pas configuré."
        default:
            return erreur.localizedDescription
        }
    }
}

// MARK: - Changements locaux

extension Synchronisation: ObservateurChangements {
    func aModifie(_ modele: any Synchronisable) {
        signaler(.saveRecord(identifiant(modele.id)), cle: "+\(modele.id.uuidString)")
    }

    func aSupprime(_ modele: any Synchronisable) {
        miroir.oublier(modele.id.uuidString)
        signaler(.deleteRecord(identifiant(modele.id)), cle: "-\(modele.id.uuidString)")
    }

    private func signaler(_ changement: CKSyncEngine.PendingRecordZoneChange, cle: String) {
        guard active else { return }
        if let moteur {
            moteur.state.add(pendingRecordZoneChanges: [changement])
        } else {
            stockage.set((stockage.stringArray(forKey: Cle.enAttente) ?? []) + [cle], forKey: Cle.enAttente)
        }
    }
}

// MARK: - CKSyncEngine

extension Synchronisation: CKSyncEngineDelegate {
    func handleEvent(_ evenement: CKSyncEngine.Event, syncEngine moteur: CKSyncEngine) async {
        // Un moteur remplacé (changement de rôle ou de compte) peut encore parler : on l'ignore.
        guard moteur === self.moteur else { return }
        switch evenement {
        case .stateUpdate(let miseAJour):
            stockage.set(try? JSONEncoder().encode(miseAJour.stateSerialization), forKey: Cle.etatMoteur)
        case .accountChange(let changement):
            compteChange(changement)
        case .fetchedDatabaseChanges(let changements):
            zonesModifiees(changements, moteur: moteur)
        case .fetchedRecordZoneChanges(let changements):
            recus(changements, moteur: moteur)
        case .sentRecordZoneChanges(let envoi):
            envoyes(envoi, moteur: moteur)
        case .willFetchChanges, .willSendChanges:
            etat = .enCours
        case .didFetchChanges, .didSendChanges:
            if etat == .enCours {
                etat = .aJour(.now)
            }
        case .sentDatabaseChanges, .willFetchRecordZoneChanges, .didFetchRecordZoneChanges:
            break
        @unknown default:
            break
        }
    }

    func nextRecordZoneChangeBatch(_ contexte: CKSyncEngine.SendChangesContext, syncEngine moteur: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let changements = moteur.state.pendingRecordZoneChanges.filter { contexte.options.scope.contains($0) }
        guard !changements.isEmpty else { return nil }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: changements) { identifiant in
            await self.enregistrement(pour: identifiant, moteur: moteur)
        }
    }

    private func enregistrement(pour identifiant: CKRecord.ID, moteur: CKSyncEngine) -> CKRecord? {
        guard let id = UUID(uuidString: identifiant.recordName), let modele = miroir.modele(id, type: nil) else {
            moteur.state.remove(pendingRecordZoneChanges: [.saveRecord(identifiant)])
            return nil
        }
        return miroir.enregistrement(pour: modele, zone: identifiant.zoneID)
    }

    private func recus(_ changements: CKSyncEngine.Event.FetchedRecordZoneChanges, moteur: CKSyncEngine) {
        let enAttente = Set(moteur.state.pendingRecordZoneChanges.compactMap { changement -> String? in
            if case .saveRecord(let identifiant) = changement { identifiant.recordName } else { nil }
        })
        let enregistrements = changements.modifications.map(\.record).filter { $0.recordID.zoneID.zoneName == Self.nomZone }
        if role == .proprietaire, let nouveauPartage = enregistrements.lazy.compactMap({ $0 as? CKShare }).first {
            partage = nouveauPartage
        }
        let aAnnoncer = miroir.appliquer(enregistrements, enAttente: enAttente)
        if !lectureInitiale, !aAnnoncer.isEmpty {
            surReception?(aAnnoncer)
        }

        let suppressions = changements.deletions.filter { $0.recordID.zoneID.zoneName == Self.nomZone }
        if suppressions.contains(where: { $0.recordType == CKRecord.SystemType.share }) {
            partage = nil
        }
        miroir.supprimer(suppressions.map(\.recordID))
    }

    private func envoyes(_ envoi: CKSyncEngine.Event.SentRecordZoneChanges, moteur: CKSyncEngine) {
        for enregistrement in envoi.savedRecords {
            miroir.memoriser(enregistrement)
        }
        var aRenvoyer: [CKSyncEngine.PendingRecordZoneChange] = []
        var zoneManquante = false
        for echec in envoi.failedRecordSaves {
            let identifiant = echec.record.recordID
            switch echec.error.code {
            case .serverRecordChanged:
                if let serveur = echec.error.serverRecord, miroir.resoudreConflit(avec: serveur) {
                    aRenvoyer.append(.saveRecord(identifiant))
                }
            case .zoneNotFound:
                zoneManquante = true
                miroir.oublier(identifiant.recordName)
                aRenvoyer.append(.saveRecord(identifiant))
            case .unknownItem:
                // Effacé sur le serveur mais encore présent ici : on le recrée.
                miroir.oublier(identifiant.recordName)
                aRenvoyer.append(.saveRecord(identifiant))
            case .quotaExceeded:
                etat = .erreur("Ton stockage iCloud est plein : les changements ne partent plus.")
            case .permissionFailure:
                etat = .erreur("Le partage ne permet pas de modifier les listes.")
            default:
                // Réseau, iCloud occupé, limite de débit… : CKSyncEngine réessaie tout seul.
                journal.info("Envoi reporté pour \(identifiant.recordName) : \(echec.error)")
            }
        }
        miroir.enregistrer()
        if zoneManquante {
            guard role == .proprietaire else {
                Task { await self.finDuPartage() }
                return
            }
            moteur.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zone))])
        }
        moteur.state.add(pendingRecordZoneChanges: aRenvoyer)
    }

    private func zonesModifiees(_ changements: CKSyncEngine.Event.FetchedDatabaseChanges, moteur: CKSyncEngine) {
        guard changements.deletions.contains(where: { $0.zoneID.zoneName == Self.nomZone }) else { return }
        switch role {
        case .proprietaire:
            // Zone effacée (données iCloud réinitialisées) : les données locales font foi, on renvoie tout.
            miroir.oublierTout()
            partage = nil
            moteur.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zone))])
            moteur.state.add(pendingRecordZoneChanges: miroir.tousLesModeles().map { .saveRecord(identifiant($0.id)) })
        case .participant:
            Task { await self.finDuPartage() }
        }
    }

    /// Le propriétaire a arrêté le partage : on garde une copie des listes, dans sa propre zone.
    private func finDuPartage() async {
        await reinitialiser(role: .proprietaire)
        await demarrer()
    }

    private func compteChange(_ changement: CKSyncEngine.Event.AccountChange) {
        switch changement.changeType {
        case .signIn:
            break
        case .signOut, .switchAccounts:
            // Autre compte (ou aucun) : on repart de zéro, en gardant les données locales.
            Task {
                await self.reinitialiser(role: .proprietaire)
                await self.demarrer()
            }
        @unknown default:
            break
        }
    }
}

// MARK: - Schéma (développement)

#if DEBUG
extension Synchronisation {
    /// Enregistre chaque type avec tous ses champs remplis, et un partage de zone, dans une zone
    /// temporaire de l'environnement de développement, puis l'efface. CloudKit ne crée un type
    /// ou un champ qu'à sa première écriture : sans cela, le schéma déployé en production serait
    /// incomplet, et la production refuserait le premier partage (`cloudkit.share`).
    func preparerSchema() async throws {
        let base = conteneurCloudKit.privateCloudDatabase
        let zoneTemporaire = CKRecordZone(zoneName: "SchemaJublo")
        _ = try await base.modifyRecordZones(saving: [zoneTemporaire], deleting: [])

        let date = Date.now
        let element = ElementListe(type: .wishList, titre: "Schéma", auteur: .pablo, pour: .julie, le: date)
        element.estCoche = true
        element.cocheLe = date
        element.cochePar = Membre.julie.rawValue
        element.rappelLe = date
        element.supprimeLe = date
        element.supprimePar = Membre.pablo.rawValue
        let cagnotte = Cagnotte(nom: "Schéma", objectifCentimes: 100, auteur: .pablo, le: date)
        cagnotte.supprimeLe = date
        cagnotte.supprimePar = Membre.pablo.rawValue
        let versement = Versement(montantCentimes: 100, note: "Schéma", auteur: .julie, le: date)
        versement.annuleLe = date
        versement.annulePar = Membre.julie.rawValue

        let evenement = Evenement(titre: "Schéma", debut: date, auteur: .pablo, le: date)
        evenement.fin = date
        evenement.journeeEntiere = true
        evenement.lieu = "Schéma"
        evenement.note = "Schéma"
        evenement.pourId = Membre.julie.rawValue
        evenement.rappelBrut = RappelEvenement.uneHeure.rawValue
        evenement.supprimeLe = date
        evenement.supprimePar = Membre.pablo.rawValue
        let destination = Destination(nom: "Schéma", auteur: .pablo, le: date)
        destination.quand = "Schéma"
        destination.budgetCentimes = 100
        destination.note = "Schéma"
        destination.statutBrut = StatutDestination.reservee.rawValue
        destination.avisPablo = 5
        destination.avisJulie = 4
        destination.cagnotteId = cagnotte.id
        destination.supprimeLe = date
        destination.supprimePar = Membre.pablo.rawValue
        let sortie = Sortie(nom: "Schéma", categorie: .expo, auteur: .julie, le: date)
        sortie.lieu = "Schéma"
        sortie.lien = "https://example.com"
        sortie.note = "Schéma"
        sortie.testeeLe = date
        sortie.avisPablo = 3
        sortie.avisJulie = 2
        sortie.supprimeLe = date
        sortie.supprimePar = Membre.julie.rawValue
        let retard = Retard(retardataire: .pablo, minutes: 10, survenuLe: date, auteur: .julie, le: date)
        retard.motif = "Schéma"
        retard.supprimeLe = date
        retard.supprimePar = Membre.julie.rawValue
        let souhait = Souhait(texte: "Schéma", mois: Souhait.cleMois(date), auteur: .julie, le: date)
        souhait.faitLe = date
        souhait.supprimeLe = date
        souhait.supprimePar = Membre.pablo.rawValue

        // Le versement reste en troisième position : son `cagnotteId` est ajouté plus bas.
        let modeles: [any Synchronisable] = [element, cagnotte, versement, evenement, destination, sortie, retard, souhait]
        let enregistrements = modeles.map { modele in
            let enregistrement = CKRecord(
                recordType: type(of: modele).typeEnregistrement,
                recordID: CKRecord.ID(recordName: modele.id.uuidString, zoneID: zoneTemporaire.zoneID)
            )
            modele.remplir(enregistrement)
            return enregistrement
        }
        enregistrements[2]["cagnotteId"] = cagnotte.id.uuidString
        let partage = CKShare(recordZoneID: zoneTemporaire.zoneID)
        partage[CKShare.SystemFieldKey.title] = "Schéma"
        partage.publicPermission = .none
        _ = try await base.modifyRecords(saving: enregistrements + [partage], deleting: [])
        _ = try await base.modifyRecordZones(saving: [], deleting: [zoneTemporaire.zoneID])
    }
}
#endif

private let journal = Logger(subsystem: "com.pmassereyes.jublo", category: "Synchronisation")
