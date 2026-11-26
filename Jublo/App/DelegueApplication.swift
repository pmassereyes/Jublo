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
    /// lance l'écran : on synchronise ici (20 s au plus, le système en laisse 30), puis on
    /// reprogramme les rappels (l'autre a pu en ajouter). Les notifications « l'autre a mis à
    /// jour… » ne passent pas par ici : iCloud les affiche lui-même (`Signaux`).
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        guard let synchronisation = Synchronisation.courante else { return .noData }
        await synchronisation.synchroniser(auPlus: .seconds(20))
        await Notificateur.courant?.replanifier()
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

/// Méthodes isolées au fil principal (`@preconcurrency`), et non `nonisolated` : iOS attend
/// leur réponse sur le fil principal. Une version `nonisolated` répondait depuis un fil
/// d'arrière-plan, et UIKit arrêtait Jublo dès qu'on touchait une notification (build 64).
extension DelegueApplication: @preconcurrency UNUserNotificationCenterDelegate {
    /// App au premier plan : les rappels s'affichent, pas les notifications « l'autre a mis à
    /// jour… » (l'écran montre déjà le changement).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        notification.request.identifier.hasPrefix(Rappels.prefixe) ? [.banner, .list, .sound] : []
    }

    /// Notification touchée : on ouvre l'onglet (et la liste) dont elle parle. Un rappel le dit
    /// dans ses infos ; une notification d'iCloud, par son abonnement (`Signaux`).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        var infos: [String: String] = [:]
        let abonnement = CKNotification(fromRemoteNotificationDictionary: userInfo)?.subscriptionID
        if let rubrique = Signaux.rubrique(abonnement: abonnement) {
            infos = Signaux.ecran(rubrique)
        } else {
            for (cle, valeur) in userInfo {
                if let cle = cle as? String, let valeur = valeur as? String {
                    infos[cle] = valeur
                }
            }
        }
        Navigation.courante?.ouvrir(infos)
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
