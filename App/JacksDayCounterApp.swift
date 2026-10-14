import SwiftUI

@main
struct JacksDayCounterApp: App {
    @State private var auth = AuthService()
    @State private var store = CountdownStore()
    @State private var outlook = OutlookService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(store)
                .environment(outlook)
                .onAppear { store.outlook = outlook }
        }
    }
}
