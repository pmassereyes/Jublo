import CloudKit
import Foundation
import SwiftData
import Testing
@testable import Jublo

@MainActor
struct MiroirLocalTests {
    let banc: Banc
    let zone = CKRecordZone.ID(zoneName: "Jublo", ownerName: CKCurrentUserDefaultName)

    init() throws {
        banc = try Banc()
    }

    private var miroir: MiroirLocal { MiroirLocal(contexte: banc.conteneur.mainContext) }

    @Test func unElementFaitLAllerRetourSansPerte() throws {
        let element = try #require(banc.depot.ajouter("Céramique", a: .wishList, par: .pablo, pour: .julie))
        banc.avancer(heures: 1)
        banc.depot.basculer(element, par: .julie)
        banc.avancer(heures: 1)
        banc.depot.supprimer(element, par: .pablo)

        let enregistrement = miroir.enregistrement(pour: element, zone: zone)

        #expect(enregistrement.recordType == "ElementListe")
        #expect(enregistrement.recordID == CKRecord.ID(recordName: element.id.uuidString, zoneID: zone))
        #expect(enregistrement.encryptedValues["titre"] as? String == "Céramique")
        #expect(enregistrement["titre"] == nil)

        let autre = try Banc()
        MiroirLocal(contexte: autre.conteneur.mainContext).appliquer([enregistrement])
        let recu = try #require(autre.tous(ElementListe.self).first)

        #expect(recu.id == element.id)
        #expect(recu.titre == "Céramique")
        #expect(recu.type == .wishList)
        #expect(recu.destinataire == .julie)
        #expect(recu.auteur == .pablo)
        #expect(recu.estCoche)
        #expect(recu.cochePar == Membre.julie.rawValue)
        #expect(recu.cocheLe == element.cocheLe)
        #expect(recu.supprimeLe == element.supprimeLe)
        #expect(recu.supprimePar == Membre.pablo.rawValue)
        #expect(recu.creeLe == element.creeLe)
        #expect(recu.modifieLe == element.modifieLe)
    }

    @Test func unVersementRetrouveSaCagnotteMemeRecuAvantElle() throws {
        let cagnotte = banc.depot.creerCagnotte("Lisbonne", objectifCentimes: 80_000, par: .pablo)
        let versement = banc.depot.verser(2_500, dans: cagnotte, par: .julie, note: "Billets")
        banc.depot.annuler(versement, par: .julie)
        let enregistrements = [
            miroir.enregistrement(pour: versement, zone: zone),
            miroir.enregistrement(pour: cagnotte, zone: zone),
        ]

        let autre = try Banc()
        MiroirLocal(contexte: autre.conteneur.mainContext).appliquer(enregistrements)

        let recue = try #require(autre.tous(Cagnotte.self).first)
        #expect(recue.nom == "Lisbonne")
        #expect(recue.objectifCentimes == 80_000)
        let recu = try #require(recue.versements?.first)
        #expect(recu.montantCentimes == 2_500)
        #expect(recu.note == "Billets")
        #expect(recu.annulePar == Membre.julie.rawValue)
        #expect(recue.soldeCentimes == 0)
    }

    @Test func uneRestaurationRecueEffaceLaSuppressionLocale() throws {
        let element = try banc.ajouter("Lait")
        banc.depot.supprimer(element, par: .pablo)
        let distant = miroir.enregistrement(pour: element, zone: zone)
        distant["supprimeLe"] = nil
        distant["supprimePar"] = nil
        distant["modifieLe"] = banc.maintenant.addingTimeInterval(60)

        miroir.appliquer([distant])

        #expect(element.supprimeLe == nil)
        #expect(element.supprimePar == nil)
        #expect(try banc.actifs(.courses).map(\.titre) == ["Lait"])
    }

    @Test func unChangementLocalEnAttentePlusRecentEstGarde() throws {
        let element = try banc.ajouter("Lait")
        let distant = miroir.enregistrement(pour: element, zone: zone)
        distant.encryptedValues["titre"] = "Lait (ancien)"
        distant["modifieLe"] = banc.maintenant.addingTimeInterval(-60)
        banc.avancer(heures: 1)
        banc.depot.basculer(element, par: .julie)

        miroir.appliquer([distant], enAttente: [element.id.uuidString])

        #expect(element.titre == "Lait")
        #expect(element.estCoche)
    }

    @Test func unConflitGardeLaVersionLaPlusRecente() throws {
        let element = try banc.ajouter("Lait")
        let serveur = miroir.enregistrement(pour: element, zone: zone)
        serveur.encryptedValues["titre"] = "Lait d'avoine"
        serveur["modifieLe"] = banc.maintenant.addingTimeInterval(3_600)

        #expect(miroir.resoudreConflit(avec: serveur) == false)
        #expect(element.titre == "Lait d'avoine")

        banc.avancer(heures: 2)
        banc.depot.basculer(element, par: .pablo)
        serveur.encryptedValues["titre"] = "Lait de coco"

        #expect(miroir.resoudreConflit(avec: serveur) == true)
        #expect(element.titre == "Lait d'avoine")
    }

    @Test func uneSuppressionRecueEffaceLeModeleEtSesMetadonnees() throws {
        let element = try banc.ajouter("Lait")
        let enregistrement = miroir.enregistrement(pour: element, zone: zone)
        miroir.memoriser(enregistrement)

        miroir.supprimer([enregistrement.recordID])

        #expect(try banc.tous(ElementListe.self).isEmpty)
        #expect(try banc.tous(MetadonneesSync.self).isEmpty)
    }

    @Test func lesChampsSystemeNeServentQueDansLeurZone() throws {
        let element = try banc.ajouter("Lait")
        let premier = miroir.enregistrement(pour: element, zone: zone)
        miroir.memoriser(premier)
        #expect(try banc.tous(MetadonneesSync.self).count == 1)

        #expect(miroir.enregistrement(pour: element, zone: zone).recordID == premier.recordID)
        let zonePartagee = CKRecordZone.ID(zoneName: "Jublo", ownerName: "_proprietaire")
        #expect(miroir.enregistrement(pour: element, zone: zonePartagee).recordID.zoneID == zonePartagee)
    }

    @Test func unTypeInconnuEstIgnore() throws {
        let partage = CKRecord(recordType: "cloudkit.share", recordID: CKRecord.ID(recordName: UUID().uuidString, zoneID: zone))

        miroir.appliquer([partage])

        #expect(try banc.tous(ElementListe.self).isEmpty)
        #expect(try banc.tous(MetadonneesSync.self).isEmpty)
    }

    @Test func tousLesModelesPartentAuPremierEnvoi() throws {
        _ = try banc.ajouter("Lait")
        let cagnotte = banc.depot.creerCagnotte("Lisbonne", par: .pablo)
        banc.depot.verser(1_000, dans: cagnotte, par: .julie)

        #expect(miroir.tousLesModeles().count == 3)
    }
}

/// Observateur de test : retient ce que `Depot` lui signale.
@MainActor
final class ObservateurEspion: ObservateurChangements {
    var modifies: [UUID] = []
    var supprimes: [UUID] = []
    var changements: [Changement] = []

    func aModifie(_ modele: any Synchronisable) { modifies.append(modele.id) }
    func aSupprime(_ modele: any Synchronisable) { supprimes.append(modele.id) }
    func aChange(_ changement: Changement) { changements.append(changement) }
}

@MainActor
struct DepotObservateurTests {
    let banc: Banc
    let espion = ObservateurEspion()

    init() throws {
        banc = try Banc()
        banc.depot.observateur = espion
    }

    @Test func chaqueEcritureEstSignalee() throws {
        let lait = try banc.ajouter("Lait")
        banc.depot.basculer(lait, par: .julie)
        banc.depot.supprimer(lait, par: .pablo)
        banc.depot.restaurer(lait)
        let cagnotte = banc.depot.creerCagnotte("Lisbonne", par: .pablo)
        let versement = banc.depot.verser(1_000, dans: cagnotte, par: .julie)
        banc.depot.annuler(versement, par: .julie)

        let attendus: [UUID] = [lait.id, lait.id, lait.id, lait.id, cagnotte.id, versement.id, versement.id]
        #expect(espion.modifies == attendus)
        #expect(espion.supprimes.isEmpty)
    }

    @Test func ceQuiNeChangeRienNEstPasSignale() throws {
        let lait = try banc.ajouter("Lait")
        banc.depot.restaurer(lait)
        banc.depot.supprimer(lait, par: .pablo)
        banc.depot.supprimer(lait, par: .julie)
        #expect(banc.depot.ajouter("   ", a: .courses, par: .pablo) == nil)

        let attendus: [UUID] = [lait.id, lait.id]
        #expect(espion.modifies == attendus)
    }

    @Test func laPurgeSignaleLesSuppressionsDefinitives() throws {
        let lait = try banc.ajouter("Lait")
        banc.depot.supprimer(lait, par: .pablo)
        let id = lait.id
        banc.avancer(jours: 31)

        banc.depot.purger()

        #expect(espion.supprimes == [id])
    }
}
