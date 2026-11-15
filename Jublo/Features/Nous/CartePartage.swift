import CloudKit
import OSLog
import SwiftUI
import UIKit

/// Partage des listes avec l'autre membre (iCloud) et état de la synchronisation.
struct CartePartage: View {
    @Environment(Synchronisation.self) private var synchronisation
    @Environment(Identite.self) private var identite

    @State private var enPreparation = false
    @State private var erreur: String?
    @State private var confirmerDepart = false
    /// Retenu ici : la feuille de partage ne garde qu'une référence faible à son délégué.
    @State private var delegue: DelegueFeuillePartage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TitreSection(titre: "Partage")
            Carte(contour: .commun) {
                VStack(alignment: .leading, spacing: Mesures.espacement) {
                    HStack(spacing: Mesures.espacement) {
                        HStack(spacing: -8) {
                            PastilleMembre(membre: identite.membre)
                            PastilleMembre(membre: identite.membre.autre)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(titre)
                                .font(.jubloCorpsFort)
                                .foregroundStyle(.texte)
                            Text(statut)
                                .font(.jubloLegende)
                                .foregroundStyle(.texteSecondaire)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    action
                    if let erreur {
                        Text(erreur)
                            .font(.jubloLegende)
                            .foregroundStyle(.pablo)
                    }
                }
            }
        }
        .confirmationDialog("Quitter le partage ?", isPresented: $confirmerDepart, titleVisibility: .visible) {
            Button("Quitter le partage", role: .destructive) {
                Task {
                    do {
                        try await synchronisation.quitterPartage()
                    } catch {
                        erreur = Synchronisation.message(error)
                    }
                }
            }
        } message: {
            Text("Tes listes resteront sur cet iPhone, mais ne seront plus partagées avec \(autre).")
        }
    }

    private var autre: String { identite.membre.autre.prenom }

    private var titre: String {
        switch synchronisation.etatPartage {
        case .aucun: "Pas encore partagé"
        case .invitationEnvoyee: "Invitation envoyée à \(autre)"
        case .actif: "Partagé avec \(autre)"
        case .participant: "Partagé par \(autre)"
        }
    }

    private var statut: String {
        switch synchronisation.etat {
        case .inactive(let message), .erreur(let message): message
        case .enCours: "Synchronisation…"
        case .aJour(let date): "À jour · \(Formats.relatif(date))"
        }
    }

    private var iCloudDisponible: Bool {
        if case .inactive = synchronisation.etat { false } else { true }
    }

    @ViewBuilder
    private var action: some View {
        switch synchronisation.etatPartage {
        case .aucun:
            Button(enPreparation ? "Préparation…" : "Inviter \(autre)", action: inviter)
                .buttonStyle(.pilule)
                .disabled(enPreparation || !iCloudDisponible)
        case .invitationEnvoyee, .actif:
            Button("Gérer le partage", action: inviter)
                .buttonStyle(.pilule(.contour, compacte: true))
        case .participant:
            Button("Quitter le partage") { confirmerDepart = true }
                .buttonStyle(.pilule(.contour, compacte: true))
        }
    }

    private func inviter() {
        enPreparation = true
        erreur = nil
        Task {
            defer { enPreparation = false }
            do {
                let partage = try await synchronisation.preparerPartage()
                let feuille = UICloudSharingController(share: partage, container: synchronisation.conteneurCloudKit)
                feuille.availablePermissions = [.allowReadWrite, .allowPrivate]
                let delegue = DelegueFeuillePartage(synchronisation: synchronisation)
                feuille.delegate = delegue
                self.delegue = delegue
                presenter(feuille)
            } catch {
                erreur = Synchronisation.message(error)
            }
        }
    }

    /// La feuille de partage d'iOS se présente depuis UIKit, au-dessus de l'écran courant.
    private func presenter(_ controleur: UIViewController) {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard var haut = scene?.keyWindow?.rootViewController else { return }
        while let presente = haut.presentedViewController {
            haut = presente
        }
        haut.present(controleur, animated: true)
    }
}

/// Délégué de la feuille de partage d'iOS.
final class DelegueFeuillePartage: NSObject, UICloudSharingControllerDelegate {
    private let synchronisation: Synchronisation

    init(synchronisation: Synchronisation) {
        self.synchronisation = synchronisation
    }

    func itemTitle(for csc: UICloudSharingController) -> String? {
        "Jublo"
    }

    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        Logger(subsystem: "com.pmassereyes.jublo", category: "Partage").error("Partage non enregistré : \(error)")
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        synchronisation.partageMisAJour(csc.share)
    }

    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        synchronisation.partageMisAJour(nil)
    }
}
