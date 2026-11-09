import Foundation
import OSLog
import SwiftData

/// Point d'entrée unique pour toutes les écritures.
///
/// Les vues lisent avec `@Query` mais ne modifient jamais un modèle elles-mêmes :
/// en phase 2, c'est ici que chaque changement sera signalé à CKSyncEngine.
@MainActor
@Observable
final class Depot {
    /// Durée de conservation dans la corbeille avant la purge.
    static let dureeCorbeille: TimeInterval = 30 * 24 * 60 * 60

    let contexte: ModelContext
    private let horloge: () -> Date

    init(contexte: ModelContext, horloge: @escaping () -> Date = { .now }) {
        self.contexte = contexte
        self.horloge = horloge
    }

    // MARK: - Listes

    /// Ajoute un élément à une liste. Renvoie nil si le titre est vide.
    /// `destinataire` ne compte que pour la wish list (par défaut : l'auteur).
    @discardableResult
    func ajouter(_ titre: String, a type: TypeListe, par membre: Membre, pour destinataire: Membre? = nil) -> ElementListe? {
        let titre = titre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !titre.isEmpty else { return nil }
        let element = ElementListe(type: type, titre: titre, auteur: membre, pour: destinataire, le: horloge())
        contexte.insert(element)
        enregistrer()
        return element
    }

    /// Coche ou décoche un élément, en retenant qui l'a coché.
    func basculer(_ element: ElementListe, par membre: Membre) {
        let maintenant = horloge()
        element.estCoche.toggle()
        element.cocheLe = element.estCoche ? maintenant : nil
        element.cochePar = element.estCoche ? membre.rawValue : nil
        element.modifieLe = maintenant
        enregistrer()
    }

    // MARK: - Cagnotte

    @discardableResult
    func creerCagnotte(_ nom: String, objectifCentimes: Int? = nil, par membre: Membre) -> Cagnotte {
        let cagnotte = Cagnotte(nom: nom, objectifCentimes: objectifCentimes, auteur: membre, le: horloge())
        contexte.insert(cagnotte)
        enregistrer()
        return cagnotte
    }

    @discardableResult
    func verser(_ montantCentimes: Int, dans cagnotte: Cagnotte, par membre: Membre, note: String? = nil) -> Versement {
        let versement = Versement(montantCentimes: montantCentimes, note: note, auteur: membre, le: horloge())
        contexte.insert(versement)
        versement.cagnotte = cagnotte
        enregistrer()
        return versement
    }

    /// Annule un versement : il reste dans l'historique mais sort du solde.
    func annuler(_ versement: Versement, par membre: Membre) {
        guard !versement.estAnnule else { return }
        let maintenant = horloge()
        versement.annuleLe = maintenant
        versement.annulePar = membre.rawValue
        versement.modifieLe = maintenant
        enregistrer()
    }

    // MARK: - Corbeille

    /// Met un élément à la corbeille.
    func supprimer(_ element: some Suppressible, par membre: Membre) {
        guard element.supprimeLe == nil else { return }
        let maintenant = horloge()
        element.supprimeLe = maintenant
        element.supprimePar = membre.rawValue
        element.modifieLe = maintenant
        enregistrer()
    }

    /// Sort un élément de la corbeille.
    func restaurer(_ element: some Suppressible) {
        guard element.supprimeLe != nil else { return }
        element.supprimeLe = nil
        element.supprimePar = nil
        element.modifieLe = horloge()
        enregistrer()
    }

    /// Éléments de la corbeille, du plus récemment supprimé au plus ancien.
    /// Chaque nouveau type `Suppressible` doit être ajouté ici.
    func elementsDansLaCorbeille() -> [any Suppressible] {
        var elements: [any Suppressible] = []
        elements += lire(FetchDescriptor<ElementListe>(predicate: #Predicate { $0.supprimeLe != nil }))
            .map { $0 as any Suppressible }
        elements += lire(FetchDescriptor<Cagnotte>(predicate: #Predicate { $0.supprimeLe != nil }))
            .map { $0 as any Suppressible }
        return elements.sorted { ($0.supprimeLe ?? .distantPast) > ($1.supprimeLe ?? .distantPast) }
    }

    /// Supprime définitivement les éléments mis à la corbeille depuis plus de 30 jours,
    /// sauf ceux qui ne sont pas purgeables. Les versements, qui ne sont pas
    /// `Suppressible`, ne sont jamais concernés.
    @discardableResult
    func purger() -> Int {
        let limite = horloge().addingTimeInterval(-Self.dureeCorbeille)
        let aPurger = elementsDansLaCorbeille().filter { element in
            guard let supprimeLe = element.supprimeLe else { return false }
            return supprimeLe < limite && element.estPurgeable
        }
        for element in aPurger {
            contexte.delete(element)
        }
        if !aPurger.isEmpty {
            enregistrer()
        }
        return aPurger.count
    }

    /// Date à laquelle un élément de la corbeille sera purgé.
    static func datePurge(de element: some Suppressible) -> Date? {
        element.supprimeLe?.addingTimeInterval(dureeCorbeille)
    }

    // MARK: - Privé

    private func lire<Modele: PersistentModel>(_ descripteur: FetchDescriptor<Modele>) -> [Modele] {
        do {
            return try contexte.fetch(descripteur)
        } catch {
            journal.error("Lecture impossible : \(error)")
            return []
        }
    }

    private func enregistrer() {
        do {
            try contexte.save()
        } catch {
            journal.error("Enregistrement impossible : \(error)")
        }
    }
}

private let journal = Logger(subsystem: "com.pmassereyes.jublo", category: "Depot")
