import SwiftUI

/// Formulaire présenté en feuille : « Annuler » et « Enregistrer » en haut, sections sur fond
/// Jublo. `enregistrer` est appelé seulement si `peutEnregistrer`, puis la feuille se ferme.
struct Formulaire<Contenu: View>: View {
    let titre: String
    var libelleEnregistrer = "Enregistrer"
    let peutEnregistrer: Bool
    let enregistrer: () -> Void
    @ViewBuilder var contenu: Contenu

    @Environment(\.dismiss) private var fermer

    var body: some View {
        NavigationStack {
            Form {
                contenu
                    .listRowBackground(Color.surface)
            }
            .font(.jubloCorps)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(.fond)
            .navigationTitle(titre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { fermer() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(libelleEnregistrer) {
                        enregistrer()
                        fermer()
                    }
                    .fontWeight(.semibold)
                    .disabled(!peutEnregistrer)
                }
            }
        }
        .tint(.texte)
    }
}

/// Saisie d'un montant en euros (« 12,50 »), avec le clavier numérique.
struct ChampMontant: View {
    let titre: String
    @Binding var saisie: String

    var body: some View {
        HStack {
            TextField(titre, text: $saisie)
                .keyboardType(.decimalPad)
            Text("€")
                .foregroundStyle(.texteSecondaire)
                .accessibilityHidden(true)
        }
    }
}

/// Bouton « Ajouter » de la barre de navigation.
struct BoutonAjouter: View {
    let libelle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .accessibilityLabel(libelle)
        }
    }
}

/// Carte cliquable qui mène à une rubrique : symbole, titre, résumé et chevron.
struct CarteRubrique: View {
    let titre: String
    let symbole: String
    let resume: String

    var body: some View {
        Carte {
            HStack(spacing: Mesures.espacement) {
                Image(systemName: symbole)
                    .font(.system(size: 22))
                    .foregroundStyle(.texte)
                    .frame(width: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titre)
                        .font(.jubloCorpsFort)
                        .foregroundStyle(.texte)
                    Text(resume)
                        .font(.jubloLegende)
                        .foregroundStyle(.texteSecondaire)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.texteSecondaire)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: Mesures.zoneTactile)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Cœurs de 1 à 5 d'un avis, en lecture seule.
struct Coeurs: View {
    let avis: Int?
    let couleur: Color
    var taille: CGFloat = 13

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { rang in
                Image(systemName: rang <= (avis ?? 0) ? "heart.fill" : "heart")
                    .font(.system(size: taille))
                    .foregroundStyle(rang <= (avis ?? 0) ? couleur : Color.separateur)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(avis.map { "\($0) sur 5" } ?? "Pas encore noté")
    }
}

/// Avis des deux membres : celui du membre courant se modifie (toucher le même cœur
/// l'efface), celui de l'autre est en lecture seule.
struct NotesDuCouple: View {
    let avisDe: (Membre) -> Int?
    let noter: (Int?) -> Void

    @Environment(Identite.self) private var identite

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ligne(identite.membre, modifiable: true)
            ligne(identite.membre.autre, modifiable: false)
        }
    }

    private func ligne(_ membre: Membre, modifiable: Bool) -> some View {
        HStack(spacing: Mesures.espacement) {
            PastilleMembre(membre: membre, taille: 26)
            Text(Libelles.quiEnDebut(membre, vuPar: identite.membre))
                .font(.jubloCorpsFort)
                .frame(minWidth: 56, alignment: .leading)
            Spacer(minLength: 0)
            if modifiable {
                HStack(spacing: 0) {
                    ForEach(1...5, id: \.self) { rang in
                        let plein = rang <= (avisDe(membre) ?? 0)
                        Button {
                            noter(avisDe(membre) == rang ? nil : rang)
                        } label: {
                            Image(systemName: plein ? "heart.fill" : "heart")
                                .font(.system(size: 20))
                                .foregroundStyle(plein ? membre.couleur : Color.separateur)
                                .frame(width: 36, height: Mesures.zoneTactile)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(rang) sur 5")
                        .accessibilityAddTraits(avisDe(membre) == rang ? .isSelected : [])
                    }
                }
            } else {
                Coeurs(avis: avisDe(membre), couleur: membre.couleur, taille: 18)
                    .frame(minHeight: Mesures.zoneTactile)
            }
        }
        .accessibilityElement(children: modifiable ? .contain : .combine)
    }
}

/// Ligne d'information d'un écran de détail : symbole et texte.
struct LigneInfo: View {
    let symbole: String
    let texte: String

    var body: some View {
        Label {
            Text(texte)
                .font(.jubloCorps)
                .foregroundStyle(.texte)
        } icon: {
            Image(systemName: symbole)
                .foregroundStyle(.texteSecondaire)
        }
    }
}
