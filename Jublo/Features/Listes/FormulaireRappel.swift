import SwiftUI

/// Rappel d'un élément du pense-bête : il sonne sur les deux iPhones, sauf si l'élément est
/// coché ou mis à la corbeille avant.
struct FormulaireRappel: View {
    let element: ElementListe

    @Environment(Depot.self) private var depot
    @Environment(Notificateur.self) private var notificateur
    @Environment(\.dismiss) private var fermer

    @State private var date = FormulaireRappel.parDefaut()
    @State private var charge = false

    var body: some View {
        Formulaire(
            titre: element.rappelLe == nil ? "Nouveau rappel" : "Rappel",
            peutEnregistrer: date > .now,
            enregistrer: enregistrer
        ) {
            Section {
                Text(element.titre)
                    .font(.jubloCorpsFort)
                    .foregroundStyle(.texte)
                DatePicker("Quand", selection: $date, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                    .environment(\.locale, .jublo)
            } footer: {
                Text("Le rappel sonnera sur vos deux iPhones, sauf si l'élément est coché avant.")
                    .font(.jubloLegende)
            }
            if element.rappelLe != nil {
                Section {
                    Button("Retirer le rappel", role: .destructive) {
                        depot.programmerRappel(nil, pour: element)
                        fermer()
                    }
                }
            }
        }
        .onAppear(perform: charger)
    }

    private func charger() {
        guard !charge else { return }
        charge = true
        if let rappel = element.rappelLe, rappel > .now {
            date = rappel
        }
    }

    private func enregistrer() {
        depot.programmerRappel(date, pour: element)
        Task { await notificateur.demanderAutorisationSiBesoin() }
    }

    /// Par défaut : l'heure pleine suivante, plus une heure.
    private static func parDefaut(maintenant: Date = .now) -> Date {
        let calendrier = Calendar.current
        let heure = calendrier.dateInterval(of: .hour, for: maintenant)?.start ?? maintenant
        return calendrier.date(byAdding: .hour, value: 2, to: heure) ?? maintenant
    }
}
