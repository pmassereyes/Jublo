import Foundation

/// Données d'exemple de l'onglet Projets (phase 1).
enum ProjetsExemples {
    struct VersementExemple: Identifiable {
        let id: Int
        let auteur: Membre
        let montantCentimes: Int
        let ilYAJours: Int
        var annule = false
    }

    struct Cagnotte {
        let nom: String
        let objectifCentimes: Int
        let versements: [VersementExemple]

        /// Même règle que le modèle : les versements annulés sont exclus du solde.
        var soldeCentimes: Int {
            versements.filter { !$0.annule }.reduce(0) { $0 + $1.montantCentimes }
        }
    }

    struct Idee: Identifiable {
        let titre: String
        let detail: String
        let proposePar: Membre

        var id: String { titre }
    }

    static let cagnotte = Cagnotte(
        nom: "Week-end à Lisbonne",
        objectifCentimes: 80_000,
        versements: [
            VersementExemple(id: 1, auteur: .julie, montantCentimes: 15_000, ilYAJours: 3),
            VersementExemple(id: 2, auteur: .pablo, montantCentimes: 5_000, ilYAJours: 6, annule: true),
            VersementExemple(id: 3, auteur: .pablo, montantCentimes: 20_000, ilYAJours: 12),
            VersementExemple(id: 4, auteur: .julie, montantCentimes: 7_500, ilYAJours: 30),
        ]
    )

    static let vacances = [
        Idee(titre: "Lisbonne", detail: "Printemps · 4 jours", proposePar: .julie),
        Idee(titre: "Islande en van", detail: "Été · 10 jours", proposePar: .pablo),
        Idee(titre: "Les Pouilles", detail: "Septembre · une semaine", proposePar: .julie),
    ]

    static let sorties = [
        Idee(titre: "Le petit libanais du canal", detail: "Restaurant", proposePar: .julie),
        Idee(titre: "Expo photo au Jeu de Paume", detail: "Exposition", proposePar: .pablo),
        Idee(titre: "Bloc à Arkose", detail: "Escalade", proposePar: .pablo),
    ]
}
