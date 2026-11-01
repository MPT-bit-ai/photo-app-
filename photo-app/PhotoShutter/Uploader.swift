import Foundation

@MainActor
final class Uploader: ObservableObject {
    @Published var pending = 0
    @Published var sent = 0
    @Published var status = ""
    private var busy = false

    private let dir: URL = {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("queue")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    init() {
        refresh()
        Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.flush() }
        }
    }

    private func files() -> [URL] {
        let all = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return all.filter { $0.pathExtension == "jpg" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func refresh() { pending = files().count }

    func enqueue(_ data: Data) {
        let name = "\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(6)).jpg"
        try? data.write(to: dir.appendingPathComponent(name))
        refresh()
        Task { await flush() }
    }

    func flush() async {
        guard !busy, Backend.stored() != nil else { return }
        busy = true
        defer { busy = false }
        for f in files() {
            guard let d = try? Data(contentsOf: f) else { continue }
            do {
                try await Backend.shared.upload(d, name: f.lastPathComponent)
                try? FileManager.default.removeItem(at: f)
                sent += 1
                status = ""
            } catch {
                status = "Нет связи, отправлю позже"
                break
            }
            refresh()
        }
        refresh()
    }
}
