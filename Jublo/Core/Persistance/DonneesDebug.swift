#if DEBUG
import Foundation
import SwiftData

/// Données d'exemple pour les aperçus Xcode et les tests d'interface (`-exemples`).
/// Jamais visibles dans l'app elle-même.
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
        depot(ilYA: 30).ajouter("Cours de céramique", a: .wishList, par: .pablo, pour: .julie)

        if let beurre = depot(ilYA: 100).ajouter("Beurre doux", a: .courses, par: .pablo) {
            depot(ilYA: 72).supprimer(beurre, par: .julie)
        }
        if let rappel = depot(ilYA: 900).ajouter("Rendre les clés à Marc", a: .penseBete, par: .julie) {
            depot(ilYA: 600).supprimer(rappel, par: .pablo)
        }

        // Agenda : aujourd'hui, demain soir, un week-end, et un rendez-vous passé.
        let calendrier = Calendar.current
        let aujourdHui = calendrier.startOfDay(for: maintenant)
        func jour(_ decalage: Int, _ heure: Int = 0) -> Date {
            calendrier.date(byAdding: DateComponents(day: decalage, hour: heure), to: aujourdHui) ?? maintenant
        }
        depot(ilYA: 20).ajouterEvenement("Dentiste", debut: jour(0, 18), fin: jour(0, 19), lieu: "Rue Oberkampf", pour: .pablo, par: .pablo)
        depot(ilYA: 48).ajouterEvenement("Dîner chez Léa et Tom", debut: jour(1, 20), lieu: "Montreuil", note: "Apporter le dessert", par: .julie)
        depot(ilYA: 70).ajouterEvenement("Week-end à Lyon", debut: jour(9), fin: jour(10), journeeEntiere: true, par: .pablo)
        depot(ilYA: 300).ajouterEvenement("Yoga", debut: jour(-3, 19), pour: .julie, par: .julie)

        // Cagnotte avec quelques versements.
        let lisbonne = depot(ilYA: 500).creerCagnotte("Lisbonne", objectifCentimes: 120_000, par: .julie)
        depot(ilYA: 480).verser(30_000, dans: lisbonne, par: .julie, note: "Prime")
        depot(ilYA: 300).verser(25_000, dans: lisbonne, par: .pablo)
        let erreur = depot(ilYA: 100).verser(5_000, dans: lisbonne, par: .pablo)
        depot(ilYA: 99).annuler(erreur, par: .pablo)

        // Vacances envisagées.
        if let porto = depot(ilYA: 400).ajouterDestination("Porto", quand: "Printemps 2027", budgetCentimes: 90_000, par: .julie) {
            depot(ilYA: 390).donnerAvis(5, sur: porto, par: .julie)
            depot(ilYA: 380).donnerAvis(4, sur: porto, par: .pablo)
        }
        if let corse = depot(ilYA: 200).ajouterDestination("La Corse en van", quand: "Été 2027", par: .pablo) {
            depot(ilYA: 190).donnerAvis(5, sur: corse, par: .pablo)
            depot(ilYA: 180).donnerAvis(2, sur: corse, par: .julie)
        }

        // Sorties à tester.
        depot(ilYA: 60).ajouterSortie("Le Servan", categorie: .restaurant, lieu: "Paris 11e", lien: "leservan.com", par: .julie)
        depot(ilYA: 30).ajouterSortie("Expo Hockney", categorie: .expo, lieu: "Centre Pompidou", par: .pablo)
        if let bar = depot(ilYA: 300).ajouterSortie("Le Syndicat", categorie: .bar, lieu: "Paris 10e", par: .pablo) {
            depot(ilYA: 200).basculerTestee(bar)
            depot(ilYA: 199).donnerAvis(4, sur: bar, par: .pablo)
            depot(ilYA: 198).donnerAvis(5, sur: bar, par: .julie)
        }

        // Retards du mois et souhaits.
        depot(ilYA: 50).noterRetard(de: .julie, minutes: 15, motif: "Métro", par: .pablo)
        depot(ilYA: 26).noterRetard(de: .pablo, minutes: 10, par: .julie)
        depot(ilYA: 4).noterRetard(de: .julie, minutes: 5, par: .julie)
        depot(ilYA: 100).confierSouhait("m'emmènes voir un concert", par: .julie)
        if let souhait = depot(ilYA: 90).confierSouhait("me laisses choisir le film du vendredi", par: .pablo) {
            depot(ilYA: 10).basculerFait(souhait)
        }
    }
}
#endif
