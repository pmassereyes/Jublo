import SwiftData
import SwiftUI

/// Pense-bête, courses et wish list : ajout, cochage, balayage vers la corbeille.
/// La wish list se divise en deux : les envies du membre courant et celles de l'autre.
struct ListesView: View {
    /// Côté de la wish list affiché, relatif au membre courant.
    enum Cote: CaseIterable, Identifiable {
        case moi, autre
        var id: Self { self }
    }

    @Environment(Depot.self) private var depot
    @Environment(Identite.self) private var identite
    @Environment(Synchronisation.self) private var synchronisation
    @Environment(Navigation.self) private var navigation

    @State private var type = TypeListe.initial
    @State private var cote = Cote.moi
    @State private var saisie = ""
    @State private var derniereSuppression: ElementListe?
    @State private var rappel: ElementListe?
    @FocusState private var saisieActive: Bool

    var body: some View {
        List {
            Section {
                SelecteurPilules(options: TypeListe.allCases, selection: $type, titre: \.titre)
                if type == .wishList {
                    SelecteurPilules(options: Cote.allCases, selection: $cote) { cote in
                        Libelles.pour(membre(cote), vuPar: identite.membre)
                    } couleur: { cote in
                        membre(cote).couleur
                    }
                    .overlay(Capsule().strokeBorder(Color.separateur))
                }
                champAjout
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: Mesures.marge, bottom: 6, trailing: Mesures.marge))

            ElementsDeListe(type: type, filtre: filtre) { element in
                depot.supprimer(element, par: identite.membre)
                derniereSuppression = element
            } programmerRappel: { element in
                rappel = element
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.interactively)
        .scrollContentBackground(.hidden)
        .background(.fond)
        .refreshable { await synchronisation.synchroniserMaintenant() }
        .sheet(item: $rappel) { element in
            FormulaireRappel(element: element)
        }
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
        // Liste demandée par une notification touchée.
        .onAppear(perform: ouvrirListeDemandee)
        .onChange(of: navigation.listeDemandee) { ouvrirListeDemandee() }
    }

    private func ouvrirListeDemandee() {
        guard let demandee = navigation.listeDemandee else { return }
        type = demandee
        navigation.listeDemandee = nil
    }

    private var champAjout: some View {
        HStack(spacing: 8) {
            TextField(invitation, text: $saisie)
                .font(.jubloCorps)
                .foregroundStyle(.texte)
                .submitLabel(.done)
                .focused($saisieActive)
                .onSubmit { ajouter(garderClavier: false) }
                .padding(.horizontal, Mesures.marge)
                .frame(minHeight: Mesures.zoneTactile)
                .background(.surface, in: .capsule)
            Button { ajouter(garderClavier: true) } label: {
                Image(systemName: "plus")
                    .accessibilityLabel("Ajouter")
            }
            .buttonStyle(.pilule)
            .disabled(saisie.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func membre(_ cote: Cote) -> Membre {
        cote == .moi ? identite.membre : identite.membre.autre
    }

    /// Destinataire des envies affichées, quand la wish list est ouverte.
    private var destinataire: Membre? {
        type == .wishList ? membre(cote) : nil
    }

    private var filtre: Predicate<ElementListe> {
        if let destinataire {
            ElementListe.envies(pour: destinataire)
        } else {
            ElementListe.actifs(dans: type)
        }
    }

    private var invitation: String {
        if let destinataire {
            Libelles.ajoutEnvie(pour: destinataire, vuPar: identite.membre)
        } else {
            type.invitationAjout
        }
    }

    /// « OK » au clavier ajoute puis ferme le clavier ; « + » le garde ouvert pour enchaîner.
    private func ajouter(garderClavier: Bool) {
        withAnimation {
            if depot.ajouter(saisie, a: type, par: identite.membre, pour: destinataire) != nil {
                saisie = ""
            }
        }
        saisieActive = garderClavier
    }
}

/// Éléments d'une liste, « à faire » puis « fait » (« à offrir » puis « offert » dans la wish list).
private struct ElementsDeListe: View {
    let type: TypeListe
    let supprimer: (ElementListe) -> Void
    let programmerRappel: (ElementListe) -> Void

    @Environment(Depot.self) private var depot
    @Environment(Identite.self) private var identite
    @Query private var elements: [ElementListe]

    init(
        type: TypeListe, filtre: Predicate<ElementListe>,
        supprimer: @escaping (ElementListe) -> Void, programmerRappel: @escaping (ElementListe) -> Void
    ) {
        self.type = type
        self.supprimer = supprimer
        self.programmerRappel = programmerRappel
        _elements = Query(filter: filtre, sort: \.creeLe, order: .reverse)
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
            section(aFaire, titre: type.libelleEnAttente)
        }
        if !faits.isEmpty {
            section(faits, titre: type.libelleTermine)
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
                .swipeActions(edge: .leading) {
                    if peutAvoirUnRappel(element) {
                        Button {
                            programmerRappel(element)
                        } label: {
                            Label("Rappel", systemImage: "bell")
                        }
                        .tint(.commun)
                    }
                }
                .contextMenu {
                    if peutAvoirUnRappel(element) {
                        Button(element.rappelLe == nil ? "Me le rappeler…" : "Modifier le rappel…", systemImage: "bell") {
                            programmerRappel(element)
                        }
                    }
                    Button("Mettre à la corbeille", systemImage: "trash", role: .destructive) {
                        withAnimation { supprimer(element) }
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

    /// Seul le pense-bête a des rappels, et un élément fait n'en a plus besoin.
    private func peutAvoirUnRappel(_ element: ElementListe) -> Bool {
        element.type == .penseBete && !element.estCoche
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
                Image(systemName: symbole)
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
                    if let rappel {
                        Label(rappel, systemImage: "bell.fill")
                            .font(.jubloLegende)
                            .foregroundStyle(.texte)
                    }
                }
                Spacer(minLength: 0)
                PastilleMembre(membre: element.auteur, taille: 26)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(element.titre)
        .accessibilityValue(element.estCoche ? element.type.libelleTermine : element.type.libelleEnAttente)
        .accessibilityHint([detail, rappel.map { "Rappel \($0)" }].compactMap(\.self).joined(separator: ", "))
    }

    /// « Demain à 09:00 », pour un élément du pense-bête pas encore fait.
    private var rappel: String? {
        guard element.type == .penseBete, !element.estCoche, let date = element.rappelLe else { return nil }
        return "\(Formats.jourProche(date)) à \(Formats.heure(date))"
    }

    /// Un cadeau pour une envie offerte, une coche ailleurs.
    private var symbole: String {
        guard element.estCoche else { return "circle" }
        return element.type == .wishList ? "gift.circle.fill" : "checkmark.circle.fill"
    }

    private var detail: String {
        if element.estCoche, let cocheLe = element.cocheLe {
            "\(element.type.libelleCochePar) \(Libelles.qui(element.cochePar, vuPar: courant)) · \(Formats.relatif(cocheLe))"
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
