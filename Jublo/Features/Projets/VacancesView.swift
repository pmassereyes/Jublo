import SwiftData
import SwiftUI

/// Idées de vacances, classées par statut puis par envie commune.
struct VacancesView: View {
    @Environment(Depot.self) private var depot
    @Environment(Identite.self) private var identite

    @Query(filter: Destination.actives, sort: \Destination.creeLe, order: .reverse)
    private var destinations: [Destination]
    @State private var nouvelle = false
    @State private var derniereSuppression: Destination?

    var body: some View {
        List {
            if destinations.isEmpty {
                ContentUnavailableView {
                    Label("Aucune idée de vacances", systemImage: "airplane")
                } description: {
                    Text("Notez vos idées de destinations, puis donnez chacun votre envie de 1 à 5 cœurs pour comparer.")
                } actions: {
                    Button("Ajouter une destination") { nouvelle = true }
                        .buttonStyle(.pilule)
                }
                .font(.jubloCorps)
                .ligneNue()
            }
            ForEach(StatutDestination.allCases) { statut in
                let groupe = destinations
                    .filter { $0.statut == statut }
                    .sorted { ($0.scoreCommun, $0.creeLe) > ($1.scoreCommun, $1.creeLe) }
                if !groupe.isEmpty {
                    Section {
                        ForEach(groupe) { destination in
                            NavigationLink {
                                DestinationView(destination: destination)
                            } label: {
                                LigneDestination(destination: destination)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation {
                                        depot.supprimer(destination, par: identite.membre)
                                        derniereSuppression = destination
                                    }
                                } label: {
                                    Label("Corbeille", systemImage: "trash")
                                }
                            }
                            .ligneCarte()
                        }
                    } header: {
                        EnTeteListe(titre: titreSection(statut), detail: "\(groupe.count)")
                    }
                    .listSectionSeparator(.hidden)
                }
            }
        }
        .listeJublo()
        .navigationTitle("Vacances envisagées")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                BoutonAjouter(libelle: "Ajouter une destination") { nouvelle = true }
            }
        }
        .sheet(isPresented: $nouvelle) {
            FormulaireDestination(destination: nil)
        }
        .bandeauAnnuler($derniereSuppression) { destination in
            "« \(destination.nom) » mise à la corbeille"
        } annuler: { destination in
            withAnimation { depot.restaurer(destination) }
        }
    }

    private func titreSection(_ statut: StatutDestination) -> String {
        switch statut {
        case .envisagee: "Envisagées"
        case .reservee: "Réservées"
        case .faite: "Déjà faites"
        }
    }
}

private struct LigneDestination: View {
    let destination: Destination

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(destination.nom)
                .font(.jubloCorpsFort)
                .foregroundStyle(.texte)
            if let detail {
                Text(detail)
                    .font(.jubloLegende)
                    .foregroundStyle(.texteSecondaire)
            }
            HStack(spacing: Mesures.espacement) {
                ForEach(Membre.allCases) { membre in
                    HStack(spacing: 4) {
                        PastilleMembre(membre: membre, taille: 18)
                        Coeurs(avis: destination.avis(de: membre), couleur: membre.couleur, taille: 11)
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var detail: String? {
        let morceaux = [destination.quand, destination.budgetCentimes.map { "budget \(Formats.montant($0))" }].compactMap { $0 }
        return morceaux.isEmpty ? nil : morceaux.joined(separator: " · ")
    }
}

/// Détail d'une destination : envies de chacun, statut, infos et note.
struct DestinationView: View {
    let destination: Destination

    @Environment(Depot.self) private var depot
    @Environment(Identite.self) private var identite
    @Environment(\.dismiss) private var fermer
    @State private var modifier = false

    var body: some View {
        Page {
            VStack(alignment: .leading, spacing: 8) {
                TitreSection(titre: "Envie")
                Carte {
                    NotesDuCouple(avisDe: { destination.avis(de: $0) }) { avis in
                        depot.donnerAvis(avis, sur: destination, par: identite.membre)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                TitreSection(titre: "Où en est-on ?")
                SelecteurPilules(
                    options: StatutDestination.allCases,
                    selection: Binding(get: { destination.statut }, set: { depot.changerStatut($0, de: destination) }),
                    titre: \.titre
                )
                .overlay(Capsule().strokeBorder(Color.separateur))
            }

            if destination.quand != nil || destination.budgetCentimes != nil || destination.note != nil {
                Carte {
                    VStack(alignment: .leading, spacing: 10) {
                        if let quand = destination.quand {
                            LigneInfo(symbole: "calendar", texte: quand)
                        }
                        if let budget = destination.budgetCentimes {
                            LigneInfo(symbole: "eurosign.circle", texte: "Budget : \(Formats.montant(budget))")
                        }
                        if let note = destination.note {
                            LigneInfo(symbole: "text.alignleft", texte: note)
                        }
                    }
                }
            }

            Text("Ajoutée par \(Libelles.qui(destination.auteurId, vuPar: identite.membre)) · \(Formats.relatif(destination.creeLe))")
                .font(.jubloLegende)
                .foregroundStyle(.texteSecondaire)
        }
        .navigationTitle(destination.nom)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Modifier", systemImage: "pencil") { modifier = true }
                    Button("Mettre à la corbeille", systemImage: "trash", role: .destructive) {
                        depot.supprimer(destination, par: identite.membre)
                        fermer()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel("Options de la destination")
                }
            }
        }
        .sheet(isPresented: $modifier) {
            FormulaireDestination(destination: destination)
        }
    }
}

/// Création ou modification d'une destination.
struct FormulaireDestination: View {
    let destination: Destination?

    @Environment(Depot.self) private var depot
    @Environment(Identite.self) private var identite
    @State private var nom = ""
    @State private var quand = ""
    @State private var budget = ""
    @State private var note = ""
    @State private var charge = false

    var body: some View {
        Formulaire(
            titre: destination == nil ? "Nouvelle destination" : "Destination",
            libelleEnregistrer: destination == nil ? "Ajouter" : "Enregistrer",
            peutEnregistrer: Depot.texte(nom) != nil && budgetValide,
            enregistrer: enregistrer
        ) {
            Section {
                TextField("Destination (Lisbonne, la Corse…)", text: $nom)
                TextField("Quand (été 2027, un long week-end…)", text: $quand)
                ChampMontant(titre: "Budget (facultatif)", saisie: $budget)
            }
            Section {
                TextField("Note", text: $note, axis: .vertical)
                    .lineLimit(1...4)
            }
        }
        .onAppear {
            guard !charge, let destination else { return }
            charge = true
            nom = destination.nom
            quand = destination.quand ?? ""
            budget = Formats.saisieMontant(destination.budgetCentimes)
            note = destination.note ?? ""
        }
    }

    private var budgetValide: Bool {
        budget.trimmingCharacters(in: .whitespaces).isEmpty || Formats.centimes(depuis: budget) != nil
    }

    private func enregistrer() {
        let centimes = Formats.centimes(depuis: budget)
        if let destination {
            guard let nom = Depot.texte(nom) else { return }
            depot.modifier(destination) {
                $0.nom = nom
                $0.quand = Depot.texte(quand)
                $0.budgetCentimes = centimes
                $0.note = Depot.texte(note)
            }
        } else {
            depot.ajouterDestination(nom, quand: quand, budgetCentimes: centimes, note: note, par: identite.membre)
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack { VacancesView() }.apercuJublo()
}
#endif
