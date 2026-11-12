#if DEBUG
import Foundation

/// Réponses simulées, sans fournisseur : aperçus Xcode et tests d'interface
/// (`-assistantSimule` au lancement).
struct ServiceSimule: ServiceDiscussion {
    var delai: Duration = .milliseconds(25)

    func repondre(a messages: [MessageIA]) -> AsyncThrowingStream<String, Error> {
        let question = messages.last { $0.role == .utilisateur }?.contenu ?? ""
        let elements = messages.first?.contenu.split(separator: "\n").filter { $0.hasPrefix("- ") }.count ?? 0
        let reponse = "Réponse simulée : tu m'as demandé « \(question) ». Je vois **\(elements) éléments** dans vos listes."
        let delai = delai
        return AsyncThrowingStream { continuation in
            let tache = Task {
                for mot in reponse.split(separator: " ") {
                    try? await Task.sleep(for: delai)
                    if Task.isCancelled { break }
                    continuation.yield("\(mot) ")
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in tache.cancel() }
        }
    }
}
#endif
