import Foundation
import SwiftData

enum CategorieSortie: String, CaseIterable, Identifiable {
    case restaurant
    case bar
    case expo
    case spectacle
    case activite
    case autre

    var id: Self { self }

    var titre: String {
        switch self {
        case .restaurant: "Restaurant"
        case .bar: "Bar"
        case .expo: "Expo"
        case .spectacle: "Spectacle"
        case .activite: "Activité"
        case .autre: "Autre"
        }
    }

    var symbole: String {
        switch self {
        case .restaurant: "fork.knife"
        case .bar: "wineglass"
        case .expo: "photo.artframe"
        case .spectacle: "theatermasks"
        case .activite: "figure.walk"
        case .autre: "mappin"
        }
    }
}

extension SchemaV4 {
    /// Sortie repérée par l'un ou l'autre, à tester puis à noter.
    @Model
    final class Sortie {
        var id: UUID = UUID()
        var nom: String = ""
        var categorieBrut: String = CategorieSortie.restaurant.rawValue
        var lieu: String?
        /// Site, compte Instagram, fiche de plan…
        var lien: String?
        var note: String?
        var testeeLe: Date?
        var avisPablo: Int?
        var avisJulie: Int?

        var auteurId: String = ""
        var creeLe: Date = Date.now
        var modifieLe: Date = Date.now
        var supprimeLe: Date?
        var supprimePar: String?

        init(nom: String, categorie: CategorieSortie, auteur: Membre, le date: Date) {
            self.nom = nom
            categorieBrut = categorie.rawValue
            auteurId = auteur.rawValue
            creeLe = date
            modifieLe = date
        }
    }
}

extension Sortie: Suppressible, AvisDuCouple {
    var libelleType: String { "Sorties" }
    var titreAffiche: String { nom }
    var categorie: CategorieSortie { CategorieSortie(rawValue: categorieBrut) ?? .autre }
    var estTestee: Bool { testeeLe != nil }

    /// Lien ouvrable, en ajoutant « https:// » s'il manque.
    var url: URL? {
        guard let lien = lien?.trimmingCharacters(in: .whitespaces), !lien.isEmpty else { return nil }
        let complet = lien.contains("://") ? lien : "https://\(lien)"
        guard let url = URL(string: complet), url.scheme == "https" || url.scheme == "http" else { return nil }
        return url
    }

    static var actives: Predicate<Sortie> {
        #Predicate { $0.supprimeLe == nil }
    }
}
