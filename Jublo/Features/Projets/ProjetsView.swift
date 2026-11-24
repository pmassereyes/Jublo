import SwiftData
import SwiftUI

/// Projets à deux : cagnottes, vacances envisagées et sorties à tester.
struct ProjetsView: View {
    @Query(filter: #Predicate<Cagnotte> { $0.supprimeLe == nil }) private var cagnottes: [Cagnotte]
    @Query(filter: Destination.actives) private var destinations: [Destination]
    @Query(filter: Sortie.actives) private var sorties: [Sortie]

    var body: some View {
        Page {
            NavigationLink {
                CagnottesView()
            } label: {
                CarteRubrique(titre: "Cagnotte", symbole: "eurosign.circle", resume: resumeCagnottes)
            }
            .buttonStyle(.plain)

            NavigationLink {
                VacancesView()
            } label: {
                CarteRubrique(titre: "Vacances envisagées", symbole: "airplane", resume: resumeVacances)
            }
            .buttonStyle(.plain)

            NavigationLink {
                SortiesView()
            } label: {
                CarteRubrique(titre: "Sorties à tester", symbole: "mappin.and.ellipse", resume: resumeSorties)
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Projets")
    }

    private var resumeCagnottes: String {
        guard !cagnottes.isEmpty else { return "Mettre de côté ensemble pour un projet." }
        let total = cagnottes.reduce(0) { $0 + $1.soldeCentimes }
        let nombre = cagnottes.count == 1 ? "1 cagnotte" : "\(cagnottes.count) cagnottes"
        return "\(nombre) · \(Formats.montant(total)) de côté"
    }

    private var resumeVacances: String {
        let envisagees = destinations.filter { $0.statut == .envisagee }
        guard let favorite = envisagees.max(by: { $0.scoreCommun < $1.scoreCommun }) else {
            return "Les idées de destinations, à comparer à deux."
        }
        let nombre = envisagees.count == 1 ? "1 idée" : "\(envisagees.count) idées"
        return favorite.scoreCommun > 0 ? "\(nombre) · \(favorite.nom) en tête" : nombre
    }

    private var resumeSorties: String {
        let aTester = sorties.filter { !$0.estTestee }.count
        guard !sorties.isEmpty else { return "Restaurants, expos et activités repérés par l'un ou l'autre." }
        return aTester == 0 ? "Tout est testé !" : "\(aTester) à tester"
    }
}

#if DEBUG
#Preview {
    NavigationStack { ProjetsView() }.apercuJublo()
}
#endif
