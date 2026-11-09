#if DEBUG
import Foundation
import SwiftData

/// Données d'exemple pour les aperçus et le réglage Nous › Debug.
@MainActor
enum DonneesDebug {
    static func remplir(_ contexte: ModelContext, maintenant: Date = .now) {
        /// Dépôt dont l'horloge est décalée dans le passé, pour des dates variées.
        func depot(ilYA heures: Double) -> Depot {
            Depot(contexte: contexte, horloge: { maintenant.addingTimeInterval(-heures * 3600) })
        }

        depot(ilYA: 50).ajouter("Renouveler l'assurance habitation", a: .penseBete, par: .pablo)
        depot(ilYA: 30).ajouter("Appeler le plombier", a: .penseBete, par: .julie)
        depot(ilYA: 3).ajouter("Réserver le resto pour samedi", a: .penseBete, par: .julie)

        depot(ilYA: 5).ajouter("Tomates cerises", a: .courses, par: .julie)
        depot(ilYA: 2).ajouter("Lait d'avoine", a: .courses, par: .pablo)
        depot(ilYA: 1).ajouter("Café en grains", a: .courses, par: .julie)
        if let pain = depot(ilYA: 26).ajouter("Pain complet", a: .courses, par: .pablo) {
            depot(ilYA: 20).basculer(pain, par: .julie)
        }

        depot(ilYA: 400).ajouter("Platine vinyle", a: .wishList, par: .pablo)
        depot(ilYA: 200).ajouter("Plaid en laine", a: .wishList, par: .julie)

        if let beurre = depot(ilYA: 100).ajouter("Beurre doux", a: .courses, par: .pablo) {
            depot(ilYA: 72).supprimer(beurre, par: .julie)
        }
        if let rappel = depot(ilYA: 900).ajouter("Rendre les clés à Marc", a: .penseBete, par: .julie) {
            depot(ilYA: 600).supprimer(rappel, par: .pablo)
        }
    }
}
#endif
