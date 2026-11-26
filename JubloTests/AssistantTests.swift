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

    private let calendrier: Calendar = {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = .current
        calendrier.locale = Locale(identifier: "fr_FR")
        return calendrier
    }()

    private func consignes(pour membre: Membre = .pablo) throws -> String {
        ContexteAssistant.consignes(
            pour: membre, donnees: .lire(dans: banc.conteneur.mainContext),
            maintenant: banc.maintenant, calendrier: calendrier
        )
    }

    /// Une date de novembre 2026 (fuseau de l'appareil, comme les formats de l'app).
    private func date(_ jour: Int, _ heure: Int = 0, _ minute: Int = 0, mois: Int = 11) throws -> Date {
        try #require(calendrier.date(from: DateComponents(year: 2026, month: mois, day: jour, hour: heure, minute: minute)))
    }

    @Test func lAgendaEnvoieLAVenirEtLeMoisPasse() throws {
        banc.maintenant = try date(24, 11)
        _ = banc.depot.ajouterEvenement(
            "Dîner chez Marc", debut: try date(25, 20), fin: try date(25, 22), lieu: "Belleville", pour: .julie, par: .pablo
        )
        _ = banc.depot.ajouterEvenement("Week-end à Lyon", debut: try date(28), fin: try date(29), journeeEntiere: true, par: .julie)
        _ = banc.depot.ajouterEvenement("Dentiste", debut: try date(20, 9), par: .pablo)
        _ = banc.depot.ajouterEvenement("Vieux rendez-vous", debut: try date(1, 9, mois: 9), par: .pablo)
        let annule = try #require(banc.depot.ajouterEvenement("Annulé", debut: try date(26, 9), par: .pablo))
        banc.depot.supprimer(annule, par: .pablo)

        let texte = try consignes()

        #expect(texte.contains("""
            ## Agenda : à venir
            - mercredi 25 novembre 2026 à 20:00–22:00 : Dîner chez Marc (pour Julie ; lieu : Belleville)
            - du samedi 28 novembre 2026 au dimanche 29 novembre 2026 : Week-end à Lyon (pour vous deux)
            """))
        #expect(texte.contains("""
            ## Agenda : passé (30 derniers jours)
            - vendredi 20 novembre 2026 à 09:00 : Dentiste (pour vous deux)
            """))
        #expect(!texte.contains("Vieux rendez-vous"))
        #expect(!texte.contains("Annulé"))
    }

    @Test func lesProjetsSontEnvoyes() throws {
        let lisbonne = banc.depot.creerCagnotte("Lisbonne", objectifCentimes: 50_000, par: .pablo)
        banc.depot.verser(12_050, dans: lisbonne, par: .pablo)
        banc.depot.verser(3_000, dans: lisbonne, par: .julie)
        banc.depot.annuler(banc.depot.verser(10_000, dans: lisbonne, par: .julie), par: .julie)

        let corse = try #require(banc.depot.ajouterDestination("La Corse", quand: "été 2027", budgetCentimes: 120_000, par: .julie))
        banc.depot.donnerAvis(5, sur: corse, par: .pablo)
        let rome = try #require(banc.depot.ajouterDestination("Rome", par: .pablo))
        banc.depot.changerStatut(.reservee, de: rome)

        _ = banc.depot.ajouterSortie("Le Comptoir", categorie: .restaurant, lieu: "Belleville", par: .julie)
        let expo = try #require(banc.depot.ajouterSortie("Expo Hockney", categorie: .expo, par: .pablo))
        banc.depot.basculerTestee(expo)
        banc.depot.donnerAvis(4, sur: expo, par: .julie)

        let texte = try consignes()
        let m = Formats.montant

        #expect(texte.contains(
            "- Lisbonne : \(m(15_050)) de côté ; objectif \(m(50_000)) ; versé par Pablo : \(m(12_050)) ; versé par Julie : \(m(3_000))"
        ))
        #expect(texte.contains("""
            ## Vacances envisagées
            - La Corse (envisagée ; quand : été 2027 ; budget \(m(120_000)) ; envie : Pablo 5/5, Julie pas encore donné)
            - Rome (réservée ; envie : Pablo pas encore donné, Julie pas encore donné)
            """))
        #expect(texte.contains("## Sorties à tester\n- Le Comptoir (restaurant ; repérée par Julie ; lieu : Belleville)"))
        #expect(texte.contains("## Sorties déjà testées\n- Expo Hockney (expo ; testée le "))
        #expect(texte.contains("avis : Pablo pas encore donné, Julie 4/5)"))
    }

    @Test func lesSouhaitsDuMoisSontEnvoyes() throws {
        banc.maintenant = try date(5, 10, mois: 10)
        let ancien = try #require(banc.depot.confierSouhait("me fasses un gâteau", par: .julie))
        banc.maintenant = try date(24, 11)
        banc.depot.basculerFait(ancien)
        _ = banc.depot.confierSouhait("m'emmènes au cinéma", par: .pablo)

        let texte = try consignes()

        #expect(texte.contains("""
            ## Ce mois-ci, j'aimerais que tu… (Novembre 2026)
            - Pablo demande à Julie : « J'aimerais que tu m'emmènes au cinéma » (pas encore fait)
            """))
        #expect(texte.contains(
            "- Julie demande à Pablo : « J'aimerais que tu me fasses un gâteau » (fait le mardi 24 novembre 2026) [Octobre 2026]"
        ))
    }

    @Test func sansDonneesChaqueRubriqueLeDit() throws {
        let texte = try consignes()

        #expect(texte.contains("## Agenda : à venir\n(rien de prévu)"))
        #expect(texte.contains("## Cagnottes\n(aucune)"))
        #expect(texte.contains("## Vacances envisagées\n(aucune idée)"))
        #expect(texte.contains("## Sorties à tester\n(aucune)"))
        #expect(texte.contains("(aucune demande ce mois-ci)"))
        #expect(!texte.contains("Agenda : passé"))
    }

    @Test func lesProjetsALaCorbeilleNeSontPasEnvoyes() throws {
        let rome = try #require(banc.depot.ajouterDestination("Rome", par: .pablo))
        banc.depot.supprimer(rome, par: .julie)
        let comptoir = try #require(banc.depot.ajouterSortie("Le Comptoir", categorie: .restaurant, par: .julie))
        banc.depot.supprimer(comptoir, par: .pablo)
        let cagnotte = banc.depot.creerCagnotte("Canapé", par: .pablo)
        banc.depot.supprimer(cagnotte, par: .pablo)

        let texte = try consignes()

        #expect(!texte.contains("Rome"))
        #expect(!texte.contains("Le Comptoir"))
        #expect(!texte.contains("Canapé"))
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
        let casque = try banc.ajouter("Casque", a: .wishList, par: .pablo)
        banc.depot.basculer(casque, par: .julie)

        let texte = try consignes()

        #expect(texte.contains("## Courses\nÀ faire :\n- Lait (ajouté par Pablo)\nFait :\n- Pain (coché par Julie)"))
        #expect(texte.contains("## Pense-bête\n(vide)"))
        #expect(texte.contains("## Wish list de Pablo\nÀ offrir :\n- Vinyle (ajouté par Pablo)\nOffert :\n- Casque (offert par Julie)"))
        #expect(texte.contains("## Wish list de Julie\nÀ offrir :\n- Céramique (ajouté par Pablo)"))
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
