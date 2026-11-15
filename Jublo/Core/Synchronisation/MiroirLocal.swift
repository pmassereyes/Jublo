import CloudKit
import Foundation
import OSLog
import SwiftData

/// Passerelle entre la base locale et les enregistrements CloudKit : construit les
/// enregistrements à envoyer et applique ceux reçus. Les changements reçus sont écrits
/// directement, sans passer par `Depot`, pour ne pas être renvoyés en boucle.
@MainActor
struct MiroirLocal {
    let contexte: ModelContext

    /// Types synchronisés, dans l'ordre où appliquer les changements reçus :
    /// une cagnotte avant ses versements.
    static let typesEnregistrement = [
        Cagnotte.typeEnregistrement, Versement.typeEnregistrement, ElementListe.typeEnregistrement,
    ]

    // MARK: - Envoi

    /// Enregistrement à envoyer pour un modèle, avec ses champs système s'il a déjà été envoyé
    /// dans cette zone.
    func enregistrement(pour modele: any Synchronisable, zone: CKRecordZone.ID) -> CKRecord {
        let identifiant = CKRecord.ID(recordName: modele.id.uuidString, zoneID: zone)
        let type = Swift.type(of: modele).typeEnregistrement
        let enregistrement: CKRecord
        if let donnees = metadonnees(modele.id.uuidString)?.champsSysteme,
           let connu = CKRecord.depuisChampsSysteme(donnees),
           connu.recordID == identifiant, connu.recordType == type {
            enregistrement = connu
        } else {
            enregistrement = CKRecord(recordType: type, recordID: identifiant)
        }
        modele.remplir(enregistrement)
        return enregistrement
    }

    /// Tous les modèles locaux, pour un premier envoi.
    func tousLesModeles() -> [any Synchronisable] {
        var modeles: [any Synchronisable] = []
        modeles += ((try? contexte.fetch(FetchDescriptor<Cagnotte>())) ?? []).map { $0 as any Synchronisable }
        modeles += ((try? contexte.fetch(FetchDescriptor<Versement>())) ?? []).map { $0 as any Synchronisable }
        modeles += ((try? contexte.fetch(FetchDescriptor<ElementListe>())) ?? []).map { $0 as any Synchronisable }
        return modeles
    }

    // MARK: - Réception

    /// Applique des enregistrements reçus. Si un modèle a un changement local en attente plus
    /// récent, il est gardé tel quel : son envoi l'emportera.
    func appliquer(_ enregistrements: [CKRecord], enAttente: Set<String> = []) {
        let tries = enregistrements.sorted { rang($0.recordType) < rang($1.recordType) }
        for enregistrement in tries {
            appliquer(enregistrement, enAttente: enAttente)
        }
        enregistrer()
    }

    /// Conflit à l'envoi : le serveur a une autre version de l'enregistrement. On garde la plus
    /// récente des deux. Renvoie vrai si la version locale doit être renvoyée.
    func resoudreConflit(avec serveur: CKRecord) -> Bool {
        memoriser(serveur)
        guard let id = UUID(uuidString: serveur.recordID.recordName),
              let local = modele(id, type: serveur.recordType) else {
            appliquer([serveur])
            return false
        }
        let modifieSurLeServeur = serveur["modifieLe"] as? Date ?? .distantPast
        if local.modifieLe > modifieSurLeServeur {
            enregistrer()
            return true
        }
        appliquer([serveur])
        return false
    }

    /// Supprime le modèle correspondant à un enregistrement effacé sur le serveur.
    func supprimer(_ identifiants: [CKRecord.ID]) {
        for identifiant in identifiants {
            guard let id = UUID(uuidString: identifiant.recordName) else { continue }
            if let modele = modele(id, type: nil) {
                contexte.delete(modele)
            }
            oublier(identifiant.recordName)
        }
        enregistrer()
    }

    // MARK: - Métadonnées

    /// Mémorise les champs système renvoyés par le serveur.
    func memoriser(_ enregistrement: CKRecord) {
        let nom = enregistrement.recordID.recordName
        if let existantes = metadonnees(nom) {
            existantes.champsSysteme = enregistrement.champsSysteme
        } else {
            contexte.insert(MetadonneesSync(nomEnregistrement: nom, champsSysteme: enregistrement.champsSysteme))
        }
    }

    func oublier(_ nomEnregistrement: String) {
        if let existantes = metadonnees(nomEnregistrement) {
            contexte.delete(existantes)
        }
    }

    /// Oublie toutes les métadonnées : changement de zone ou de compte iCloud.
    func oublierTout() {
        try? contexte.delete(model: MetadonneesSync.self)
        enregistrer()
    }

    func enregistrer() {
        do {
            try contexte.save()
        } catch {
            journal.error("Enregistrement impossible après synchronisation : \(error)")
        }
    }

    // MARK: - Recherche

    /// Modèle local portant cet identifiant, du type indiqué ou de n'importe quel type.
    func modele(_ id: UUID, type: String?) -> (any Synchronisable)? {
        switch type {
        case ElementListe.typeEnregistrement?:
            return element(id)
        case Cagnotte.typeEnregistrement?:
            return cagnotte(id)
        case Versement.typeEnregistrement?:
            return versement(id)
        case nil:
            return element(id) ?? cagnotte(id) ?? versement(id)
        default:
            return nil
        }
    }

    private func appliquer(_ enregistrement: CKRecord, enAttente: Set<String>) {
        let nom = enregistrement.recordID.recordName
        guard let id = UUID(uuidString: nom), let nouveau = fabriquer(enregistrement.recordType) else { return }
        let modifieSurLeServeur = enregistrement["modifieLe"] as? Date ?? .distantPast
        if let local = modele(id, type: enregistrement.recordType) {
            if enAttente.contains(nom) && local.modifieLe > modifieSurLeServeur {
                memoriser(enregistrement)
                return
            }
            local.reprendre(enregistrement)
            relier(local, enregistrement)
        } else {
            let modele = nouveau()
            modele.id = id
            modele.reprendre(enregistrement)
            contexte.insert(modele)
            relier(modele, enregistrement)
        }
        memoriser(enregistrement)
    }

    /// Fabrique un modèle vide du type de l'enregistrement, ou nil pour un type inconnu
    /// (par exemple le partage lui-même, « cloudkit.share »).
    private func fabriquer(_ type: String) -> (() -> any Synchronisable)? {
        switch type {
        case ElementListe.typeEnregistrement:
            { ElementListe(type: .penseBete, titre: "", auteur: .pablo, le: .now) }
        case Cagnotte.typeEnregistrement:
            { Cagnotte(nom: "", objectifCentimes: nil, auteur: .pablo, le: .now) }
        case Versement.typeEnregistrement:
            { Versement(montantCentimes: 0, note: nil, auteur: .pablo, le: .now) }
        default:
            nil
        }
    }

    private func relier(_ modele: any Synchronisable, _ enregistrement: CKRecord) {
        guard let versement = modele as? Versement else { return }
        let idCagnotte = (enregistrement["cagnotteId"] as? String).flatMap(UUID.init(uuidString:))
        versement.cagnotte = idCagnotte.flatMap(cagnotte)
    }

    private func rang(_ type: String) -> Int {
        Self.typesEnregistrement.firstIndex(of: type) ?? Self.typesEnregistrement.count
    }

    private func metadonnees(_ nom: String) -> MetadonneesSync? {
        try? contexte.fetch(FetchDescriptor<MetadonneesSync>(predicate: #Predicate { $0.nomEnregistrement == nom })).first
    }

    private func element(_ id: UUID) -> ElementListe? {
        try? contexte.fetch(FetchDescriptor<ElementListe>(predicate: #Predicate { $0.id == id })).first
    }

    private func cagnotte(_ id: UUID) -> Cagnotte? {
        try? contexte.fetch(FetchDescriptor<Cagnotte>(predicate: #Predicate { $0.id == id })).first
    }

    private func versement(_ id: UUID) -> Versement? {
        try? contexte.fetch(FetchDescriptor<Versement>(predicate: #Predicate { $0.id == id })).first
    }
}

private let journal = Logger(subsystem: "com.pmassereyes.jublo", category: "Synchronisation")
