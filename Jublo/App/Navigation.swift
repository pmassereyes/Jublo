import Observation

/// Onglet et liste affichés. Partagé par la racine, l'onglet Listes et le délégué des
/// notifications : toucher une notification ouvre l'écran dont elle parle.
@MainActor
@Observable
final class Navigation {
    /// Instance de l'app, pour le délégué des notifications.
    private(set) static weak var courante: Navigation?

    var onglet: RacineView.Onglet
    /// Liste à ouvrir dans l'onglet Listes ; `ListesView` la prend puis la remet à nil.
    var listeDemandee: TypeListe?

    init(onglet: RacineView.Onglet = .initial, courante: Bool = false) {
        self.onglet = onglet
        if courante {
            Self.courante = self
        }
    }

    /// Ouvre l'écran décrit par une notification (clés `onglet` et `liste`).
    func ouvrir(_ infos: [String: String]) {
        if let onglet = infos["onglet"].flatMap(RacineView.Onglet.init(rawValue:)) {
            self.onglet = onglet
        }
        listeDemandee = infos["liste"].flatMap(TypeListe.init(rawValue:))
    }
}
