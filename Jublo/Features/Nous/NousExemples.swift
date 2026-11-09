/// Données d'exemple de l'onglet Nous (phase 1).
enum NousExemples {
    struct Souhait: Identifiable {
        let auteur: Membre
        /// Suite de « j'aimerais que tu… ».
        let texte: String

        var id: String { texte }
    }

    /// Retards du mois, par membre.
    static let retards: [Membre: Int] = [.pablo: 3, .julie: 5]

    static let souhaits = [
        Souhait(auteur: .julie, texte: "cuisines un vrai dîner un soir de semaine, sans écran."),
        Souhait(auteur: .pablo, texte: "viennes grimper avec moi un samedi matin."),
    ]
}
