import AppKit
import CoreGraphics
import Darwin
import Foundation

@main
struct CoreSmoke {
    private static var checks = 0
    private static var failures = 0

    static func main() {
        setbuf(stdout, nil)
        runRuleChecks()
        runMatcherChecks()
        runConfigurationChecks()
        runResolverChecks()
        print("CORE_SMOKE_CHECKS=\(checks) PASS=\(checks - failures) FAIL=\(failures)")
        if failures > 0 { exit(1) }
    }

    private static func check(_ condition: @autoclosure () -> Bool, _ name: String) {
        checks += 1
        if condition() {
            print("PASS \(name)")
        } else {
            failures += 1
            print("FAIL \(name)")
        }
    }

    private static func expectThrow(_ name: String, _ body: () throws -> Void) {
        checks += 1
        do {
            try body()
            failures += 1
            print("FAIL \(name)")
        } catch {
            print("PASS \(name)")
        }
    }

    private static func runRuleChecks() {
        let a = KeyDescriptor(keyCode: 0)
        let b = KeyDescriptor(keyCode: 11)
        let comma = KeyDescriptor(keyCode: 43)
        let c = KeyDescriptor(keyCode: 8)
        let compiler = RuleCompiler()

        do {
            var configuration = AppConfiguration.default
            configuration.remapRules = [RemapRule(source: a, target: b)]
            let snapshot = try compiler.compile(configuration, version: 1)
            check(snapshot.remapBySource[a.keyCode] == b.keyCode, "one-way mapping")

            configuration.remapRules = [RemapRule(source: b, target: comma, mode: .swap)]
            let swap = try compiler.compile(configuration, version: 2)
            check(swap.remapBySource[b.keyCode] == comma.keyCode, "swap forward")
            check(swap.remapBySource[comma.keyCode] == b.keyCode, "swap reverse")
        } catch {
            failures += 3
            checks += 3
            print("FAIL rule compilation: \(error)")
        }

        expectThrow("self mapping rejected") {
            try ConflictValidator.validateRemaps([RemapRule(source: b, target: b)])
        }
        expectThrow("mapping chain rejected") {
            try ConflictValidator.validateRemaps([
                RemapRule(source: a, target: b),
                RemapRule(source: b, target: c)
            ])
        }

        let target = ApplicationTarget(
            displayName: "Test",
            bundleIdentifier: "com.example.test",
            applicationURL: URL(fileURLWithPath: "/Applications/Test.app")
        )
        let shortcut = ShortcutRule(
            key: c,
            modifiers: [.command, .option],
            action: .launchApplication(target)
        )
        expectThrow("duplicate hotkey rejected") {
            try ConflictValidator.validateShortcuts([shortcut, shortcut])
        }
        let multiPress = MultiPressRule(
            source: a,
            pressCount: 2,
            maxIntervalMilliseconds: 300,
            action: .emitKey(c)
        )
        do {
            var configuration = AppConfiguration.default
            configuration.multiPressRules = [multiPress]
            let snapshot = try compiler.compile(configuration, version: 3)
            check(snapshot.multiPressBySource[a.keyCode]?.action == .emitKey(c),
                  "multi-press action compilation")
        } catch {
            checks += 1
            failures += 1
            print("FAIL multi-press compilation: \(error)")
        }
        expectThrow("duplicate multi-press source rejected") {
            try ConflictValidator.validateMultiPressRules([multiPress, multiPress])
        }
        expectThrow("multi-press and remap source conflict rejected") {
            try ConflictValidator.validateMultiPressRules(
                [multiPress],
                remapRules: [RemapRule(source: a, target: b)]
            )
        }
        check(ModifierSet(cgFlags: [.maskCommand, .maskAlternate, .maskAlphaShift]) == [.command, .option],
              "modifier normalization")
    }

    private static func runMatcherChecks() {
        let matcher = HotkeyMatcher()
        let signature = HotkeySignature(keyCode: 8, modifiers: [.command])
        check(matcher.shouldTrigger(signature: signature, eventType: .keyDown, isAutorepeat: false),
              "first keyDown triggers")
        check(!matcher.shouldTrigger(signature: signature, eventType: .keyDown, isAutorepeat: false),
              "held key does not retrigger")
        _ = matcher.release(keyCode: 8)
        check(matcher.shouldTrigger(signature: signature, eventType: .keyDown, isAutorepeat: false),
              "keyUp release permits next trigger")

        let remapMatcher = RemapMatcher()
        let snapshot = RuntimeRuleSnapshot(version: 1, remapBySource: [11: 43], hotkeys: [:])
        check(remapMatcher.target(for: 11, eventType: .keyDown, in: snapshot) == 43, "keyDown remapped")
        check(remapMatcher.target(for: 11, eventType: .keyUp, in: .empty) == 43,
              "keyUp retains pressed mapping")
    }

    private static func runConfigurationChecks() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeyPilotCoreSmoke-\(UUID().uuidString)", isDirectory: true)
        defer {
            do {
                if FileManager.default.fileExists(atPath: directory.path) {
                    try FileManager.default.removeItem(at: directory)
                }
            } catch {
                print("WARN cleanup failed: \(error.localizedDescription)")
            }
        }
        let store = ConfigurationStore(directoryURL: directory)
        do {
            let initial = try store.load()
            check(initial == .default, "default configuration")
            var expected = initial
            expected.remapRules = [RemapRule(source: KeyDescriptor(keyCode: 0), target: KeyDescriptor(keyCode: 11))]
            try store.save(expected)
            let roundTrip = try store.load()
            check(roundTrip == expected, "configuration round trip")
            try Data("invalid".utf8).write(to: store.configurationURL, options: .atomic)
            let recovered = try store.load()
            check(recovered == expected, "backup recovery")

            let legacyJSON = """
            {
              "schemaVersion": 1,
              "globalEnabled": true,
              "launchAtLogin": false,
              "showTriggerNotification": false,
              "remapRules": [],
              "shortcutRules": []
            }
            """
            try Data(legacyJSON.utf8).write(to: store.configurationURL, options: .atomic)
            let legacy = try store.load()
            check(legacy.multiPressRules.isEmpty, "legacy configuration compatibility")
        } catch {
            checks += 4
            failures += 4
            print("FAIL configuration checks: \(error)")
        }
    }

    private static func runResolverChecks() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeyPilotResolverSmoke-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let appURL = directory.appendingPathComponent("Valid.app", isDirectory: true)
            try FileManager.default.createDirectory(at: appURL, withIntermediateDirectories: true)
            let target = ApplicationTarget(displayName: "Valid", bundleIdentifier: nil, applicationURL: appURL)
            let resolution = try ApplicationResolver(workspace: SmokeWorkspace()).resolve(target)
            if case let .open(url) = resolution {
                check(url == appURL, "valid application launch request")
            } else {
                check(false, "valid application launch request")
            }
            try FileManager.default.removeItem(at: directory)
        } catch {
            checks += 1
            failures += 1
            print("FAIL resolver check: \(error)")
        }
    }
}

private struct SmokeWorkspace: WorkspaceProviding {
    func runningApplication(bundleIdentifier: String) -> RunningApplicationProviding? { nil }
    func applicationURL(bundleIdentifier: String) -> URL? { nil }
    func openApplication(
        at url: URL,
        configuration: NSWorkspace.OpenConfiguration,
        completionHandler: @escaping (NSRunningApplication?, Error?) -> Void
    ) {
        completionHandler(nil, nil)
    }
}
