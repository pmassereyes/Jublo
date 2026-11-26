import CloudKit
import UIKit
import UserNotifications

/// Délégué UIKit : notifications push (réveil de CKSyncEngine), notifications locales et
/// invitations de partage.
final class DelegueApplication: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    /// Notification push silencieuse de CloudKit : l'autre iPhone a envoyé des changements.
    /// L'app est souvent réveillée en arrière-plan sans scène, donc sans la synchronisation que
    /// lance l'écran : on synchronise ici (20 s au plus, le système en laisse 30), puis on attend
    /// que les notifications des changements reçus soient parties et les rappels reprogrammés.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        guard let synchronisation = Synchronisation.courante else { return .noData }
        await synchronisation.synchroniser(auPlus: .seconds(20))
        if let notificateur = Notificateur.courant {
            await notificateur.terminerEnvois()
            await notificateur.replanifier()
        }
        return .newData
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting session: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        configuration.delegateClass = DelegueScene.self
        return configuration
    }
}

extension DelegueApplication: UNUserNotificationCenterDelegate {
    /// App au premier plan : les rappels s'affichent, pas les annonces (l'écran montre déjà le
    /// changement).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        notification.request.identifier.hasPrefix(Rappels.prefixe) ? [.banner, .list, .sound] : []
    }

    /// Notification touchée : on ouvre l'onglet (et la liste) dont elle parle.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        var infos: [String: String] = [:]
        for (cle, valeur) in response.notification.request.content.userInfo {
            if let cle = cle as? String, let valeur = valeur as? String {
                infos[cle] = valeur
            }
        }
        await MainActor.run { [infos] in
            Navigation.courante?.ouvrir(infos)
        }
    }
}

/// Reçoit les invitations ouvertes depuis un lien de partage CloudKit.
final class DelegueScene: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        // App lancée par le lien d'invitation.
        if let metadonnees = options.cloudKitShareMetadata {
            accepter(metadonnees)
        }
    }

    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith metadonnees: CKShare.Metadata) {
        accepter(metadonnees)
    }

    private func accepter(_ metadonnees: CKShare.Metadata) {
        Task {
            await Synchronisation.courante?.accepter(metadonnees)
        }
    }
}
