import SwiftData
import SwiftUI

/// « Ce mois-ci, j'aimerais que tu… » dans l'onglet Nous : ma demande à l'autre, la sienne
/// pour moi, et l'accès aux mois précédents.
struct CarteSouhaits: View {
    @Environment(Depot.self) private var depot
    @Environment(Identite.self) private var identite

    @Query(filter: Souhait.actifs, sort: \Souhait.creeLe) private var souhaits: [Souhait]
    @State private var brouillon = ""
    @State private var modification: Souhait?
    @FocusState private var saisieActive: Bool

    var body: some View {
        let mois = Souhait.cleMois(.now)
        let duMois = souhaits.filter { $0.mois == mois }
        let moi = identite.membre
        let mien = duMois.last { $0.auteur == moi }
        let sien = duMois.last { $0.auteur == moi.autre }

        VStack(alignment: .leading, spacing: 8) {
            TitreSection(titre: "Ce mois-ci, j'aimerais que tu…", detail: Formats.mois(.now))
            Carte {
                VStack(alignment: .leading, spacing: Mesures.espacement) {
                    pourMoi(sien, de: moi.autre)
                    Divider().overlay(Color.separateur)
                    maDemande(mien, a: moi.autre)
                    NavigationLink {
                        SouhaitsView()
                    } label: {
                        HStack {
                            Text("Mois précédents")
                                .font(.jubloCorpsFort)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.texteSecondaire)
                                .accessibilityHidden(true)
                        }
                        .foregroundStyle(.texte)
                        .frame(minHeight: Mesures.zoneTactile)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(item: $modification) { souhait in
            FormulaireSouhait(souhait: souhait)
        }
    }

    /// Ce que l'autre m'a demandé, à cocher quand c'est fait.
    @ViewBuilder
    private func pourMoi(_ souhait: Souhait?, de autre: Membre) -> some View {
        HStack(alignment: .top, spacing: Mesures.espacement) {
            PastilleMembre(membre: autre, taille: 28)
            VStack(alignment: .leading, spacing: 6) {
                Text(Libelles.souhait(de: autre, vuPar: identite.membre))
                    .font(.jubloLegende)
                    .foregroundStyle(.texteSecondaire)
                if let souhait {
                    Text(Libelles.texteSouhait(souhait.texte, de: autre, vuPar: identite.membre))
                        .font(.jubloCorpsFort)
                        .foregroundStyle(.texte)
                        .strikethrough(souhait.estFait)
                    Button {
                        withAnimation { depot.basculerFait(souhait) }
                    } label: {
                        Label(souhait.estFait ? "Fait !" : "C'est fait", systemImage: souhait.estFait ? "checkmark.circle.fill" : "circle")
                    }
                    .buttonStyle(.pilule(.douce(fond: autre.couleurDouce, texte: autre.couleur), compacte: true))
                    .accessibilityHint(souhait.estFait ? "Décoche le souhait" : "Indique que c'est fait")
                } else {
                    Text("\(autre.prenom) n'a encore rien demandé ce mois-ci.")
                        .font(.jubloCorps)
                        .foregroundStyle(.texteSecondaire)
                }
            }
        }
    }

    /// Ma demande à l'autre : à écrire, ou déjà confiée.
    @ViewBuilder
    private func maDemande(_ souhait: Souhait?, a autre: Membre) -> some View {
        HStack(alignment: .top, spacing: Mesures.espacement) {
            PastilleMembre(membre: identite.membre, taille: 28)
            VStack(alignment: .leading, spacing: 6) {
                Text(Libelles.souhait(de: identite.membre, vuPar: identite.membre))
                    .font(.jubloLegende)
                    .foregroundStyle(.texteSecondaire)
                if let souhait {
                    Text(Libelles.texteSouhait(souhait.texte, de: identite.membre, vuPar: identite.membre))
                        .font(.jubloCorpsFort)
                        .foregroundStyle(.texte)
                    HStack {
                        Text(souhait.estFait ? "\(autre.prenom) l'a fait 🎉" : "Pas encore fait")
                            .font(.jubloLegende)
                            .foregroundStyle(.texteSecondaire)
                        Spacer()
                        Button("Modifier") { modification = souhait }
                            .buttonStyle(.pilule(.contour, compacte: true))
                    }
                } else {
                    HStack(spacing: 8) {
                        TextField("…m'emmènes au cinéma", text: $brouillon)
                            .font(.jubloCorps)
                            .submitLabel(.done)
                            .focused($saisieActive)
                            .onSubmit(confier)
                            .padding(.horizontal, Mesures.marge)
                            .frame(minHeight: Mesures.zoneTactile)
                            .background(.fond, in: .capsule)
                        Button("Confier", action: confier)
                            .buttonStyle(.pilule(.pleine(fond: identite.membre.couleur, texte: .surface), compacte: true))
                            .disabled(Depot.texte(brouillon) == nil)
                    }
                }
            }
        }
    }

    private func confier() {
        if depot.confierSouhait(brouillon, par: identite.membre) != nil {
            brouillon = ""
        }
        saisieActive = false
    }
}

/// Souhaits de tous les mois, du plus récent au plus ancien.
struct SouhaitsView: View {
    @Environment(Depot.self) private var depot
    @Environment(Identite.self) private var identite

    @Query(filter: Souhait.actifs, sort: \Souhait.creeLe, order: .reverse) private var souhaits: [Souhait]
    @State private var modification: Souhait?
    @State private var derniereSuppression: Souhait?

    var body: some View {
        let mois = Dictionary(grouping: souhaits, by: \.mois).keys.sorted(by: >)

        List {
            if souhaits.isEmpty {
                ContentUnavailableView(
                    "Aucun souhait pour l'instant",
                    systemImage: "heart.text.square",
                    description: Text("Chaque mois, confiez-vous une envie : un resto, un geste, un moment à deux.")
                )
                .font(.jubloCorps)
                .ligneNue()
            }
            ForEach(mois, id: \.self) { cle in
                Section {
                    ForEach(souhaits.filter { $0.mois == cle }) { souhait in
                        LigneSouhait(souhait: souhait, courant: identite.membre) {
                            withAnimation { depot.basculerFait(souhait) }
                        }
                        .contentShape(.rect)
                        .onTapGesture {
                            if souhait.auteur == identite.membre { modification = souhait }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    depot.supprimer(souhait, par: identite.membre)
                                    derniereSuppression = souhait
                                }
                            } label: {
                                Label("Corbeille", systemImage: "trash")
                            }
                        }
                        .ligneCarte()
                    }
                } header: {
                    EnTeteListe(titre: Formats.mois(cle))
                }
                .listSectionSeparator(.hidden)
            }
        }
        .listeJublo()
        .navigationTitle("Ce mois-ci")
        .sheet(item: $modification) { souhait in
            FormulaireSouhait(souhait: souhait)
        }
        .bandeauAnnuler($derniereSuppression) { _ in
            "Souhait mis à la corbeille"
        } annuler: { souhait in
            withAnimation { depot.restaurer(souhait) }
        }
    }
}

private struct LigneSouhait: View {
    let souhait: Souhait
    let courant: Membre
    let basculer: () -> Void

    var body: some View {
        HStack(spacing: Mesures.espacement) {
            PastilleMembre(membre: souhait.auteur, taille: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(souhait.auteur.map { Libelles.souhait(de: $0, vuPar: courant) } ?? "")
                    .font(.jubloLegende)
                    .foregroundStyle(.texteSecondaire)
                Text(souhait.auteur.map { Libelles.texteSouhait(souhait.texte, de: $0, vuPar: courant) } ?? souhait.texte)
                    .font(.jubloCorpsFort)
                    .foregroundStyle(.texte)
                    .strikethrough(souhait.estFait)
            }
            Spacer(minLength: 0)
            // Seul celui à qui le souhait est confié le coche.
            if souhait.destinataire == courant {
                Button(action: basculer) {
                    Image(systemName: souhait.estFait ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundStyle(souhait.auteur?.couleur ?? .commun)
                        .frame(width: Mesures.zoneTactile, height: Mesures.zoneTactile)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(souhait.estFait ? "Fait" : "Pas encore fait")
                .accessibilityHint("Coche ou décoche le souhait")
            } else if souhait.estFait {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.texteSecondaire)
                    .frame(width: Mesures.zoneTactile, height: Mesures.zoneTactile)
                    .accessibilityLabel("Fait")
            }
        }
    }
}

/// Modification du texte d'un souhait confié.
struct FormulaireSouhait: View {
    let souhait: Souhait

    @Environment(Depot.self) private var depot
    @Environment(Identite.self) private var identite
    @Environment(\.dismiss) private var fermer
    @State private var texte = ""
    @State private var charge = false

    var body: some View {
        Formulaire(titre: "Ta demande", peutEnregistrer: Depot.texte(texte) != nil, enregistrer: enregistrer) {
            Section {
                TextField("…m'emmènes au cinéma", text: $texte, axis: .vertical)
                    .lineLimit(1...4)
            } header: {
                Text("J'aimerais que tu…")
                    .font(.jubloLegende)
            }
            Section {
                Button("Mettre à la corbeille", role: .destructive) {
                    depot.supprimer(souhait, par: identite.membre)
                    fermer()
                }
            }
        }
        .onAppear {
            guard !charge else { return }
            charge = true
            texte = souhait.texte
        }
    }

    private func enregistrer() {
        guard let texte = Depot.texte(texte) else { return }
        depot.modifier(souhait) { $0.texte = texte }
    }
}

#if DEBUG
#Preview {
    NavigationStack { Page { CarteSouhaits() } }.apercuJublo()
}
#endif
