import Foundation
import SwiftData

/// Tout ce que l'assistant peut lire, hors corbeille : listes, agenda, projets (cagnottes,
/// vacances, sorties) et souhaits « ce mois-ci, j'aimerais que tu… ».
struct DonneesAssistant {
    var elements: [ElementListe] = []
    var evenements: [Evenement] = []
    var cagnottes: [Cagnotte] = []
    var destinations: [Destination] = []
    var sorties: [Sortie] = []
    var souhaits: [Souhait] = []

    /// Lit la base au moment de la question (les éléments supprimés sont écartés par `ContexteAssistant`).
    @MainActor
    static func lire(dans contexte: ModelContext) -> DonneesAssistant {
        DonneesAssistant(
            elements: (try? contexte.fetch(FetchDescriptor<ElementListe>())) ?? [],
            evenements: (try? contexte.fetch(FetchDescriptor<Evenement>())) ?? [],
            cagnottes: (try? contexte.fetch(FetchDescriptor<Cagnotte>())) ?? [],
            destinations: (try? contexte.fetch(FetchDescriptor<Destination>())) ?? [],
            sorties: (try? contexte.fetch(FetchDescriptor<Sortie>())) ?? [],
            souhaits: (try? contexte.fetch(FetchDescriptor<Souhait>())) ?? []
        )
    }
}

/// Consignes envoyées au modèle avec chaque question : qui parle, la date, puis le contenu
/// de l'app (listes, agenda, projets, souhaits du mois). Les retards ne sont pas envoyés.
enum ContexteAssistant {
    /// Nombre maximal d'éléments par section, pour garder des requêtes courtes.
    static let maxParSection = 40
    /// Rendez-vous passés envoyés : ceux des 30 derniers jours.
    static let joursPassesAgenda = 30

    static func consignes(
        pour membre: Membre, donnees: DonneesAssistant, maintenant: Date = .now, calendrier: Calendar = .current
    ) -> String {
        let date = maintenant.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(.jublo))
        var lignes = [
            "Tu es l'assistant de Jublo, l'application que partagent \(membre.prenom) et \(membre.autre.prenom), un couple.",
            "Tu parles avec \(membre.prenom) : « tu » désigne \(membre.prenom), et \(membre.autre.prenom) est son ou sa partenaire.",
            "Réponds en français, brièvement et chaleureusement. Appuie-toi sur les données de Jublo ci-dessous sans rien inventer ; si une information manque, dis-le.",
            "Nous sommes le \(date), il est \(Formats.heure(maintenant)).",
        ]
        lignes += listes(donnees.elements.filter { $0.supprimeLe == nil }, membre: membre)
        lignes += agenda(donnees.evenements.filter { $0.supprimeLe == nil }, maintenant: maintenant, calendrier: calendrier)
        lignes += cagnottes(donnees.cagnottes.filter { $0.supprimeLe == nil })
        lignes += vacances(donnees.destinations.filter { $0.supprimeLe == nil })
        lignes += sorties(donnees.sorties.filter { $0.supprimeLe == nil }, calendrier: calendrier)
        lignes += souhaits(donnees.souhaits.filter { $0.supprimeLe == nil }, maintenant: maintenant, calendrier: calendrier)
        return lignes.joined(separator: "\n")
    }

    // MARK: - Listes

    private static func listes(_ elements: [ElementListe], membre: Membre) -> [String] {
        var lignes: [String] = []
        for type in TypeListe.allCases where type != .wishList {
            lignes += section(type.titre, elements.filter { $0.type == type }, type: type)
        }
        for destinataire in [membre, membre.autre] {
            let envies = elements.filter { $0.type == .wishList && $0.destinataire == destinataire }
            lignes += section("Wish list de \(destinataire.prenom)", envies, type: .wishList)
        }
        return lignes
    }

    /// « À faire » / « Fait », ou « À offrir » / « Offert » pour la wish list.
    private static func section(_ titre: String, _ elements: [ElementListe], type: TypeListe) -> [String] {
        var lignes = ["", "## \(titre)"]
        guard !elements.isEmpty else { return lignes + ["(vide)"] }
        let aFaire = elements.filter { !$0.estCoche }.sorted { $0.creeLe > $1.creeLe }
        let faits = elements.filter(\.estCoche).sorted { ($0.cocheLe ?? $0.creeLe) > ($1.cocheLe ?? $1.creeLe) }
        if !aFaire.isEmpty {
            lignes.append("\(type.libelleEnAttente) :")
            lignes += puces(aFaire) { "- \($0.titre) (ajouté par \(prenom($0.auteurId)))" }
        }
        if !faits.isEmpty {
            lignes.append("\(type.libelleTermine) :")
            lignes += puces(faits) { "- \($0.titre) (\(type.libelleCochePar.lowercased()) \(prenom($0.cochePar)))" }
        }
        return lignes
    }

    // MARK: - Agenda

    private static func agenda(_ evenements: [Evenement], maintenant: Date, calendrier: Calendar) -> [String] {
        let aVenir = evenements.filter { $0.estAVenir(a: maintenant, calendrier: calendrier) }.sorted { $0.debut < $1.debut }
        let limite = calendrier.date(byAdding: .day, value: -joursPassesAgenda, to: maintenant) ?? maintenant
        let passes = evenements
            .filter { !$0.estAVenir(a: maintenant, calendrier: calendrier) && $0.finEffective >= limite }
            .sorted { $0.debut > $1.debut }

        var lignes = ["", "## Agenda : à venir"]
        lignes += aVenir.isEmpty ? ["(rien de prévu)"] : puces(aVenir) { ligne($0, calendrier: calendrier) }
        if !passes.isEmpty {
            lignes += ["", "## Agenda : passé (\(joursPassesAgenda) derniers jours)"]
            lignes += puces(passes) { ligne($0, calendrier: calendrier) }
        }
        return lignes
    }

    private static func ligne(_ evenement: Evenement, calendrier: Calendar) -> String {
        var details = ["pour \(evenement.concerne?.prenom ?? "vous deux")"]
        if let lieu = evenement.lieu { details.append("lieu : \(lieu)") }
        if let note = evenement.note { details.append("note : \(note)") }
        return "- \(quand(evenement, calendrier: calendrier)) : \(evenement.titre) (\(details.joined(separator: " ; ")))"
    }

    /// « mercredi 25 novembre 2026 à 20:00–22:00 », « samedi 28 novembre 2026 (toute la journée) »…
    private static func quand(_ evenement: Evenement, calendrier: Calendar) -> String {
        let debut = jour(evenement.debut)
        let fin = evenement.finEffective
        let memeJour = calendrier.isDate(fin, inSameDayAs: evenement.debut)
        if evenement.journeeEntiere {
            return memeJour ? "\(debut) (toute la journée)" : "du \(debut) au \(jour(fin))"
        }
        let heure = "\(debut) à \(Formats.heure(evenement.debut))"
        guard fin > evenement.debut else { return heure }
        return memeJour ? "\(heure)–\(Formats.heure(fin))" : "\(heure), jusqu'au \(jour(fin)) à \(Formats.heure(fin))"
    }

    // MARK: - Projets

    private static func cagnottes(_ cagnottes: [Cagnotte]) -> [String] {
        var lignes = ["", "## Cagnottes"]
        guard !cagnottes.isEmpty else { return lignes + ["(aucune)"] }
        lignes += puces(cagnottes.sorted { $0.creeLe > $1.creeLe }) { cagnotte in
            var details = ["\(Formats.montant(cagnotte.soldeCentimes)) de côté"]
            if let objectif = cagnotte.objectifCentimes, objectif > 0 {
                details.append("objectif \(Formats.montant(objectif))")
            }
            let valides = cagnotte.historique.filter { !$0.estAnnule }
            for membre in Membre.allCases {
                let part = valides.filter { $0.auteur == membre }.reduce(0) { $0 + $1.montantCentimes }
                details.append("versé par \(membre.prenom) : \(Formats.montant(part))")
            }
            return "- \(cagnotte.nom) : \(details.joined(separator: " ; "))"
        }
        return lignes
    }

    private static func vacances(_ destinations: [Destination]) -> [String] {
        var lignes = ["", "## Vacances envisagées"]
        guard !destinations.isEmpty else { return lignes + ["(aucune idée)"] }
        // Envisagées, puis réservées, puis faites ; les plus désirées d'abord.
        let rang = { (destination: Destination) in StatutDestination.allCases.firstIndex(of: destination.statut) ?? 0 }
        let triees = destinations.sorted {
            (rang($0), -$0.scoreCommun, $0.creeLe) < (rang($1), -$1.scoreCommun, $1.creeLe)
        }
        lignes += puces(triees) { destination in
            var details = [destination.statut.titre.lowercased()]
            if let quand = destination.quand { details.append("quand : \(quand)") }
            if let budget = destination.budgetCentimes { details.append("budget \(Formats.montant(budget))") }
            details.append(envies(destination))
            if let note = destination.note { details.append("note : \(note)") }
            return "- \(destination.nom) (\(details.joined(separator: " ; ")))"
        }
        return lignes
    }

    private static func sorties(_ sorties: [Sortie], calendrier: Calendar) -> [String] {
        let aTester = sorties.filter { !$0.estTestee }.sorted { $0.creeLe > $1.creeLe }
        let testees = sorties.filter(\.estTestee).sorted { ($0.testeeLe ?? $0.creeLe) > ($1.testeeLe ?? $1.creeLe) }
        var lignes = ["", "## Sorties à tester"]
        lignes += aTester.isEmpty ? ["(aucune)"] : puces(aTester) { sortie in
            "- \(sortie.nom) (\(detailsSortie(sortie, en: "repérée par \(prenom(sortie.auteurId))").joined(separator: " ; ")))"
        }
        if !testees.isEmpty {
            lignes += ["", "## Sorties déjà testées"]
            lignes += puces(testees) { sortie in
                let testee = sortie.testeeLe.map { "testée le \(jour($0))" } ?? "testée"
                return "- \(sortie.nom) (\((detailsSortie(sortie, en: testee) + [envies(sortie, mot: "avis")]).joined(separator: " ; ")))"
            }
        }
        return lignes
    }

    private static func detailsSortie(_ sortie: Sortie, en etat: String) -> [String] {
        var details = [sortie.categorie.titre.lowercased(), etat]
        if let lieu = sortie.lieu { details.append("lieu : \(lieu)") }
        if let lien = sortie.lien { details.append("lien : \(lien)") }
        if let note = sortie.note { details.append("note : \(note)") }
        return details
    }

    /// « envie : Pablo 5/5, Julie pas encore donné »
    private static func envies<Note: AvisDuCouple>(_ note: Note, mot: String = "envie") -> String {
        let avis = Membre.allCases.map { membre in
            note.avis(de: membre).map { "\(membre.prenom) \($0)/\(Note.avisMaximum)" } ?? "\(membre.prenom) pas encore donné"
        }
        return "\(mot) : \(avis.joined(separator: ", "))"
    }

    // MARK: - Souhaits du mois

    private static func souhaits(_ souhaits: [Souhait], maintenant: Date, calendrier: Calendar) -> [String] {
        let moisCourant = Souhait.cleMois(maintenant, calendrier: calendrier)
        let duMois = souhaits.filter { $0.mois == moisCourant }.sorted { $0.creeLe < $1.creeLe }
        let anciens = souhaits.filter { $0.mois < moisCourant }.sorted { ($0.mois, $0.creeLe) > ($1.mois, $1.creeLe) }

        var lignes = ["", "## Ce mois-ci, j'aimerais que tu… (\(Formats.mois(moisCourant, calendrier: calendrier)))"]
        lignes += duMois.isEmpty ? ["(aucune demande ce mois-ci)"] : puces(duMois) { ligne($0, calendrier: calendrier) }
        if !anciens.isEmpty {
            lignes += ["", "## Demandes des mois précédents"]
            lignes += puces(anciens) { "\(ligne($0, calendrier: calendrier)) [\(Formats.mois($0.mois, calendrier: calendrier))]" }
        }
        return lignes
    }

    private static func ligne(_ souhait: Souhait, calendrier: Calendar) -> String {
        let auteur = prenom(souhait.auteurId)
        let destinataire = souhait.destinataire?.prenom ?? "l'autre"
        let etat = souhait.faitLe.map { "fait le \(jour($0))" } ?? "pas encore fait"
        return "- \(auteur) demande à \(destinataire) : « \(souhait.titreAffiche) » (\(etat))"
    }

    // MARK: - Outils

    private static func puces<Element>(_ elements: [Element], ligne: (Element) -> String) -> [String] {
        var lignes = elements.prefix(maxParSection).map(ligne)
        if elements.count > maxParSection {
            lignes.append("… et \(elements.count - maxParSection) autres")
        }
        return lignes
    }

    /// « mercredi 25 novembre 2026 » : l'année lève toute ambiguïté pour le modèle.
    private static func jour(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(.jublo))
    }

    private static func prenom(_ id: String?) -> String {
        id.flatMap(Membre.init(rawValue:))?.prenom ?? "quelqu'un"
    }
}
