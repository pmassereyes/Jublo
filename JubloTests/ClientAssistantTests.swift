import Foundation
import Testing
@testable import Jublo

/// Réponses HTTP simulées. Chaque test reçoit un hôte unique, les tests peuvent donc
/// tourner en parallèle.
final class ProtocoleSimule: URLProtocol, @unchecked Sendable {
    enum Reponse: Sendable {
        case http(statut: Int, corps: String)
        case echec(URLError.Code)
    }

    private static let verrou = NSLock()
    nonisolated(unsafe) private static var reponses: [String: Reponse] = [:]

    static func session(_ reponse: Reponse) -> (session: URLSession, adresse: URL) {
        let hote = "test-\(UUID().uuidString.lowercased()).example"
        verrou.withLock { reponses[hote] = reponse }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ProtocoleSimule.self]
        return (URLSession(configuration: configuration), URL(string: "https://\(hote)/v1")!)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let url = request.url else { return }
        let reponse = Self.verrou.withLock { Self.reponses[url.host() ?? ""] }
        switch reponse {
        case .http(let statut, let corps):
            let http = HTTPURLResponse(url: url, statusCode: statut, httpVersion: "HTTP/1.1", headerFields: nil)!
            client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(corps.utf8))
            client?.urlProtocolDidFinishLoading(self)
        case .echec(let code):
            client?.urlProtocol(self, didFailWithError: URLError(code, userInfo: [NSURLErrorFailingURLErrorKey: url]))
        case nil:
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
        }
    }
}

func collecter(_ flux: AsyncThrowingStream<String, Error>) async throws -> String {
    var texte = ""
    for try await morceau in flux {
        texte += morceau
    }
    return texte
}

struct FluxSSETests {
    @Test func unMorceauDeTexte() throws {
        #expect(try FluxSSE.evenement(#"data: {"choices":[{"index":0,"delta":{"content":"Bon"}}]}"#) == .texte("Bon"))
        #expect(try FluxSSE.evenement(#"data:{"choices":[{"delta":{"content":"jour"}}]}"#) == .texte("jour"))
    }

    @Test func laFinDuFlux() throws {
        #expect(try FluxSSE.evenement("data: [DONE]") == .fin)
    }

    @Test(arguments: [
        "",
        ": keep-alive",
        "event: message",
        #"data: {"choices":[{"delta":{"role":"assistant"}}]}"#,
        #"data: {"choices":[{"delta":{"content":[{"type":"thinking"}]}}]}"#,
        "data: pas du json",
    ])
    func lesLignesSansTexteSontIgnorees(ligne: String) throws {
        #expect(try FluxSSE.evenement(ligne) == nil)
    }

    @Test func uneErreurDansLeFluxEstRemontee() {
        #expect(throws: ErreurAssistant.fournisseur(code: nil, message: "surcharge")) {
            try FluxSSE.evenement(#"data: {"error":{"message":"surcharge"}}"#)
        }
    }
}

struct ClientCompatibleOpenAITests {
    let messages = [
        MessageIA(role: .systeme, contenu: "Consignes"),
        MessageIA(role: .utilisateur, contenu: "Salut"),
    ]

    private func client(_ adresse: URL, cle: String? = "cle", session: URLSession = .shared) -> ClientCompatibleOpenAI {
        ClientCompatibleOpenAI(parametres: ParametresConnexion(adresse: adresse, modele: "mistral-small-latest", cle: cle), session: session)
    }

    @Test(arguments: ["https://api.exemple.fr/v1", "https://api.exemple.fr/v1/"])
    func laRequeteVisLePointDAccesDesDiscussions(adresse: String) throws {
        let requete = try client(URL(string: adresse)!).requete(pour: messages)

        #expect(requete.url?.absoluteString == "https://api.exemple.fr/v1/chat/completions")
        #expect(requete.httpMethod == "POST")
        #expect(requete.value(forHTTPHeaderField: "Authorization") == "Bearer cle")
    }

    @Test func sansClePasDEnTeteDAutorisation() throws {
        let requete = try client(URL(string: "https://pc.exemple.ts.net/v1")!, cle: nil).requete(pour: messages)

        #expect(requete.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func leCorpsSuitLeFormatOpenAI() throws {
        let requete = try client(URL(string: "https://api.exemple.fr/v1")!).requete(pour: messages)
        let donnees = try #require(requete.httpBody)
        let corps = try #require(JSONSerialization.jsonObject(with: donnees) as? [String: Any])

        #expect(corps["model"] as? String == "mistral-small-latest")
        #expect(corps["stream"] as? Bool == true)
        #expect(corps["messages"] as? [[String: String]] == [
            ["role": "system", "content": "Consignes"],
            ["role": "user", "content": "Salut"],
        ])
    }

    @Test func laReponseArriveMorceauParMorceau() async throws {
        let flux = """
        data: {"choices":[{"delta":{"role":"assistant"}}]}

        data: {"choices":[{"delta":{"content":"Bon"}}]}

        : keep-alive

        data: {"choices":[{"delta":{"content":"jour à toi"}}]}

        data: [DONE]

        """
        let (session, adresse) = ProtocoleSimule.session(.http(statut: 200, corps: flux))

        #expect(try await collecter(client(adresse, session: session).repondre(a: messages)) == "Bonjour à toi")
    }

    @Test(arguments: [
        (401, ErreurAssistant.cleRefusee),
        (403, ErreurAssistant.cleRefusee),
        (402, ErreurAssistant.creditEpuise),
        (404, ErreurAssistant.introuvable),
        (429, ErreurAssistant.limiteAtteinte),
    ])
    func lesCodesHTTPDeviennentDesErreursClaires(statut: Int, attendue: ErreurAssistant) async {
        let (session, adresse) = ProtocoleSimule.session(.http(statut: statut, corps: "{}"))

        await #expect(throws: attendue) {
            try await collecter(client(adresse, session: session).repondre(a: messages))
        }
    }

    @Test func uneErreurServeurGardeLeMessageDuFournisseur() async {
        let (session, adresse) = ProtocoleSimule.session(.http(statut: 500, corps: #"{"error":{"message":"modèle surchargé"}}"#))

        await #expect(throws: ErreurAssistant.fournisseur(code: 500, message: "modèle surchargé")) {
            try await collecter(client(adresse, session: session).repondre(a: messages))
        }
    }

    @Test func unServeurInjoignableEstSignale() async {
        let (session, adresse) = ProtocoleSimule.session(.echec(.cannotConnectToHost))

        await #expect(throws: ErreurAssistant.injoignable(hote: adresse.host())) {
            try await collecter(client(adresse, session: session).repondre(a: messages))
        }
    }
}

struct ErreurAssistantTests {
    @Test(arguments: [
        (#"{"error":{"message":"clé invalide","type":"auth"}}"#, "clé invalide"),
        (#"[{"error":{"code":400,"message":"modèle inconnu"}}]"#, "modèle inconnu"),
        (#"{"object":"error","message":"quota dépassé"}"#, "quota dépassé"),
        (#"{"detail":"non autorisé"}"#, "non autorisé"),
        ("Bad Gateway", "Bad Gateway"),
    ])
    func leMessageDuFournisseurEstRetrouve(corps: String, message: String) {
        #expect(ErreurAssistant.message(dans: Data(corps.utf8)) == message)
    }

    @Test func unCorpsVideNeDonneAucunMessage() {
        #expect(ErreurAssistant.message(dans: Data()) == nil)
    }

    @Test func leHTTPNonChiffreEstExplique() {
        #expect(ErreurAssistant.depuis(URLError(.appTransportSecurityRequiresSecureConnection)) == .httpsRequis)
    }
}
