import Foundation
import OSLog
import UserNotifications

/// Notification locale à programmer : un rappel (à sa date) ou une annonce (tout de suite).
struct NotificationPrevue: Equatable {
    let identifiant: String
    let titre: String
    let corps: String
    /// Fil qui regroupe les notifications dans le centre de notifications.
    let fil: String
    /// Date d'envoi ; nil pour tout de suite.
    let date: Date?
    /// Écran à ouvrir quand on touche la notification (clés `onglet` et `liste`).
    let ouvrir: [String: String]
}

enum StatutNotifications: Equatable {
    case aDemander, autorisees, refusees
}

/// Centre de notifications du système, derrière un protocole : les tests et la base en mémoire
/// n'en touchent pas.
@MainActor
protocol CentreNotifications: AnyObject {
    func statut() async -> StatutNotifications
    /// Affiche la demande d'autorisation du système. Renvoie vrai si elle est accordée.
    func demanderAutorisation() async -> Bool
    func identifiantsEnAttente() async -> [String]
    func programmer(_ notification: NotificationPrevue) async
    func retirer(_ identifiants: [String])
}

/// `UNUserNotificationCenter`.
@MainActor
final class CentreSysteme: CentreNotifications {
    private var centre: UNUserNotificationCenter { .current() }

    func statut() async -> StatutNotifications {
        switch await centre.notificationSettings().authorizationStatus {
        case .notDetermined: .aDemander
        case .denied: .refusees
        default: .autorisees
        }
    }

    func demanderAutorisation() async -> Bool {
        do {
            return try await centre.requestAuthorization(options: [.alert, .sound])
        } catch {
            journal.error("Autorisation des notifications impossible : \(error)")
            return false
        }
    }

    func identifiantsEnAttente() async -> [String] {
        await centre.pendingNotificationRequests().map(\.identifier)
    }

    func programmer(_ notification: NotificationPrevue) async {
        let contenu = UNMutableNotificationContent()
        contenu.title = notification.titre
        contenu.body = notification.corps
        contenu.sound = .default
        contenu.threadIdentifier = notification.fil
        contenu.userInfo = notification.ouvrir
        let declencheur = notification.date.map { date in
            UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date),
                repeats: false
            )
        }
        do {
            try await centre.add(UNNotificationRequest(identifier: notification.identifiant, content: contenu, trigger: declencheur))
        } catch {
            journal.error("Notification non programmée : \(error)")
        }
    }

    func retirer(_ identifiants: [String]) {
        guard !identifiants.isEmpty else { return }
        centre.removePendingNotificationRequests(withIdentifiers: identifiants)
    }
}

/// Aucune notification : base en mémoire (tests d'interface), tests unitaires, aperçus.
@MainActor
final class CentreInerte: CentreNotifications {
    func statut() async -> StatutNotifications { .autorisees }
    func demanderAutorisation() async -> Bool { true }
    func identifiantsEnAttente() async -> [String] { [] }
    func programmer(_ notification: NotificationPrevue) async {}
    func retirer(_ identifiants: [String]) {}
}

private let journal = Logger(subsystem: "com.pmassereyes.jublo", category: "Notifications")
