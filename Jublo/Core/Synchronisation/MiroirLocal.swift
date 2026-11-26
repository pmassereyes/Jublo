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
        Evenement.typeEnregistrement, Destination.typeEnregistrement, Sortie.typeEnregistrement,
        Retard.typeEnregistrement, Souhait.typeEnregistrement,
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
        modeles += tous(Evenement.self) + tous(Destination.self) + tous(Sortie.self)
        modeles += tous(Retard.self) + tous(Souhait.self)
        return modeles
    }

    // MARK: - Réception

    /// Applique des enregistrements reçus. Si un modèle a un changement local en attente plus
    /// récent, il est gardé tel quel : son envoi l'emportera.
    /// Renvoie ce qui a changé dans les listes et l'agenda, pour prévenir ce membre.
    @discardableResult
    func appliquer(_ enregistrements: [CKRecord], enAttente: Set<String> = []) -> [ChangementRecu] {
        let tries = enregistrements.sorted { rang($0.recordType) < rang($1.recordType) }
        let changements = tries.compactMap { appliquer($0, enAttente: enAttente) }
        enregistrer()
        return changements
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
            completerAvis(local, depuis: serveur)
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
        case Evenement.typeEnregistrement?:
            return chercher(Evenement.self, id)
        case Destination.typeEnregistrement?:
            return chercher(Destination.self, id)
        case Sortie.typeEnregistrement?:
            return chercher(Sortie.self, id)
        case Retard.typeEnregistrement?:
            return chercher(Retard.self, id)
        case Souhait.typeEnregistrement?:
            return chercher(Souhait.self, id)
        case nil:
            return Self.typesEnregistrement.lazy.compactMap { modele(id, type: $0) }.first
        default:
            return nil
        }
    }

    /// Applique un enregistrement. Renvoie le changement à annoncer : un modèle inconnu ici, ou
    /// une version strictement plus récente que la version locale (une relecture de toute la
    /// zone ne renvoie donc rien de ce que cet iPhone a déjà).
    private func appliquer(_ enregistrement: CKRecord, enAttente: Set<String>) -> ChangementRecu? {
        let nom = enregistrement.recordID.recordName
        guard let id = UUID(uuidString: nom), let nouveau = fabriquer(enregistrement.recordType) else { return nil }
        let modifieSurLeServeur = enregistrement["modifieLe"] as? Date ?? .distantPast
        var changement: ChangementRecu?
        if let local = modele(id, type: enregistrement.recordType) {
            if enAttente.contains(nom) && local.modifieLe > modifieSurLeServeur {
                completerAvis(local, depuis: enregistrement)
                memoriser(enregistrement)
                return nil
            }
            let avant = modifieSurLeServeur > local.modifieLe ? EtatAvantReception(local) : nil
            local.reprendre(enregistrement)
            relier(local, enregistrement)
            changement = avant?.changement(vers: local)
        } else {
            let modele = nouveau()
            modele.id = id
            modele.reprendre(enregistrement)
            contexte.insert(modele)
            relier(modele, enregistrement)
            changement = EtatAvantReception.ajout(modele)
        }
        memoriser(enregistrement)
        return changement
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
        case Evenement.typeEnregistrement:
            { Evenement(titre: "", debut: .now, auteur: .pablo, le: .now) }
        case Destination.typeEnregistrement:
            { Destination(nom: "", auteur: .pablo, le: .now) }
        case Sortie.typeEnregistrement:
            { Sortie(nom: "", categorie: .autre, auteur: .pablo, le: .now) }
        case Retard.typeEnregistrement:
            { Retard(retardataire: .pablo, minutes: 0, survenuLe: .now, auteur: .pablo, le: .now) }
        case Souhait.typeEnregistrement:
            { Souhait(texte: "", mois: "", auteur: .pablo, le: .now) }
        default:
            nil
        }
    }

    /// La version locale l'emporte sur celle du serveur, mais chacun note de son côté : elle
    /// reprend l'avis que l'autre a donné entre-temps et qu'elle n'a pas encore. Seule limite :
    /// un avis effacé ici au même moment qu'une autre modification revient.
    private func completerAvis(_ local: any Synchronisable, depuis serveur: CKRecord) {
        guard let note = local as? any AvisDuCouple else { return }
        if note.avisPablo == nil, let avis = serveur["avisPablo"] as? Int {
            note.avisPablo = avis
        }
        if note.avisJulie == nil, let avis = serveur["avisJulie"] as? Int {
            note.avisJulie = avis
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

    // Filtres écrits type par type : SwiftData ne sait pas filtrer sur une propriété
    // atteinte à travers un protocole.
    private func chercher(_: Evenement.Type, _ id: UUID) -> Evenement? {
        try? contexte.fetch(FetchDescriptor<Evenement>(predicate: #Predicate { $0.id == id })).first
    }

    private func chercher(_: Destination.Type, _ id: UUID) -> Destination? {
        try? contexte.fetch(FetchDescriptor<Destination>(predicate: #Predicate { $0.id == id })).first
    }

    private func chercher(_: Sortie.Type, _ id: UUID) -> Sortie? {
        try? contexte.fetch(FetchDescriptor<Sortie>(predicate: #Predicate { $0.id == id })).first
    }

    private func chercher(_: Retard.Type, _ id: UUID) -> Retard? {
        try? contexte.fetch(FetchDescriptor<Retard>(predicate: #Predicate { $0.id == id })).first
    }

    private func chercher(_: Souhait.Type, _ id: UUID) -> Souhait? {
        try? contexte.fetch(FetchDescriptor<Souhait>(predicate: #Predicate { $0.id == id })).first
    }

    private func tous<Modele: Suppressible>(_: Modele.Type) -> [any Synchronisable] {
        ((try? contexte.fetch(FetchDescriptor<Modele>())) ?? []).map { $0 as any Synchronisable }
    }
}

private let journal = Logger(subsystem: "com.pmassereyes.jublo", category: "Synchronisation")
