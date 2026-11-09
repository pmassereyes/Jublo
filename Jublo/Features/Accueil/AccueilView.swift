import SwiftData
import SwiftUI

struct AccueilView: View {
    @Environment(Identite.self) private var identite
    @Query(filter: #Predicate<ElementListe> { $0.supprimeLe == nil && !$0.estCoche })
    private var aFaire: [ElementListe]

    var body: some View {
        Page {
            Text(Formats.jour(.now))
                .font(.jubloCorps)
                .foregroundStyle(.texteSecondaire)

            VStack(alignment: .leading, spacing: 8) {
                TitreSection(titre: "Listes")
                Carte {
                    VStack(spacing: 0) {
                        ForEach(TypeListe.allCases) { type in
                            ligneListe(type)
                            if type != TypeListe.allCases.last {
                                Divider().overlay(Color.separateur)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                TitreSection(titre: "À venir", detail: "exemple")
                ForEach(AgendaExemples.evenements().prefix(2)) { evenement in
                    LigneEvenement(evenement: evenement)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                TitreSection(titre: "Cagnotte", detail: "exemple")
                CarteCagnotte(cagnotte: ProjetsExemples.cagnotte, nombreVersements: 0)
            }

            NavigationLink {
                AssistantView()
            } label: {
                Label("Demander à l'assistant", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pilule)
        }
        .navigationTitle("Salut \(identite.membre.prenom)")
    }

    private func ligneListe(_ type: TypeListe) -> some View {
        let nombre = aFaire.filter { $0.type == type }.count
        return HStack {
            Text(type.titre)
                .font(.jubloCorps)
                .foregroundStyle(.texte)
            Spacer()
            Text(nombre == 0 ? "rien en attente" : "\(nombre) en attente")
                .font(.jubloCorpsFort)
                .foregroundStyle(nombre == 0 ? Color.texteSecondaire : Color.texte)
        }
        .frame(minHeight: Mesures.zoneTactile)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    NavigationStack { AccueilView() }.apercuJublo()
}
#endif
