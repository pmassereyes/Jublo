import SwiftData
import SwiftUI

/// Pense-bête, courses et wish list : ajout, cochage, balayage vers la corbeille.
struct ListesView: View {
    @Environment(Depot.self) private var depot
    @Environment(Identite.self) private var identite

    @State private var type = TypeListe.initial
    @State private var saisie = ""
    @State private var derniereSuppression: ElementListe?
    @FocusState private var saisieActive: Bool

    var body: some View {
        List {
            Section {
                SelecteurPilules(options: TypeListe.allCases, selection: $type, titre: \.titre)
                champAjout
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: Mesures.marge, bottom: 6, trailing: Mesures.marge))

            ElementsDeListe(type: type) { element in
                depot.supprimer(element, par: identite.membre)
                derniereSuppression = element
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(.fond)
        .navigationTitle("Listes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    CorbeilleView()
                } label: {
                    Image(systemName: "trash")
                        .accessibilityLabel("Ouvrir la corbeille")
                }
            }
        }
        .bandeauAnnuler($derniereSuppression) { element in
            "« \(element.titre) » mis à la corbeille"
        } annuler: { element in
            withAnimation { depot.restaurer(element) }
        }
    }

    private var champAjout: some View {
        HStack(spacing: 8) {
            TextField(type.invitationAjout, text: $saisie)
                .font(.jubloCorps)
                .foregroundStyle(.texte)
                .submitLabel(.done)
                .focused($saisieActive)
                .onSubmit(ajouter)
                .padding(.horizontal, Mesures.marge)
                .frame(minHeight: Mesures.zoneTactile)
                .background(.surface, in: .capsule)
            Button(action: ajouter) {
                Image(systemName: "plus")
                    .accessibilityLabel("Ajouter")
            }
            .buttonStyle(.pilule)
            .disabled(saisie.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func ajouter() {
        withAnimation {
            if depot.ajouter(saisie, a: type, par: identite.membre) != nil {
                saisie = ""
            }
        }
        // On garde le clavier ouvert pour enchaîner les ajouts.
        saisieActive = true
    }
}

/// Éléments d'une liste, « à faire » puis « fait ».
private struct ElementsDeListe: View {
    let type: TypeListe
    let supprimer: (ElementListe) -> Void

    @Environment(Depot.self) private var depot
    @Environment(Identite.self) private var identite
    @Query private var elements: [ElementListe]

    init(type: TypeListe, supprimer: @escaping (ElementListe) -> Void) {
        self.type = type
        self.supprimer = supprimer
        _elements = Query(filter: ElementListe.actifs(dans: type), sort: \.creeLe, order: .reverse)
    }

    var body: some View {
        let aFaire = elements.filter { !$0.estCoche }
        let faits = elements.filter(\.estCoche)

        if elements.isEmpty {
            ContentUnavailableView(
                "Rien pour l'instant",
                systemImage: "checklist",
                description: Text("Ajoute un premier élément avec le champ ci-dessus.")
            )
            .font(.jubloCorps)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        if !aFaire.isEmpty {
            section(aFaire, titre: "À faire")
        }
        if !faits.isEmpty {
            section(faits, titre: "Fait")
        }
    }

    private func section(_ elements: [ElementListe], titre: String) -> some View {
        Section {
            ForEach(elements) { element in
                LigneElement(element: element, courant: identite.membre) {
                    withAnimation { depot.basculer(element, par: identite.membre) }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation { supprimer(element) }
                    } label: {
                        Label("Corbeille", systemImage: "trash")
                    }
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: Mesures.rayonCarte, style: .continuous)
                        .fill(Color.surface)
                        .padding(.horizontal, Mesures.marge)
                        .padding(.vertical, 4)
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: Mesures.marge + 4, bottom: 8, trailing: Mesures.marge + 12))
            }
        } header: {
            TitreSection(titre: titre, detail: "\(elements.count)")
                .padding(.horizontal, Mesures.marge)
                .padding(.top, 8)
                .listRowInsets(EdgeInsets())
        }
        .listSectionSeparator(.hidden)
    }
}

/// Ligne d'un élément : toute la ligne coche ou décoche.
private struct LigneElement: View {
    let element: ElementListe
    let courant: Membre
    let basculer: () -> Void

    var body: some View {
        Button(action: basculer) {
            HStack(spacing: Mesures.espacement) {
                Image(systemName: element.estCoche ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(element.estCoche ? Color.texteSecondaire : element.auteur?.couleur ?? .commun)
                    .frame(width: Mesures.zoneTactile, height: Mesures.zoneTactile)
                VStack(alignment: .leading, spacing: 2) {
                    Text(element.titre)
                        .font(.jubloCorps)
                        .strikethrough(element.estCoche)
                        .foregroundStyle(element.estCoche ? Color.texteSecondaire : Color.texte)
                    Text(detail)
                        .font(.jubloLegende)
                        .foregroundStyle(.texteSecondaire)
                }
                Spacer(minLength: 0)
                PastilleMembre(membre: element.auteur, taille: 26)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(element.titre)
        .accessibilityValue(element.estCoche ? "Fait" : "À faire")
        .accessibilityHint(detail)
    }

    private var detail: String {
        if element.estCoche, let cocheLe = element.cocheLe {
            "Coché par \(Libelles.qui(element.cochePar, vuPar: courant)) · \(Formats.relatif(cocheLe))"
        } else {
            "Ajouté par \(Libelles.qui(element.auteurId, vuPar: courant)) · \(Formats.relatif(element.creeLe))"
        }
    }
}

private extension TypeListe {
    /// En debug, l'argument de lancement `-liste courses` ouvre directement une liste.
    static var initial: Self {
        #if DEBUG
        UserDefaults.standard.string(forKey: "liste").flatMap(Self.init(rawValue:)) ?? .penseBete
        #else
        .penseBete
        #endif
    }
}

#if DEBUG
#Preview {
    NavigationStack { ListesView() }.apercuJublo()
}
#endif
