import SwiftUI

@main
struct JacksDayCounterApp: App {
    @State private var auth = AuthService()
    @State private var store = CountdownStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(store)
        }
    }
}
