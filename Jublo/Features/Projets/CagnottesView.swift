import SwiftData
import SwiftUI

/// Les cagnottes en cours.
struct CagnottesView: View {
    @Environment(Depot.self) private var depot
    @Environment(Identite.self) private var identite

    @Query(filter: #Predicate<Cagnotte> { $0.supprimeLe == nil }, sort: \Cagnotte.creeLe, order: .reverse)
    private var cagnottes: [Cagnotte]
    @State private var nouvelle = false
    @State private var derniereSuppression: Cagnotte?

    var body: some View {
        List {
            if cagnottes.isEmpty {
                ContentUnavailableView {
                    Label("Aucune cagnotte", systemImage: "eurosign.circle")
                } description: {
                    Text("Une cagnotte pour un voyage, un cadeau ou un meuble : chacun y verse ce qu'il veut.")
                } actions: {
                    Button("Créer une cagnotte") { nouvelle = true }
                        .buttonStyle(.pilule)
                }
                .font(.jubloCorps)
                .ligneNue()
            }
            ForEach(cagnottes) { cagnotte in
                NavigationLink {
                    CagnotteView(cagnotte: cagnotte)
                } label: {
                    LigneCagnotte(cagnotte: cagnotte)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation {
                            depot.supprimer(cagnotte, par: identite.membre)
                            derniereSuppression = cagnotte
                        }
                    } label: {
                        Label("Corbeille", systemImage: "trash")
                    }
                }
                .ligneCarte()
            }
        }
        .listeJublo()
        .navigationTitle("Cagnotte")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                BoutonAjouter(libelle: "Créer une cagnotte") { nouvelle = true }
            }
        }
        .sheet(isPresented: $nouvelle) {
            FormulaireCagnotte(cagnotte: nil)
        }
        .bandeauAnnuler($derniereSuppression) { cagnotte in
            "« \(cagnotte.nom) » mise à la corbeille"
        } annuler: { cagnotte in
            withAnimation { depot.restaurer(cagnotte) }
        }
    }
}

private struct LigneCagnotte: View {
    let cagnotte: Cagnotte

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(cagnotte.nom)
                    .font(.jubloCorpsFort)
                Spacer()
                Text(Formats.montant(cagnotte.soldeCentimes))
                    .font(.jubloCorpsFort)
            }
            if let objectif = cagnotte.objectifCentimes, objectif > 0 {
                ProgressView(value: Double(min(cagnotte.soldeCentimes, objectif)), total: Double(objectif))
                    .tint(.texte)
                Text("Objectif : \(Formats.montant(objectif))")
                    .font(.jubloLegende)
                    .foregroundStyle(.texteSecondaire)
            }
        }
        .foregroundStyle(.texte)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// Détail d'une cagnotte : solde, objectif, part de chacun et historique des versements.
struct CagnotteView: View {
    let cagnotte: Cagnotte

    @Environment(Depot.self) private var depot
    @Environment(Identite.self) private var identite
    @Environment(\.dismiss) private var fermer
    @State private var verser = false
    @State private var modifier = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(Formats.montant(cagnotte.soldeCentimes))
                        .font(.jubloChiffre)
                        .foregroundStyle(.texte)
                    if let objectif = cagnotte.objectifCentimes, objectif > 0 {
                        ProgressView(value: Double(min(cagnotte.soldeCentimes, objectif)), total: Double(objectif))
                            .tint(.texte)
                        Text(resteAVerser(objectif))
                            .font(.jubloLegende)
                            .foregroundStyle(.texteSecondaire)
                    }
                    HStack(spacing: Mesures.espacement) {
                        ForEach([identite.membre, identite.membre.autre]) { membre in
                            HStack(spacing: 6) {
                                PastilleMembre(membre: membre, taille: 22)
                                Text("\(Libelles.quiEnDebut(membre, vuPar: identite.membre)) : \(Formats.montant(part(de: membre)))")
                                    .font(.jubloLegende)
                                    .foregroundStyle(.texte)
                            }
                        }
                    }
                    Button {
                        verser = true
                    } label: {
                        Label("Verser", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.pilule(.pleine(fond: identite.membre.couleur, texte: .surface)))
                }
                .padding(.vertical, 6)
                .ligneCarte()
            }

            Section {
                if cagnotte.historique.isEmpty {
                    Text("Aucun versement pour l'instant.")
                        .font(.jubloLegende)
                        .foregroundStyle(.texteSecondaire)
                        .ligneNue()
                }
                ForEach(cagnotte.historique) { versement in
                    LigneVersement(versement: versement, courant: identite.membre)
                        .swipeActions(edge: .trailing) {
                            if !versement.estAnnule {
                                Button(role: .destructive) {
                                    withAnimation { depot.annuler(versement, par: identite.membre) }
                                } label: {
                                    Label("Annuler", systemImage: "arrow.uturn.backward")
                                }
                            }
                        }
                        .ligneCarte()
                }
                if !cagnotte.historique.isEmpty {
                    Text("Un versement annulé reste dans l'historique mais ne compte plus dans le solde. Balaie un versement vers la gauche pour l'annuler.")
                        .font(.jubloLegende)
                        .foregroundStyle(.texteSecondaire)
                        .ligneNue()
                }
            } header: {
                EnTeteListe(titre: "Versements", detail: "\(cagnotte.historique.count)")
            }
            .listSectionSeparator(.hidden)
        }
        .listeJublo()
        .navigationTitle(cagnotte.nom)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Modifier", systemImage: "pencil") { modifier = true }
                    Button("Mettre à la corbeille", systemImage: "trash", role: .destructive) {
                        depot.supprimer(cagnotte, par: identite.membre)
                        fermer()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel("Options de la cagnotte")
                }
            }
        }
        .sheet(isPresented: $verser) {
            FormulaireVersement(cagnotte: cagnotte)
        }
        .sheet(isPresented: $modifier) {
            FormulaireCagnotte(cagnotte: cagnotte)
        }
    }

    private func part(de membre: Membre) -> Int {
        cagnotte.historique
            .filter { !$0.estAnnule && $0.auteur == membre }
            .reduce(0) { $0 + $1.montantCentimes }
    }

    private func resteAVerser(_ objectif: Int) -> String {
        let reste = objectif - cagnotte.soldeCentimes
        return reste > 0
            ? "Encore \(Formats.montant(reste)) pour atteindre \(Formats.montant(objectif))"
            : "Objectif de \(Formats.montant(objectif)) atteint !"
    }
}

private struct LigneVersement: View {
    let versement: Versement
    let courant: Membre

    var body: some View {
        HStack(spacing: Mesures.espacement) {
            PastilleMembre(membre: versement.auteur, taille: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(Formats.montant(versement.montantCentimes))
                    .font(.jubloCorpsFort)
                    .strikethrough(versement.estAnnule)
                    .foregroundStyle(versement.estAnnule ? Color.texteSecondaire : Color.texte)
                Text(detail)
                    .font(.jubloLegende)
                    .foregroundStyle(.texteSecondaire)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        var morceaux = ["Versé par \(Libelles.qui(versement.auteurId, vuPar: courant)) · \(Formats.relatif(versement.creeLe))"]
        if let note = versement.note, !note.isEmpty { morceaux.append(note) }
        if versement.estAnnule {
            morceaux.append("annulé par \(Libelles.qui(versement.annulePar, vuPar: courant))")
        }
        return morceaux.joined(separator: " · ")
    }
}

/// Création ou modification d'une cagnotte.
struct FormulaireCagnotte: View {
    let cagnotte: Cagnotte?

    @Environment(Depot.self) private var depot
    @Environment(Identite.self) private var identite
    @State private var nom = ""
    @State private var objectif = ""
    @State private var charge = false

    var body: some View {
        Formulaire(
            titre: cagnotte == nil ? "Nouvelle cagnotte" : "Cagnotte",
            libelleEnregistrer: cagnotte == nil ? "Créer" : "Enregistrer",
            peutEnregistrer: Depot.texte(nom) != nil && objectifValide,
            enregistrer: enregistrer
        ) {
            Section {
                TextField("Nom (Lisbonne, canapé…)", text: $nom)
            }
            Section {
                ChampMontant(titre: "Objectif (facultatif)", saisie: $objectif)
            } footer: {
                Text("Sans objectif, la cagnotte affiche simplement le total versé.")
                    .font(.jubloLegende)
            }
        }
        .onAppear {
            guard !charge, let cagnotte else { return }
            charge = true
            nom = cagnotte.nom
            objectif = Formats.saisieMontant(cagnotte.objectifCentimes)
        }
    }

    private var objectifValide: Bool {
        objectif.trimmingCharacters(in: .whitespaces).isEmpty || Formats.centimes(depuis: objectif) != nil
    }

    private func enregistrer() {
        guard let nom = Depot.texte(nom) else { return }
        let centimes = Formats.centimes(depuis: objectif)
        if let cagnotte {
            depot.modifier(cagnotte) {
                $0.nom = nom
                $0.objectifCentimes = centimes
            }
        } else {
            depot.creerCagnotte(nom, objectifCentimes: centimes, par: identite.membre)
        }
    }
}

/// Nouveau versement du membre courant.
struct FormulaireVersement: View {
    let cagnotte: Cagnotte

    @Environment(Depot.self) private var depot
    @Environment(Identite.self) private var identite
    @State private var montant = ""
    @State private var note = ""

    var body: some View {
        Formulaire(
            titre: "Verser dans « \(cagnotte.nom) »",
            libelleEnregistrer: "Verser",
            peutEnregistrer: Formats.centimes(depuis: montant) != nil,
            enregistrer: enregistrer
        ) {
            Section {
                ChampMontant(titre: "Montant", saisie: $montant)
                TextField("Note (facultatif)", text: $note)
            } footer: {
                Text("Le versement est noté à ton nom : \(identite.membre.prenom).")
                    .font(.jubloLegende)
            }
        }
    }

    private func enregistrer() {
        guard let centimes = Formats.centimes(depuis: montant) else { return }
        depot.verser(centimes, dans: cagnotte, par: identite.membre, note: Depot.texte(note))
    }
}

#if DEBUG
#Preview {
    NavigationStack { CagnottesView() }.apercuJublo()
}
#endif
