import Foundation

/// Message échangé avec le modèle.
struct MessageIA: Sendable, Equatable, Encodable {
    enum Role: String, Sendable, Encodable {
        case systeme = "system"
        case utilisateur = "user"
        case assistant
    }

    let role: Role
    let contenu: String

    private enum CodingKeys: String, CodingKey {
        case role
        case contenu = "content"
    }
}

/// Service qui répond à une discussion, morceau par morceau.
protocol ServiceDiscussion: Sendable {
    func repondre(a messages: [MessageIA]) -> AsyncThrowingStream<String, Error>
}

struct ParametresConnexion: Sendable, Equatable {
    /// Adresse de base, sans « /chat/completions ».
    let adresse: URL
    let modele: String
    let cle: String?
}

/// Client pour toute API au format « chat completions » d'OpenAI :
/// Mistral, DeepSeek, Gemini, Ollama…
struct ClientCompatibleOpenAI: ServiceDiscussion {
    let parametres: ParametresConnexion
    var session: URLSession = .shared
    var temperature = 0.4

    func requete(pour messages: [MessageIA]) throws -> URLRequest {
        var requete = URLRequest(url: parametres.adresse.appending(path: "chat/completions"))
        requete.httpMethod = "POST"
        requete.timeoutInterval = 60
        requete.setValue("application/json", forHTTPHeaderField: "Content-Type")
        requete.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if let cle = parametres.cle, !cle.isEmpty {
            requete.setValue("Bearer \(cle)", forHTTPHeaderField: "Authorization")
        }
        let corps = Corps(model: parametres.modele, messages: messages, stream: true, temperature: temperature)
        requete.httpBody = try JSONEncoder().encode(corps)
        return requete
    }

    func repondre(a messages: [MessageIA]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let tache = Task {
                do {
                    let (octets, reponse) = try await session.bytes(for: requete(pour: messages))
                    guard let http = reponse as? HTTPURLResponse else {
                        throw ErreurAssistant.reponseInattendue
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        var corps = Data()
                        for try await octet in octets {
                            corps.append(octet)
                            if corps.count >= 8_192 { break }
                        }
                        throw ErreurAssistant.depuis(statut: http.statusCode, corps: corps)
                    }
                    for try await ligne in octets.lines {
                        switch try FluxSSE.evenement(ligne) {
                        case .texte(let texte):
                            continuation.yield(texte)
                        case .fin:
                            continuation.finish()
                            return
                        case nil:
                            continue
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: Task.isCancelled ? CancellationError() : ErreurAssistant.depuis(error))
                }
            }
            continuation.onTermination = { _ in tache.cancel() }
        }
    }

    private struct Corps: Encodable {
        let model: String
        let messages: [MessageIA]
        let stream: Bool
        let temperature: Double
    }
}

/// Lecture du flux « server-sent events » renvoyé par l'API.
enum FluxSSE {
    enum Evenement: Equatable {
        case texte(String)
        case fin
    }

    /// Interprète une ligne du flux. nil pour les lignes sans texte (commentaires, rôle, morceaux
    /// dans un format inconnu) : un fournisseur un peu différent ne doit pas casser la réponse.
    static func evenement(_ ligne: String) throws -> Evenement? {
        guard ligne.hasPrefix("data:") else { return nil }
        let donnees = ligne.dropFirst(5).trimmingCharacters(in: .whitespaces)
        if donnees == "[DONE]" { return .fin }
        guard !donnees.isEmpty,
              let morceau = try? JSONDecoder().decode(Morceau.self, from: Data(donnees.utf8)) else { return nil }
        if let erreur = morceau.error {
            throw ErreurAssistant.fournisseur(code: nil, message: erreur.message)
        }
        guard let texte = morceau.choices?.first?.delta?.content, !texte.isEmpty else { return nil }
        return .texte(texte)
    }

    private struct Morceau: Decodable {
        struct Choix: Decodable {
            let delta: Delta?
        }

        struct Delta: Decodable {
            let content: String?

            init(from decoder: Decoder) throws {
                // Certains modèles envoient un tableau de blocs (raisonnement) : on l'ignore.
                let conteneur = try decoder.container(keyedBy: CodingKeys.self)
                content = try? conteneur.decode(String.self, forKey: .content)
            }

            private enum CodingKeys: String, CodingKey {
                case content
            }
        }

        struct Erreur: Decodable {
            let message: String
        }

        let choices: [Choix]?
        let error: Erreur?
    }
}

enum ErreurAssistant: LocalizedError, Equatable {
    case cleRefusee
    case creditEpuise
    case introuvable
    case limiteAtteinte
    case httpsRequis
    case injoignable(hote: String?)
    case fournisseur(code: Int?, message: String)
    case reponseInattendue

    var errorDescription: String? {
        switch self {
        case .cleRefusee:
            "Le fournisseur a refusé la clé d'API. Vérifie-la dans les réglages."
        case .creditEpuise:
            "Crédit épuisé chez le fournisseur."
        case .introuvable:
            "Adresse ou modèle introuvable. Vérifie les réglages de l'assistant."
        case .limiteAtteinte:
            "Trop de demandes ou limite atteinte. Réessaie dans un moment."
        case .httpsRequis:
            "iOS exige une adresse en https://. Pour un modèle chez vous, passe par « tailscale serve »."
        case .injoignable(let hote):
            "Impossible de joindre \(hote ?? "le serveur"). Vérifie la connexion, et Tailscale si l'assistant tourne chez vous."
        case .fournisseur(let code, let message):
            "Le fournisseur a répondu une erreur\(code.map { " (\($0))" } ?? "") : \(message)"
        case .reponseInattendue:
            "Réponse inattendue du fournisseur."
        }
    }

    static func depuis(statut: Int, corps: Data) -> ErreurAssistant {
        switch statut {
        case 401, 403: .cleRefusee
        case 402: .creditEpuise
        case 404: .introuvable
        case 429: .limiteAtteinte
        default: .fournisseur(code: statut, message: message(dans: corps) ?? "réponse illisible")
        }
    }

    static func depuis(_ erreur: Error) -> ErreurAssistant {
        if let erreur = erreur as? ErreurAssistant { return erreur }
        guard let erreur = erreur as? URLError else {
            return .fournisseur(code: nil, message: erreur.localizedDescription)
        }
        switch erreur.code {
        case .appTransportSecurityRequiresSecureConnection:
            return .httpsRequis
        case .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .timedOut,
             .networkConnectionLost, .dnsLookupFailed, .internationalRoamingOff, .dataNotAllowed:
            return .injoignable(hote: erreur.failingURL?.host())
        default:
            return .fournisseur(code: nil, message: erreur.localizedDescription)
        }
    }

    /// Message d'erreur dans un corps JSON : `{"error": {"message": …}}` (OpenAI, DeepSeek),
    /// `[{"error": …}]` (Gemini), `{"message": …}` ou `{"detail": …}` (Mistral).
    static func message(dans corps: Data) -> String? {
        let json = try? JSONSerialization.jsonObject(with: corps)
        let objet = (json as? [String: Any]) ?? (json as? [[String: Any]])?.first
        if let objet {
            if let erreur = objet["error"] as? [String: Any], let message = erreur["message"] as? String {
                return message
            }
            if let message = (objet["message"] ?? objet["detail"] ?? objet["error"]) as? String {
                return message
            }
        }
        let texte = String(decoding: corps.prefix(300), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return texte.isEmpty ? nil : texte
    }
}
