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
        enregistrement["rappelLe"] = rappelLe
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
        rappelLe = enregistrement["rappelLe"] as? Date
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

extension Evenement: Synchronisable {
    static var typeEnregistrement: String { "Evenement" }

    func remplir(_ enregistrement: CKRecord) {
        enregistrement.encryptedValues["titre"] = titre
        enregistrement["debut"] = debut
        enregistrement["fin"] = fin
        enregistrement["journeeEntiere"] = journeeEntiere
        enregistrement.encryptedValues["lieu"] = lieu
        enregistrement.encryptedValues["note"] = note
        enregistrement["pourId"] = pourId
        enregistrement["rappelBrut"] = rappelBrut
        enregistrement.remplirSuppressible(self)
    }

    func reprendre(_ enregistrement: CKRecord) {
        titre = enregistrement.encryptedValues["titre"] as? String ?? ""
        debut = enregistrement["debut"] as? Date ?? .now
        fin = enregistrement["fin"] as? Date
        journeeEntiere = enregistrement["journeeEntiere"] as? Bool ?? false
        lieu = enregistrement.encryptedValues["lieu"] as? String
        note = enregistrement.encryptedValues["note"] as? String
        pourId = enregistrement["pourId"] as? String
        rappelBrut = enregistrement["rappelBrut"] as? String
        enregistrement.reprendreSuppressible(self)
    }
}

extension Destination: Synchronisable {
    static var typeEnregistrement: String { "Destination" }

    func remplir(_ enregistrement: CKRecord) {
        enregistrement.encryptedValues["nom"] = nom
        enregistrement.encryptedValues["quand"] = quand
        enregistrement["budgetCentimes"] = budgetCentimes
        enregistrement.encryptedValues["note"] = note
        enregistrement["statutBrut"] = statutBrut
        enregistrement["avisPablo"] = avisPablo
        enregistrement["avisJulie"] = avisJulie
        enregistrement["cagnotteId"] = cagnotteId?.uuidString
        enregistrement.remplirSuppressible(self)
    }

    func reprendre(_ enregistrement: CKRecord) {
        nom = enregistrement.encryptedValues["nom"] as? String ?? ""
        quand = enregistrement.encryptedValues["quand"] as? String
        budgetCentimes = enregistrement["budgetCentimes"] as? Int
        note = enregistrement.encryptedValues["note"] as? String
        statutBrut = enregistrement["statutBrut"] as? String ?? StatutDestination.envisagee.rawValue
        avisPablo = enregistrement["avisPablo"] as? Int
        avisJulie = enregistrement["avisJulie"] as? Int
        cagnotteId = (enregistrement["cagnotteId"] as? String).flatMap(UUID.init(uuidString:))
        enregistrement.reprendreSuppressible(self)
    }
}

extension Sortie: Synchronisable {
    static var typeEnregistrement: String { "Sortie" }

    func remplir(_ enregistrement: CKRecord) {
        enregistrement.encryptedValues["nom"] = nom
        enregistrement["categorieBrut"] = categorieBrut
        enregistrement.encryptedValues["lieu"] = lieu
        enregistrement.encryptedValues["lien"] = lien
        enregistrement.encryptedValues["note"] = note
        enregistrement["testeeLe"] = testeeLe
        enregistrement["avisPablo"] = avisPablo
        enregistrement["avisJulie"] = avisJulie
        enregistrement.remplirSuppressible(self)
    }

    func reprendre(_ enregistrement: CKRecord) {
        nom = enregistrement.encryptedValues["nom"] as? String ?? ""
        categorieBrut = enregistrement["categorieBrut"] as? String ?? CategorieSortie.autre.rawValue
        lieu = enregistrement.encryptedValues["lieu"] as? String
        lien = enregistrement.encryptedValues["lien"] as? String
        note = enregistrement.encryptedValues["note"] as? String
        testeeLe = enregistrement["testeeLe"] as? Date
        avisPablo = enregistrement["avisPablo"] as? Int
        avisJulie = enregistrement["avisJulie"] as? Int
        enregistrement.reprendreSuppressible(self)
    }
}

extension Retard: Synchronisable {
    static var typeEnregistrement: String { "Retard" }

    func remplir(_ enregistrement: CKRecord) {
        enregistrement["retardataireId"] = retardataireId
        enregistrement["minutes"] = minutes
        enregistrement.encryptedValues["motif"] = motif
        enregistrement["survenuLe"] = survenuLe
        enregistrement.remplirSuppressible(self)
    }

    func reprendre(_ enregistrement: CKRecord) {
        retardataireId = enregistrement["retardataireId"] as? String ?? Membre.pablo.rawValue
        minutes = enregistrement["minutes"] as? Int ?? 0
        motif = enregistrement.encryptedValues["motif"] as? String
        survenuLe = enregistrement["survenuLe"] as? Date ?? .now
        enregistrement.reprendreSuppressible(self)
    }
}

extension Souhait: Synchronisable {
    static var typeEnregistrement: String { "Souhait" }

    func remplir(_ enregistrement: CKRecord) {
        enregistrement.encryptedValues["texte"] = texte
        enregistrement["mois"] = mois
        enregistrement["faitLe"] = faitLe
        enregistrement.remplirSuppressible(self)
    }

    func reprendre(_ enregistrement: CKRecord) {
        texte = enregistrement.encryptedValues["texte"] as? String ?? ""
        mois = enregistrement["mois"] as? String ?? ""
        faitLe = enregistrement["faitLe"] as? Date
        enregistrement.reprendreSuppressible(self)
    }
}

/// Champs communs aux modèles `Suppressible` créés à partir de la V4 : auteur, dates et
/// suppression douce. Les modèles plus anciens les écrivent eux-mêmes, champ par champ.
private protocol ChampsCommuns: AnyObject {
    var auteurId: String { get set }
    var creeLe: Date { get set }
    var modifieLe: Date { get set }
    var supprimeLe: Date? { get set }
    var supprimePar: String? { get set }
}

extension Evenement: ChampsCommuns {}
extension Destination: ChampsCommuns {}
extension Sortie: ChampsCommuns {}
extension Retard: ChampsCommuns {}
extension Souhait: ChampsCommuns {}

private extension CKRecord {
    func remplirSuppressible(_ modele: some ChampsCommuns) {
        self["auteurId"] = modele.auteurId
        self["creeLe"] = modele.creeLe
        self["modifieLe"] = modele.modifieLe
        self["supprimeLe"] = modele.supprimeLe
        self["supprimePar"] = modele.supprimePar
    }

    func reprendreSuppressible(_ modele: some ChampsCommuns) {
        modele.auteurId = self["auteurId"] as? String ?? ""
        modele.creeLe = self["creeLe"] as? Date ?? .now
        modele.modifieLe = self["modifieLe"] as? Date ?? .now
        modele.supprimeLe = self["supprimeLe"] as? Date
        modele.supprimePar = self["supprimePar"] as? String
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
