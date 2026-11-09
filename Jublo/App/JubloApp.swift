import SwiftUI

@main
struct JubloApp: App {
    init() {
        Apparence.appliquer()
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            CatalogueDesignSystem()
            #else
            Text("Jublo")
            #endif
        }
    }
}
