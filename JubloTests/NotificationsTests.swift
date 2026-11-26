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

    func statut() async -> StatutNotifications { statutCourant }

    func demanderAutorisation() async -> Bool {
        demandes += 1
        statutCourant = .autorisees
        return true
    }

    func identifiantsEnAttente() async -> [String] { Array(programmees.keys) }

    func programmer(_ notification: NotificationPrevue) async {
        programmees[notification.identifiant] = notification
    }

    func retirer(_ identifiants: [String]) {
        for identifiant in identifiants {
            programmees[identifiant] = nil
        }
    }
}

/// Ce que `Depot` signale pour prévenir l'autre.
@MainActor
struct ChangementsLocauxTests {
    let banc: Banc
    let observateur = ObservateurEspion()

    init() throws {
        banc = try Banc()
        banc.depot.observateur = observateur
    }

    private var natures: [Changement.Nature] { observateur.changements.map(\.nature) }

    @Test func ajouterCocherEtJeterSontSignales() throws {
        let lait = try banc.ajouter("Lait", a: .courses, par: .julie)
        banc.depot.basculer(lait, par: .julie)
        banc.depot.basculer(lait, par: .julie)
        banc.depot.supprimer(lait, par: .julie)
        banc.depot.restaurer(lait)

        #expect(natures == [.ajout, .coche, .suppression])
        #expect(observateur.changements.first == Changement(nature: .ajout, sujet: .liste(.courses, pour: nil), auteur: .julie))
    }

    @Test func uneEnvieGardeSonDestinataire() throws {
        banc.depot.ajouter("Céramique", a: .wishList, par: .pablo, pour: .julie)

        #expect(observateur.changements == [Changement(nature: .ajout, sujet: .liste(.wishList, pour: .julie), auteur: .pablo)])
    }

    @Test func unRappelSeulNEstPasSignale() throws {
        let plombier = try banc.ajouter("Plombier", a: .penseBete)
        let dentiste = try #require(banc.depot.ajouterEvenement("Dentiste", debut: banc.maintenant, par: .pablo))
        observateur.changements.removeAll()

        banc.depot.programmerRappel(banc.maintenant.addingTimeInterval(3_600), pour: plombier)
        banc.depot.modifier(dentiste) { $0.rappelBrut = RappelEvenement.uneHeure.rawValue }

        #expect(natures.isEmpty)
    }

    @Test func unRendezVousModifieOuJeteEstSignale() throws {
        let dentiste = try #require(banc.depot.ajouterEvenement("Dentiste", debut: banc.maintenant, par: .pablo))
        banc.depot.modifier(dentiste) { $0.lieu = "Cabinet" }
        banc.depot.supprimer(dentiste, par: .pablo)

        #expect(natures == [.ajout, .modification, .suppression])
    }

    @Test func lesAutresTypesNeSontPasSignales() throws {
        banc.depot.ajouterSortie("Le Comptoir", categorie: .restaurant, par: .julie)
        banc.depot.creerCagnotte("Lisbonne", par: .pablo)
        banc.depot.confierSouhait("cuisines un soir", par: .julie)

        #expect(natures.isEmpty)
    }
}

@MainActor
struct SignauxTests {
    let maintenant = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func liste(_ nature: Changement.Nature, _ type: TypeListe, pour: Membre? = nil, auteur: Membre = .julie) -> Changement {
        Changement(nature: nature, sujet: .liste(type, pour: pour), auteur: auteur)
    }

    private func rendezVous(_ nature: Changement.Nature, debut: Date) -> Changement {
        Changement(nature: nature, sujet: .agenda(debut: debut, fin: debut, journeeEntiere: false), auteur: .julie)
    }

    private func rubrique(_ changement: Changement) -> RubriqueSignal? {
        Signaux.rubrique(changement, maintenant: maintenant)
    }

    @Test func lesCoursesEtLePenseBeteSignalentAjoutsEtCoches() {
        #expect(rubrique(liste(.ajout, .courses)) == .courses)
        #expect(rubrique(liste(.coche, .courses)) == .courses)
        #expect(rubrique(liste(.ajout, .penseBete)) == .penseBete)
        #expect(rubrique(liste(.coche, .penseBete)) == .penseBete)
        #expect(rubrique(liste(.suppression, .courses)) == nil)
    }

    @Test func laWishListNeSignaleQueLesEnviesPourSoi() {
        #expect(rubrique(liste(.ajout, .wishList, pour: .julie)) == .wishList)
        #expect(rubrique(liste(.ajout, .wishList, pour: .pablo)) == nil)
        #expect(rubrique(liste(.coche, .wishList, pour: .julie)) == nil)
    }

    @Test func lAgendaNeSignalePasLePasse() {
        #expect(rubrique(rendezVous(.ajout, debut: maintenant + 3_600)) == .agenda)
        #expect(rubrique(rendezVous(.modification, debut: maintenant + 3_600)) == .agenda)
        #expect(rubrique(rendezVous(.suppression, debut: maintenant + 3_600)) == .agenda)
        #expect(rubrique(rendezVous(.suppression, debut: maintenant - 3 * 86_400)) == nil)
    }

    @Test func leDestinataireFaitPartieDuType() {
        #expect(Signaux.typeEnregistrement(.courses, pour: .julie) == "SignalCoursesPourJulie")
        #expect(Signaux.typeEnregistrement(.penseBete, pour: .pablo) == "SignalPenseBetePourPablo")
        #expect(Signaux.nomEnregistrement(.agenda, pour: .pablo) == "signal-agenda-pablo")
        let types = Set(RubriqueSignal.allCases.flatMap { rubrique in Membre.allCases.map { Signaux.typeEnregistrement(rubrique, pour: $0) } })
        #expect(types.count == 8)
    }

    @Test func lAbonnementDitQuelEcranOuvrir() {
        let abonnement = Signaux.identifiantAbonnement(.wishList)

        #expect(Signaux.rubrique(abonnement: abonnement) == .wishList)
        #expect(Signaux.rubrique(abonnement: "autre-chose") == nil)
        #expect(Signaux.rubrique(abonnement: nil) == nil)
        #expect(Signaux.ecran(.wishList) == ["onglet": "listes", "liste": "wishList", "envies": "autre"])
        #expect(Signaux.ecran(.agenda) == ["onglet": "agenda"])
    }

    @Test func lesTextesNommentLAutre() {
        #expect(Signaux.texte(.courses, de: .julie) == "Julie a mis à jour les courses")
        #expect(Signaux.texte(.wishList, de: .pablo) == "Pablo a ajouté une envie à sa wish list")
        #expect(Signaux.titre(.agenda) == "Agenda")
    }

    @Test func unSignalParRubriqueToutesLesDixMinutes() {
        var cadence = CadenceSignaux()
        let premier = cadence.reserver(.courses, a: maintenant)
        let pendantLEnvoi = cadence.reserver(.courses, a: maintenant)
        cadence.terminer(.courses, envoyeLe: maintenant)
        let rafale = cadence.reserver(.courses, a: maintenant + 60)
        let autreRubrique = cadence.reserver(.agenda, a: maintenant + 60)
        let plusTard = cadence.reserver(.courses, a: maintenant + Signaux.intervalle)

        #expect(premier)
        #expect(!pendantLEnvoi)
        #expect(!rafale)
        #expect(autreRubrique)
        #expect(plusTard)
    }

    @Test func unSignalQuiNAPasPuPartirNeBloquePasLeSuivant() {
        var cadence = CadenceSignaux()
        let premier = cadence.reserver(.courses, a: maintenant)
        cadence.terminer(.courses, envoyeLe: nil)
        let suivant = cadence.reserver(.courses, a: maintenant + 60)

        #expect(premier)
        #expect(suivant)
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
        centre.programmees.values.sorted { $0.date < $1.date }
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

    @Test func lesReglagesDisentAQuoiSAbonner() {
        #expect(notificateur.abonnementsVoulus == Synchronisation.AbonnementsVoulus(
            membre: .pablo, rubriques: [.penseBete, .courses, .wishList, .agenda]
        ))

        notificateur.annoncerListes = false
        #expect(notificateur.abonnementsVoulus?.rubriques == [.agenda])
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

@MainActor
struct NavigationTests {
    @Test func uneNotificationOuvreLOngletEtLaListe() {
        let navigation = Navigation(onglet: .accueil)

        navigation.ouvrir(Signaux.ecran(.wishList))

        #expect(navigation.onglet == .listes)
        #expect(navigation.listeDemandee == .wishList)
        #expect(navigation.enviesDeLAutre)

        navigation.ouvrir(["onglet": "agenda"])
        #expect(navigation.onglet == .agenda)
        #expect(navigation.listeDemandee == nil)
        #expect(!navigation.enviesDeLAutre)
    }
}
