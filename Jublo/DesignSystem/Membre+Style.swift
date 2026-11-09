import SwiftUI

extension Membre {
    var couleur: Color {
        switch self {
        case .pablo: Color.pablo
        case .julie: Color.julie
        }
    }

    var couleurDouce: Color {
        switch self {
        case .pablo: Color.pabloDoux
        case .julie: Color.julieDoux
        }
    }
}

/// Pastille ronde à l'initiale d'un membre, à ses couleurs.
/// Sans membre, pastille commune à contour pour « nous deux ».
struct PastilleMembre: View {
    let membre: Membre?
    var taille: CGFloat = 28

    var body: some View {
        ZStack {
            if let membre {
                Circle().fill(membre.couleurDouce)
                Text(membre.initiale)
                    .font(.custom(NomPolice.texteGras, size: taille * 0.45))
                    .foregroundStyle(membre.couleur)
            } else {
                Circle().strokeBorder(Color.commun, lineWidth: 1.5)
                Image(systemName: "heart.fill")
                    .font(.system(size: taille * 0.38))
                    .foregroundStyle(.commun)
            }
        }
        .frame(width: taille, height: taille)
        .accessibilityHidden(true)
    }
}
