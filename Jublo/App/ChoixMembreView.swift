import SwiftUI

/// Premier lancement : qui utilise cet iPhone ?
struct ChoixMembreView: View {
    @Environment(Identite.self) private var identite

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            HStack(spacing: -12) {
                ForEach(Membre.allCases) { membre in
                    PastilleMembre(membre: membre, taille: 72)
                }
            }
            VStack(spacing: 8) {
                Text("Bienvenue dans Jublo")
                    .font(.jubloGrandTitre)
                    .foregroundStyle(.texte)
                Text("Qui utilise cet iPhone ?")
                    .font(.jubloCorps)
                    .foregroundStyle(.texteSecondaire)
            }
            .multilineTextAlignment(.center)
            VStack(spacing: Mesures.espacement) {
                ForEach(Membre.allCases) { membre in
                    Button {
                        identite.membre = membre
                    } label: {
                        Text("Je suis \(membre.prenom)")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.pilule(.douce(fond: membre.couleurDouce, texte: membre.couleur)))
                }
            }
            Text("Ce choix signe ce que tu ajoutes. Tu pourras le changer dans Nous.")
                .font(.jubloLegende)
                .foregroundStyle(.texteSecondaire)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, Mesures.marge * 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.fond)
    }
}

#if DEBUG
#Preview {
    ChoixMembreView().apercuJublo()
}
#endif
