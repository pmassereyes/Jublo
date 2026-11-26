import Foundation
import Observation
import SwiftData

/// Notifications de cet iPhone : autorisation, **rappels** du pense-bête et de l'agenda
/// (reprogrammés à partir de la base après chaque enregistrement, qu'il vienne de `Depot` ou de
/// CloudKit), et préférences des notifications « l'autre a mis à jour… », envoyées par iCloud
/// (`Signaux`, abonnements gérés par `Synchronisation`).
///
/// Les préférences sont propres à cet iPhone (`UserDefaults`).
@MainActor
@Observable
final class Notificateur {
    /// Instance de l'app, pour le délégué UIKit (réveil par une notification push).
    private(set) static weak var courant: Notificateur?

    private(set) var statut: StatutNotifications = .aDemander

    /// Être prévenu quand l'autre modifie les listes.
    var annoncerListes: Bool {
        didSet { stockage.set(annoncerListes, forKey: Cle.listes) }
    }

    /// Être prévenu quand l'autre modifie l'agenda.
    var annoncerAgenda: Bool {
        didSet { stockage.set(annoncerAgenda, forKey: Cle.agenda) }
    }

    @ObservationIgnored private let centre: any CentreNotifications
    @ObservationIgnored private let contexte: ModelContext
    @ObservationIgnored private let identite: Identite
    @ObservationIgnored private let stockage: UserDefaults
    @ObservationIgnored private let horloge: () -> Date
    @ObservationIgnored private var planification: Task<Void, Never>?
    @ObservationIgnored private var observation: (any NSObjectProtocol)?

    private enum Cle {
        static let listes = "notifications.listes"
        static let agenda = "notifications.agenda"
    }

    init(
        contexte: ModelContext,
        identite: Identite,
        centre: any CentreNotifications,
        stockage: UserDefaults = .standard,
        horloge: @escaping () -> Date = { .now },
        courant: Bool = false
    ) {
        self.contexte = contexte
        self.identite = identite
        self.centre = centre
        self.stockage = stockage
        self.horloge = horloge
        annoncerListes = stockage.object(forKey: Cle.listes) as? Bool ?? true
        annoncerAgenda = stockage.object(forKey: Cle.agenda) as? Bool ?? true
        if courant {
            Self.courant = self
        }
    }

    // MARK: - Autorisation

    func actualiserStatut() async {
        statut = await centre.statut()
    }

    /// Affiche la demande du système si elle n'a jamais été faite, puis programme les rappels.
    func demanderAutorisationSiBesoin() async {
        await actualiserStatut()
        guard statut == .aDemander else { return }
        _ = await centre.demanderAutorisation()
        await actualiserStatut()
        await replanifier()
    }

    // MARK: - Rappels

    /// Reprogramme les rappels après chaque enregistrement de la base, qu'il vienne de `Depot`
    /// ou de la synchronisation.
    func ecouterLaBase() {
        guard observation == nil else { return }
        observation = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: contexte, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.planifierBientot() }
        }
    }

    /// Reprogramme les rappels un instant plus tard, une seule fois pour une rafale d'enregistrements.
    func planifierBientot() {
        planification?.cancel()
        planification = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await replanifier()
        }
    }

    /// Met les rappels programmés en accord avec la base : ajoute ou met à jour ceux à venir,
    /// retire ceux d'éléments cochés, supprimés ou qui ne concernent plus ce membre.
    func replanifier() async {
        guard identite.estChoisi, await centre.statut() == .autorisees else { return }
        let penseBete = TypeListe.penseBete.rawValue
        let elements = (try? contexte.fetch(FetchDescriptor<ElementListe>(predicate: #Predicate {
            $0.typeBrut == penseBete && $0.supprimeLe == nil && !$0.estCoche && $0.rappelLe != nil
        }))) ?? []
        let evenements = (try? contexte.fetch(FetchDescriptor<Evenement>(predicate: #Predicate {
            $0.supprimeLe == nil && $0.rappelBrut != nil
        }))) ?? []
        let prevus = Rappels.prevus(elements: elements, evenements: evenements, pour: identite.membre, maintenant: horloge())
        let gardes = Set(prevus.map(\.identifiant))
        let enAttente = await centre.identifiantsEnAttente()
        centre.retirer(enAttente.filter { $0.hasPrefix(Rappels.prefixe) && !gardes.contains($0) })
        for rappel in prevus {
            await centre.programmer(rappel)
        }
    }

    /// Abonnements voulus aux signaux de l'autre, d'après les réglages ; nil sans membre choisi.
    var abonnementsVoulus: Synchronisation.AbonnementsVoulus? {
        guard identite.estChoisi else { return nil }
        var rubriques: Set<RubriqueSignal> = []
        if annoncerListes { rubriques.formUnion(RubriqueSignal.listes) }
        if annoncerAgenda { rubriques.insert(.agenda) }
        return Synchronisation.AbonnementsVoulus(membre: identite.membre, rubriques: rubriques)
    }
}
