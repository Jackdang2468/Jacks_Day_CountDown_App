import SwiftUI

struct RootView: View {
    @Environment(AuthService.self) private var auth
    @Environment(CountdownStore.self) private var store
    @Environment(OutlookService.self) private var outlook
    @Environment(AppLock.self) private var appLock
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
        .overlay {
            if appLock.isLocked {
                LockScreen()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                store.refreshSystemFeatures()
                Task { await store.syncNow() }
            case .background:
                appLock.lock()
            default:
                break
            }
        }
    }
}

private struct LockScreen: View {
    @Environment(AppLock.self) private var appLock

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThickMaterial).ignoresSafeArea()
            VStack(spacing: 20) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                Text("Day Counter is locked")
                    .font(.title3.bold())
                if let error = appLock.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.secondary)
                }
                Button("Unlock with \(appLock.biometryName)") {
                    Task { await appLock.unlock() }
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            }
            .padding()
        }
        .task { await appLock.unlock() }
    }
}
