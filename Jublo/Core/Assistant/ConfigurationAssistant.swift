import Foundation
import Observation

/// Réglages de l'assistant, propres à chaque iPhone : fournisseur, adresse et modèle dans
/// `UserDefaults`, clé d'API dans le trousseau (une par fournisseur).
@MainActor
@Observable
final class ConfigurationAssistant {
    private enum Cle {
        static let fournisseur = "assistant.fournisseur"
        static let adresse = "assistant.adresse"
        static let modele = "assistant.modele"
    }

    private let stockage: UserDefaults
    private let serviceTrousseau: String
    /// Réponses simulées, sans fournisseur (debug : `-assistantSimule`).
    let simulee: Bool

    /// Changer de fournisseur remet son adresse et son modèle par défaut.
    var fournisseur: Fournisseur {
        didSet {
            guard fournisseur != oldValue else { return }
            stockage.set(fournisseur.rawValue, forKey: Cle.fournisseur)
            adresse = fournisseur.adresseParDefaut
            modele = fournisseur.modeleParDefaut
            cleEnregistree = Trousseau.lire(fournisseur.rawValue, service: serviceTrousseau) != nil
        }
    }

    var adresse: String {
        didSet { stockage.set(adresse, forKey: Cle.adresse) }
    }

    var modele: String {
        didSet { stockage.set(modele, forKey: Cle.modele) }
    }

    private(set) var cleEnregistree: Bool

    init(stockage: UserDefaults = .standard, serviceTrousseau: String = Trousseau.serviceAssistant, simulee: Bool = false) {
        self.stockage = stockage
        self.serviceTrousseau = serviceTrousseau
        self.simulee = simulee
        let fournisseur = stockage.string(forKey: Cle.fournisseur).flatMap(Fournisseur.init(rawValue:)) ?? .mistral
        self.fournisseur = fournisseur
        adresse = stockage.string(forKey: Cle.adresse) ?? fournisseur.adresseParDefaut
        modele = stockage.string(forKey: Cle.modele) ?? fournisseur.modeleParDefaut
        cleEnregistree = Trousseau.lire(fournisseur.rawValue, service: serviceTrousseau) != nil
    }

    /// Enregistre la clé du fournisseur courant dans le trousseau.
    func enregistrerCle(_ cle: String) throws {
        let cle = cle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cle.isEmpty else { return }
        try Trousseau.enregistrer(cle, pour: fournisseur.rawValue, service: serviceTrousseau)
        cleEnregistree = true
    }

    func supprimerCle() {
        Trousseau.supprimer(fournisseur.rawValue, service: serviceTrousseau)
        cleEnregistree = false
    }

    /// Ce qui manque pour utiliser l'assistant, ou nil s'il est prêt.
    var manque: String? {
        if simulee { return nil }
        guard let url = urlAdresse, let hote = url.host(), !hote.isEmpty else {
            return "Indique l'adresse de l'API (https://…)."
        }
        guard url.scheme == "https" || hote == "localhost" || hote == "127.0.0.1" else {
            return ErreurAssistant.httpsRequis.errorDescription
        }
        if modele.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Indique le modèle à utiliser."
        }
        if fournisseur.cleObligatoire && !cleEnregistree {
            return "Enregistre ta clé d'API \(fournisseur.nom)."
        }
        return nil
    }

    /// Nom de la destination des messages, pour prévenir l'utilisateur.
    var destination: String {
        fournisseur == .autre ? (urlAdresse?.host() ?? "votre serveur") : fournisseur.nom
    }

    /// Service correspondant aux réglages, ou nil s'ils sont incomplets.
    func service() -> (any ServiceDiscussion)? {
        #if DEBUG
        if simulee { return ServiceSimule() }
        #endif
        guard manque == nil, let url = urlAdresse else { return nil }
        let parametres = ParametresConnexion(
            adresse: url,
            modele: modele.trimmingCharacters(in: .whitespaces),
            cle: Trousseau.lire(fournisseur.rawValue, service: serviceTrousseau)
        )
        return ClientCompatibleOpenAI(parametres: parametres)
    }

    private var urlAdresse: URL? {
        URL(string: adresse.trimmingCharacters(in: .whitespaces))
    }
}
