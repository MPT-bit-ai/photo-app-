import Foundation

enum Config {
    static let defaultUrl = "https://gisjcvenulyituqshdrz.supabase.co"
    static let defaultKey = "sb_publishable_LVGjAvz7YWdtY5L7Cn0sRg_Uy2FN2kY"
    static let bucket = "photos"

    static var url: String { UserDefaults.standard.string(forKey: "custom_url") ?? defaultUrl }
    static var key: String { UserDefaults.standard.string(forKey: "custom_key") ?? defaultKey }
    static var customUrl: String { UserDefaults.standard.string(forKey: "custom_url") ?? "" }
    static var customKey: String { UserDefaults.standard.string(forKey: "custom_key") ?? "" }

    static func save(url: String, key: String) {
        let u = normalize(url)
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if let u, !k.isEmpty {
            set(u, "custom_url")
            set(k, "custom_key")
        } else {
            set(nil, "custom_url")
            set(nil, "custom_key")
        }
    }

    static func snapshot() -> (String?, String?) {
        (UserDefaults.standard.string(forKey: "custom_url"),
         UserDefaults.standard.string(forKey: "custom_key"))
    }

    static func restore(_ s: (String?, String?)) {
        set(s.0, "custom_url")
        set(s.1, "custom_key")
    }

    private static func set(_ v: String?, _ k: String) {
        if let v { UserDefaults.standard.set(v, forKey: k) }
        else { UserDefaults.standard.removeObject(forKey: k) }
    }

    private static func normalize(_ s: String) -> String? {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        if !t.hasPrefix("http") { t = "https://" + t }
        while t.hasSuffix("/") { t.removeLast() }
        return t
    }
}
