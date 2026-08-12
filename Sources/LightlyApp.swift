import SwiftUI

@main
struct LightlyApp: App {
    @StateObject private var store = CompressionStore()
    @StateObject private var purchaseManager = PurchaseManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(purchaseManager)
        }
    }
}
