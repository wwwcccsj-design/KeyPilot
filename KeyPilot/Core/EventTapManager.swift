import CoreGraphics
import Foundation

enum EventTapStatus: Equatable, Sendable {
    case stopped
    case running
    case recovering(attempt: Int)
    case failed(String)

    var displayName: String {
        switch self {
        case .stopped: return "已停止"
        case .running: return "运行中"
        case let .recovering(attempt): return "恢复中（第 \(attempt) 次）"
        case let .failed(message): return "异常：\(message)"
        }
    }
}

final class EventTapManager: @unchecked Sendable {
    typealias EventHandler = (CGEventType, CGEvent) -> CGEvent?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var recoveryAttempt = 0
    private var handler: EventHandler?
    var onStatusChange: ((EventTapStatus) -> Void)?
    var onDisabled: ((CGEventType) -> Void)?

    func start(handler: @escaping EventHandler) throws {
        stop()
        self.handler = handler
        let mask = eventMask(for: [.keyDown, .keyUp, .flagsChanged])
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: userInfo
        ) else {
            onStatusChange?(.failed("创建失败，请检查辅助功能权限"))
            throw KeyPilotError.eventTapCreationFailed
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        guard CGEvent.tapIsEnabled(tap: tap) else {
            stop()
            throw KeyPilotError.eventTapEnableFailed
        }
        recoveryAttempt = 0
        onStatusChange?(.running)
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        runLoopSource = nil
        eventTap = nil
        handler = nil
        recoveryAttempt = 0
        onStatusChange?(.stopped)
    }

    fileprivate func process(type: CGEventType, event: CGEvent) -> CGEvent? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            onDisabled?(type)
            attemptRecovery()
            return event
        }
        return handler?(type, event) ?? event
    }

    private func attemptRecovery() {
        guard let eventTap else {
            onStatusChange?(.failed("事件监听器已释放"))
            return
        }
        recoveryAttempt += 1
        onStatusChange?(.recovering(attempt: recoveryAttempt))
        CGEvent.tapEnable(tap: eventTap, enable: true)
        if CGEvent.tapIsEnabled(tap: eventTap) {
            recoveryAttempt = 0
            onStatusChange?(.running)
            return
        }

        guard recoveryAttempt < 5 else {
            onStatusChange?(.failed("自动恢复失败，请手动重启键盘引擎"))
            return
        }
        let delay = min(pow(2.0, Double(recoveryAttempt - 1)) * 0.25, 4.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.attemptRecovery()
        }
    }

    private func eventMask(for types: [CGEventType]) -> CGEventMask {
        types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
    }
}

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let manager = Unmanaged<EventTapManager>.fromOpaque(userInfo).takeUnretainedValue()
    guard let processed = manager.process(type: type, event: event) else { return nil }
    return Unmanaged.passUnretained(processed)
}
