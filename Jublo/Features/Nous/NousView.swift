import SwiftUI

struct NousView: View {
    @Environment(Identite.self) private var identite
    @Environment(ConfigurationAssistant.self) private var configurationAssistant
    #if DEBUG
    @Environment(Synchronisation.self) private var synchronisation
    @State private var messageSchema: String?
    #endif

    var body: some View {
        @Bindable var identite = identite

        Page {
            CartePartage()

            CarteSouhaits()
            CarteRetards()

            NavigationLink {
                ReglagesAssistantView()
            } label: {
                Carte {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Assistant", systemImage: "sparkles")
                                .font(.jubloCorpsFort)
                            Text(configurationAssistant.manque == nil
                                 ? "\(configurationAssistant.fournisseur.nom) · prêt"
                                 : "À configurer")
                                .font(.jubloLegende)
                                .foregroundStyle(.texteSecondaire)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.texteSecondaire)
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(.texte)
                    .frame(minHeight: Mesures.zoneTactile)
                }
            }
            .buttonStyle(.plain)

            NavigationLink {
                CorbeilleView()
            } label: {
                Carte {
                    HStack {
                        Label("Corbeille", systemImage: "trash")
                            .font(.jubloCorpsFort)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.texteSecondaire)
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(.texte)
                    .frame(minHeight: Mesures.zoneTactile)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                TitreSection(titre: "Cet iPhone")
                Carte {
                    VStack(alignment: .leading, spacing: Mesures.espacement) {
                        Text("Je suis")
                            .font(.jubloCorpsFort)
                            .foregroundStyle(.texte)
                        SelecteurPilules(options: Membre.allCases, selection: $identite.membre, titre: \.prenom) { membre in
                            membre.couleur
                        }
                        .overlay(Capsule().strokeBorder(Color.separateur))
                        Text("Sert à signer ce que tu ajoutes, coches ou supprimes.")
                            .font(.jubloLegende)
                            .foregroundStyle(.texteSecondaire)
                    }
                }
                CarteNotifications()
            }

            #if DEBUG
            VStack(alignment: .leading, spacing: 8) {
                TitreSection(titre: "Développement")
                Carte {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Crée tous les champs dans l'environnement CloudKit de développement, avant de déployer le schéma en production.")
                            .font(.jubloLegende)
                            .foregroundStyle(.texteSecondaire)
                        Button("Préparer le schéma CloudKit") {
                            messageSchema = "Préparation…"
                            Task {
                                do {
                                    try await synchronisation.preparerSchema()
                                    messageSchema = "Schéma prêt : déploie-le en production dans la console CloudKit."
                                } catch {
                                    messageSchema = Synchronisation.message(error)
                                }
                            }
                        }
                        .buttonStyle(.pilule(.contour, compacte: true))
                        if let messageSchema {
                            Text(messageSchema)
                                .font(.jubloLegende)
                                .foregroundStyle(.texte)
                        }
                        Button("Tester l'abonnement iCloud") {
                            messageSchema = "Test de l'abonnement…"
                            Task {
                                do {
                                    try await synchronisation.testerAbonnementSignal(pour: identite.membre)
                                    messageSchema = "Abonnement accepté par iCloud."
                                } catch {
                                    messageSchema = "Abonnement refusé : \(Synchronisation.message(error))"
                                }
                            }
                        }
                        .buttonStyle(.pilule(.contour, compacte: true))
                    }
                }
            }
            #endif
        }
        .navigationTitle("Nous")
    }
}

#if DEBUG
#Preview {
    NavigationStack { NousView() }.apercuJublo()
}
#endif
