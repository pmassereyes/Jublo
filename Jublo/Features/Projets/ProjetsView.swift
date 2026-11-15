import SwiftUI

struct ProjetsView: View {
    var body: some View {
        Page {
            BientotDisponible(
                titre: "Cagnotte",
                symbole: "eurosign.circle",
                description: "Mettre de côté ensemble pour un projet, avec l'historique des versements."
            )
            BientotDisponible(
                titre: "Vacances envisagées",
                symbole: "airplane",
                description: "Les idées de destinations, à comparer à deux."
            )
            BientotDisponible(
                titre: "Sorties à tester",
                symbole: "mappin.and.ellipse",
                description: "Restaurants, expos et activités repérés par l'un ou l'autre."
            )
        }
        .navigationTitle("Projets")
    }
}

#if DEBUG
#Preview {
    NavigationStack { ProjetsView() }.apercuJublo()
}
#endif
