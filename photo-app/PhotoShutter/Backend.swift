import Foundation

struct Session: Codable {
    var access: String
    var refresh: String
    var userId: String
    var expires: Date
}

enum BackendError: Error { case auth, server(Int) }

actor Backend {
    static let shared = Backend()
    private var session: Session? = Backend.stored()

    static func stored() -> Session? {
        guard let d = UserDefaults.standard.data(forKey: "session") else { return nil }
        return try? JSONDecoder().decode(Session.self, from: d)
    }

    private func store(_ s: Session?) {
        session = s
        if let s, let d = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(d, forKey: "session")
        } else {
            UserDefaults.standard.removeObject(forKey: "session")
        }
    }

    private struct TokenResp: Decodable {
        struct U: Decodable { let id: String }
        let access_token: String
        let refresh_token: String
        let expires_in: Double
        let user: U
    }

    private func tokenRequest(grant: String, body: [String: String]) async throws -> Session {
        var r = URLRequest(url: URL(string: "\(Config.url)/auth/v1/token?grant_type=\(grant)")!)
        r.httpMethod = "POST"
        r.setValue(Config.key, forHTTPHeaderField: "apikey")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (d, resp) = try await URLSession.shared.data(for: r)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw BackendError.auth }
        let t = try JSONDecoder().decode(TokenResp.self, from: d)
        return Session(access: t.access_token, refresh: t.refresh_token,
                       userId: t.user.id, expires: Date().addingTimeInterval(t.expires_in))
    }

    func signIn(email: String, password: String) async throws {
        store(try await tokenRequest(grant: "password", body: ["email": email, "password": password]))
    }

    func signOut() { store(nil) }

    private func current() async throws -> Session {
        guard var s = session else { throw BackendError.auth }
        if s.expires.timeIntervalSinceNow < 60 {
            s = try await tokenRequest(grant: "refresh_token", body: ["refresh_token": s.refresh])
            store(s)
        }
        return s
    }

    func upload(_ data: Data, name: String) async throws {
        let s = try await current()
        let path = "\(s.userId)/\(name)"

        var r = URLRequest(url: URL(string: "\(Config.url)/storage/v1/object/\(Config.bucket)/\(path)")!)
        r.httpMethod = "POST"
        r.setValue(Config.key, forHTTPHeaderField: "apikey")
        r.setValue("Bearer \(s.access)", forHTTPHeaderField: "Authorization")
        r.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        r.httpBody = data
        let (body, resp) = try await URLSession.shared.data(for: r)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let duplicate = String(data: body, encoding: .utf8)?.contains("Duplicate") ?? false
        guard (200..<300).contains(code) || duplicate else { throw BackendError.server(code) }

        var q = URLRequest(url: URL(string: "\(Config.url)/rest/v1/photos")!)
        q.httpMethod = "POST"
        q.setValue(Config.key, forHTTPHeaderField: "apikey")
        q.setValue("Bearer \(s.access)", forHTTPHeaderField: "Authorization")
        q.setValue("application/json", forHTTPHeaderField: "Content-Type")
        q.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        q.httpBody = try JSONSerialization.data(withJSONObject: ["path": path])
        let (_, resp2) = try await URLSession.shared.data(for: q)
        let code2 = (resp2 as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code2) || code2 == 409 else { throw BackendError.server(code2) }
    }
}
