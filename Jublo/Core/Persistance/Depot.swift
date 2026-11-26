import Foundation
import OSLog
import SwiftData

/// Reçoit chaque changement fait par `Depot`, pour l'envoyer à CloudKit (`Synchronisation`).
@MainActor
protocol ObservateurChangements: AnyObject {
    func aModifie(_ modele: any Synchronisable)
    func aSupprime(_ modele: any Synchronisable)
}

/// Point d'entrée unique pour toutes les écritures locales.
///
/// Les vues lisent avec `@Query` mais ne modifient jamais un modèle elles-mêmes : chaque
/// changement est signalé à `observateur`, qui l'envoie à CloudKit.
@MainActor
@Observable
final class Depot {
    /// Durée de conservation dans la corbeille avant la purge.
    static let dureeCorbeille: TimeInterval = 30 * 24 * 60 * 60

    let contexte: ModelContext
    private let horloge: () -> Date
    @ObservationIgnored weak var observateur: (any ObservateurChangements)?

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
        observateur?.aModifie(element)
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
        observateur?.aModifie(element)
    }

    /// Programme (ou retire, avec nil) le rappel d'un élément du pense-bête.
    func programmerRappel(_ date: Date?, pour element: ElementListe) {
        guard element.type == .penseBete || date == nil, element.rappelLe != date else { return }
        modifier(element) { $0.rappelLe = date }
    }

    // MARK: - Cagnotte

    @discardableResult
    func creerCagnotte(_ nom: String, objectifCentimes: Int? = nil, par membre: Membre) -> Cagnotte {
        let cagnotte = Cagnotte(nom: nom, objectifCentimes: objectifCentimes, auteur: membre, le: horloge())
        contexte.insert(cagnotte)
        enregistrer()
        observateur?.aModifie(cagnotte)
        return cagnotte
    }

    @discardableResult
    func verser(_ montantCentimes: Int, dans cagnotte: Cagnotte, par membre: Membre, note: String? = nil) -> Versement {
        let versement = Versement(montantCentimes: montantCentimes, note: note, auteur: membre, le: horloge())
        contexte.insert(versement)
        versement.cagnotte = cagnotte
        enregistrer()
        observateur?.aModifie(versement)
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
        observateur?.aModifie(versement)
    }

    // MARK: - Agenda

    /// Ajoute un rendez-vous. Renvoie nil si le titre est vide.
    /// `concerne` : le membre concerné, ou nil pour les deux.
    @discardableResult
    func ajouterEvenement(
        _ titre: String, debut: Date, fin: Date? = nil, journeeEntiere: Bool = false,
        lieu: String? = nil, note: String? = nil, pour concerne: Membre? = nil,
        rappel: RappelEvenement? = nil, par membre: Membre
    ) -> Evenement? {
        guard let titre = Self.texte(titre) else { return nil }
        let evenement = Evenement(titre: titre, debut: debut, auteur: membre, le: horloge())
        evenement.fin = fin.map { max($0, debut) }
        evenement.journeeEntiere = journeeEntiere
        evenement.lieu = Self.texte(lieu)
        evenement.note = Self.texte(note)
        evenement.pourId = concerne?.rawValue
        evenement.rappelBrut = rappel?.adapte(journeeEntiere: journeeEntiere).rawValue
        return inserer(evenement)
    }

    // MARK: - Vacances envisagées

    @discardableResult
    func ajouterDestination(
        _ nom: String, quand: String? = nil, budgetCentimes: Int? = nil, note: String? = nil, par membre: Membre
    ) -> Destination? {
        guard let nom = Self.texte(nom) else { return nil }
        let destination = Destination(nom: nom, auteur: membre, le: horloge())
        destination.quand = Self.texte(quand)
        destination.budgetCentimes = budgetCentimes
        destination.note = Self.texte(note)
        return inserer(destination)
    }

    func changerStatut(_ statut: StatutDestination, de destination: Destination) {
        guard destination.statut != statut else { return }
        modifier(destination) { $0.statutBrut = statut.rawValue }
    }

    // MARK: - Sorties à tester

    @discardableResult
    func ajouterSortie(
        _ nom: String, categorie: CategorieSortie, lieu: String? = nil, lien: String? = nil,
        note: String? = nil, par membre: Membre
    ) -> Sortie? {
        guard let nom = Self.texte(nom) else { return nil }
        let sortie = Sortie(nom: nom, categorie: categorie, auteur: membre, le: horloge())
        sortie.lieu = Self.texte(lieu)
        sortie.lien = Self.texte(lien)
        sortie.note = Self.texte(note)
        return inserer(sortie)
    }

    /// Marque une sortie comme testée, ou la remet à tester.
    func basculerTestee(_ sortie: Sortie) {
        let maintenant = horloge()
        modifier(sortie) { $0.testeeLe = $0.testeeLe == nil ? maintenant : nil }
    }

    /// Note de 1 à 5 donnée par `membre` ; nil efface son avis.
    func donnerAvis(_ avis: Int?, sur element: some Suppressible & AvisDuCouple, par membre: Membre) {
        guard element.avis(de: membre) != avis else { return }
        modifier(element) { $0.definirAvis(avis, de: membre) }
    }

    // MARK: - Retards

    /// Note un retard. Renvoie nil si la durée n'est pas positive.
    @discardableResult
    func noterRetard(
        de retardataire: Membre, minutes: Int, motif: String? = nil, le date: Date? = nil, par membre: Membre
    ) -> Retard? {
        guard minutes > 0 else { return nil }
        let maintenant = horloge()
        let retard = Retard(retardataire: retardataire, minutes: minutes, survenuLe: date ?? maintenant, auteur: membre, le: maintenant)
        retard.motif = Self.texte(motif)
        return inserer(retard)
    }

    // MARK: - Ce mois-ci, j'aimerais que tu…

    /// Confie un souhait à l'autre pour le mois de `date` (par défaut, le mois en cours).
    /// Renvoie nil si le texte est vide.
    @discardableResult
    func confierSouhait(_ texte: String, pour date: Date? = nil, par membre: Membre) -> Souhait? {
        guard let texte = Self.texte(texte) else { return nil }
        let maintenant = horloge()
        let souhait = Souhait(texte: texte, mois: Souhait.cleMois(date ?? maintenant), auteur: membre, le: maintenant)
        return inserer(souhait)
    }

    /// Coche ou décoche un souhait réalisé.
    func basculerFait(_ souhait: Souhait) {
        let maintenant = horloge()
        modifier(souhait) { $0.faitLe = $0.faitLe == nil ? maintenant : nil }
    }

    // MARK: - Modification

    /// Modifie un élément (formulaires d'édition, avis, statuts) : la date de modification
    /// avance, puis le changement est enregistré et envoyé.
    func modifier<Modele: Suppressible>(_ element: Modele, _ changement: (Modele) -> Void) {
        changement(element)
        element.modifieLe = horloge()
        enregistrer()
        observateur?.aModifie(element)
    }

    /// Texte nettoyé de ses espaces, ou nil s'il est vide.
    static func texte(_ texte: String?) -> String? {
        guard let propre = texte?.trimmingCharacters(in: .whitespacesAndNewlines), !propre.isEmpty else { return nil }
        return propre
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
        observateur?.aModifie(element)
    }

    /// Sort un élément de la corbeille.
    func restaurer(_ element: some Suppressible) {
        guard element.supprimeLe != nil else { return }
        element.supprimeLe = nil
        element.supprimePar = nil
        element.modifieLe = horloge()
        enregistrer()
        observateur?.aModifie(element)
    }

    /// Éléments de la corbeille, du plus récemment supprimé au plus ancien.
    /// Chaque nouveau type `Suppressible` doit être ajouté ici.
    func elementsDansLaCorbeille() -> [any Suppressible] {
        var elements: [any Suppressible] = []
        elements += lire(FetchDescriptor<ElementListe>(predicate: #Predicate { $0.supprimeLe != nil }))
            .map { $0 as any Suppressible }
        elements += lire(FetchDescriptor<Cagnotte>(predicate: #Predicate { $0.supprimeLe != nil }))
            .map { $0 as any Suppressible }
        elements += lire(FetchDescriptor<Evenement>(predicate: #Predicate { $0.supprimeLe != nil }))
            .map { $0 as any Suppressible }
        elements += lire(FetchDescriptor<Destination>(predicate: #Predicate { $0.supprimeLe != nil }))
            .map { $0 as any Suppressible }
        elements += lire(FetchDescriptor<Sortie>(predicate: #Predicate { $0.supprimeLe != nil }))
            .map { $0 as any Suppressible }
        elements += lire(FetchDescriptor<Retard>(predicate: #Predicate { $0.supprimeLe != nil }))
            .map { $0 as any Suppressible }
        elements += lire(FetchDescriptor<Souhait>(predicate: #Predicate { $0.supprimeLe != nil }))
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
            observateur?.aSupprime(element)
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

    private func inserer<Modele: Synchronisable>(_ modele: Modele) -> Modele {
        contexte.insert(modele)
        enregistrer()
        observateur?.aModifie(modele)
        return modele
    }

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
