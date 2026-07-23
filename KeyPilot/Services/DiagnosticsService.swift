import Foundation

final class DiagnosticsService: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [DiagnosticEvent] = []
    var onChange: (([DiagnosticEvent]) -> Void)?

    func record(_ level: DiagnosticLevel, module: String, message: String) {
        let snapshot: [DiagnosticEvent]
        lock.lock()
        events.insert(DiagnosticEvent(level: level, module: module, message: message), at: 0)
        if events.count > 100 { events.removeLast(events.count - 100) }
        snapshot = events
        lock.unlock()
        DispatchQueue.main.async { [weak self] in self?.onChange?(snapshot) }
    }

    func currentEvents() -> [DiagnosticEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }

    func clear() {
        lock.lock()
        events.removeAll()
        lock.unlock()
        DispatchQueue.main.async { [weak self] in self?.onChange?([]) }
    }
}
