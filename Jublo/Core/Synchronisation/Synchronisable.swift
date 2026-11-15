import CloudKit
import SwiftData

/// Modèle synchronisé avec CloudKit. Le nom de l'enregistrement est l'`id` du modèle : un même
/// élément garde le même nom partout, ce qui rend les fusions sans doublon.
///
/// Les textes personnels (titres, noms, notes) sont stockés en champs chiffrés (`encryptedValues`).
protocol Synchronisable: PersistentModel {
    static var typeEnregistrement: String { get }
    var id: UUID { get set }
    var modifieLe: Date { get }

    /// Écrit les champs du modèle dans l'enregistrement.
    func remplir(_ enregistrement: CKRecord)
    /// Reprend les champs d'un enregistrement reçu. Les relations sont résolues par `MiroirLocal`.
    func reprendre(_ enregistrement: CKRecord)
}

extension ElementListe: Synchronisable {
    static var typeEnregistrement: String { "ElementListe" }

    func remplir(_ enregistrement: CKRecord) {
        enregistrement["typeBrut"] = typeBrut
        enregistrement.encryptedValues["titre"] = titre
        enregistrement["estCoche"] = estCoche
        enregistrement["cocheLe"] = cocheLe
        enregistrement["cochePar"] = cochePar
        enregistrement["pourId"] = pourId
        enregistrement["auteurId"] = auteurId
        enregistrement["creeLe"] = creeLe
        enregistrement["modifieLe"] = modifieLe
        enregistrement["supprimeLe"] = supprimeLe
        enregistrement["supprimePar"] = supprimePar
    }

    func reprendre(_ enregistrement: CKRecord) {
        typeBrut = enregistrement["typeBrut"] as? String ?? TypeListe.penseBete.rawValue
        titre = enregistrement.encryptedValues["titre"] as? String ?? ""
        estCoche = enregistrement["estCoche"] as? Bool ?? false
        cocheLe = enregistrement["cocheLe"] as? Date
        cochePar = enregistrement["cochePar"] as? String
        pourId = enregistrement["pourId"] as? String
        auteurId = enregistrement["auteurId"] as? String ?? ""
        creeLe = enregistrement["creeLe"] as? Date ?? .now
        modifieLe = enregistrement["modifieLe"] as? Date ?? .now
        supprimeLe = enregistrement["supprimeLe"] as? Date
        supprimePar = enregistrement["supprimePar"] as? String
    }
}

extension Cagnotte: Synchronisable {
    static var typeEnregistrement: String { "Cagnotte" }

    func remplir(_ enregistrement: CKRecord) {
        enregistrement.encryptedValues["nom"] = nom
        enregistrement["objectifCentimes"] = objectifCentimes
        enregistrement["auteurId"] = auteurId
        enregistrement["creeLe"] = creeLe
        enregistrement["modifieLe"] = modifieLe
        enregistrement["supprimeLe"] = supprimeLe
        enregistrement["supprimePar"] = supprimePar
    }

    func reprendre(_ enregistrement: CKRecord) {
        nom = enregistrement.encryptedValues["nom"] as? String ?? ""
        objectifCentimes = enregistrement["objectifCentimes"] as? Int
        auteurId = enregistrement["auteurId"] as? String ?? ""
        creeLe = enregistrement["creeLe"] as? Date ?? .now
        modifieLe = enregistrement["modifieLe"] as? Date ?? .now
        supprimeLe = enregistrement["supprimeLe"] as? Date
        supprimePar = enregistrement["supprimePar"] as? String
    }
}

extension Versement: Synchronisable {
    static var typeEnregistrement: String { "Versement" }

    func remplir(_ enregistrement: CKRecord) {
        enregistrement["montantCentimes"] = montantCentimes
        enregistrement.encryptedValues["note"] = note
        enregistrement["cagnotteId"] = cagnotte?.id.uuidString
        enregistrement["auteurId"] = auteurId
        enregistrement["creeLe"] = creeLe
        enregistrement["modifieLe"] = modifieLe
        enregistrement["annuleLe"] = annuleLe
        enregistrement["annulePar"] = annulePar
    }

    func reprendre(_ enregistrement: CKRecord) {
        montantCentimes = enregistrement["montantCentimes"] as? Int ?? 0
        note = enregistrement.encryptedValues["note"] as? String
        auteurId = enregistrement["auteurId"] as? String ?? ""
        creeLe = enregistrement["creeLe"] as? Date ?? .now
        modifieLe = enregistrement["modifieLe"] as? Date ?? .now
        annuleLe = enregistrement["annuleLe"] as? Date
        annulePar = enregistrement["annulePar"] as? String
    }
}

extension CKRecord {
    /// Champs système (zone, étiquette de version…), à conserver entre deux envois.
    var champsSysteme: Data {
        let archiveur = NSKeyedArchiver(requiringSecureCoding: true)
        encodeSystemFields(with: archiveur)
        archiveur.finishEncoding()
        return archiveur.encodedData
    }

    /// Enregistrement vide portant les champs système mémorisés.
    static func depuisChampsSysteme(_ donnees: Data) -> CKRecord? {
        guard let lecteur = try? NSKeyedUnarchiver(forReadingFrom: donnees) else { return nil }
        lecteur.requiresSecureCoding = true
        defer { lecteur.finishDecoding() }
        return CKRecord(coder: lecteur)
    }
}
