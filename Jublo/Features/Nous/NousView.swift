import SwiftUI

struct NousView: View {
    @Environment(Identite.self) private var identite
    @Environment(Depot.self) private var depot

    var body: some View {
        @Bindable var identite = identite

        Page {
            VStack(alignment: .leading, spacing: 8) {
                TitreSection(titre: "Retards ce mois-ci")
                HStack(spacing: Mesures.espacement) {
                    ForEach(Membre.allCases) { membre in
                        compteurRetards(membre)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                TitreSection(titre: "Ce mois-ci, j'aimerais que tu…")
                ForEach(NousExemples.souhaits) { souhait in
                    carteSouhait(souhait)
                }
            }

            MentionExemple()

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
                TitreSection(titre: "Debug")
                Carte {
                    VStack(alignment: .leading, spacing: Mesures.espacement) {
                        Text("Je suis")
                            .font(.jubloCorpsFort)
                            .foregroundStyle(.texte)
                        SelecteurPilules(options: Membre.allCases, selection: $identite.membre, titre: \.prenom)
                            .overlay(Capsule().strokeBorder(Color.separateur))
                        Text("En phase 2, l'identité viendra du compte iCloud.")
                            .font(.jubloLegende)
                            .foregroundStyle(.texteSecondaire)
                        #if DEBUG
                        Button("Ajouter des données d'exemple") {
                            DonneesDebug.remplir(depot.contexte)
                        }
                        .buttonStyle(.pilule(.contour))
                        #endif
                    }
                }
            }
        }
        .navigationTitle("Nous")
    }

    private func compteurRetards(_ membre: Membre) -> some View {
        let nombre = NousExemples.retards[membre, default: 0]
        return VStack(alignment: .leading, spacing: 4) {
            Text("\(nombre)")
                .font(.jubloChiffre)
                .foregroundStyle(membre.couleur)
            Text(Libelles.quiEnDebut(membre, vuPar: identite.membre))
                .font(.jubloCorpsFort)
                .foregroundStyle(.texte)
        }
        .padding(Mesures.marge)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(membre.couleurDouce, in: .rect(cornerRadius: Mesures.rayonCarte, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Libelles.quiEnDebut(membre, vuPar: identite.membre)) : \(nombre) retards")
    }

    private func carteSouhait(_ souhait: NousExemples.Souhait) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Libelles.souhait(de: souhait.auteur, vuPar: identite.membre))
                .font(.jubloLegende)
                .foregroundStyle(souhait.auteur.couleur)
            Text(Libelles.texteSouhait(souhait.texte, de: souhait.auteur, vuPar: identite.membre))
                .font(.jubloCorps)
                .foregroundStyle(.texte)
        }
        .padding(Mesures.marge)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(souhait.auteur.couleurDouce, in: .rect(cornerRadius: Mesures.rayonCarte, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    NavigationStack { NousView() }.apercuJublo()
}
#endif
