import CloudKit
import Foundation
import SwiftData
import Testing
@testable import Jublo

@MainActor
struct AgendaTests {
    let banc: Banc

    init() throws {
        banc = try Banc()
    }

    @Test func unRendezVousSansTitreEstRefuse() throws {
        #expect(banc.depot.ajouterEvenement("   ", debut: banc.maintenant, par: .pablo) == nil)
        #expect(try banc.tous(Evenement.self).isEmpty)
    }

    @Test func unRendezVousGardeSesDetailsNettoyes() throws {
        let debut = banc.maintenant.addingTimeInterval(3_600)
        let evenement = try #require(banc.depot.ajouterEvenement(
            " Dîner chez Léa ", debut: debut, lieu: "  ", note: " Apporter le dessert ", pour: .julie, par: .pablo
        ))

        #expect(evenement.titre == "Dîner chez Léa")
        #expect(evenement.lieu == nil)
        #expect(evenement.note == "Apporter le dessert")
        #expect(evenement.concerne == .julie)
        #expect(evenement.auteur == .pablo)
        #expect(evenement.creeLe == banc.maintenant)
    }

    @Test func uneFinAvantLeDebutEstRameneeAuDebut() throws {
        let debut = banc.maintenant
        let evenement = try #require(banc.depot.ajouterEvenement("Cinéma", debut: debut, fin: debut.addingTimeInterval(-60), par: .julie))

        #expect(evenement.fin == debut)
        #expect(evenement.concerne == nil)
    }

    @Test func uneJourneeEntiereResteAVenirJusquAuSoir() throws {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = TimeZone(identifier: "Europe/Paris")!
        let matin = calendrier.date(from: DateComponents(year: 2026, month: 12, day: 5, hour: 9))!
        let soir = calendrier.date(from: DateComponents(year: 2026, month: 12, day: 5, hour: 23))!
        let lendemain = calendrier.date(from: DateComponents(year: 2026, month: 12, day: 6, hour: 0, minute: 1))!
        let evenement = try #require(banc.depot.ajouterEvenement("Anniversaire", debut: matin, journeeEntiere: true, par: .pablo))

        #expect(evenement.estAVenir(a: soir, calendrier: calendrier))
        #expect(!evenement.estAVenir(a: lendemain, calendrier: calendrier))
    }

    @Test func unRendezVousPonctuelEstPasseApresSaFin() throws {
        let debut = banc.maintenant
        let evenement = try #require(banc.depot.ajouterEvenement("Dentiste", debut: debut, fin: debut.addingTimeInterval(1_800), par: .pablo))

        #expect(evenement.estAVenir(a: debut.addingTimeInterval(1_000)))
        #expect(!evenement.estAVenir(a: debut.addingTimeInterval(2_000)))
    }
}

@MainActor
struct VacancesEtSortiesTests {
    let banc: Banc
    let espion = ObservateurEspion()

    init() throws {
        banc = try Banc()
        banc.depot.observateur = espion
    }

    @Test func chacunNoteSansEcraserLAvisDeLAutre() throws {
        let lisbonne = try #require(banc.depot.ajouterDestination("Lisbonne", quand: "Printemps", budgetCentimes: 120_000, par: .pablo))

        banc.depot.donnerAvis(4, sur: lisbonne, par: .pablo)
        banc.depot.donnerAvis(9, sur: lisbonne, par: .julie)

        #expect(lisbonne.avis(de: .pablo) == 4)
        #expect(lisbonne.avis(de: .julie) == 5)
        #expect(lisbonne.scoreCommun == 9)

        banc.depot.donnerAvis(nil, sur: lisbonne, par: .pablo)
        #expect(lisbonne.avis(de: .pablo) == nil)
        #expect(lisbonne.avis(de: .julie) == 5)
    }

    @Test func unAvisInchangeNEstPasRenvoye() throws {
        let sortie = try #require(banc.depot.ajouterSortie("Le Comptoir", categorie: .restaurant, par: .julie))
        banc.depot.donnerAvis(3, sur: sortie, par: .julie)
        banc.depot.donnerAvis(3, sur: sortie, par: .julie)

        #expect(espion.modifies == [sortie.id, sortie.id])
    }

    @Test func leStatutDUneDestinationAvanceEtSeSynchronise() throws {
        let destination = try #require(banc.depot.ajouterDestination("Rome", par: .julie))
        banc.avancer(heures: 1)

        banc.depot.changerStatut(.reservee, de: destination)

        #expect(destination.statut == .reservee)
        #expect(destination.modifieLe == banc.maintenant)
        #expect(espion.modifies == [destination.id, destination.id])
    }

    @Test func uneSortieTesteeRetientLaDateEtPeutRevenir() throws {
        let sortie = try #require(banc.depot.ajouterSortie("Expo Hockney", categorie: .expo, lien: "centrepompidou.fr", par: .pablo))
        banc.avancer(jours: 2)

        banc.depot.basculerTestee(sortie)
        #expect(sortie.testeeLe == banc.maintenant)

        banc.depot.basculerTestee(sortie)
        #expect(!sortie.estTestee)
    }

    @Test func leLienDUneSortieDevientUneAdresseOuvrable() throws {
        let sortie = try #require(banc.depot.ajouterSortie("Bar à vin", categorie: .bar, lien: "exemple.fr/carte", par: .pablo))
        #expect(sortie.url?.absoluteString == "https://exemple.fr/carte")

        banc.depot.modifier(sortie) { $0.lien = "javascript:alert(1)" }
        #expect(sortie.url == nil)
    }

    @Test func unNomVideEstRefuse() {
        #expect(banc.depot.ajouterDestination(" ", par: .pablo) == nil)
        #expect(banc.depot.ajouterSortie("", categorie: .bar, par: .pablo) == nil)
        #expect(espion.modifies.isEmpty)
    }
}

@MainActor
struct RetardsEtSouhaitsTests {
    let banc: Banc
    var calendrier: Calendar {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendrier
    }

    init() throws {
        banc = try Banc()
    }

    @Test func unRetardSansDureeEstRefuse() {
        #expect(banc.depot.noterRetard(de: .julie, minutes: 0, par: .pablo) == nil)
    }

    @Test func leBilanDuMoisCompteChacunHorsCorbeille() throws {
        let novembre = calendrier.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 19))!
        let octobre = calendrier.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 19))!
        banc.depot.noterRetard(de: .julie, minutes: 10, le: novembre, par: .pablo)
        banc.depot.noterRetard(de: .julie, minutes: 25, motif: "Métro", le: novembre, par: .julie)
        banc.depot.noterRetard(de: .pablo, minutes: 5, le: novembre, par: .julie)
        banc.depot.noterRetard(de: .pablo, minutes: 40, le: octobre, par: .julie)
        let erreur = try #require(banc.depot.noterRetard(de: .pablo, minutes: 15, le: novembre, par: .julie))
        banc.depot.supprimer(erreur, par: .pablo)

        let bilans = BilanRetards.duMois(try banc.tous(Retard.self), contenant: novembre, calendrier: calendrier)

        #expect(bilans[.julie] == BilanRetards(nombre: 2, minutes: 35))
        #expect(bilans[.pablo] == BilanRetards(nombre: 1, minutes: 5))
    }

    @Test func unRetardSeLitDansLaCorbeille() throws {
        let retard = try #require(banc.depot.noterRetard(de: .julie, minutes: 20, motif: "Vélib'", par: .pablo))
        #expect(retard.titreAffiche == "20 min de retard · Vélib'")
        #expect(retard.retardataire == .julie)
    }

    @Test func unSouhaitEstConfieALAutrePourLeMoisEnCours() throws {
        let souhait = try #require(banc.depot.confierSouhait(" m'emmènes au cinéma ", par: .julie))

        #expect(souhait.texte == "m'emmènes au cinéma")
        #expect(souhait.mois == Souhait.cleMois(banc.maintenant))
        #expect(souhait.destinataire == .pablo)
        #expect(souhait.titreAffiche == "J'aimerais que tu m'emmènes au cinéma")
        #expect(banc.depot.confierSouhait("  ", par: .julie) == nil)
    }

    @Test func unSouhaitSeCocheEtSeDecoche() throws {
        let souhait = try #require(banc.depot.confierSouhait("cuisines un soir", par: .pablo))
        banc.avancer(jours: 3)

        banc.depot.basculerFait(souhait)
        #expect(souhait.faitLe == banc.maintenant)

        banc.depot.basculerFait(souhait)
        #expect(!souhait.estFait)
    }

    @Test func laCleDuMoisFaitLAllerRetour() {
        let date = calendrier.date(from: DateComponents(year: 2027, month: 3, day: 31, hour: 23, minute: 30))!

        let cle = Souhait.cleMois(date, calendrier: calendrier)

        #expect(cle == "2027-03")
        #expect(Souhait.debutDuMois(cle, calendrier: calendrier) == calendrier.date(from: DateComponents(year: 2027, month: 3, day: 1)))
        #expect(Souhait.debutDuMois("mars", calendrier: calendrier) == nil)
    }
}

@MainActor
struct CorbeilleV4Tests {
    let banc: Banc

    init() throws {
        banc = try Banc()
    }

    /// Un élément de chaque nouveau type, mis à la corbeille.
    private func toutSupprimer() throws -> [any Suppressible] {
        let elements: [any Suppressible] = [
            try #require(banc.depot.ajouterEvenement("Dentiste", debut: banc.maintenant, par: .pablo)),
            try #require(banc.depot.ajouterDestination("Rome", par: .pablo)),
            try #require(banc.depot.ajouterSortie("Le Comptoir", categorie: .restaurant, par: .julie)),
            try #require(banc.depot.noterRetard(de: .julie, minutes: 10, par: .pablo)),
            try #require(banc.depot.confierSouhait("cuisines un soir", par: .julie)),
        ]
        for element in elements {
            banc.depot.supprimer(element, par: .julie)
        }
        return elements
    }

    @Test func lesNouveauxTypesPassentParLaCorbeille() throws {
        let supprimes = try toutSupprimer()

        let corbeille = banc.depot.elementsDansLaCorbeille()

        #expect(Set(corbeille.map(\.id)) == Set(supprimes.map(\.id)))
        #expect(Set(corbeille.map(\.libelleType)) == ["Agenda", "Vacances", "Sorties", "Retards", "Ce mois-ci"])
    }

    @Test func lesNouveauxTypesSontPurgesApres30Jours() throws {
        _ = try toutSupprimer()
        banc.avancer(jours: 31)

        #expect(banc.depot.purger() == 5)
        #expect(try banc.tous(Evenement.self).isEmpty)
        #expect(try banc.tous(Souhait.self).isEmpty)
    }
}

@MainActor
struct MiroirLocalV4Tests {
    let banc: Banc
    let zone = CKRecordZone.ID(zoneName: "Jublo", ownerName: CKCurrentUserDefaultName)

    init() throws {
        banc = try Banc()
    }

    private var miroir: MiroirLocal { MiroirLocal(contexte: banc.conteneur.mainContext) }

    /// Envoie les modèles locaux dans une autre base, comme le ferait CloudKit.
    private func transmettre(_ modeles: [any Synchronisable]) throws -> Banc {
        let autre = try Banc()
        MiroirLocal(contexte: autre.conteneur.mainContext).appliquer(modeles.map { miroir.enregistrement(pour: $0, zone: zone) })
        return autre
    }

    @Test func unRendezVousFaitLAllerRetourSansPerte() throws {
        let debut = banc.maintenant
        let evenement = try #require(banc.depot.ajouterEvenement(
            "Week-end à Lyon", debut: debut, fin: debut.addingTimeInterval(172_800), journeeEntiere: true,
            lieu: "Lyon", note: "Train de 8 h", pour: .julie, par: .pablo
        ))
        banc.depot.supprimer(evenement, par: .julie)

        let enregistrement = miroir.enregistrement(pour: evenement, zone: zone)
        #expect(enregistrement.recordType == "Evenement")
        #expect(enregistrement["titre"] == nil)
        #expect(enregistrement.encryptedValues["lieu"] as? String == "Lyon")

        let autre = try transmettre([evenement])
        let recu = try #require(try autre.tous(Evenement.self).first)
        #expect(recu.id == evenement.id)
        #expect(recu.titre == "Week-end à Lyon")
        #expect(recu.debut == evenement.debut)
        #expect(recu.fin == evenement.fin)
        #expect(recu.journeeEntiere)
        #expect(recu.lieu == "Lyon")
        #expect(recu.note == "Train de 8 h")
        #expect(recu.concerne == .julie)
        #expect(recu.auteur == .pablo)
        #expect(recu.supprimePar == Membre.julie.rawValue)
        #expect(recu.modifieLe == evenement.modifieLe)
    }

    @Test func vacancesEtSortiesFontLAllerRetourSansPerte() throws {
        let destination = try #require(banc.depot.ajouterDestination("Lisbonne", quand: "Printemps", budgetCentimes: 90_000, note: "Tram 28", par: .julie))
        banc.depot.donnerAvis(5, sur: destination, par: .julie)
        banc.depot.donnerAvis(3, sur: destination, par: .pablo)
        banc.depot.changerStatut(.faite, de: destination)
        let sortie = try #require(banc.depot.ajouterSortie("Septime", categorie: .restaurant, lieu: "Paris 11e", lien: "septime.fr", note: "Réserver 3 semaines avant", par: .pablo))
        banc.depot.basculerTestee(sortie)
        banc.depot.donnerAvis(4, sur: sortie, par: .julie)

        let autre = try transmettre([destination, sortie])

        let recue = try #require(try autre.tous(Destination.self).first)
        #expect(recue.nom == "Lisbonne")
        #expect(recue.quand == "Printemps")
        #expect(recue.budgetCentimes == 90_000)
        #expect(recue.note == "Tram 28")
        #expect(recue.statut == .faite)
        #expect(recue.avis(de: .julie) == 5)
        #expect(recue.avis(de: .pablo) == 3)
        let recu = try #require(try autre.tous(Sortie.self).first)
        #expect(recu.nom == "Septime")
        #expect(recu.categorie == .restaurant)
        #expect(recu.lieu == "Paris 11e")
        #expect(recu.lien == "septime.fr")
        #expect(recu.note == "Réserver 3 semaines avant")
        #expect(recu.testeeLe == sortie.testeeLe)
        #expect(recu.avis(de: .julie) == 4)
        #expect(recu.avis(de: .pablo) == nil)
    }

    @Test func retardsEtSouhaitsFontLAllerRetourSansPerte() throws {
        let retard = try #require(banc.depot.noterRetard(de: .julie, minutes: 25, motif: "Métro", par: .pablo))
        let souhait = try #require(banc.depot.confierSouhait("m'écrives une lettre", par: .julie))
        banc.depot.basculerFait(souhait)

        let autre = try transmettre([retard, souhait])

        let recu = try #require(try autre.tous(Retard.self).first)
        #expect(recu.retardataire == .julie)
        #expect(recu.minutes == 25)
        #expect(recu.motif == "Métro")
        #expect(recu.survenuLe == retard.survenuLe)
        #expect(recu.auteur == .pablo)
        let recue = try #require(try autre.tous(Souhait.self).first)
        #expect(recue.texte == "m'écrives une lettre")
        #expect(recue.mois == souhait.mois)
        #expect(recue.faitLe == souhait.faitLe)
        #expect(recue.auteur == .julie)
    }

    @Test func chaqueNouveauTypeEstRetrouveEtEnvoye() throws {
        let modeles: [any Synchronisable] = [
            try #require(banc.depot.ajouterEvenement("Dentiste", debut: banc.maintenant, par: .pablo)),
            try #require(banc.depot.ajouterDestination("Rome", par: .pablo)),
            try #require(banc.depot.ajouterSortie("Le Comptoir", categorie: .restaurant, par: .julie)),
            try #require(banc.depot.noterRetard(de: .julie, minutes: 10, par: .pablo)),
            try #require(banc.depot.confierSouhait("cuisines un soir", par: .julie)),
        ]

        #expect(miroir.tousLesModeles().count == 5)
        for modele in modeles {
            #expect(miroir.modele(modele.id, type: nil)?.id == modele.id)
            #expect(miroir.modele(modele.id, type: type(of: modele).typeEnregistrement)?.id == modele.id)
        }
        #expect(Set(MiroirLocal.typesEnregistrement).isSuperset(of: modeles.map { type(of: $0).typeEnregistrement }))
    }

    @Test func uneSuppressionRecueEffaceUnNouveauType() throws {
        let sortie = try #require(banc.depot.ajouterSortie("Le Comptoir", categorie: .restaurant, par: .julie))

        miroir.supprimer([CKRecord.ID(recordName: sortie.id.uuidString, zoneID: zone)])

        #expect(try banc.tous(Sortie.self).isEmpty)
    }
}

@MainActor
struct MigrationV4Tests {
    @Test func uneBaseV3GardeSesDonneesEtAccueilleLesNouveauxTypes() throws {
        let dossier = FileManager.default.temporaryDirectory.appending(path: "jublo-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dossier) }
        let url = dossier.appending(path: "jublo.store")
        let date = Date(timeIntervalSinceReferenceDate: 800_000_000)

        do {
            let schemaV3 = Schema(versionedSchema: SchemaV3.self)
            let v3 = try ModelContainer(
                for: schemaV3,
                configurations: [ModelConfiguration(schema: schemaV3, url: url, cloudKitDatabase: .none)]
            )
            let contexte = v3.mainContext
            let element = SchemaV2.ElementListe(type: .courses, titre: "Lait", auteur: .pablo, le: date)
            contexte.insert(element)
            contexte.insert(SchemaV3.MetadonneesSync(nomEnregistrement: element.id.uuidString, champsSysteme: Data([1])))
            try contexte.save()
        }

        let v4 = try Persistance.conteneur(url: url)
        let contexte = v4.mainContext
        #expect(try contexte.fetch(FetchDescriptor<ElementListe>()).map(\.titre) == ["Lait"])
        #expect(try contexte.fetchCount(FetchDescriptor<MetadonneesSync>()) == 1)
        let depot = Depot(contexte: contexte, horloge: { date })
        #expect(depot.ajouterEvenement("Dentiste", debut: date, par: .julie) != nil)
        #expect(depot.confierSouhait("cuisines un soir", par: .pablo) != nil)
        #expect(try contexte.fetchCount(FetchDescriptor<Evenement>()) == 1)
    }
}
