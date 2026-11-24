import SwiftData
import SwiftUI

struct AccueilView: View {
    @Environment(Identite.self) private var identite
    @Query(filter: #Predicate<ElementListe> { $0.supprimeLe == nil && !$0.estCoche })
    private var aFaire: [ElementListe]
    @Query(filter: Evenement.actifs, sort: \Evenement.debut) private var evenements: [Evenement]
    @Query(filter: Souhait.actifs, sort: \Souhait.creeLe) private var souhaits: [Souhait]

    var body: some View {
        let maintenant = Date.now
        let prochains = Array(evenements.filter { $0.estAVenir(a: maintenant) }.prefix(3))
        let pourMoi = souhaits.last { $0.mois == Souhait.cleMois(maintenant) && $0.destinataire == identite.membre }

        Page {
            Text(Formats.jour(maintenant))
                .font(.jubloCorps)
                .foregroundStyle(.texteSecondaire)

            VStack(alignment: .leading, spacing: 8) {
                TitreSection(titre: "À venir")
                Carte {
                    if prochains.isEmpty {
                        Text("Rien de prévu dans l'agenda.")
                            .font(.jubloCorps)
                            .foregroundStyle(.texteSecondaire)
                            .frame(minHeight: Mesures.zoneTactile)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(prochains) { evenement in
                                ligneEvenement(evenement)
                                if evenement.id != prochains.last?.id {
                                    Divider().overlay(Color.separateur)
                                }
                            }
                        }
                    }
                }
            }

            if let pourMoi, let auteur = pourMoi.auteur, !pourMoi.estFait {
                VStack(alignment: .leading, spacing: 8) {
                    TitreSection(titre: "Ce mois-ci")
                    Carte(contour: auteur.couleur) {
                        HStack(alignment: .top, spacing: Mesures.espacement) {
                            PastilleMembre(membre: auteur, taille: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Libelles.souhait(de: auteur, vuPar: identite.membre))
                                    .font(.jubloLegende)
                                    .foregroundStyle(.texteSecondaire)
                                Text(Libelles.texteSouhait(pourMoi.texte, de: auteur, vuPar: identite.membre))
                                    .font(.jubloCorpsFort)
                                    .foregroundStyle(.texte)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }

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

    private func ligneEvenement(_ evenement: Evenement) -> some View {
        HStack(spacing: Mesures.espacement) {
            VStack(alignment: .leading, spacing: 2) {
                Text(evenement.titre)
                    .font(.jubloCorpsFort)
                    .foregroundStyle(.texte)
                Text(quand(evenement))
                    .font(.jubloLegende)
                    .foregroundStyle(.texteSecondaire)
            }
            Spacer(minLength: 0)
            PastilleMembre(membre: evenement.concerne, taille: 24)
        }
        .frame(minHeight: Mesures.zoneTactile)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func quand(_ evenement: Evenement) -> String {
        let jour = Formats.jourProche(max(evenement.debut, Calendar.current.startOfDay(for: .now)))
        let heure = evenement.journeeEntiere ? "" : " · \(Formats.heure(evenement.debut))"
        return jour + heure + " · " + Libelles.concerne(evenement.concerne, vuPar: identite.membre)
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
