import Foundation

/// Ce dont l'autre est prévenu, même Jublo fermé : une liste ou l'agenda.
enum RubriqueSignal: String, CaseIterable {
    case penseBete, courses, wishList, agenda

    /// Rubriques de la wish list, du pense-bête et des courses.
    static let listes: Set<RubriqueSignal> = [.penseBete, .courses, .wishList]

    init(_ type: TypeListe) {
        switch type {
        case .penseBete: self = .penseBete
        case .courses: self = .courses
        case .wishList: self = .wishList
        }
    }
}

/// Notifications « Julie a mis à jour les courses », envoyées par iCloud même quand Jublo est
/// fermé, comme celles de Notes.
///
/// L'iPhone qui fait un changement écrit un **signal** : un enregistrement CloudKit à nom fixe,
/// un par rubrique et par destinataire, réécrit à chaque fois et jamais supprimé (une
/// suppression déclencherait aussi la notification). L'autre iPhone est abonné à ses signaux
/// (`CKDatabaseSubscription` filtrée sur leur type) avec un texte fixé à l'abonnement : iCloud
/// affiche la notification sans réveiller Jublo. Les titres ne passent jamais en clair.
///
/// Un signal par rubrique au plus toutes les 10 minutes. Pas de signal pour les suppressions
/// dans les listes, les rendez-vous passés, ni dans la wish list, sauf pour une envie que
/// l'auteur ajoute pour lui-même (une idée pour l'autre ou un cadeau offert gâcheraient la
/// surprise). Un changement de rappel seul n'est pas signalé.
enum Signaux {
    /// Délai minimal entre deux signaux d'une même rubrique.
    static let intervalle: TimeInterval = 10 * 60
    static let prefixeAbonnement = "jublo.signal."

    /// Rubrique à signaler pour un changement fait sur cet iPhone, ou nil.
    static func rubrique(_ changement: Changement, maintenant: Date, calendrier: Calendar = .current) -> RubriqueSignal? {
        switch changement.sujet {
        case .liste(let type, let pour):
            switch (type, changement.nature) {
            case (.wishList, .ajout):
                return pour == changement.auteur ? .wishList : nil
            case (.penseBete, .ajout), (.penseBete, .coche), (.courses, .ajout), (.courses, .coche):
                return RubriqueSignal(type)
            default:
                return nil
            }
        case .agenda(_, let fin, _):
            guard changement.nature != .coche, fin >= calendrier.startOfDay(for: maintenant) else { return nil }
            return .agenda
        }
    }

    /// Type d'enregistrement CloudKit du signal destiné à `destinataire` (« SignalCoursesPourJulie »).
    /// Le destinataire fait partie du type : on n'est jamais abonné à ses propres signaux.
    static func typeEnregistrement(_ rubrique: RubriqueSignal, pour destinataire: Membre) -> String {
        "Signal\(nomType(rubrique))Pour\(destinataire.prenom)"
    }

    /// Nom fixe de l'enregistrement : il est réécrit à chaque signal.
    static func nomEnregistrement(_ rubrique: RubriqueSignal, pour destinataire: Membre) -> String {
        "signal-\(rubrique.rawValue)-\(destinataire.rawValue)"
    }

    static func identifiantAbonnement(_ rubrique: RubriqueSignal) -> String {
        prefixeAbonnement + rubrique.rawValue
    }

    /// Rubrique d'une notification reçue, d'après son abonnement.
    static func rubrique(abonnement: String?) -> RubriqueSignal? {
        guard let abonnement, abonnement.hasPrefix(prefixeAbonnement) else { return nil }
        return RubriqueSignal(rawValue: String(abonnement.dropFirst(prefixeAbonnement.count)))
    }

    /// Titre de la notification : la liste, ou « Agenda ».
    static func titre(_ rubrique: RubriqueSignal) -> String {
        switch rubrique {
        case .penseBete: TypeListe.penseBete.titre
        case .courses: TypeListe.courses.titre
        case .wishList: TypeListe.wishList.titre
        case .agenda: "Agenda"
        }
    }

    /// Texte de la notification, vu par le destinataire : `auteur` est l'autre.
    static func texte(_ rubrique: RubriqueSignal, de auteur: Membre) -> String {
        switch rubrique {
        case .penseBete: "\(auteur.prenom) a mis à jour le pense-bête"
        case .courses: "\(auteur.prenom) a mis à jour les courses"
        case .wishList: "\(auteur.prenom) a ajouté une envie à sa wish list"
        case .agenda: "\(auteur.prenom) a mis à jour l'agenda"
        }
    }

    /// Écran à ouvrir quand on touche la notification (clés de `Navigation.ouvrir`) : pour la
    /// wish list, les envies de l'autre.
    static func ecran(_ rubrique: RubriqueSignal) -> [String: String] {
        switch rubrique {
        case .agenda: ["onglet": "agenda"]
        case .wishList: ["onglet": "listes", "liste": TypeListe.wishList.rawValue, "envies": "autre"]
        case .penseBete: ["onglet": "listes", "liste": TypeListe.penseBete.rawValue]
        case .courses: ["onglet": "listes", "liste": TypeListe.courses.rawValue]
        }
    }

    private static func nomType(_ rubrique: RubriqueSignal) -> String {
        switch rubrique {
        case .penseBete: "PenseBete"
        case .courses: "Courses"
        case .wishList: "WishList"
        case .agenda: "Agenda"
        }
    }
}

/// Cadence des signaux : le premier changement d'une rafale part tout de suite, les suivants
/// de la même rubrique attendent `Signaux.intervalle`.
struct CadenceSignaux {
    private var derniers: [RubriqueSignal: Date] = [:]

    /// Vrai si un signal de cette rubrique peut partir maintenant ; le note comme parti.
    mutating func autoriser(_ rubrique: RubriqueSignal, a date: Date) -> Bool {
        if let dernier = derniers[rubrique], date.timeIntervalSince(dernier) < Signaux.intervalle {
            return false
        }
        derniers[rubrique] = date
        return true
    }
}
