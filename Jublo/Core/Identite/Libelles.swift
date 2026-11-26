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

    /// « Pour moi » / « Pour Julie » : à qui est destinée une envie de la wish list.
    static func pour(_ membre: Membre, vuPar courant: Membre) -> String {
        membre == courant ? "Pour moi" : "Pour \(membre.prenom)"
    }

    /// Invite du champ d'ajout de la wish list.
    static func ajoutEnvie(pour membre: Membre, vuPar courant: Membre) -> String {
        membre == courant ? "Ajouter à mes envies" : "Ajouter une idée pour \(membre.prenom)"
    }

    /// À qui s'adresse un rendez-vous : « Vous deux », « Toi » ou le prénom de l'autre.
    static func concerne(_ membre: Membre?, vuPar courant: Membre) -> String {
        guard let membre else { return "Vous deux" }
        return quiEnDebut(membre, vuPar: courant)
    }

    /// Où sonnera le rappel d'un rendez-vous : chez le membre concerné, ou chez les deux.
    /// Sur l'autre iPhone, il faut d'abord que le rendez-vous y soit arrivé.
    static func rappelSonne(pour concerne: Membre?, vuPar courant: Membre) -> String {
        switch concerne {
        case nil: "Le rappel sonnera sur ton iPhone, et sur celui de \(courant.autre.prenom) dès qu'il aura reçu le rendez-vous."
        case courant?: "Le rappel sonnera sur ton iPhone."
        case let autre?: "Le rappel sonnera sur l'iPhone de \(autre.prenom), dès qu'il aura reçu le rendez-vous."
        }
    }

    /// Où sonnera le rappel d'un élément du pense-bête.
    static func rappelPenseBete(vuPar courant: Membre) -> String {
        "Le rappel sonnera sur ton iPhone, et sur celui de \(courant.autre.prenom) dès qu'il l'aura reçu, sauf si l'élément est coché avant."
    }

    /// « Quand Julie modifie les listes » : réglage des notifications de cet iPhone.
    static func quandLAutreModifie(_ quoi: String, vuPar courant: Membre) -> String {
        "Quand \(courant.autre.prenom) modifie \(quoi)"
    }

    /// Titre d'un souhait « ce mois-ci, j'aimerais que tu… » selon qui le lit.
    static func souhait(de auteur: Membre, vuPar courant: Membre) -> String {
        auteur == courant
            ? "Ta demande à \(auteur.autre.prenom)"
            : "\(auteur.prenom) aimerait que tu…"
    }

    /// Texte d'un souhait : cité tel quel pour son auteur, en suite de phrase pour l'autre.
    static func texteSouhait(_ texte: String, de auteur: Membre, vuPar courant: Membre) -> String {
        auteur == courant ? "J'aimerais que tu \(texte)" : "…\(texte)"
    }
}
