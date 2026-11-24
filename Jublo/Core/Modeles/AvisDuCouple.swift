/// Élément noté par chacun des deux, de 1 à 5 (vacances envisagées, sorties testées).
/// Chaque avis a son propre champ : l'un peut noter sans écraser l'avis de l'autre.
protocol AvisDuCouple: AnyObject {
    var avisPablo: Int? { get set }
    var avisJulie: Int? { get set }
}

extension AvisDuCouple {
    static var avisMaximum: Int { 5 }

    func avis(de membre: Membre) -> Int? {
        switch membre {
        case .pablo: avisPablo
        case .julie: avisJulie
        }
    }

    /// Note de `membre`, ramenée entre 1 et 5 ; nil efface son avis.
    func definirAvis(_ avis: Int?, de membre: Membre) {
        let borne = avis.map { min(max($0, 1), Self.avisMaximum) }
        switch membre {
        case .pablo: avisPablo = borne
        case .julie: avisJulie = borne
        }
    }

    /// Somme des avis donnés, pour classer : ce qui plaît aux deux passe devant.
    var scoreCommun: Int { (avisPablo ?? 0) + (avisJulie ?? 0) }
}
