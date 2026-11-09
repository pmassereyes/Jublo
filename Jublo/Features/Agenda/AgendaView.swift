import SwiftUI

struct AgendaView: View {
    var body: some View {
        Page {
            ForEach(AgendaExemples.parJour(), id: \.jour) { groupe in
                VStack(alignment: .leading, spacing: 8) {
                    TitreSection(titre: Self.titre(du: groupe.jour))
                    ForEach(groupe.evenements) { evenement in
                        LigneEvenement(evenement: evenement)
                    }
                }
            }
            MentionExemple()
        }
        .navigationTitle("Agenda")
    }

    /// « Aujourd'hui », « Demain » ou « Jeudi 12 novembre ».
    static func titre(du jour: Date) -> String {
        let calendrier = Calendar.current
        if calendrier.isDateInToday(jour) { return "Aujourd'hui" }
        if calendrier.isDateInTomorrow(jour) { return "Demain" }
        return Formats.jour(jour)
    }
}

/// Carte d'un événement. Les événements communs ont un contour.
struct LigneEvenement: View {
    let evenement: EvenementExemple

    @Environment(Identite.self) private var identite

    var body: some View {
        Carte(contour: evenement.pour == nil ? .commun : nil) {
            HStack(spacing: Mesures.espacement) {
                Text(evenement.debut.formatted(.dateTime.hour().minute().locale(.jublo)))
                    .font(.jubloCorpsFort)
                    .foregroundStyle(.texte)
                    .frame(minWidth: 48, alignment: .leading)
                Capsule()
                    .fill(evenement.pour?.couleur ?? .commun)
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(evenement.titre)
                        .font(.jubloCorpsFort)
                        .foregroundStyle(.texte)
                    Text(sousTitre)
                        .font(.jubloLegende)
                        .foregroundStyle(.texteSecondaire)
                }
                Spacer(minLength: 0)
                PastilleMembre(membre: evenement.pour)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var sousTitre: String {
        let pour = evenement.pour.map { Libelles.quiEnDebut($0, vuPar: identite.membre) } ?? "Nous deux"
        return [pour, evenement.lieu].compactMap(\.self).joined(separator: " · ")
    }
}

#if DEBUG
#Preview {
    NavigationStack { AgendaView() }.apercuJublo()
}
#endif
