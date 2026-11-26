import CloudKit
import Foundation
import SwiftData
import Testing
@testable import Jublo

/// Rappels du pense-bête et de l'agenda (schéma V5).
@MainActor
struct RappelsTests {
    let banc: Banc
    let zone = CKRecordZone.ID(zoneName: "Jublo", ownerName: CKCurrentUserDefaultName)

    init() throws {
        banc = try Banc()
    }

    private var miroir: MiroirLocal { MiroirLocal(contexte: banc.conteneur.mainContext) }

    private var calendrier: Calendar {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
        return calendrier
    }

    private func date(_ jour: Int, _ heure: Int, _ minute: Int = 0) throws -> Date {
        try #require(calendrier.date(from: DateComponents(year: 2026, month: 12, day: jour, hour: heure, minute: minute)))
    }

    // MARK: - Pense-bête

    @Test func unRappelSeProgrammeEtSeRetire() throws {
        let plombier = try banc.ajouter("Appeler le plombier", a: .penseBete)
        let demain = banc.maintenant.addingTimeInterval(86_400)
        banc.avancer(heures: 1)

        banc.depot.programmerRappel(demain, pour: plombier)

        #expect(plombier.rappelLe == demain)
        #expect(plombier.modifieLe == banc.maintenant)

        banc.depot.programmerRappel(nil, pour: plombier)
        #expect(plombier.rappelLe == nil)
    }

    @Test func seulLePenseBeteADesRappels() throws {
        let lait = try banc.ajouter("Lait", a: .courses)

        banc.depot.programmerRappel(banc.maintenant, pour: lait)

        #expect(lait.rappelLe == nil)
    }

    @Test func leRappelDUnElementFaitLAllerRetour() throws {
        let plombier = try banc.ajouter("Appeler le plombier", a: .penseBete)
        let rappel = banc.maintenant.addingTimeInterval(3_600)
        banc.depot.programmerRappel(rappel, pour: plombier)

        let enregistrement = miroir.enregistrement(pour: plombier, zone: zone)
        #expect(enregistrement["rappelLe"] as? Date == rappel)

        let autre = try Banc()
        MiroirLocal(contexte: autre.conteneur.mainContext).appliquer([enregistrement])
        #expect(try autre.tous(ElementListe.self).first?.rappelLe == rappel)
    }

    // MARK: - Agenda

    @Test func leRappelDUnRendezVousFaitLAllerRetour() throws {
        let evenement = try #require(banc.depot.ajouterEvenement(
            "Dentiste", debut: banc.maintenant, pour: .julie, rappel: .quinzeMinutes, par: .pablo
        ))
        #expect(evenement.rappel == .quinzeMinutes)

        let enregistrement = miroir.enregistrement(pour: evenement, zone: zone)
        let autre = try Banc()
        MiroirLocal(contexte: autre.conteneur.mainContext).appliquer([enregistrement])

        #expect(try autre.tous(Evenement.self).first?.rappel == .quinzeMinutes)
    }

    @Test func unRappelALaMinuteDevientLeJourMemePourUneJourneeEntiere() throws {
        let evenement = try #require(banc.depot.ajouterEvenement(
            "Anniversaire", debut: banc.maintenant, journeeEntiere: true, rappel: .quinzeMinutes, par: .pablo
        ))

        #expect(evenement.rappel == .auDebut)
    }

    @Test func lesRappelsDUnRendezVousTombentAvantLeDebut() throws {
        let debut = try date(10, 14, 30)

        #expect(RappelEvenement.auDebut.date(debut: debut, journeeEntiere: false, calendrier: calendrier) == debut)
        #expect(RappelEvenement.quinzeMinutes.date(debut: debut, journeeEntiere: false, calendrier: calendrier) == (try date(10, 14, 15)))
        #expect(RappelEvenement.deuxHeures.date(debut: debut, journeeEntiere: false, calendrier: calendrier) == (try date(10, 12, 30)))
        #expect(RappelEvenement.unJour.date(debut: debut, journeeEntiere: false, calendrier: calendrier) == (try date(9, 14, 30)))
        #expect(RappelEvenement.uneSemaine.date(debut: debut, journeeEntiere: false, calendrier: calendrier) == (try date(3, 14, 30)))
    }

    @Test func lesRappelsDUneJourneeEntiereTombentAHeureFixe() throws {
        let jour = try date(10, 0)

        #expect(RappelEvenement.auDebut.date(debut: jour, journeeEntiere: true, calendrier: calendrier) == (try date(10, 9)))
        #expect(RappelEvenement.unJour.date(debut: jour, journeeEntiere: true, calendrier: calendrier) == (try date(9, 18)))
        #expect(RappelEvenement.deuxJours.date(debut: jour, journeeEntiere: true, calendrier: calendrier) == (try date(8, 9)))
        #expect(RappelEvenement.uneSemaine.date(debut: jour, journeeEntiere: true, calendrier: calendrier) == (try date(3, 9)))
    }

    @Test func uneJourneeEntiereNeProposeQueDesRappelsAuJour() {
        #expect(RappelEvenement.choix(journeeEntiere: true) == [.auDebut, .unJour, .deuxJours, .uneSemaine])
        #expect(RappelEvenement.choix(journeeEntiere: false) == RappelEvenement.allCases)
        #expect(RappelEvenement.uneHeure.adapte(journeeEntiere: true) == .auDebut)
        #expect(RappelEvenement.unJour.adapte(journeeEntiere: true) == .unJour)
    }

    @Test func unRendezVousEstPourLeMembreConcerneOuPourLesDeux() throws {
        let commun = try #require(banc.depot.ajouterEvenement("Dîner", debut: banc.maintenant, par: .pablo))
        let pourJulie = try #require(banc.depot.ajouterEvenement("Dentiste", debut: banc.maintenant, pour: .julie, par: .pablo))

        #expect(commun.estPour(.pablo) && commun.estPour(.julie))
        #expect(pourJulie.estPour(.julie) && !pourJulie.estPour(.pablo))
    }
}

@MainActor
struct MigrationV5Tests {
    @Test func uneBaseV4GardeSesDonneesSansRappel() throws {
        let dossier = FileManager.default.temporaryDirectory.appending(path: "jublo-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dossier) }
        let url = dossier.appending(path: "jublo.store")
        let date = Date(timeIntervalSinceReferenceDate: 800_000_000)

        do {
            let schemaV4 = Schema(versionedSchema: SchemaV4.self)
            let v4 = try ModelContainer(
                for: schemaV4,
                configurations: [ModelConfiguration(schema: schemaV4, url: url, cloudKitDatabase: .none)]
            )
            let contexte = v4.mainContext
            contexte.insert(SchemaV2.ElementListe(type: .penseBete, titre: "Plombier", auteur: .julie, le: date))
            let evenement = SchemaV4.Evenement(titre: "Dentiste", debut: date, auteur: .pablo, le: date)
            evenement.pourId = Membre.julie.rawValue
            evenement.lieu = "Cabinet"
            contexte.insert(evenement)
            contexte.insert(SchemaV4.Souhait(texte: "cuisines un soir", mois: "2026-11", auteur: .julie, le: date))
            try contexte.save()
        }

        let v5 = try Persistance.conteneur(url: url)
        let contexte = v5.mainContext
        let element = try #require(try contexte.fetch(FetchDescriptor<ElementListe>()).first)
        #expect(element.titre == "Plombier")
        #expect(element.rappelLe == nil)
        let evenement = try #require(try contexte.fetch(FetchDescriptor<Evenement>()).first)
        #expect(evenement.titre == "Dentiste")
        #expect(evenement.lieu == "Cabinet")
        #expect(evenement.concerne == .julie)
        #expect(evenement.rappel == nil)
        #expect(try contexte.fetchCount(FetchDescriptor<Souhait>()) == 1)

        let depot = Depot(contexte: contexte, horloge: { date })
        depot.programmerRappel(date, pour: element)
        #expect(element.rappelLe == date)
    }
}
