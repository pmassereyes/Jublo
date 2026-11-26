import Foundation

/// Ce qu'un enregistrement reçu de CloudKit a changé dans une liste ou dans l'agenda, pour
/// prévenir l'autre membre (voir `Annonces`). Seuls les éléments de liste et les rendez-vous
/// sont concernés, et seulement quand la version reçue est plus récente que la version locale.
struct ChangementRecu: Equatable {
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
    let titre: String
    /// Qui a fait le changement, quand l'enregistrement le dit (auteur, coché par, supprimé
    /// par) ; nil pour une modification de rendez-vous, faite forcément sur l'autre iPhone.
    let par: Membre?
    /// Date de la modification (`modifieLe` reçu).
    let le: Date
}

/// État d'un élément de liste ou d'un rendez-vous avant d'appliquer un enregistrement reçu.
struct EtatAvantReception {
    private let supprime: Bool
    private let coche: Bool
    /// Champs visibles d'un rendez-vous : un changement de rappel seul n'est pas annoncé.
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

    /// Changement entre cet état et le modèle une fois l'enregistrement appliqué.
    func changement(vers modele: any Synchronisable) -> ChangementRecu? {
        switch modele {
        case let element as ElementListe:
            if !supprime, element.supprimeLe != nil {
                return ChangementRecu(element, .suppression, par: element.supprimePar)
            }
            if !supprime, !coche, element.estCoche {
                return ChangementRecu(element, .coche, par: element.cochePar)
            }
            return nil
        case let evenement as Evenement:
            if !supprime, evenement.supprimeLe != nil {
                return ChangementRecu(evenement, .suppression, par: evenement.supprimePar)
            }
            if !supprime, evenement.supprimeLe == nil, champsVisibles != Self.champsVisibles(evenement) {
                return ChangementRecu(evenement, .modification, par: nil)
            }
            return nil
        default:
            return nil
        }
    }

    /// Ajout d'un modèle reçu pour la première fois, s'il n'est pas déjà à la corbeille.
    static func ajout(_ modele: any Synchronisable) -> ChangementRecu? {
        switch modele {
        case let element as ElementListe where element.supprimeLe == nil:
            ChangementRecu(element, .ajout, par: element.auteurId)
        case let evenement as Evenement where evenement.supprimeLe == nil:
            ChangementRecu(evenement, .ajout, par: evenement.auteurId)
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

private extension ChangementRecu {
    init(_ element: ElementListe, _ nature: Nature, par: String?) {
        self.init(
            nature: nature, sujet: .liste(element.type, pour: element.type == .wishList ? element.destinataire : nil),
            titre: element.titre, par: par.flatMap(Membre.init(rawValue:)), le: element.modifieLe
        )
    }

    init(_ evenement: Evenement, _ nature: Nature, par: String?) {
        self.init(
            nature: nature,
            sujet: .agenda(debut: evenement.debut, fin: evenement.finEffective, journeeEntiere: evenement.journeeEntiere),
            titre: evenement.titre, par: par.flatMap(Membre.init(rawValue:)), le: evenement.modifieLe
        )
    }
}
