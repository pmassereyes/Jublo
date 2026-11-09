import SwiftData
import SwiftUI

/// Éléments supprimés, tous types confondus : type, qui, quand, et restauration.
/// Poussée depuis Listes et depuis Nous.
struct CorbeilleView: View {
    @Environment(Depot.self) private var depot

    // Chaque nouveau type `Suppressible` doit être ajouté ici
    // et dans `Depot.elementsDansLaCorbeille()`.
    @Query(filter: #Predicate<ElementListe> { $0.supprimeLe != nil })
    private var elementsListe: [ElementListe]
    @Query(filter: #Predicate<Cagnotte> { $0.supprimeLe != nil })
    private var cagnottes: [Cagnotte]

    private var entrees: [EntreeCorbeille] {
        let toutes = elementsListe.map { EntreeCorbeille(element: $0) }
            + cagnottes.map { EntreeCorbeille(element: $0) }
        return toutes.sorted { $0.supprimeLe > $1.supprimeLe }
    }

    var body: some View {
        List {
            if entrees.isEmpty {
                ContentUnavailableView(
                    "La corbeille est vide",
                    systemImage: "trash",
                    description: Text("Les éléments supprimés y restent 30 jours.")
                )
                .font(.jubloCorps)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(entrees) { entree in
                        LigneCorbeille(entree: entree) {
                            withAnimation { depot.restaurer(entree.element) }
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: Mesures.rayonCarte, style: .continuous)
                                .fill(Color.surface)
                                .padding(.horizontal, Mesures.marge)
                                .padding(.vertical, 4)
                        )
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 12, leading: Mesures.marge * 2, bottom: 12, trailing: Mesures.marge * 2))
                    }
                    // Une ligne plutôt qu'un pied de section, dont le fond par défaut est opaque.
                    Text("Les éléments sont effacés définitivement 30 jours après leur mise à la corbeille. Les cagnottes qui ont des versements sont toujours conservées.")
                        .font(.jubloLegende)
                        .foregroundStyle(.texteSecondaire)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: Mesures.marge, bottom: 8, trailing: Mesures.marge))
                }
                .listSectionSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(.fond)
        .navigationTitle("Corbeille")
    }
}

struct EntreeCorbeille: Identifiable {
    let element: any Suppressible

    var id: PersistentIdentifier { element.persistentModelID }
    var supprimeLe: Date { element.supprimeLe ?? .distantPast }
}

private struct LigneCorbeille: View {
    let entree: EntreeCorbeille
    let restaurer: () -> Void

    @Environment(Identite.self) private var identite

    var body: some View {
        HStack(spacing: Mesures.espacement) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entree.element.libelleType)
                    .font(.jubloLegende)
                    .foregroundStyle(.texteSecondaire)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.fond, in: .capsule)
                Text(entree.element.titreAffiche)
                    .font(.jubloCorpsFort)
                    .foregroundStyle(.texte)
                Text("Mis à la corbeille par \(Libelles.qui(entree.element.supprimePar, vuPar: identite.membre)) · \(Formats.relatif(entree.supprimeLe))")
                    .font(.jubloLegende)
                    .foregroundStyle(.texteSecondaire)
                Text(echeance)
                    .font(.jubloLegende)
                    .foregroundStyle(.texteSecondaire)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            Button("Restaurer", action: restaurer)
                .buttonStyle(.pilule(.contour, compacte: true))
                .accessibilityHint("Remet « \(entree.element.titreAffiche) » à sa place")
        }
    }

    private var echeance: String {
        guard entree.element.estPurgeable else { return "Conservée : elle a des versements" }
        guard let date = Depot.datePurge(de: entree.element), date > .now else {
            return "Effacé au prochain lancement"
        }
        return "Effacé \(Formats.relatif(date))"
    }
}

#if DEBUG
#Preview {
    NavigationStack { CorbeilleView() }.apercuJublo()
}
#endif
