import Foundation

/// Fournisseurs d'IA préréglés. Tous parlent le format « chat completions » d'OpenAI :
/// passer de l'un à l'autre revient à changer l'adresse, le modèle et la clé.
enum Fournisseur: String, CaseIterable, Identifiable {
    case mistral
    case deepseek
    case gemini
    /// Ollama ou tout autre serveur compatible, par exemple sur un PC joint via Tailscale.
    case autre

    var id: Self { self }

    var nom: String {
        switch self {
        case .mistral: "Mistral"
        case .deepseek: "DeepSeek"
        case .gemini: "Gemini"
        case .autre: "Autre"
        }
    }

    /// Adresse de base de l'API, sans « /chat/completions ».
    var adresseParDefaut: String {
        switch self {
        case .mistral: "https://api.mistral.ai/v1"
        case .deepseek: "https://api.deepseek.com/v1"
        case .gemini: "https://generativelanguage.googleapis.com/v1beta/openai"
        case .autre: ""
        }
    }

    /// Modèle proposé. Les noms évoluent : ils restent modifiables dans les réglages.
    var modeleParDefaut: String {
        switch self {
        case .mistral: "mistral-small-latest"
        case .deepseek: "deepseek-chat"
        case .gemini: "gemini-2.5-flash"
        case .autre: "qwen2.5:3b"
        }
    }

    /// Page où créer une clé d'API.
    var consoleCles: URL? {
        switch self {
        case .mistral: URL(string: "https://console.mistral.ai/api-keys")
        case .deepseek: URL(string: "https://platform.deepseek.com/api_keys")
        case .gemini: URL(string: "https://aistudio.google.com/apikey")
        case .autre: nil
        }
    }

    /// Un serveur local (Ollama) n'exige pas de clé.
    var cleObligatoire: Bool { self != .autre }

    var description: String {
        switch self {
        case .mistral: "Hébergé en Europe, très bon en français."
        case .deepseek: "Le moins cher. Données stockées en Chine."
        case .gemini: "Google. L'offre gratuite peut servir à entraîner ses modèles."
        case .autre: "Ollama ou tout serveur compatible OpenAI, par exemple votre PC via Tailscale (adresse en https://)."
        }
    }
}
