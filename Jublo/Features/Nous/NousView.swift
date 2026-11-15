import SwiftUI

struct NousView: View {
    @Environment(Identite.self) private var identite
    @Environment(ConfigurationAssistant.self) private var configurationAssistant

    var body: some View {
        @Bindable var identite = identite

        Page {
            BientotDisponible(
                titre: "Compteur de retards",
                symbole: "clock",
                description: "Qui fait attendre l'autre, mois après mois."
            )
            BientotDisponible(
                titre: "Ce mois-ci, j'aimerais que tu…",
                symbole: "heart.text.square",
                description: "Chaque mois, une envie confiée à l'autre."
            )

            NavigationLink {
                ReglagesAssistantView()
            } label: {
                Carte {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Assistant", systemImage: "sparkles")
                                .font(.jubloCorpsFort)
                            Text(configurationAssistant.manque == nil
                                 ? "\(configurationAssistant.fournisseur.nom) · prêt"
                                 : "À configurer")
                                .font(.jubloLegende)
                                .foregroundStyle(.texteSecondaire)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.texteSecondaire)
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(.texte)
                    .frame(minHeight: Mesures.zoneTactile)
                }
            }
            .buttonStyle(.plain)

            NavigationLink {
                CorbeilleView()
            } label: {
                Carte {
                    HStack {
                        Label("Corbeille", systemImage: "trash")
                            .font(.jubloCorpsFort)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.texteSecondaire)
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(.texte)
                    .frame(minHeight: Mesures.zoneTactile)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                TitreSection(titre: "Cet iPhone")
                Carte {
                    VStack(alignment: .leading, spacing: Mesures.espacement) {
                        Text("Je suis")
                            .font(.jubloCorpsFort)
                            .foregroundStyle(.texte)
                        SelecteurPilules(options: Membre.allCases, selection: $identite.membre, titre: \.prenom) { membre in
                            membre.couleur
                        }
                        .overlay(Capsule().strokeBorder(Color.separateur))
                        Text("Sert à signer ce que tu ajoutes, coches ou supprimes.")
                            .font(.jubloLegende)
                            .foregroundStyle(.texteSecondaire)
                    }
                }
            }
        }
        .navigationTitle("Nous")
    }
}

#if DEBUG
#Preview {
    NavigationStack { NousView() }.apercuJublo()
}
#endif
