import XCTest

/// Rappels du pense-bête et de l'agenda, et réglages des notifications, sur une base vierge.
/// Aucune notification réelle : la base en mémoire coupe le centre de notifications.
final class ParcoursRappelsTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func lancer(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-baseEnMemoire", "-membreCourant", "pablo", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
            + arguments
        app.launch()
        return app
    }

    @MainActor
    func testProgrammerPuisRetirerUnRappelDuPenseBete() throws {
        let app = lancer(["-onglet", "listes", "-liste", "penseBete"])

        let champ = app.textFields["Ajouter au pense-bête"]
        XCTAssertTrue(champ.waitForExistence(timeout: 5))
        champ.tap()
        champ.typeText("Appeler le plombier\n")
        let ligne = app.buttons["Appeler le plombier"]
        XCTAssertTrue(ligne.waitForExistence(timeout: 2))

        // Balayage vers la droite : « Rappel »
        ligne.swipeRight()
        app.buttons["Rappel"].tap()
        XCTAssertTrue(app.navigationBars["Nouveau rappel"].waitForExistence(timeout: 2))
        capturer(app, "10-rappel")
        app.navigationBars.buttons["Enregistrer"].tap()
        XCTAssertTrue(ligne.waitForExistence(timeout: 2))
        capturer(app, "11-pense-bete-rappel")

        // Le menu de la ligne propose maintenant de modifier le rappel, puis de le retirer
        ligne.press(forDuration: 1.2)
        let modifier = app.buttons["Modifier le rappel…"]
        XCTAssertTrue(modifier.waitForExistence(timeout: 2))
        modifier.tap()
        XCTAssertTrue(app.navigationBars["Rappel"].waitForExistence(timeout: 2))
        app.buttons["Retirer le rappel"].tap()

        XCTAssertTrue(ligne.waitForExistence(timeout: 2))
        ligne.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Me le rappeler…"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testUnRendezVousAvecRappel() throws {
        let app = lancer(["-onglet", "agenda"])

        XCTAssertTrue(app.staticTexts["Rien de prévu"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Ajouter un rendez-vous"].tap()
        let titre = app.textFields["Titre (dîner, dentiste, week-end…)"]
        XCTAssertTrue(titre.waitForExistence(timeout: 2))
        titre.tap()
        titre.typeText("Dentiste\n")

        // Le sélecteur s'annonce « Rappel, Aucun »
        let rappel = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Rappel,")).firstMatch
        XCTAssertTrue(rappel.waitForExistence(timeout: 2))
        rappel.tap()
        let quinzeMinutes = app.buttons["15 min avant"]
        XCTAssertTrue(quinzeMinutes.waitForExistence(timeout: 2))
        quinzeMinutes.tap()
        XCTAssertTrue(app.staticTexts["Le rappel sonnera sur vos deux iPhones."].waitForExistence(timeout: 2))
        XCTAssertTrue(rappel.label.contains("15 min avant"))
        capturer(app, "12-rendez-vous-rappel")
        app.navigationBars.buttons["Ajouter"].tap()

        let ligne = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Dentiste")).firstMatch
        XCTAssertTrue(ligne.waitForExistence(timeout: 2))
        XCTAssertTrue(ligne.label.contains("Avec rappel"))
    }

    @MainActor
    func testLesNotificationsSeReglentDansNous() throws {
        let app = lancer(["-onglet", "nous"])

        let listes = app.switches["Quand Julie modifie les listes"]
        for _ in 0..<5 where !listes.exists {
            app.swipeUp()
        }
        XCTAssertTrue(listes.waitForExistence(timeout: 2))
        XCTAssertTrue(app.switches["Quand Julie modifie l'agenda"].exists)
        capturer(app, "13-notifications")
    }

    @MainActor
    private func capturer(_ app: XCUIApplication, _ nom: String) {
        let piece = XCTAttachment(screenshot: app.screenshot())
        piece.name = nom
        piece.lifetime = .keepAlways
        add(piece)
    }
}
