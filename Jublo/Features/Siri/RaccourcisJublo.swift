import AppIntents

/// Phrases que Siri reconnaît sans configuration. Pour une app tierce, chacune doit contenir le
/// nom de l'app ; le titre et la date sont ensuite demandés par Siri.
struct RaccourcisJublo: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AjouterRendezVous(),
            phrases: [
                "Ajoute un rendez-vous dans \(.applicationName)",
                "Ajoute un rendez-vous sur \(.applicationName)",
                "Ajouter un rendez-vous dans \(.applicationName)",
                "Nouveau rendez-vous dans \(.applicationName)",
                "Ajoute un rendez-vous pour \(\.$pour) dans \(.applicationName)",
            ],
            shortTitle: "Ajouter un rendez-vous",
            systemImageName: "calendar.badge.plus"
        )
    }
}
