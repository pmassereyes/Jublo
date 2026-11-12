import SwiftData
import SwiftUI

/// Discussion avec l'assistant, qui connaît vos listes. Poussé depuis l'Accueil.
/// Le fournisseur d'IA se choisit dans `ReglagesAssistantView`.
struct AssistantView: View {
    @Environment(Identite.self) private var identite
    @Environment(ConfigurationAssistant.self) private var configuration
    @Query(filter: #Predicate<ElementListe> { $0.supprimeLe == nil })
    private var elements: [ElementListe]

    @State private var discussion = Discussion()
    @State private var saisie = ""

    var body: some View {
        ScrollViewReader { defilement in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Mesures.espacement) {
                    if let manque = configuration.manque {
                        carteConfiguration(manque)
                    } else if discussion.messages.isEmpty {
                        accueil
                    }
                    ForEach(discussion.messages) { message in
                        BulleMessage(message: message, enAttente: discussion.enCours && message.texte.isEmpty)
                    }
                    if let erreur = discussion.erreur {
                        carteErreur(erreur)
                    }
                    Color.clear.frame(height: 1).id("bas")
                }
                .padding(Mesures.marge)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: discussion.messages.last?.texte) {
                defilement.scrollTo("bas", anchor: .bottom)
            }
            .onChange(of: discussion.erreur) {
                withAnimation { defilement.scrollTo("bas", anchor: .bottom) }
            }
        }
        .background(.fond)
        .safeAreaInset(edge: .bottom) { barreSaisie }
        .navigationTitle("Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !discussion.messages.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        discussion.effacer()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .accessibilityLabel("Nouvelle discussion")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ReglagesAssistantView()
                } label: {
                    Image(systemName: "gearshape")
                        .accessibilityLabel("Réglages de l'assistant")
                }
            }
        }
        .onDisappear { discussion.arreter() }
    }

    // MARK: - Contenu

    private var accueil: some View {
        VStack(alignment: .leading, spacing: Mesures.espacement) {
            Carte(contour: .commun) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Bonjour \(identite.membre.prenom)", systemImage: "sparkles")
                        .font(.jubloSousTitre)
                        .foregroundStyle(.texte)
                    Text("Pose une question sur vos listes : ce qu'il reste à acheter, les pense-bêtes en attente, une idée de cadeau…")
                        .font(.jubloCorps)
                        .foregroundStyle(.texteSecondaire)
                }
            }
            ForEach(questionsSuggerees, id: \.self) { question in
                Button(question) { envoyer(question) }
                    .buttonStyle(.pilule(.contour, compacte: true))
            }
        }
    }

    private var questionsSuggerees: [String] {
        [
            "Qu'est-ce qu'il reste à acheter ?",
            "Résume nos pense-bêtes en attente",
            "Une idée de cadeau pour \(identite.membre.autre.prenom) ?",
        ]
    }

    private func carteConfiguration(_ manque: String) -> some View {
        Carte(contour: .commun) {
            VStack(alignment: .leading, spacing: 10) {
                Label("À configurer", systemImage: "gearshape")
                    .font(.jubloSousTitre)
                    .foregroundStyle(.texte)
                Text("Choisis un fournisseur d'IA dans les réglages pour commencer.")
                    .font(.jubloCorps)
                    .foregroundStyle(.texte)
                Text(manque)
                    .font(.jubloLegende)
                    .foregroundStyle(.texteSecondaire)
                NavigationLink("Ouvrir les réglages") {
                    ReglagesAssistantView()
                }
                .buttonStyle(.pilule)
            }
        }
    }

    private func carteErreur(_ erreur: ErreurAssistant) -> some View {
        Carte {
            VStack(alignment: .leading, spacing: 10) {
                Label(erreur.localizedDescription, systemImage: "exclamationmark.triangle")
                    .font(.jubloCorps)
                    .foregroundStyle(.texte)
                Button("Réessayer") {
                    guard let service = configuration.service() else { return }
                    discussion.reessayer(consignes: consignes, service: service)
                }
                .buttonStyle(.pilule(.contour, compacte: true))
            }
        }
    }

    private var barreSaisie: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Demande à l'assistant…", text: $saisie, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.jubloCorps)
                    .foregroundStyle(.texte)
                    .padding(.horizontal, Mesures.marge)
                    .padding(.vertical, 11)
                    .frame(minHeight: Mesures.zoneTactile)
                    .background(.surface, in: .rect(cornerRadius: 22, style: .continuous))
                    .disabled(configuration.manque != nil)
                    .accessibilityIdentifier("saisieAssistant")
                if discussion.enCours {
                    Button {
                        discussion.arreter()
                    } label: {
                        Image(systemName: "stop.fill")
                            .accessibilityLabel("Arrêter")
                    }
                    .buttonStyle(.pilule)
                } else {
                    Button {
                        envoyer(saisie)
                    } label: {
                        Image(systemName: "arrow.up")
                            .accessibilityLabel("Envoyer")
                    }
                    .buttonStyle(.pilule)
                    .disabled(saisie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || configuration.manque != nil)
                }
            }
            Text(configuration.simulee
                 ? "Réponses simulées (debug)."
                 : "Vos listes sont envoyées à \(configuration.destination) avec chaque question.")
                .font(.jubloLegende)
                .foregroundStyle(.texteSecondaire)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Mesures.marge)
        .padding(.vertical, 8)
        .background(.fond)
    }

    // MARK: - Actions

    private var consignes: String {
        ContexteAssistant.consignes(pour: identite.membre, elements: elements)
    }

    private func envoyer(_ question: String) {
        guard let service = configuration.service() else { return }
        discussion.envoyer(question, consignes: consignes, service: service)
        saisie = ""
    }
}

/// Bulle d'un message : à droite aux couleurs du membre pour ses questions,
/// à gauche sur une surface pour l'assistant. Le Markdown simple est mis en forme.
private struct BulleMessage: View {
    let message: Discussion.Message
    let enAttente: Bool

    @Environment(Identite.self) private var identite

    var body: some View {
        HStack {
            if message.auteur == .moi { Spacer(minLength: 48) }
            Group {
                if enAttente {
                    ProgressView()
                        .accessibilityLabel("L'assistant écrit")
                } else {
                    Text(Self.miseEnForme(message.texte))
                        .font(.jubloCorps)
                        .foregroundStyle(.texte)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(fond, in: .rect(cornerRadius: Mesures.rayonCarte, style: .continuous))
            if message.auteur == .assistant { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.auteur == .moi ? "Toi" : "Assistant") : \(texteLu)")
    }

    /// Texte sans la syntaxe Markdown, pour VoiceOver.
    private var texteLu: String {
        String(Self.miseEnForme(message.texte).characters)
    }

    private var fond: Color {
        message.auteur == .moi ? identite.membre.couleurDouce : .surface
    }

    static func miseEnForme(_ texte: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: texte, options: options)) ?? AttributedString(texte)
    }
}

#if DEBUG
#Preview {
    NavigationStack { AssistantView() }.apercuJublo()
}
#endif
