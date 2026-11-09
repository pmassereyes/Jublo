import Foundation
import SwiftData
import Testing
@testable import Jublo

/// Banc d'essai : base en mémoire et horloge contrôlée.
@MainActor
final class Banc {
    var maintenant = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let conteneur: ModelContainer
    private(set) var depot: Depot!

    init() throws {
        conteneur = try Persistance.conteneur(enMemoire: true)
        depot = Depot(contexte: conteneur.mainContext, horloge: { [unowned self] in maintenant })
    }

    func avancer(jours: Double = 0, heures: Double = 0) {
        maintenant.addTimeInterval(jours * 86_400 + heures * 3_600)
    }

    func tous<Modele: PersistentModel>(_: Modele.Type) throws -> [Modele] {
        try conteneur.mainContext.fetch(FetchDescriptor<Modele>())
    }

    func actifs(_ type: TypeListe) throws -> [ElementListe] {
        try conteneur.mainContext.fetch(FetchDescriptor(predicate: ElementListe.actifs(dans: type)))
    }

    /// Ajoute un élément de liste ; échoue si le dépôt le refuse.
    func ajouter(_ titre: String, a type: TypeListe = .courses, par membre: Membre = .pablo) throws -> ElementListe {
        try #require(depot.ajouter(titre, a: type, par: membre))
    }
}
