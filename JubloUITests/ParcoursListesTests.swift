import XCTest

/// Parcours de l'onglet Listes jusqu'à la corbeille, sur une base vierge.
final class ParcoursListesTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testAjouterCocherSupprimerAnnulerPuisRestaurer() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-baseEnMemoire", "-onglet", "listes", "-liste", "courses", "-membreCourant", "pablo",
            "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR",
        ]
        app.launch()

        // Ajout
        let champ = app.textFields["Ajouter aux courses"]
        XCTAssertTrue(champ.waitForExistence(timeout: 5))
        champ.tap()
        champ.typeText("Bananes\n")
        XCTAssertTrue(app.buttons["Bananes"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons["Bananes"].value as? String, "À faire")
        capturer(app, "1-ajout")

        // Cochage
        app.buttons["Bananes"].tap()
        XCTAssertEqual(app.buttons["Bananes"].value as? String, "Fait")

        // Balayage vers la corbeille, puis « Annuler »
        supprimer(app.buttons["Bananes"], dans: app)
        let bandeau = app.staticTexts["« Bananes » mis à la corbeille"]
        XCTAssertTrue(bandeau.waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Bananes"].exists)
        capturer(app, "2-bandeau")
        app.buttons["Annuler"].tap()
        XCTAssertTrue(app.buttons["Bananes"].waitForExistence(timeout: 2))

        // Nouvelle suppression : le bandeau disparaît seul après quelques secondes
        supprimer(app.buttons["Bananes"], dans: app)
        XCTAssertTrue(bandeau.waitForExistence(timeout: 2))
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: bandeau)
        waitForExpectations(timeout: 8)

        // Corbeille : type, qui, quand, puis restauration
        app.buttons["Ouvrir la corbeille"].tap()
        let ligne = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Bananes")).firstMatch
        XCTAssertTrue(ligne.waitForExistence(timeout: 2))
        XCTAssertTrue(ligne.label.contains("Courses"))
        XCTAssertTrue(ligne.label.contains("Mis à la corbeille par toi"))
        capturer(app, "3-corbeille")
        app.buttons["Restaurer"].tap()
        XCTAssertTrue(app.staticTexts["La corbeille est vide"].waitForExistence(timeout: 2))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Bananes"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testLaWishListSeSepareEntreLesDeux() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-baseEnMemoire", "-onglet", "listes", "-liste", "wishList", "-membreCourant", "pablo",
            "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR",
        ]
        app.launch()

        // Mes envies
        let mesEnvies = app.textFields["Ajouter à mes envies"]
        XCTAssertTrue(mesEnvies.waitForExistence(timeout: 5))
        mesEnvies.tap()
        mesEnvies.typeText("Platine vinyle\n")
        XCTAssertTrue(app.buttons["Platine vinyle"].waitForExistence(timeout: 2))

        // Une idée pour Julie
        app.buttons["Pour Julie"].tap()
        let idee = app.textFields["Ajouter une idée pour Julie"]
        XCTAssertTrue(idee.waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Platine vinyle"].exists)
        idee.tap()
        idee.typeText("Cours de céramique\n")
        XCTAssertTrue(app.buttons["Cours de céramique"].waitForExistence(timeout: 2))
        capturer(app, "5-wishlist-julie")

        // Retour à mes envies
        app.buttons["Pour moi"].tap()
        XCTAssertTrue(app.buttons["Platine vinyle"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Cours de céramique"].exists)
        capturer(app, "6-wishlist-moi")
    }

    @MainActor
    private func supprimer(_ ligne: XCUIElement, dans app: XCUIApplication) {
        ligne.swipeLeft()
        // Un balayage court révèle le bouton ; un balayage complet supprime directement.
        let action = app.buttons["Corbeille"]
        if action.waitForExistence(timeout: 1) {
            action.tap()
        }
    }

    @MainActor
    private func capturer(_ app: XCUIApplication, _ nom: String) {
        let piece = XCTAttachment(screenshot: app.screenshot())
        piece.name = nom
        piece.lifetime = .keepAlways
        add(piece)
    }
}
