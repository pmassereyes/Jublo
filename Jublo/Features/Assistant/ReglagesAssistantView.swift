import SwiftUI

/// Choix du fournisseur d'IA, de l'adresse, du modèle et de la clé d'API.
/// Ces réglages sont propres à chaque iPhone.
struct ReglagesAssistantView: View {
    enum EtatTest: Equatable {
        case aucun
        case enCours
        case reussi(String)
        case echec(String)
    }

    @Environment(ConfigurationAssistant.self) private var configuration

    @State private var nouvelleCle = ""
    @State private var erreurCle: String?
    @State private var test = EtatTest.aucun

    var body: some View {
        @Bindable var configuration = configuration

        Page {
            if configuration.simulee {
                Carte(contour: .commun) {
                    Text("Mode simulé (debug) : l'assistant répond sans fournisseur.")
                        .font(.jubloCorps)
                        .foregroundStyle(.texte)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                TitreSection(titre: "Fournisseur")
                SelecteurPilules(options: Fournisseur.allCases, selection: $configuration.fournisseur, titre: \.nom)
                    .overlay(Capsule().strokeBorder(Color.separateur))
                Text(configuration.fournisseur.description)
                    .font(.jubloLegende)
                    .foregroundStyle(.texteSecondaire)
            }

            VStack(alignment: .leading, spacing: 8) {
                TitreSection(titre: "Connexion")
                Carte {
                    VStack(alignment: .leading, spacing: Mesures.espacement) {
                        champ("Adresse de l'API", texte: $configuration.adresse, invite: "https://…/v1", clavier: .URL)
                        champ("Modèle", texte: $configuration.modele, invite: configuration.fournisseur.modeleParDefaut)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                TitreSection(titre: "Clé d'API", detail: configuration.fournisseur.cleObligatoire ? nil : "facultative")
                Carte { sectionCle }
            }

            VStack(alignment: .leading, spacing: 8) {
                Button(test == .enCours ? "Test en cours…" : "Tester la connexion", action: tester)
                    .buttonStyle(.pilule)
                    .disabled(test == .enCours || configuration.manque != nil)
                resultatTest
            }
        }
        .navigationTitle("Réglages de l'assistant")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: configuration.fournisseur) {
            test = .aucun
            nouvelleCle = ""
            erreurCle = nil
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var sectionCle: some View {
        VStack(alignment: .leading, spacing: 10) {
            if configuration.cleEnregistree {
                HStack {
                    Label("Enregistrée sur cet iPhone", systemImage: "key.fill")
                        .font(.jubloCorps)
                        .foregroundStyle(.texte)
                    Spacer()
                    Button("Supprimer") {
                        configuration.supprimerCle()
                        test = .aucun
                    }
                    .buttonStyle(.pilule(.contour, compacte: true))
                }
            } else {
                HStack(spacing: 8) {
                    SecureField("Colle ta clé ici", text: $nouvelleCle)
                        .font(.jubloCorps)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .frame(minHeight: Mesures.zoneTactile)
                        .background(.fond, in: .capsule)
                    Button("Enregistrer", action: enregistrerCle)
                        .buttonStyle(.pilule(.pleine(fond: .texte, texte: .surface), compacte: true))
                        .disabled(nouvelleCle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            if let erreurCle {
                Text(erreurCle)
                    .font(.jubloLegende)
                    .foregroundStyle(.pablo)
            }
            Text("Rangée dans le trousseau de cet iPhone, elle n'est envoyée qu'à \(configuration.destination).")
                .font(.jubloLegende)
                .foregroundStyle(.texteSecondaire)
            if let console = configuration.fournisseur.consoleCles {
                Link("Créer une clé sur \(console.host() ?? console.absoluteString)", destination: console)
                    .font(.jubloLegende)
            }
        }
    }

    @ViewBuilder
    private var resultatTest: some View {
        switch test {
        case .aucun, .enCours:
            if let manque = configuration.manque {
                Text(manque)
                    .font(.jubloLegende)
                    .foregroundStyle(.texteSecondaire)
            }
        case .reussi(let reponse):
            Label("Connexion réussie. Réponse : « \(reponse) »", systemImage: "checkmark.circle")
                .font(.jubloLegende)
                .foregroundStyle(.julie)
        case .echec(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.jubloLegende)
                .foregroundStyle(.pablo)
        }
    }

    private func champ(_ titre: String, texte: Binding<String>, invite: String, clavier: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titre)
                .font(.jubloLegende)
                .foregroundStyle(.texteSecondaire)
            TextField(invite, text: texte)
                .font(.jubloCorps)
                .foregroundStyle(.texte)
                .keyboardType(clavier)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .frame(minHeight: Mesures.zoneTactile)
        }
    }

    // MARK: - Actions

    private func enregistrerCle() {
        do {
            try configuration.enregistrerCle(nouvelleCle)
            nouvelleCle = ""
            erreurCle = nil
        } catch {
            erreurCle = error.localizedDescription
        }
    }

    private func tester() {
        guard let service = configuration.service() else { return }
        test = .enCours
        let messages = [
            MessageIA(role: .systeme, contenu: "Réponds uniquement par le mot OK."),
            MessageIA(role: .utilisateur, contenu: "Test de connexion"),
        ]
        Task {
            do {
                var reponse = ""
                for try await morceau in service.repondre(a: messages) {
                    reponse += morceau
                    if reponse.count > 80 { break }
                }
                let texte = reponse.trimmingCharacters(in: .whitespacesAndNewlines)
                test = texte.isEmpty ? .echec(ErreurAssistant.reponseInattendue.localizedDescription) : .reussi(texte)
            } catch {
                test = .echec(ErreurAssistant.depuis(error).localizedDescription)
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack { ReglagesAssistantView() }.apercuJublo()
}
#endif
