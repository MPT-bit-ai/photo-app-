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
            Buzz.shutter()
            Task { @MainActor in self?.uploader.enqueue(data) }
        }
    }

    func signIn(email: String, password: String, serverUrl: String, serverKey: String) async {
        busy = true
        error = ""
        let old = Config.snapshot()
        Config.save(url: serverUrl, key: serverKey)
        do {
            try await Backend.shared.signIn(email: email, password: password)
            loggedIn = true
            await uploader.flush()
        } catch {
            Config.restore(old)
            self.error = "Не удалось войти. Проверьте почту, пароль и адрес сервера"
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
