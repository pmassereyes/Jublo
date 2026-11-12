import Foundation
import Testing
@testable import Jublo

/// Service de test : renvoie des morceaux fixes, ou une erreur, et retient ce qu'il a reçu.
final class ServiceTest: ServiceDiscussion, @unchecked Sendable {
    let morceaux: [String]
    let erreur: ErreurAssistant?
    /// Pause après le premier morceau, pour laisser le temps d'arrêter la réponse.
    let pause: Duration?

    private let verrou = NSLock()
    private var _recus: [[MessageIA]] = []

    init(_ morceaux: [String] = [], erreur: ErreurAssistant? = nil, pause: Duration? = nil) {
        self.morceaux = morceaux
        self.erreur = erreur
        self.pause = pause
    }

    var recus: [[MessageIA]] { verrou.withLock { _recus } }

    func repondre(a messages: [MessageIA]) -> AsyncThrowingStream<String, Error> {
        verrou.withLock { _recus.append(messages) }
        let (morceaux, erreur, pause) = (morceaux, erreur, pause)
        return AsyncThrowingStream { continuation in
            let tache = Task {
                for (index, morceau) in morceaux.enumerated() {
                    if index == 1, let pause { try? await Task.sleep(for: pause) }
                    if Task.isCancelled { break }
                    continuation.yield(morceau)
                }
                continuation.finish(throwing: erreur)
            }
            continuation.onTermination = { _ in tache.cancel() }
        }
    }
}

@MainActor
struct DiscussionTests {
    let discussion = Discussion()

    @Test func laReponseArriveParMorceaux() async {
        discussion.envoyer("Salut", consignes: "C", service: ServiceTest(["Bon", "jour"]))
        await discussion.attendreFin()

        #expect(discussion.messages.map(\.texte) == ["Salut", "Bonjour"])
        #expect(discussion.messages.map(\.auteur) == [.moi, .assistant])
        #expect(!discussion.enCours)
        #expect(discussion.erreur == nil)
    }

    @Test func lesConsignesEtLHistoriqueSontEnvoyes() async {
        let service = ServiceTest(["R1"])
        discussion.envoyer("Q1", consignes: "Consignes", service: service)
        await discussion.attendreFin()
        discussion.envoyer("Q2", consignes: "Consignes", service: service)
        await discussion.attendreFin()

        #expect(service.recus.last == [
            MessageIA(role: .systeme, contenu: "Consignes"),
            MessageIA(role: .utilisateur, contenu: "Q1"),
            MessageIA(role: .assistant, contenu: "R1"),
            MessageIA(role: .utilisateur, contenu: "Q2"),
        ])
    }

    @Test func uneErreurGardeLaQuestionEtOnPeutReessayer() async {
        discussion.envoyer("Q", consignes: "C", service: ServiceTest(erreur: .cleRefusee))
        await discussion.attendreFin()

        #expect(discussion.erreur == .cleRefusee)
        #expect(discussion.messages.map(\.texte) == ["Q"])

        discussion.reessayer(consignes: "C", service: ServiceTest(["OK"]))
        await discussion.attendreFin()

        #expect(discussion.erreur == nil)
        #expect(discussion.messages.map(\.texte) == ["Q", "OK"])
    }

    @Test func uneReponseVideEstSignalee() async {
        discussion.envoyer("Q", consignes: "C", service: ServiceTest([]))
        await discussion.attendreFin()

        #expect(discussion.erreur == .reponseInattendue)
        #expect(discussion.messages.map(\.texte) == ["Q"])
    }

    @Test func arreterGardeLeDebutDeLaReponse() async throws {
        discussion.envoyer("Q", consignes: "C", service: ServiceTest(["Un ", "deux"], pause: .seconds(30)))
        for _ in 0..<200 where discussion.messages.last?.texte.isEmpty != false {
            try await Task.sleep(for: .milliseconds(10))
        }

        discussion.arreter()
        await discussion.attendreFin()

        #expect(discussion.messages.map(\.texte) == ["Q", "Un "])
        #expect(discussion.erreur == nil)
        #expect(!discussion.enCours)
    }

    @Test func uneQuestionVideEstIgnoree() {
        discussion.envoyer("   ", consignes: "C", service: ServiceTest(["?"]))

        #expect(discussion.messages.isEmpty)
        #expect(!discussion.enCours)
    }
}

@MainActor
struct ContexteAssistantTests {
    let banc: Banc

    init() throws {
        banc = try Banc()
    }

    private func consignes(pour membre: Membre = .pablo) throws -> String {
        try ContexteAssistant.consignes(pour: membre, elements: banc.tous(ElementListe.self), maintenant: banc.maintenant)
    }

    @Test func lesConsignesDisentQuiParle() throws {
        let texte = try consignes(pour: .julie)

        #expect(texte.contains("Tu parles avec Julie"))
        #expect(texte.contains("Pablo est son ou sa partenaire"))
        #expect(texte.contains("Réponds en français"))
    }

    @Test func lesListesSontDetaillees() throws {
        _ = try banc.ajouter("Lait", a: .courses, par: .pablo)
        let pain = try banc.ajouter("Pain", a: .courses, par: .pablo)
        banc.depot.basculer(pain, par: .julie)
        banc.depot.ajouter("Céramique", a: .wishList, par: .pablo, pour: .julie)
        _ = try banc.ajouter("Vinyle", a: .wishList, par: .pablo)

        let texte = try consignes()

        #expect(texte.contains("## Courses\nÀ faire :\n- Lait (ajouté par Pablo)\nFait :\n- Pain (coché par Julie)"))
        #expect(texte.contains("## Pense-bête\n(vide)"))
        #expect(texte.contains("## Wish list de Pablo\nÀ faire :\n- Vinyle (ajouté par Pablo)"))
        #expect(texte.contains("## Wish list de Julie\nÀ faire :\n- Céramique (ajouté par Pablo)"))
    }

    @Test func laCorbeilleNEstPasEnvoyee() throws {
        let beurre = try banc.ajouter("Beurre")
        banc.depot.supprimer(beurre, par: .julie)

        #expect(try !consignes().contains("Beurre"))
    }

    @Test func lesListesTropLonguesSontTronquees() throws {
        for numero in 1...(ContexteAssistant.maxParSection + 5) {
            _ = try banc.ajouter("Article \(numero)")
        }

        #expect(try consignes().contains("… et 5 autres"))
    }
}

@MainActor
struct ConfigurationAssistantTests {
    let suite = "jublo-assistant-\(UUID().uuidString)"
    let trousseau = "jublo-tests-\(UUID().uuidString)"

    private func configuration() throws -> ConfigurationAssistant {
        ConfigurationAssistant(stockage: try #require(UserDefaults(suiteName: suite)), serviceTrousseau: trousseau)
    }

    private func nettoyer() {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        for fournisseur in Fournisseur.allCases {
            Trousseau.supprimer(fournisseur.rawValue, service: trousseau)
        }
    }

    @Test func parDefautMistralEnAttenteDeCle() throws {
        defer { nettoyer() }
        let reglages = try configuration()

        #expect(reglages.fournisseur == .mistral)
        #expect(reglages.adresse == Fournisseur.mistral.adresseParDefaut)
        #expect(reglages.manque == "Enregistre ta clé d'API Mistral.")
        #expect(reglages.service() == nil)
    }

    @Test func avecUneCleLAssistantEstPret() throws {
        defer { nettoyer() }
        let reglages = try configuration()

        try reglages.enregistrerCle("  cle-de-test \n")

        #expect(reglages.manque == nil)
        #expect(reglages.service() != nil)
        #expect(Trousseau.lire("mistral", service: trousseau) == "cle-de-test")
    }

    @Test func changerDeFournisseurRemetSesValeursParDefaut() throws {
        defer { nettoyer() }
        let reglages = try configuration()
        reglages.modele = "un-autre-modele"

        reglages.fournisseur = .deepseek

        #expect(reglages.adresse == Fournisseur.deepseek.adresseParDefaut)
        #expect(reglages.modele == Fournisseur.deepseek.modeleParDefaut)
    }

    @Test func chaqueFournisseurGardeSaCle() throws {
        defer { nettoyer() }
        let reglages = try configuration()
        try reglages.enregistrerCle("cle-mistral")

        reglages.fournisseur = .deepseek
        #expect(!reglages.cleEnregistree)

        reglages.fournisseur = .mistral
        #expect(reglages.cleEnregistree)

        reglages.supprimerCle()
        #expect(!reglages.cleEnregistree)
        #expect(Trousseau.lire("mistral", service: trousseau) == nil)
    }

    @Test func unServeurLocalSePasseDeCleMaisExigeHTTPS() throws {
        defer { nettoyer() }
        let reglages = try configuration()
        reglages.fournisseur = .autre
        #expect(reglages.manque == "Indique l'adresse de l'API (https://…).")

        reglages.adresse = "http://pc.exemple.ts.net:11434/v1"
        #expect(reglages.manque == ErreurAssistant.httpsRequis.errorDescription)

        reglages.adresse = "https://pc.exemple.ts.net/v1"
        #expect(reglages.manque == nil)
        #expect(reglages.destination == "pc.exemple.ts.net")
    }

    @Test func lesReglagesSontMemorises() throws {
        defer { nettoyer() }
        let reglages = try configuration()
        reglages.fournisseur = .gemini
        reglages.modele = "gemini-test"

        let relus = try configuration()

        #expect(relus.fournisseur == .gemini)
        #expect(relus.modele == "gemini-test")
    }
}
