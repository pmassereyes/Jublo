import SwiftUI

struct ProjetsView: View {
    @Environment(Identite.self) private var identite

    var body: some View {
        Page {
            VStack(alignment: .leading, spacing: 8) {
                TitreSection(titre: "Cagnotte")
                CarteCagnotte(cagnotte: ProjetsExemples.cagnotte)
            }
            VStack(alignment: .leading, spacing: 8) {
                TitreSection(titre: "Vacances envisagées")
                ForEach(ProjetsExemples.vacances) { idee in
                    ligne(idee, symbole: "airplane")
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                TitreSection(titre: "Sorties à tester")
                ForEach(ProjetsExemples.sorties) { idee in
                    ligne(idee, symbole: "mappin.and.ellipse")
                }
            }
            MentionExemple()
        }
        .navigationTitle("Projets")
    }

    private func ligne(_ idee: ProjetsExemples.Idee, symbole: String) -> some View {
        Carte {
            HStack(spacing: Mesures.espacement) {
                Image(systemName: symbole)
                    .foregroundStyle(idee.proposePar.couleur)
                    .frame(width: 36, height: 36)
                    .background(idee.proposePar.couleurDouce, in: .circle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(idee.titre)
                        .font(.jubloCorpsFort)
                        .foregroundStyle(.texte)
                    Text("\(idee.detail) · proposé par \(Libelles.qui(idee.proposePar, vuPar: identite.membre))")
                        .font(.jubloLegende)
                        .foregroundStyle(.texteSecondaire)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Carte d'une cagnotte : solde, objectif et derniers versements.
struct CarteCagnotte: View {
    let cagnotte: ProjetsExemples.Cagnotte
    var nombreVersements = 4

    @Environment(Identite.self) private var identite

    var body: some View {
        Carte(contour: .commun) {
            VStack(alignment: .leading, spacing: Mesures.espacement) {
                Text(cagnotte.nom)
                    .font(.jubloSousTitre)
                    .foregroundStyle(.texte)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Formats.montant(cagnotte.soldeCentimes))
                        .font(.jubloChiffre)
                        .foregroundStyle(.texte)
                    Text("sur \(Formats.montant(cagnotte.objectifCentimes))")
                        .font(.jubloCorps)
                        .foregroundStyle(.texteSecondaire)
                }
                ProgressView(value: Double(min(cagnotte.soldeCentimes, cagnotte.objectifCentimes)),
                             total: Double(cagnotte.objectifCentimes))
                    .tint(.texte)
                ForEach(cagnotte.versements.prefix(nombreVersements)) { versement in
                    ligne(versement)
                }
            }
        }
    }

    private func ligne(_ versement: ProjetsExemples.VersementExemple) -> some View {
        HStack(spacing: 10) {
            PastilleMembre(membre: versement.auteur, taille: 24)
            Text(Libelles.quiEnDebut(versement.auteur, vuPar: identite.membre))
                .font(.jubloCorps)
            Text(versement.annule ? "annulé" : "il y a \(versement.ilYAJours) j")
                .font(.jubloLegende)
                .foregroundStyle(.texteSecondaire)
            Spacer()
            Text(Formats.montant(versement.montantCentimes))
                .font(.jubloCorpsFort)
                .strikethrough(versement.annule)
        }
        .foregroundStyle(versement.annule ? Color.texteSecondaire : Color.texte)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    NavigationStack { ProjetsView() }.apercuJublo()
}
#endif
