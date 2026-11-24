import SwiftData
import SwiftUI

/// Compteur de retards du mois, dans l'onglet Nous.
struct CarteRetards: View {
    @Environment(Identite.self) private var identite

    @Query(filter: Retard.actifs) private var retards: [Retard]
    @State private var noter = false

    var body: some View {
        let bilans = BilanRetards.duMois(retards, contenant: .now)

        VStack(alignment: .leading, spacing: 8) {
            TitreSection(titre: "Compteur de retards", detail: Formats.mois(.now))
            Carte {
                VStack(alignment: .leading, spacing: Mesures.espacement) {
                    HStack(spacing: Mesures.espacement) {
                        ForEach([identite.membre, identite.membre.autre]) { membre in
                            compteur(membre, bilans[membre] ?? BilanRetards())
                        }
                    }
                    Button {
                        noter = true
                    } label: {
                        Label("Noter un retard", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.pilule)
                    NavigationLink {
                        RetardsView()
                    } label: {
                        HStack {
                            Text("Historique")
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
        .sheet(isPresented: $noter) {
            FormulaireRetard()
        }
    }

    private func compteur(_ membre: Membre, _ bilan: BilanRetards) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Libelles.quiEnDebut(membre, vuPar: identite.membre))
                .font(.jubloCorpsFort)
                .foregroundStyle(membre.couleur)
            Text("\(bilan.nombre)")
                .font(.jubloChiffre)
                .foregroundStyle(membre.couleur)
            Text(bilan.nombre == 0 ? "aucun retard" : "\(bilan.nombre == 1 ? "retard" : "retards") · \(bilan.minutes) min")
                .font(.jubloLegende)
                .foregroundStyle(.texteSecondaire)
        }
        .padding(Mesures.espacement)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(membre.couleurDouce, in: .rect(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Tous les retards, mois par mois, avec le bilan de chacun.
struct RetardsView: View {
    @Environment(Depot.self) private var depot
    @Environment(Identite.self) private var identite

    @Query(filter: Retard.actifs, sort: \Retard.survenuLe, order: .reverse) private var retards: [Retard]
    @State private var noter = false
    @State private var derniereSuppression: Retard?

    var body: some View {
        let calendrier = Calendar.current
        let mois = Dictionary(grouping: retards) { calendrier.dateInterval(of: .month, for: $0.survenuLe)?.start ?? $0.survenuLe }
            .keys.sorted(by: >)

        List {
            if retards.isEmpty {
                ContentUnavailableView(
                    "Aucun retard noté",
                    systemImage: "clock",
                    description: Text("Ponctuels tous les deux ? Bravo. Sinon, notez ici qui a fait attendre l'autre.")
                )
                .font(.jubloCorps)
                .ligneNue()
            }
            ForEach(mois, id: \.self) { debut in
                let duMois = retards.filter { calendrier.isDate($0.survenuLe, equalTo: debut, toGranularity: .month) }
                Section {
                    ForEach(duMois) { retard in
                        LigneRetard(retard: retard, courant: identite.membre)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation {
                                        depot.supprimer(retard, par: identite.membre)
                                        derniereSuppression = retard
                                    }
                                } label: {
                                    Label("Corbeille", systemImage: "trash")
                                }
                            }
                            .ligneCarte()
                    }
                } header: {
                    EnTeteListe(titre: Formats.mois(debut), detail: resume(BilanRetards.duMois(duMois, contenant: debut)))
                }
                .listSectionSeparator(.hidden)
            }
        }
        .listeJublo()
        .navigationTitle("Retards")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                BoutonAjouter(libelle: "Noter un retard") { noter = true }
            }
        }
        .sheet(isPresented: $noter) {
            FormulaireRetard()
        }
        .bandeauAnnuler($derniereSuppression) { _ in
            "Retard mis à la corbeille"
        } annuler: { retard in
            withAnimation { depot.restaurer(retard) }
        }
    }

    /// « Toi 2 · Julie 3 ».
    private func resume(_ bilans: [Membre: BilanRetards]) -> String {
        [identite.membre, identite.membre.autre]
            .map { "\(Libelles.quiEnDebut($0, vuPar: identite.membre)) \(bilans[$0]?.nombre ?? 0)" }
            .joined(separator: " · ")
    }
}

private struct LigneRetard: View {
    let retard: Retard
    let courant: Membre

    var body: some View {
        HStack(spacing: Mesures.espacement) {
            PastilleMembre(membre: retard.retardataire, taille: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(retard.retardataire.map { Libelles.quiEnDebut($0, vuPar: courant) } ?? "Quelqu'un") · \(retard.minutes) min")
                    .font(.jubloCorpsFort)
                    .foregroundStyle(.texte)
                Text(detail)
                    .font(.jubloLegende)
                    .foregroundStyle(.texteSecondaire)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        var morceaux = [Formats.jourProche(retard.survenuLe)]
        if let motif = retard.motif { morceaux.append(motif) }
        morceaux.append("noté par \(Libelles.qui(retard.auteurId, vuPar: courant))")
        return morceaux.joined(separator: " · ")
    }
}

/// Nouveau retard : qui, combien de temps, pourquoi, et quand.
struct FormulaireRetard: View {
    @Environment(Depot.self) private var depot
    @Environment(Identite.self) private var identite
    @State private var retardataire: Membre?
    @State private var minutes = 10
    @State private var motif = ""
    @State private var date = Date.now

    private let durees = [5, 10, 15, 20, 30, 45, 60]

    var body: some View {
        let qui = retardataire ?? identite.membre.autre

        Formulaire(titre: "Noter un retard", libelleEnregistrer: "Noter", peutEnregistrer: minutes > 0) {
            depot.noterRetard(de: qui, minutes: minutes, motif: motif, le: date, par: identite.membre)
        } contenu: {
            Section {
                Picker("Qui était en retard ?", selection: Binding(get: { qui }, set: { retardataire = $0 })) {
                    ForEach([identite.membre.autre, identite.membre]) { membre in
                        Text(Libelles.quiEnDebut(membre, vuPar: identite.membre)).tag(membre)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Qui était en retard ?")
                    .font(.jubloLegende)
            }
            Section {
                Stepper(value: $minutes, in: 1...240, step: 5) {
                    Text("\(minutes) min")
                        .font(.jubloCorpsFort)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(durees, id: \.self) { duree in
                            Button("\(duree) min") { minutes = duree }
                                .buttonStyle(.pilule(duree == minutes ? .pleine(fond: .texte, texte: .surface) : .contour, compacte: true))
                        }
                    }
                }
                TextField("Motif (métro, réunion…)", text: $motif)
                DatePicker("Quand", selection: $date, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                    .environment(\.locale, .jublo)
            } header: {
                Text("Combien de temps ?")
                    .font(.jubloLegende)
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack { Page { CarteRetards() } }.apercuJublo()
}
#endif
