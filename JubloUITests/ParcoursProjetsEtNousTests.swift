import XCTest

/// Parcours des fonctionnalités de la V4 sur une base vierge : agenda, cagnotte,
/// souhait du mois et compteur de retards.
final class ParcoursProjetsEtNousTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func lancer(onglet: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-baseEnMemoire", "-onglet", onglet, "-membreCourant", "pablo",
            "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR",
        ]
        app.launch()
        return app
    }

    @MainActor
    func testAjouterUnRendezVousPuisLeMettreALaCorbeille() throws {
        let app = lancer(onglet: "agenda")

        XCTAssertTrue(app.staticTexts["Rien de prévu"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Ajouter un rendez-vous"].tap()
        let titre = app.textFields["Titre (dîner, dentiste, week-end…)"]
        XCTAssertTrue(titre.waitForExistence(timeout: 2))
        titre.tap()
        titre.typeText("Cinéma")
        app.navigationBars.buttons["Ajouter"].tap()

        let ligne = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Cinéma")).firstMatch
        XCTAssertTrue(ligne.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Aujourd'hui"].exists || app.staticTexts["Demain"].exists)
        capturer(app, "7-agenda")

        ligne.swipeLeft()
        let corbeille = app.buttons["Corbeille"]
        if corbeille.waitForExistence(timeout: 1) {
            corbeille.tap()
        }
        XCTAssertTrue(app.staticTexts["« Cinéma » mis à la corbeille"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Rien de prévu"].exists)
    }

    @MainActor
    func testCreerUneCagnottePuisVerser() throws {
        let app = lancer(onglet: "projets")

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Cagnotte")).firstMatch.tap()
        app.navigationBars.buttons["Créer une cagnotte"].tap()
        let nom = app.textFields["Nom (Lisbonne, canapé…)"]
        XCTAssertTrue(nom.waitForExistence(timeout: 2))
        nom.tap()
        nom.typeText("Lisbonne")
        let objectif = app.textFields["Objectif (facultatif)"]
        objectif.tap()
        objectif.typeText("500")
        app.navigationBars.buttons["Créer"].tap()

        let ligne = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Lisbonne")).firstMatch
        XCTAssertTrue(ligne.waitForExistence(timeout: 2))
        ligne.tap()
        app.buttons["Verser"].tap()
        let montant = app.textFields["Montant"]
        XCTAssertTrue(montant.waitForExistence(timeout: 2))
        montant.tap()
        montant.typeText("120,5")
        app.navigationBars.buttons["Verser"].tap()

        let solde = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "120,50")).firstMatch
        XCTAssertTrue(solde.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Encore 379,50")).firstMatch.exists)
        capturer(app, "8-cagnotte")
    }

    @MainActor
    func testConfierUnSouhaitEtNoterUnRetard() throws {
        let app = lancer(onglet: "nous")

        let champ = app.textFields["…m'emmènes au cinéma"]
        XCTAssertTrue(champ.waitForExistence(timeout: 5))
        champ.tap()
        champ.typeText("m'emmènes au cinéma")
        app.buttons["Confier"].tap()
        XCTAssertTrue(app.staticTexts["J'aimerais que tu m'emmènes au cinéma"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Julie n'a encore rien demandé ce mois-ci."].exists)

        let noter = app.buttons["Noter un retard"]
        app.swipeUp()
        XCTAssertTrue(noter.waitForExistence(timeout: 2))
        noter.tap()
        XCTAssertTrue(app.navigationBars["Noter un retard"].waitForExistence(timeout: 2))
        app.navigationBars.buttons["Noter"].tap()

        // Par défaut, le retard est celui de l'autre : 10 minutes pour Julie.
        let bilan = app.staticTexts["retard · 10 min"]
        XCTAssertTrue(bilan.waitForExistence(timeout: 2))
        capturer(app, "9-nous")
    }

    @MainActor
    private func capturer(_ app: XCUIApplication, _ nom: String) {
        let piece = XCTAttachment(screenshot: app.screenshot())
        piece.name = nom
        piece.lifetime = .keepAlways
        add(piece)
    }
}
