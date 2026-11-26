import AppIntents
import SwiftData
import SwiftUI

/// Agenda partagé : les rendez-vous à venir groupés par jour, puis les passés à la demande.
struct AgendaView: View {
    @Environment(Depot.self) private var depot
    @Environment(Identite.self) private var identite
    @Environment(Synchronisation.self) private var synchronisation

    @Query(filter: Evenement.actifs, sort: \Evenement.debut) private var evenements: [Evenement]
    @State private var edition: EditionEvenement?
    @State private var voirPasses = false
    @State private var derniereSuppression: Evenement?
    @AppStorage("agenda.astuceSiri") private var astuceSiri = true

    var body: some View {
        let maintenant = Date.now
        let aVenir = evenements.filter { $0.estAVenir(a: maintenant) }
        let passes = evenements.filter { !$0.estAVenir(a: maintenant) }.reversed()

        List {
            if astuceSiri {
                // « Dis Siri, ajoute un rendez-vous dans Jublo » ; la croix la masque pour de bon.
                SiriTipView(intent: AjouterRendezVous(), isVisible: $astuceSiri)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: Mesures.marge, bottom: 8, trailing: Mesures.marge))
            }
            if aVenir.isEmpty {
                ContentUnavailableView {
                    Label("Rien de prévu", systemImage: "calendar")
                } description: {
                    Text("Ajoute un rendez-vous, une sortie ou un week-end : il apparaîtra chez vous deux.")
                } actions: {
                    Button("Ajouter un rendez-vous") { edition = .nouveau }
                        .buttonStyle(.pilule)
                }
                .font(.jubloCorps)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            ForEach(jours(aVenir, maintenant: maintenant), id: \.jour) { groupe in
                section(groupe.evenements, titre: Formats.jourProche(groupe.jour))
            }
            if !passes.isEmpty {
                Section {
                    Button(voirPasses ? "Masquer les rendez-vous passés" : "Voir les rendez-vous passés (\(passes.count))") {
                        withAnimation { voirPasses.toggle() }
                    }
                    .buttonStyle(.pilule(.contour, compacte: true))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 12, leading: Mesures.marge, bottom: 12, trailing: Mesures.marge))
                }
                if voirPasses {
                    section(Array(passes), titre: "Passés", passes: true)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(.fond)
        .refreshable { await synchronisation.synchroniserMaintenant() }
        .navigationTitle("Agenda")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                BoutonAjouter(libelle: "Ajouter un rendez-vous") { edition = .nouveau }
            }
        }
        .sheet(item: $edition) { edition in
            FormulaireEvenement(edition: edition)
        }
        .bandeauAnnuler($derniereSuppression) { evenement in
            "« \(evenement.titre) » mis à la corbeille"
        } annuler: { evenement in
            withAnimation { depot.restaurer(evenement) }
        }
    }

    /// Rendez-vous à venir groupés par jour ; un rendez-vous déjà commencé (sur plusieurs
    /// jours) est rangé à aujourd'hui.
    private func jours(_ evenements: [Evenement], maintenant: Date) -> [(jour: Date, evenements: [Evenement])] {
        let calendrier = Calendar.current
        let aujourdHui = calendrier.startOfDay(for: maintenant)
        let groupes = Dictionary(grouping: evenements) { max(calendrier.startOfDay(for: $0.debut), aujourdHui) }
        return groupes.keys.sorted().map { (jour: $0, evenements: groupes[$0] ?? []) }
    }

    private func section(_ evenements: [Evenement], titre: String, passes: Bool = false) -> some View {
        Section {
            ForEach(evenements) { evenement in
                Button {
                    edition = .modifier(evenement)
                } label: {
                    LigneEvenement(evenement: evenement, courant: identite.membre, montrerDate: passes)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation {
                            depot.supprimer(evenement, par: identite.membre)
                            derniereSuppression = evenement
                        }
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
                .listRowInsets(EdgeInsets(top: 10, leading: Mesures.marge + 4, bottom: 10, trailing: Mesures.marge + 12))
            }
        } header: {
            TitreSection(titre: titre)
                .padding(.horizontal, Mesures.marge)
                .padding(.top, 8)
                .listRowInsets(EdgeInsets())
        }
        .listSectionSeparator(.hidden)
    }
}

/// Ligne d'un rendez-vous : horaire, titre, lieu, et à qui il s'adresse.
private struct LigneEvenement: View {
    let evenement: Evenement
    let courant: Membre
    let montrerDate: Bool

    var body: some View {
        HStack(spacing: Mesures.espacement) {
            Text(horaire)
                .font(.jubloCorpsFort)
                .foregroundStyle(.texte)
                .frame(width: 64, alignment: .leading)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            VStack(alignment: .leading, spacing: 2) {
                Text(evenement.titre)
                    .font(.jubloCorpsFort)
                    .foregroundStyle(.texte)
                if let detail {
                    Text(detail)
                        .font(.jubloLegende)
                        .foregroundStyle(.texteSecondaire)
                }
            }
            Spacer(minLength: 0)
            if evenement.rappel != nil {
                Image(systemName: "bell.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.texteSecondaire)
                    .accessibilityLabel("Avec rappel")
            }
            PastilleMembre(membre: evenement.concerne, taille: 26)
        }
        .frame(minHeight: Mesures.zoneTactile)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Libelles.concerne(evenement.concerne, vuPar: courant))
        .accessibilityHint("Modifier le rendez-vous")
    }

    private var horaire: String {
        if montrerDate {
            return evenement.debut.formatted(.dateTime.day().month(.abbreviated).locale(.jublo))
        }
        return evenement.journeeEntiere ? "Journée" : Formats.heure(evenement.debut)
    }

    /// Lieu, fin et concerné, réunis en une ligne.
    private var detail: String? {
        var morceaux: [String] = []
        if let fin = evenement.fin, fin > evenement.debut {
            if Calendar.current.isDate(fin, inSameDayAs: evenement.debut) {
                if !evenement.journeeEntiere { morceaux.append("jusqu'à \(Formats.heure(fin))") }
            } else {
                morceaux.append("jusqu'au \(fin.formatted(.dateTime.day().month(.wide).locale(.jublo)))")
            }
        }
        if let lieu = evenement.lieu { morceaux.append(lieu) }
        morceaux.append(Libelles.concerne(evenement.concerne, vuPar: courant))
        return morceaux.joined(separator: " · ")
    }
}

/// Rendez-vous à créer ou à modifier.
enum EditionEvenement: Identifiable {
    case nouveau
    case modifier(Evenement)

    var id: String {
        switch self {
        case .nouveau: "nouveau"
        case .modifier(let evenement): evenement.id.uuidString
        }
    }
}

struct FormulaireEvenement: View {
    let edition: EditionEvenement

    @Environment(Depot.self) private var depot
    @Environment(Identite.self) private var identite
    @Environment(Notificateur.self) private var notificateur
    @Environment(\.dismiss) private var fermer

    @State private var titre = ""
    @State private var debut = FormulaireEvenement.prochaineHeure()
    @State private var avecFin = false
    @State private var fin = FormulaireEvenement.prochaineHeure().addingTimeInterval(3_600)
    @State private var journeeEntiere = false
    @State private var lieu = ""
    @State private var note = ""
    @State private var concerne: Membre?
    @State private var rappel: RappelEvenement?
    @State private var charge = false
    /// Vrai quand `debut` vient d'être chargé : la fin ne doit pas le suivre cette fois-là.
    @State private var debutCharge = false

    var body: some View {
        Formulaire(
            titre: estNouveau ? "Nouveau rendez-vous" : "Rendez-vous",
            libelleEnregistrer: estNouveau ? "Ajouter" : "Enregistrer",
            peutEnregistrer: Depot.texte(titre) != nil,
            enregistrer: enregistrer
        ) {
            Section {
                TextField("Titre (dîner, dentiste, week-end…)", text: $titre)
                Picker("Pour", selection: $concerne) {
                    Text("Vous deux").tag(Membre?.none)
                    ForEach([identite.membre, identite.membre.autre]) { membre in
                        Text(Libelles.quiEnDebut(membre, vuPar: identite.membre)).tag(Membre?.some(membre))
                    }
                }
            }
            Section {
                Toggle("Toute la journée", isOn: $journeeEntiere)
                DatePicker("Début", selection: $debut, displayedComponents: composantes)
                    .environment(\.locale, .jublo)
                Toggle(journeeEntiere ? "Sur plusieurs jours" : "Avec une heure de fin", isOn: $avecFin)
                if avecFin {
                    DatePicker("Fin", selection: $fin, in: debut..., displayedComponents: composantes)
                        .environment(\.locale, .jublo)
                }
            }
            Section {
                Picker("Rappel", selection: $rappel) {
                    Text("Aucun").tag(RappelEvenement?.none)
                    ForEach(RappelEvenement.choix(journeeEntiere: journeeEntiere)) { choix in
                        Text(choix.libelle(journeeEntiere: journeeEntiere)).tag(RappelEvenement?.some(choix))
                    }
                }
            } footer: {
                if rappel != nil {
                    Text(Libelles.rappelSonne(pour: concerne, vuPar: identite.membre))
                        .font(.jubloLegende)
                }
            }
            Section {
                TextField("Lieu", text: $lieu)
                TextField("Note", text: $note, axis: .vertical)
                    .lineLimit(1...4)
            }
            if case .modifier(let evenement) = edition {
                Section {
                    Button("Mettre à la corbeille", role: .destructive) {
                        depot.supprimer(evenement, par: identite.membre)
                        fermer()
                    }
                }
            }
        }
        .onAppear(perform: charger)
        .onChange(of: journeeEntiere) {
            rappel = rappel?.adapte(journeeEntiere: journeeEntiere)
        }
        .onChange(of: debut) { ancien, nouveau in
            guard !debutCharge else {
                debutCharge = false
                return
            }
            // La fin suit le début, en gardant la même durée.
            fin = max(fin.addingTimeInterval(nouveau.timeIntervalSince(ancien)), nouveau)
        }
    }

    private var estNouveau: Bool {
        if case .nouveau = edition { true } else { false }
    }

    private var composantes: DatePickerComponents {
        journeeEntiere ? .date : [.date, .hourAndMinute]
    }

    private func charger() {
        guard !charge else { return }
        charge = true
        guard case .modifier(let evenement) = edition else { return }
        titre = evenement.titre
        debutCharge = evenement.debut != debut
        debut = evenement.debut
        journeeEntiere = evenement.journeeEntiere
        avecFin = evenement.fin.map { $0 > evenement.debut } ?? false
        fin = evenement.fin ?? evenement.debut.addingTimeInterval(3_600)
        lieu = evenement.lieu ?? ""
        note = evenement.note ?? ""
        concerne = evenement.concerne
        rappel = evenement.rappel
    }

    private func enregistrer() {
        let calendrier = Calendar.current
        let debutFinal = journeeEntiere ? calendrier.startOfDay(for: debut) : debut
        let finFinale: Date? = avecFin ? (journeeEntiere ? calendrier.startOfDay(for: fin) : fin) : nil
        let rappelFinal = rappel?.adapte(journeeEntiere: journeeEntiere)
        if rappelFinal != nil {
            Task { await notificateur.demanderAutorisationSiBesoin() }
        }
        switch edition {
        case .nouveau:
            depot.ajouterEvenement(
                titre, debut: debutFinal, fin: finFinale, journeeEntiere: journeeEntiere,
                lieu: lieu, note: note, pour: concerne, rappel: rappelFinal, par: identite.membre
            )
        case .modifier(let evenement):
            guard let titre = Depot.texte(titre) else { return }
            depot.modifier(evenement) {
                $0.titre = titre
                $0.debut = debutFinal
                $0.fin = finFinale.map { max($0, debutFinal) }
                $0.journeeEntiere = journeeEntiere
                $0.lieu = Depot.texte(lieu)
                $0.note = Depot.texte(note)
                $0.pourId = concerne?.rawValue
                $0.rappelBrut = rappelFinal?.rawValue
            }
        }
    }

    /// Heure pleine suivante, par défaut pour un nouveau rendez-vous.
    private static func prochaineHeure(maintenant: Date = .now) -> Date {
        let calendrier = Calendar.current
        let heure = calendrier.dateInterval(of: .hour, for: maintenant)?.start ?? maintenant
        return calendrier.date(byAdding: .hour, value: 1, to: heure) ?? maintenant
    }
}

#if DEBUG
#Preview {
    NavigationStack { AgendaView() }.apercuJublo()
}
#endif
