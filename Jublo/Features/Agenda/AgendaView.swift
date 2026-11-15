import SwiftUI

struct AgendaView: View {
    var body: some View {
        Page {
            BientotDisponible(
                titre: "Agenda partagé",
                symbole: "calendar",
                description: "Vos rendez-vous, sorties et week-ends, visibles par vous deux."
            )
        }
        .navigationTitle("Agenda")
    }
}

#if DEBUG
#Preview {
    NavigationStack { AgendaView() }.apercuJublo()
}
#endif
