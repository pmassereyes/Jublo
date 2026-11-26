import CloudKit
import Foundation
import SwiftData
import Testing
@testable import Jublo

/// Centre de notifications factice : retient ce qui est programmé ou envoyé.
@MainActor
final class CentreFactice: CentreNotifications {
    var statutCourant = StatutNotifications.autorisees
    var demandes = 0
    /// Rappels programmés, par identifiant.
    var programmees: [String: NotificationPrevue] = [:]
    /// Annonces envoyées tout de suite.
    var envoyees: [NotificationPrevue] = []

    func statut() async -> StatutNotifications { statutCourant }

    func demanderAutorisation() async -> Bool {
        demandes += 1
        statutCourant = .autorisees
        return true
    }

    func identifiantsEnAttente() async -> [String] { Array(programmees.keys) }

    func programmer(_ notification: NotificationPrevue) async {
        if notification.date == nil {
            envoyees.append(notification)
        } else {
            programmees[notification.identifiant] = notification
        }
    }

    func retirer(_ identifiants: [String]) {
        for identifiant in identifiants {
            programmees[identifiant] = nil
        }
    }
}

/// Ce que l'iPhone de Pablo voit changer quand celui de Julie lui envoie ses enregistrements.
@MainActor
struct ChangementsRecusTests {
    let pablo: Banc
    let julie: Banc
    let zone = CKRecordZone.ID(zoneName: "Jublo", ownerName: CKCurrentUserDefaultName)

    init() throws {
        pablo = try Banc()
        julie = try Banc()
    }

    /// Envoie des modèles de Julie chez Pablo, comme CloudKit.
    @discardableResult
    private func recevoir(_ modeles: [any Synchronisable], enAttente: Set<String> = []) -> [ChangementRecu] {
        let depart = MiroirLocal(contexte: julie.conteneur.mainContext)
        let enregistrements = modeles.map { depart.enregistrement(pour: $0, zone: zone) }
        return MiroirLocal(contexte: pablo.conteneur.mainContext).appliquer(enregistrements, enAttente: enAttente)
    }

    @Test func unAjoutDeLAutreEstSignale() throws {
        let lait = try julie.ajouter("Lait", a: .courses, par: .julie)

        let changements = recevoir([lait])

        #expect(changements == [ChangementRecu(
            nature: .ajout, sujet: .liste(.courses, pour: nil), titre: "Lait", par: .julie, le: lait.modifieLe
        )])
    }

    @Test func uneRelectureNeSignaleRien() throws {
        let lait = try julie.ajouter("Lait", a: .courses, par: .julie)
        recevoir([lait])

        #expect(recevoir([lait]).isEmpty)
    }

    @Test func unElementCocheEstSignaleAvecQuiLACoche() throws {
        let lait = try julie.ajouter("Lait", a: .courses, par: .pablo)
        recevoir([lait])
        julie.avancer(heures: 1)
        julie.depot.basculer(lait, par: .julie)

        let changements = recevoir([lait])

        #expect(changements.map(\.nature) == [.coche])
        #expect(changements.first?.par == .julie)
    }

    @Test func unElementMisALaCorbeilleEstSignale() throws {
        let lait = try julie.ajouter("Lait", a: .courses, par: .pablo)
        recevoir([lait])
        julie.avancer(heures: 1)
        julie.depot.supprimer(lait, par: .julie)

        #expect(recevoir([lait]).map(\.nature) == [.suppression])
    }

    @Test func unElementDejaALaCorbeilleNEstPasUnAjout() throws {
        let lait = try julie.ajouter("Lait", a: .courses, par: .julie)
        julie.depot.supprimer(lait, par: .julie)

        #expect(recevoir([lait]).isEmpty)
    }

    @Test func unRendezVousModifieEstSignale() throws {
        let dentiste = try #require(julie.depot.ajouterEvenement("Dentiste", debut: julie.maintenant, par: .pablo))
        recevoir([dentiste])
        julie.avancer(heures: 1)
        julie.depot.modifier(dentiste) { $0.lieu = "Cabinet" }

        let changements = recevoir([dentiste])

        #expect(changements.map(\.nature) == [.modification])
        #expect(changements.first?.par == nil)
    }

    @Test func unRappelAjouteSeulNEstPasSignale() throws {
        let dentiste = try #require(julie.depot.ajouterEvenement("Dentiste", debut: julie.maintenant, par: .pablo))
        recevoir([dentiste])
        julie.avancer(heures: 1)
        julie.depot.modifier(dentiste) { $0.rappelBrut = RappelEvenement.uneHeure.rawValue }

        #expect(recevoir([dentiste]).isEmpty)
        let recu = try #require(try pablo.tous(Evenement.self).first)
        #expect(recu.rappel == .uneHeure)
    }

    @Test func unChangementLocalPlusRecentEnAttenteNEstPasSignale() throws {
        let lait = try julie.ajouter("Lait", a: .courses, par: .pablo)
        recevoir([lait])
        let local = try #require(try pablo.tous(ElementListe.self).first)
        julie.avancer(heures: 1)
        julie.depot.basculer(lait, par: .julie)
        pablo.avancer(heures: 2)
        pablo.depot.supprimer(local, par: .pablo)

        #expect(recevoir([lait], enAttente: [lait.id.uuidString]).isEmpty)
    }

    @Test func lesAutresTypesNeSontPasSignales() throws {
        let sortie = try #require(julie.depot.ajouterSortie("Le Comptoir", categorie: .restaurant, par: .julie))

        #expect(recevoir([sortie]).isEmpty)
    }
}

@MainActor
struct AnnoncesTests {
    let maintenant = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func changement(
        _ nature: ChangementRecu.Nature, _ titre: String, dans type: TypeListe = .courses,
        pour destinataire: Membre? = nil, par auteur: Membre? = .julie, il yA: TimeInterval = 60
    ) -> ChangementRecu {
        ChangementRecu(nature: nature, sujet: .liste(type, pour: destinataire), titre: titre, par: auteur, le: maintenant - yA)
    }

    private func rendezVous(_ nature: ChangementRecu.Nature, _ titre: String, debut: Date, par auteur: Membre? = nil) -> ChangementRecu {
        ChangementRecu(nature: nature, sujet: .agenda(debut: debut, fin: debut, journeeEntiere: false), titre: titre, par: auteur, le: maintenant)
    }

    private func annonces(_ changements: [ChangementRecu], listes: Bool = true, agenda: Bool = true) -> [NotificationPrevue] {
        Annonces.prevues(changements, pour: .pablo, listes: listes, agenda: agenda, maintenant: maintenant)
    }

    @Test func unAjoutDeLAutreEstAnnonce() throws {
        let annonce = try #require(annonces([changement(.ajout, "Lait")]).first)

        #expect(annonce.titre == "Courses")
        #expect(annonce.corps == "Julie a ajouté « Lait »")
        #expect(annonce.date == nil)
        #expect(annonce.ouvrir == ["onglet": "listes", "liste": "courses"])
        #expect(annonce.identifiant.hasPrefix(Annonces.prefixe))
    }

    @Test func plusieursChangementsSontRegroupes() {
        let resultat = annonces([
            changement(.ajout, "Lait"), changement(.ajout, "Œufs"), changement(.coche, "Pain"),
            changement(.ajout, "Pain"), changement(.ajout, "Beurre"), changement(.ajout, "Sel"),
        ])

        #expect(resultat.map(\.corps) == [
            "Julie a ajouté 5 éléments : Lait, Œufs, Pain et 2 autres",
            "Julie a coché « Pain »",
        ])
    }

    @Test func sesPropresChangementsNeSontPasAnnonces() {
        #expect(annonces([changement(.ajout, "Lait", par: .pablo)]).isEmpty)
    }

    @Test func unChangementAncienNEstPasAnnonce() {
        #expect(annonces([changement(.ajout, "Lait", il: Annonces.fraicheur + 60)]).isEmpty)
    }

    @Test func lesSuppressionsDansLesListesNeSontPasAnnoncees() {
        #expect(annonces([changement(.suppression, "Lait")]).isEmpty)
    }

    @Test func laWishListNAnnonceQueLesEnviesDeLAutre() {
        let resultat = annonces([
            changement(.ajout, "Plaid", dans: .wishList, pour: .julie),
            changement(.ajout, "Platine", dans: .wishList, pour: .pablo),
            changement(.coche, "Casque", dans: .wishList, pour: .pablo),
        ])

        #expect(resultat.map(\.corps) == ["Julie a ajouté « Plaid » à ses envies"])
        #expect(resultat.first?.titre == "Wish list")
    }

    @Test func lesPreferencesCoupentChaqueRubrique() {
        let rdv = rendezVous(.ajout, "Dentiste", debut: maintenant + 3_600, par: .julie)

        #expect(annonces([changement(.ajout, "Lait"), rdv], listes: false).map(\.titre) == ["Agenda"])
        #expect(annonces([changement(.ajout, "Lait"), rdv], agenda: false).map(\.titre) == ["Courses"])
    }

    @Test func unRendezVousAjouteDitQuand() throws {
        let debut = maintenant + 3_600
        let annonce = try #require(annonces([rendezVous(.ajout, "Dentiste", debut: debut, par: .julie)]).first)

        #expect(annonce.titre == "Agenda")
        #expect(annonce.corps == "Julie a ajouté « Dentiste » · \(Formats.jourProche(debut, maintenant: maintenant)) à \(Formats.heure(debut))")
        #expect(annonce.ouvrir == ["onglet": "agenda"])
    }

    @Test func uneModificationSansAuteurVientDeLAutre() throws {
        let annonce = try #require(annonces([rendezVous(.modification, "Dentiste", debut: maintenant + 3_600)]).first)

        #expect(annonce.corps.hasPrefix("Julie a modifié « Dentiste »"))
    }

    @Test func unRendezVousRetireEstAnnonce() {
        #expect(annonces([rendezVous(.suppression, "Dentiste", debut: maintenant + 3_600, par: .julie)]).map(\.corps)
            == ["Julie a retiré « Dentiste » de l'agenda"])
    }

    @Test func unRendezVousPasseNEstPasAnnonce() {
        #expect(annonces([rendezVous(.suppression, "Dentiste", debut: maintenant - 3 * 86_400, par: .julie)]).isEmpty)
    }

    @Test func lEnumerationResteCourte() {
        #expect(Annonces.enumeration(["A"]) == "A")
        #expect(Annonces.enumeration(["A", "B"]) == "A et B")
        #expect(Annonces.enumeration(["A", "B", "C"]) == "A, B et C")
        #expect(Annonces.enumeration(["A", "B", "C", "D", "E"]) == "A, B, C et 2 autres")
    }
}

@MainActor
struct RappelsProgrammesTests {
    let banc: Banc
    let centre = CentreFactice()
    let identite: Identite
    let notificateur: Notificateur

    init() throws {
        banc = try Banc()
        let stockage = try #require(UserDefaults(suiteName: "tests-notifications-\(UUID().uuidString)"))
        identite = Identite(stockage: stockage)
        identite.membre = .pablo
        let banc = banc
        notificateur = Notificateur(
            contexte: banc.conteneur.mainContext, identite: identite, centre: centre,
            stockage: stockage, horloge: { banc.maintenant }
        )
    }

    private func rappels() -> [NotificationPrevue] {
        centre.programmees.values.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
    }

    @Test func lePenseBeteSonneTantQuIlNEstPasFait() async throws {
        let plombier = try banc.ajouter("Appeler le plombier", a: .penseBete, par: .julie)
        let date = banc.maintenant.addingTimeInterval(3_600)
        banc.depot.programmerRappel(date, pour: plombier)
        await notificateur.replanifier()

        let rappel = try #require(rappels().first)
        #expect(rappel.identifiant == Rappels.prefixe + plombier.id.uuidString)
        #expect(rappel.titre == "Pense-bête")
        #expect(rappel.corps == "Appeler le plombier")
        #expect(rappel.date == date)

        banc.depot.basculer(plombier, par: .julie)
        await notificateur.replanifier()
        #expect(rappels().isEmpty)
    }

    @Test func unRappelPasseOuALaCorbeilleNeSonnePas() async throws {
        let passe = try banc.ajouter("Passé", a: .penseBete)
        banc.depot.programmerRappel(banc.maintenant.addingTimeInterval(-60), pour: passe)
        let jete = try banc.ajouter("Jeté", a: .penseBete)
        banc.depot.programmerRappel(banc.maintenant.addingTimeInterval(60), pour: jete)
        banc.depot.supprimer(jete, par: .pablo)

        await notificateur.replanifier()

        #expect(rappels().isEmpty)
    }

    @Test func unRendezVousSonneSeulementChezCeuxQuIlConcerne() async throws {
        let debut = banc.maintenant.addingTimeInterval(86_400)
        banc.depot.ajouterEvenement("Dîner", debut: debut, lieu: "Chez Paul", rappel: .uneHeure, par: .julie)
        banc.depot.ajouterEvenement("Dentiste de Julie", debut: debut, pour: .julie, rappel: .uneHeure, par: .julie)
        banc.depot.ajouterEvenement("Kiné", debut: debut, pour: .pablo, rappel: .quinzeMinutes, par: .julie)
        banc.depot.ajouterEvenement("Sans rappel", debut: debut, par: .julie)

        await notificateur.replanifier()

        #expect(rappels().map(\.titre) == ["Dîner", "Kiné"])
        let diner = try #require(rappels().first)
        #expect(diner.date == debut.addingTimeInterval(-3_600))
        #expect(diner.corps == "\(Formats.jourProche(debut, maintenant: debut.addingTimeInterval(-3_600))) à \(Formats.heure(debut)) · Chez Paul · Vous deux")
        #expect(diner.ouvrir == ["onglet": "agenda"])
    }

    @Test func changerDeMembreChangeLesRappels() async throws {
        let debut = banc.maintenant.addingTimeInterval(86_400)
        banc.depot.ajouterEvenement("Dentiste de Julie", debut: debut, pour: .julie, rappel: .uneHeure, par: .julie)
        await notificateur.replanifier()
        #expect(rappels().isEmpty)

        identite.membre = .julie
        await notificateur.replanifier()

        #expect(rappels().map(\.titre) == ["Dentiste de Julie"])
    }

    @Test func seulsLesPlusProchesSontProgrammes() async throws {
        for numero in 1...(Rappels.maximum + 5) {
            let element = try banc.ajouter("Tâche \(numero)", a: .penseBete)
            banc.depot.programmerRappel(banc.maintenant.addingTimeInterval(Double(numero) * 60), pour: element)
        }

        await notificateur.replanifier()

        #expect(rappels().count == Rappels.maximum)
        #expect(rappels().last?.corps == "Tâche \(Rappels.maximum)")
    }

    @Test func sansAutorisationRienNEstProgramme() async throws {
        centre.statutCourant = .refusees
        let plombier = try banc.ajouter("Plombier", a: .penseBete)
        banc.depot.programmerRappel(banc.maintenant.addingTimeInterval(60), pour: plombier)

        await notificateur.replanifier()

        #expect(rappels().isEmpty)
    }

    @Test func chaqueEnregistrementReprogrammeLesRappels() async throws {
        notificateur.ecouterLaBase()
        let plombier = try banc.ajouter("Plombier", a: .penseBete)
        banc.depot.programmerRappel(banc.maintenant.addingTimeInterval(3_600), pour: plombier)

        for _ in 0..<40 where centre.programmees.isEmpty {
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(centre.programmees.count == 1)
    }

    @Test func laDemandeDAutorisationNeSeFaitQuUneFois() async {
        centre.statutCourant = .aDemander
        await notificateur.demanderAutorisationSiBesoin()
        await notificateur.demanderAutorisationSiBesoin()

        #expect(centre.demandes == 1)
        #expect(notificateur.statut == .autorisees)
    }

    @Test func lesAnnoncesPartentEnArrierePlanSeulement() async throws {
        let changement = ChangementRecu(
            nature: .ajout, sujet: .liste(.courses, pour: nil), titre: "Lait", par: .julie, le: banc.maintenant
        )
        notificateur.annoncer([changement])
        await notificateur.terminerEnvois()
        #expect(centre.envoyees.map(\.corps) == ["Julie a ajouté « Lait »"])

        let stockage = try #require(UserDefaults(suiteName: "tests-notifications-\(UUID().uuidString)"))
        let banc = banc
        let auPremierPlan = Notificateur(
            contexte: banc.conteneur.mainContext, identite: identite, centre: centre,
            stockage: stockage, horloge: { banc.maintenant }, estAuPremierPlan: { true }
        )
        auPremierPlan.annoncer([changement])
        await auPremierPlan.terminerEnvois()
        #expect(centre.envoyees.count == 1)
    }

    @Test func lesPreferencesSontGardeesSurCetIPhone() throws {
        let stockage = try #require(UserDefaults(suiteName: "tests-notifications-\(UUID().uuidString)"))
        let premier = Notificateur(contexte: banc.conteneur.mainContext, identite: identite, centre: centre, stockage: stockage)
        #expect(premier.annoncerListes && premier.annoncerAgenda)
        premier.annoncerListes = false

        let second = Notificateur(contexte: banc.conteneur.mainContext, identite: identite, centre: centre, stockage: stockage)
        #expect(!second.annoncerListes)
        #expect(second.annoncerAgenda)
    }
}
