import AppIntents
import Foundation

/// « Dis Siri, ajoute un rendez-vous dans Jublo » : Siri demande le rendez-vous et la date, puis
/// l'enregistre dans l'agenda partagé sans ouvrir l'app. Le rendez-vous part ensuite vers
/// l'autre iPhone comme ceux saisis à la main.
///
/// L'intention tourne dans le processus de l'app (lancé en arrière-plan au besoin) et passe par
/// le `Depot` de l'app, enregistré dans `AppDependencyManager` par `JubloApp`.
struct AjouterRendezVous: AppIntent {
    static let title: LocalizedStringResource = "Ajouter un rendez-vous"
    static let description = IntentDescription("Ajoute un rendez-vous à l'agenda partagé de Jublo.")

    @Parameter(title: "Rendez-vous", requestValueDialog: "Quel rendez-vous ?")
    var titre: String

    @Parameter(title: "Quand", requestValueDialog: "C'est quand ?")
    var quand: Date

    @Parameter(title: "Pour", default: .nousDeux)
    var pour: PourQuiSiri

    static var parameterSummary: some ParameterSummary {
        Summary("Ajouter \(\.$titre) le \(\.$quand) pour \(\.$pour)")
    }

    @Dependency private var depot: Depot
    @Dependency private var identite: Identite
    @Dependency private var synchronisation: Synchronisation

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let evenement = try RendezVousDicte.enregistrer(
            titre: titre, quand: quand, pour: pour, depot: depot, identite: identite
        )
        // Lancée par Siri, l'app n'a pas d'écran : la synchronisation n'a pas démarré. On envoie
        // tout de suite, sans faire attendre Siri au-delà de quelques secondes ; sinon, le
        // rendez-vous partira à la prochaine ouverture de Jublo.
        await synchronisation.synchroniser(auPlus: .seconds(5))
        return .result(dialog: IntentDialog(stringLiteral: RendezVousDicte.confirmation(evenement, vuPar: identite.membre)))
    }
}

/// Pour qui est un rendez-vous dicté à Siri. « Moi » désigne le membre de cet iPhone.
enum PourQuiSiri: String, AppEnum {
    case nousDeux, moi, pablo, julie

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Pour"
    static let caseDisplayRepresentations: [PourQuiSiri: DisplayRepresentation] = [
        .nousDeux: DisplayRepresentation(title: "nous deux", synonyms: ["vous deux", "tous les deux", "nous"]),
        .moi: "moi",
        .pablo: "Pablo",
        .julie: "Julie",
    ]

    /// Membre concerné, nil pour « vous deux » (comme `Evenement.pourId`).
    func membre(courant: Membre) -> Membre? {
        switch self {
        case .nousDeux: nil
        case .moi: courant
        case .pablo: .pablo
        case .julie: .julie
        }
    }
}

/// Logique du raccourci, séparée de l'intention pour être testée.
@MainActor
enum RendezVousDicte {
    enum Erreur: Error, CustomLocalizedStringResourceConvertible {
        case membreInconnu, titreVide

        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .membreInconnu: "Ouvre Jublo une première fois pour dire qui utilise cet iPhone."
            case .titreVide: "Il me faut le nom du rendez-vous."
            }
        }
    }

    /// Enregistre le rendez-vous au nom du membre de cet iPhone. Une heure à minuit pile vient
    /// d'une date dite sans heure (« demain ») : le rendez-vous dure alors toute la journée.
    @discardableResult
    static func enregistrer(
        titre: String, quand: Date, pour: PourQuiSiri, depot: Depot, identite: Identite,
        calendrier: Calendar = .current
    ) throws -> Evenement {
        // On ne signe jamais à la place de quelqu'un : sans membre choisi, on refuse.
        guard identite.estChoisi else { throw Erreur.membreInconnu }
        let journeeEntiere = calendrier.startOfDay(for: quand) == quand
        guard let evenement = depot.ajouterEvenement(
            titre, debut: quand, journeeEntiere: journeeEntiere,
            pour: pour.membre(courant: identite.membre), par: identite.membre
        ) else { throw Erreur.titreVide }
        return evenement
    }

    /// Ce que Siri répond : « C'est noté : « Dîner chez Marc », demain à 20:00. »
    static func confirmation(
        _ evenement: Evenement, vuPar courant: Membre, maintenant: Date = .now, calendrier: Calendar = .current
    ) -> String {
        let jour = Formats.jourProche(evenement.debut, maintenant: maintenant, calendrier: calendrier)
        let jourDansLaPhrase = jour.prefix(1).lowercased() + jour.dropFirst()
        let quand = evenement.journeeEntiere
            ? "\(jourDansLaPhrase), toute la journée"
            : "\(jourDansLaPhrase) à \(Formats.heure(evenement.debut))"
        let pour = evenement.concerne.map { " (pour \(Libelles.qui($0, vuPar: courant)))" } ?? ""
        return "C'est noté : « \(evenement.titre) », \(quand)\(pour)."
    }
}
