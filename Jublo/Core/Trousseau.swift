import Foundation
import Security

/// Accès minimal au trousseau iOS, pour les secrets (clés d'API).
/// Les éléments restent sur cet appareil (`ThisDeviceOnly`) : ni iCloud, ni sauvegarde.
enum Trousseau {
    static let serviceAssistant = "com.pmassereyes.jublo.assistant"

    static func lire(_ compte: String, service: String) -> String? {
        var requete = base(compte, service)
        requete[kSecReturnData as String] = true
        requete[kSecMatchLimit as String] = kSecMatchLimitOne
        var resultat: CFTypeRef?
        guard SecItemCopyMatching(requete as CFDictionary, &resultat) == errSecSuccess,
              let donnees = resultat as? Data else { return nil }
        return String(data: donnees, encoding: .utf8)
    }

    static func enregistrer(_ valeur: String, pour compte: String, service: String) throws {
        supprimer(compte, service: service)
        var requete = base(compte, service)
        requete[kSecValueData as String] = Data(valeur.utf8)
        requete[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let statut = SecItemAdd(requete as CFDictionary, nil)
        guard statut == errSecSuccess else { throw ErreurTrousseau(statut: statut) }
    }

    static func supprimer(_ compte: String, service: String) {
        SecItemDelete(base(compte, service) as CFDictionary)
    }

    private static func base(_ compte: String, _ service: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: compte,
        ]
    }
}

struct ErreurTrousseau: LocalizedError {
    let statut: OSStatus

    var errorDescription: String? {
        "Impossible d'enregistrer la clé dans le trousseau (erreur \(statut))."
    }
}
