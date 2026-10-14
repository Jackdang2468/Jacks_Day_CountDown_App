import SwiftUI

@main
struct JacksDayCounterApp: App {
    @State private var auth = AuthService()
    @State private var store = CountdownStore()
    @State private var outlook = OutlookService()
    @State private var appLock = AppLock()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(store)
                .environment(outlook)
                .environment(appLock)
                .onAppear { store.outlook = outlook }
        }
    }
}
