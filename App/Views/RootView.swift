import SwiftUI

struct RootView: View {
    @Environment(AuthService.self) private var auth
    @Environment(CountdownStore.self) private var store
    @Environment(OutlookService.self) private var outlook
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch auth.state {
            case .loading:
                ProgressView()
            case .signedOut:
                AuthView()
            case .signedIn, .offline:
                CountdownListView()
            }
        }
        .animation(.smooth, value: auth.state)
        .task(id: auth.state) {
            switch auth.state {
            case .signedIn(let id, _): await store.attach(userID: id)
            case .signedOut:
                store.signedOut()
                outlook.disconnect()
            default: break
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.syncNow() } }
        }
    }
}
