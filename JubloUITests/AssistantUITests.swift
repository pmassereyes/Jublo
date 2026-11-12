import XCTest

/// Écran de l'assistant, en mode simulé (sans fournisseur).
final class AssistantUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func lancer(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments + [
            "-baseEnMemoire", "-exemples", "-onglet", "accueil", "-membreCourant", "pablo",
            "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR",
        ]
        app.launch()
        app.buttons["Demander à l'assistant"].tap()
        return app
    }

    private func texte(contenant fragment: String, dans app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", fragment))
    }

    @MainActor
    func testUneQuestionObtientUneReponseAuFilDeLEau() throws {
        let app = lancer(["-assistantSimule"])

        // Question suggérée
        let suggestion = app.buttons["Qu'est-ce qu'il reste à acheter ?"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 3))
        suggestion.tap()
        XCTAssertTrue(texte(contenant: "Réponse simulée", dans: app).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Envoyer"].waitForExistence(timeout: 10))
        XCTAssertTrue(texte(contenant: "éléments dans vos listes", dans: app).firstMatch.exists)

        // Question tapée
        let champ = app.descendants(matching: .any)["saisieAssistant"].firstMatch
        champ.tap()
        champ.typeText("Et le pense-bête ?")
        app.buttons["Envoyer"].tap()
        XCTAssertTrue(texte(contenant: "« Et le pense-bête ? »", dans: app).firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Envoyer"].waitForExistence(timeout: 10))
        capturer(app, "assistant-discussion")

        // Réglages
        app.buttons["Réglages de l'assistant"].tap()
        XCTAssertTrue(texte(contenant: "Mode simulé", dans: app).firstMatch.waitForExistence(timeout: 3))
        capturer(app, "assistant-reglages")
    }

    @MainActor
    func testSansFournisseurLAssistantInviteAleConfigurer() throws {
        let app = lancer(["-assistant.fournisseur", "autre", "-assistant.adresse", ""])

        XCTAssertTrue(app.buttons["Ouvrir les réglages"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Qu'est-ce qu'il reste à acheter ?"].exists)
        capturer(app, "assistant-a-configurer")
    }

    @MainActor
    private func capturer(_ app: XCUIApplication, _ nom: String) {
        let piece = XCTAttachment(screenshot: app.screenshot())
        piece.name = nom
        piece.lifetime = .keepAlways
        add(piece)
    }
}
