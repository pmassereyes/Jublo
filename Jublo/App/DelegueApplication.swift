import CloudKit
import UIKit

/// Délégué UIKit : notifications push (réveil de CKSyncEngine) et invitations de partage.
final class DelegueApplication: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
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
