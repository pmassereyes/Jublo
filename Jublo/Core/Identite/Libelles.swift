/// Libellés qui désignent une personne. Jamais « toi » ou « elle » en dur :
/// tout dépend du membre qui regarde l'écran.
enum Libelles {
    /// « toi » si `membre` est le membre courant, sinon son prénom.
    static func qui(_ membre: Membre, vuPar courant: Membre) -> String {
        membre == courant ? "toi" : membre.prenom
    }

    /// Même chose à partir d'un identifiant stocké (`auteurId`, `supprimePar`…).
    static func qui(_ id: String?, vuPar courant: Membre) -> String {
        guard let id, let membre = Membre(rawValue: id) else { return "quelqu'un" }
        return qui(membre, vuPar: courant)
    }

    /// « Toi » ou le prénom, en début de phrase.
    static func quiEnDebut(_ membre: Membre, vuPar courant: Membre) -> String {
        membre == courant ? "Toi" : membre.prenom
    }

    /// Titre d'un souhait « ce mois-ci, j'aimerais que tu… » selon qui le lit.
    static func souhait(de auteur: Membre, vuPar courant: Membre) -> String {
        auteur == courant
            ? "Tu aimerais que \(auteur.autre.prenom)…"
            : "\(auteur.prenom) aimerait que tu…"
    }
}
