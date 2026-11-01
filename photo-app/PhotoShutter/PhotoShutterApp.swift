import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var loggedIn = Backend.stored() != nil
    @Published var error = ""
    @Published var busy = false
    let uploader = Uploader()
    let camera = CameraModel()

    init() {
        camera.onPhoto = { [weak self] data in
            Task { @MainActor in self?.uploader.enqueue(data) }
        }
    }

    func signIn(email: String, password: String) async {
        busy = true
        error = ""
        do {
            try await Backend.shared.signIn(email: email, password: password)
            loggedIn = true
            await uploader.flush()
        } catch {
            self.error = "Неверная почта или пароль"
        }
        busy = false
    }

    func signOut() {
        Task { await Backend.shared.signOut() }
        loggedIn = false
    }
}

@main
struct PhotoShutterApp: App {
    @StateObject private var state = AppState()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .preferredColorScheme(.dark)
        }
    }
}
