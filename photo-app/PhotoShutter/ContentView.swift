import SwiftUI

struct ContentView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.scenePhase) private var phase

    var body: some View {
        Group {
            if app.loggedIn { CameraScreen() } else { LoginScreen() }
        }
        .onChange(of: phase) { _, p in
            if p == .active { Task { await app.uploader.flush() } }
        }
    }
}

struct LoginScreen: View {
    @EnvironmentObject var app: AppState
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 12) {
            Text("Вход").font(.title.bold()).frame(maxWidth: .infinity, alignment: .leading)
            TextField("Почта", text: $email)
                .textContentType(.username).keyboardType(.emailAddress)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .padding(12).background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            SecureField("Пароль", text: $password)
                .textContentType(.password)
                .padding(12).background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            Text(app.error).foregroundStyle(.red).font(.footnote).frame(maxWidth: .infinity, alignment: .leading)
            Button {
                Task { await app.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password) }
            } label: {
                Text(app.busy ? "Входим…" : "Войти").frame(maxWidth: .infinity).padding(12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(app.busy || email.isEmpty || password.isEmpty)
        }
        .padding(24)
    }
}

struct CameraScreen: View {
    @EnvironmentObject var app: AppState
    @State private var flash = false

    var body: some View {
        ZStack {
            CameraPreview(session: app.camera.session) { shoot() }
                .ignoresSafeArea()
            Color.white.opacity(flash ? 0.6 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            VStack {
                StatusBar(uploader: app.uploader) { app.signOut() }
                Spacer()
                Button { shoot() } label: {
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .background(Circle().fill(.white.opacity(0.85)).padding(8))
                        .frame(width: 76, height: 76)
                }
                .accessibilityLabel("Сделать фото")
                .padding(.bottom, 30)
            }
        }
        .onAppear { app.camera.start() }
        .onDisappear { app.camera.stop() }
    }

    private func shoot() {
        app.camera.shoot()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        flash = true
        withAnimation(.easeOut(duration: 0.2)) { flash = false }
    }
}

struct StatusBar: View {
    @ObservedObject var uploader: Uploader
    var onLogout: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Отправлено: \(uploader.sent)  В очереди: \(uploader.pending)")
                if !uploader.status.isEmpty { Text(uploader.status).foregroundStyle(.orange) }
            }
            .font(.footnote)
            .padding(8)
            .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            Spacer()
            Button("Выйти", action: onLogout)
                .font(.footnote)
                .padding(8)
                .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
}
