import Foundation

/// Attentes bornées dans le temps.
enum Attente {
    /// Attend `operation` au plus `delai`. Au-delà, rend la main et laisse l'opération finir
    /// seule (raccourci Siri : la réponse ne doit pas dépendre du réseau).
    ///
    /// Pas de `withTaskGroup` ici : un groupe attend tous ses enfants avant de rendre la main,
    /// même annulés, donc il ne bornerait rien. Les deux tâches sont libres et la première
    /// arrivée débloque le flux.
    static func auPlus(_ delai: Duration, _ operation: @escaping @Sendable () async -> Void) async {
        let (signal, suite) = AsyncStream.makeStream(of: Void.self)
        Task {
            await operation()
            suite.yield()
        }
        let minuteur = Task {
            try? await Task.sleep(for: delai)
            suite.yield()
        }
        for await _ in signal { break }
        minuteur.cancel()
        suite.finish()
    }
}
