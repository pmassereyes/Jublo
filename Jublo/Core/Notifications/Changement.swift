import Foundation

/// Ce qu'une écriture de `Depot` a changé dans une liste ou dans l'agenda, pour prévenir l'autre
/// membre (voir `Signaux`). Les autres modèles ne sont pas concernés.
struct Changement: Equatable {
    enum Nature: Hashable {
        case ajout, coche, modification, suppression
    }

    enum Sujet: Equatable {
        /// `pour` : destinataire d'une envie de la wish list.
        case liste(TypeListe, pour: Membre?)
        case agenda(debut: Date, fin: Date, journeeEntiere: Bool)
    }

    let nature: Nature
    let sujet: Sujet
    /// Auteur de l'élément (pour reconnaître une envie notée pour soi-même).
    let auteur: Membre?
}

/// État d'un élément de liste ou d'un rendez-vous avant une écriture, pour savoir ensuite ce
/// qu'elle a changé.
struct EtatAvantChangement {
    private let supprime: Bool
    private let coche: Bool
    /// Champs visibles d'un rendez-vous : un changement de rappel seul ne compte pas.
    private let champsVisibles: [String?]

    init?(_ modele: any Synchronisable) {
        switch modele {
        case let element as ElementListe:
            supprime = element.supprimeLe != nil
            coche = element.estCoche
            champsVisibles = []
        case let evenement as Evenement:
            supprime = evenement.supprimeLe != nil
            coche = false
            champsVisibles = Self.champsVisibles(evenement)
        default:
            return nil
        }
    }

    /// Changement entre cet état et le modèle après l'écriture : mise à la corbeille, élément
    /// coché, ou rendez-vous modifié. Décocher, restaurer ou changer un rappel ne compte pas.
    func changement(vers modele: any Synchronisable) -> Changement? {
        switch modele {
        case let element as ElementListe:
            if !supprime, element.supprimeLe != nil {
                return Changement(element, .suppression)
            }
            if !supprime, !coche, element.estCoche {
                return Changement(element, .coche)
            }
            return nil
        case let evenement as Evenement:
            if !supprime, evenement.supprimeLe != nil {
                return Changement(evenement, .suppression)
            }
            if !supprime, evenement.supprimeLe == nil, champsVisibles != Self.champsVisibles(evenement) {
                return Changement(evenement, .modification)
            }
            return nil
        default:
            return nil
        }
    }

    /// Ajout d'un élément de liste ou d'un rendez-vous.
    static func ajout(_ modele: any Synchronisable) -> Changement? {
        switch modele {
        case let element as ElementListe where element.supprimeLe == nil:
            Changement(element, .ajout)
        case let evenement as Evenement where evenement.supprimeLe == nil:
            Changement(evenement, .ajout)
        default:
            nil
        }
    }

    private static func champsVisibles(_ evenement: Evenement) -> [String?] {
        [
            evenement.titre, evenement.debut.timeIntervalSinceReferenceDate.description,
            evenement.fin?.timeIntervalSinceReferenceDate.description, evenement.journeeEntiere.description,
            evenement.lieu, evenement.note, evenement.pourId,
        ]
    }
}

private extension Changement {
    init(_ element: ElementListe, _ nature: Nature) {
        self.init(
            nature: nature,
            sujet: .liste(element.type, pour: element.type == .wishList ? element.destinataire : nil),
            auteur: element.auteur
        )
    }

    init(_ evenement: Evenement, _ nature: Nature) {
        self.init(
            nature: nature,
            sujet: .agenda(debut: evenement.debut, fin: evenement.finEffective, journeeEntiere: evenement.journeeEntiere),
            auteur: evenement.auteur
        )
    }
}
