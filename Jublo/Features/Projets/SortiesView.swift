import SwiftData
import SwiftUI

/// Sorties repérées : à tester, puis testées et notées par chacun.
struct SortiesView: View {
    enum Filtre: CaseIterable, Identifiable {
        case aTester, testees
        var id: Self { self }
        var titre: String {
            switch self {
            case .aTester: "À tester"
            case .testees: "Testées"
            }
        }
    }

    @Environment(Depot.self) private var depot
    @Environment(Identite.self) private var identite

    @Query(filter: Sortie.actives, sort: \Sortie.creeLe, order: .reverse) private var sorties: [Sortie]
    @State private var filtre = Filtre.aTester
    @State private var nouvelle = false
    @State private var derniereSuppression: Sortie?

    var body: some View {
        let affichees = filtre == .aTester
            ? sorties.filter { !$0.estTestee }
            : sorties.filter(\.estTestee).sorted { ($0.scoreCommun, $0.testeeLe ?? .distantPast) > ($1.scoreCommun, $1.testeeLe ?? .distantPast) }

        List {
            Section {
                SelecteurPilules(options: Filtre.allCases, selection: $filtre, titre: \.titre)
                    .overlay(Capsule().strokeBorder(Color.separateur))
                    .ligneNue()
            }
            if affichees.isEmpty {
                ContentUnavailableView {
                    Label(filtre == .aTester ? "Rien à tester" : "Rien de testé", systemImage: "mappin.and.ellipse")
                } description: {
                    Text(filtre == .aTester
                         ? "Un resto, une expo, un bar repéré ? Note-le ici pour ne pas l'oublier."
                         : "Une fois testée, une sortie arrive ici avec vos avis.")
                } actions: {
                    if filtre == .aTester {
                        Button("Ajouter une sortie") { nouvelle = true }
                            .buttonStyle(.pilule)
                    }
                }
                .font(.jubloCorps)
                .ligneNue()
            }
            ForEach(affichees) { sortie in
                NavigationLink {
                    SortieView(sortie: sortie)
                } label: {
                    LigneSortie(sortie: sortie, courant: identite.membre)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation {
                            depot.supprimer(sortie, par: identite.membre)
                            derniereSuppression = sortie
                        }
                    } label: {
                        Label("Corbeille", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        withAnimation { depot.basculerTestee(sortie) }
                    } label: {
                        Label(sortie.estTestee ? "À retester" : "Testée", systemImage: sortie.estTestee ? "arrow.uturn.backward" : "checkmark")
                    }
                    .tint(.commun)
                }
                .ligneCarte()
            }
        }
        .listeJublo()
        .navigationTitle("Sorties à tester")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                BoutonAjouter(libelle: "Ajouter une sortie") { nouvelle = true }
            }
        }
        .sheet(isPresented: $nouvelle) {
            FormulaireSortie(sortie: nil)
        }
        .bandeauAnnuler($derniereSuppression) { sortie in
            "« \(sortie.nom) » mise à la corbeille"
        } annuler: { sortie in
            withAnimation { depot.restaurer(sortie) }
        }
    }
}

private struct LigneSortie: View {
    let sortie: Sortie
    let courant: Membre

    var body: some View {
        HStack(spacing: Mesures.espacement) {
            Image(systemName: sortie.categorie.symbole)
                .font(.system(size: 18))
                .foregroundStyle(.texte)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(sortie.nom)
                    .font(.jubloCorpsFort)
                    .foregroundStyle(.texte)
                Text(detail)
                    .font(.jubloLegende)
                    .foregroundStyle(.texteSecondaire)
                if sortie.estTestee {
                    HStack(spacing: Mesures.espacement) {
                        ForEach(Membre.allCases) { membre in
                            HStack(spacing: 4) {
                                PastilleMembre(membre: membre, taille: 18)
                                Coeurs(avis: sortie.avis(de: membre), couleur: membre.couleur, taille: 11)
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            if !sortie.estTestee {
                PastilleMembre(membre: sortie.auteur, taille: 26)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        var morceaux = [sortie.categorie.titre]
        if let lieu = sortie.lieu { morceaux.append(lieu) }
        if let testeeLe = sortie.testeeLe {
            morceaux.append("testée \(Formats.relatif(testeeLe))")
        } else {
            morceaux.append("repérée par \(Libelles.qui(sortie.auteurId, vuPar: courant))")
        }
        return morceaux.joined(separator: " · ")
    }
}

/// Détail d'une sortie : infos, lien, « testée » et avis de chacun.
struct SortieView: View {
    let sortie: Sortie

    @Environment(Depot.self) private var depot
    @Environment(Identite.self) private var identite
    @Environment(\.dismiss) private var fermer
    @State private var modifier = false

    var body: some View {
        Page {
            Carte {
                VStack(alignment: .leading, spacing: 10) {
                    LigneInfo(symbole: sortie.categorie.symbole, texte: sortie.categorie.titre)
                    if let lieu = sortie.lieu {
                        LigneInfo(symbole: "mappin", texte: lieu)
                    }
                    if let url = sortie.url {
                        Link(destination: url) {
                            Label(url.host() ?? url.absoluteString, systemImage: "link")
                                .font(.jubloCorps)
                                .foregroundStyle(.texte)
                                .underline()
                        }
                    }
                    if let note = sortie.note {
                        LigneInfo(symbole: "text.alignleft", texte: note)
                    }
                    Text("Repérée par \(Libelles.qui(sortie.auteurId, vuPar: identite.membre)) · \(Formats.relatif(sortie.creeLe))")
                        .font(.jubloLegende)
                        .foregroundStyle(.texteSecondaire)
                }
            }

            Button {
                withAnimation { depot.basculerTestee(sortie) }
            } label: {
                Label(sortie.estTestee ? "Pas encore testée, finalement" : "On l'a testée !",
                      systemImage: sortie.estTestee ? "arrow.uturn.backward" : "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(sortie.estTestee ? .pilule(.contour) : .pilule)

            if sortie.estTestee {
                VStack(alignment: .leading, spacing: 8) {
                    TitreSection(titre: "Vos avis")
                    Carte {
                        NotesDuCouple(avisDe: { sortie.avis(de: $0) }) { avis in
                            depot.donnerAvis(avis, sur: sortie, par: identite.membre)
                        }
                    }
                }
            }
        }
        .navigationTitle(sortie.nom)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Modifier", systemImage: "pencil") { modifier = true }
                    Button("Mettre à la corbeille", systemImage: "trash", role: .destructive) {
                        depot.supprimer(sortie, par: identite.membre)
                        fermer()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel("Options de la sortie")
                }
            }
        }
        .sheet(isPresented: $modifier) {
            FormulaireSortie(sortie: sortie)
        }
    }
}

/// Création ou modification d'une sortie.
struct FormulaireSortie: View {
    let sortie: Sortie?

    @Environment(Depot.self) private var depot
    @Environment(Identite.self) private var identite
    @State private var nom = ""
    @State private var categorie = CategorieSortie.restaurant
    @State private var lieu = ""
    @State private var lien = ""
    @State private var note = ""
    @State private var charge = false

    var body: some View {
        Formulaire(
            titre: sortie == nil ? "Nouvelle sortie" : "Sortie",
            libelleEnregistrer: sortie == nil ? "Ajouter" : "Enregistrer",
            peutEnregistrer: Depot.texte(nom) != nil,
            enregistrer: enregistrer
        ) {
            Section {
                TextField("Nom", text: $nom)
                Picker("Catégorie", selection: $categorie) {
                    ForEach(CategorieSortie.allCases) { categorie in
                        Label(categorie.titre, systemImage: categorie.symbole).tag(categorie)
                    }
                }
            }
            Section {
                TextField("Lieu ou quartier", text: $lieu)
                TextField("Lien (site, Instagram…)", text: $lien)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Note", text: $note, axis: .vertical)
                    .lineLimit(1...4)
            }
        }
        .onAppear {
            guard !charge, let sortie else { return }
            charge = true
            nom = sortie.nom
            categorie = sortie.categorie
            lieu = sortie.lieu ?? ""
            lien = sortie.lien ?? ""
            note = sortie.note ?? ""
        }
    }

    private func enregistrer() {
        if let sortie {
            guard let nom = Depot.texte(nom) else { return }
            depot.modifier(sortie) {
                $0.nom = nom
                $0.categorieBrut = categorie.rawValue
                $0.lieu = Depot.texte(lieu)
                $0.lien = Depot.texte(lien)
                $0.note = Depot.texte(note)
            }
        } else {
            depot.ajouterSortie(nom, categorie: categorie, lieu: lieu, lien: lien, note: note, par: identite.membre)
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack { SortiesView() }.apercuJublo()
}
#endif
