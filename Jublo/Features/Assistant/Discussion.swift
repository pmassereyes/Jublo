import Foundation
import Observation

/// Une discussion avec l'assistant, gardée en mémoire le temps de l'écran.
@MainActor
@Observable
final class Discussion {
    struct Message: Identifiable, Equatable {
        enum Auteur {
            case moi
            case assistant
        }

        let id = UUID()
        let auteur: Auteur
        var texte: String
    }

    /// Nombre de messages précédents renvoyés au modèle avec chaque question.
    static let historiqueMax = 12

    private(set) var messages: [Message] = []
    private(set) var enCours = false
    private(set) var erreur: ErreurAssistant?

    private var tache: Task<Void, Never>?
    private var derniereQuestion: String?

    func envoyer(_ question: String, consignes: String, service: any ServiceDiscussion) {
        let question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !enCours else { return }
        erreur = nil
        derniereQuestion = question
        messages.append(Message(auteur: .moi, texte: question))

        let historique = [MessageIA(role: .systeme, contenu: consignes)]
            + messages.suffix(Self.historiqueMax).map {
                MessageIA(role: $0.auteur == .moi ? .utilisateur : .assistant, contenu: $0.texte)
            }
        let reponse = Message(auteur: .assistant, texte: "")
        messages.append(reponse)
        enCours = true

        tache = Task {
            do {
                for try await morceau in service.repondre(a: historique) {
                    completer(reponse.id, avec: morceau)
                }
                if !Task.isCancelled, texte(de: reponse.id)?.isEmpty == true {
                    erreur = .reponseInattendue
                }
            } catch is CancellationError {
                // Arrêt demandé : on garde ce qui a déjà été reçu.
            } catch {
                erreur = .depuis(error)
            }
            messages.removeAll { $0.id == reponse.id && $0.texte.isEmpty }
            enCours = false
        }
    }

    /// Renvoie la dernière question restée sans réponse.
    func reessayer(consignes: String, service: any ServiceDiscussion) {
        guard let question = derniereQuestion, !enCours else { return }
        if messages.last?.auteur == .moi {
            messages.removeLast()
        }
        envoyer(question, consignes: consignes, service: service)
    }

    func arreter() {
        tache?.cancel()
    }

    func effacer() {
        arreter()
        messages.removeAll()
        erreur = nil
        derniereQuestion = nil
    }

    /// Attend la fin de la réponse en cours (tests).
    func attendreFin() async {
        await tache?.value
    }

    private func completer(_ id: UUID, avec morceau: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].texte += morceau
    }

    private func texte(de id: UUID) -> String? {
        messages.first { $0.id == id }?.texte
    }
}
