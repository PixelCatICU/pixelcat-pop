import XCTest
@testable import PixelCatPop

final class AppCleanerScannerTests: XCTestCase {
    func testFindsBundleRelatedUserLibraryItems() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PixelCatPopScannerTests-\(UUID().uuidString)", isDirectory: true)
        let home = root.appendingPathComponent("Home", isDirectory: true)
        let systemLibrary = root.appendingPathComponent("Library", isDirectory: true)
        let app = root.appendingPathComponent("Example.app", isDirectory: true)
        let info = app.appendingPathComponent("Contents/Info.plist")
        let helperInfo = app.appendingPathComponent("Contents/Library/LoginItems/Example Helper.app/Contents/Info.plist")
        let support = home.appendingPathComponent("Library/Application Support/com.example.testapp", isDirectory: true)
        let cache = home.appendingPathComponent("Library/Caches/com.example.testapp", isDirectory: true)
        let preference = home.appendingPathComponent("Library/Preferences/com.example.testapp.plist")
        let httpStorage = home.appendingPathComponent("Library/HTTPStorages/com.example.testapp", isDirectory: true)
        let crashReport = home.appendingPathComponent("Library/Application Support/CrashReporter/Example_ABC.plist")
        let nestedLog = home.appendingPathComponent("Library/Logs/ExampleVendor/Example", isDirectory: true)
        let daemonContainer = home.appendingPathComponent("Library/Daemon Containers/com.example.testapp", isDirectory: true)
        let systemSupport = systemLibrary.appendingPathComponent("Application Support/ExampleVendor/Example", isDirectory: true)
        let systemPreference = systemLibrary.appendingPathComponent("Preferences/com.example.testapp.plist")
        let systemLaunchAgent = systemLibrary.appendingPathComponent("LaunchAgents/com.example.testapp.plist")
        let systemLaunchDaemon = systemLibrary.appendingPathComponent("LaunchDaemons/com.example.helper.plist")
        let privilegedHelper = systemLibrary.appendingPathComponent("PrivilegedHelperTools/com.example.helper")

        try FileManager.default.createDirectory(at: info.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: helperInfo.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: preference.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: httpStorage, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: crashReport.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nestedLog, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: daemonContainer, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: systemSupport, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: systemPreference.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: systemLaunchAgent.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: systemLaunchDaemon.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: privilegedHelper.deletingLastPathComponent(), withIntermediateDirectories: true)

        let plist: [String: String] = [
            "CFBundleIdentifier": "com.example.testapp",
            "CFBundleName": "Example",
            "CFBundleExecutable": "Example"
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: info)
        let helperPlist: [String: String] = [
            "CFBundleIdentifier": "com.example.helper",
            "CFBundleName": "Example Helper",
            "CFBundleExecutable": "Example Helper"
        ]
        let helperData = try PropertyListSerialization.data(fromPropertyList: helperPlist, format: .xml, options: 0)
        try helperData.write(to: helperInfo)
        try Data("support".utf8).write(to: support.appendingPathComponent("state.db"))
        try Data("cache".utf8).write(to: cache.appendingPathComponent("cache.db"))
        try Data("prefs".utf8).write(to: preference)
        try Data("http".utf8).write(to: httpStorage.appendingPathComponent("store.db"))
        try Data("crash".utf8).write(to: crashReport)
        try Data("log".utf8).write(to: nestedLog.appendingPathComponent("run.log"))
        try Data("daemon".utf8).write(to: daemonContainer.appendingPathComponent("state.db"))
        try Data("system".utf8).write(to: systemSupport.appendingPathComponent("shared.db"))
        try Data("system prefs".utf8).write(to: systemPreference)
        try Data("agent".utf8).write(to: systemLaunchAgent)
        try Data("daemon".utf8).write(to: systemLaunchDaemon)
        try Data("helper".utf8).write(to: privilegedHelper)

        let scanner = AppCleanerScanner(homeDirectory: home, systemLibraryDirectory: systemLibrary)
        let scan = try scanner.scan(appURL: app)

        XCTAssertEqual(scan.bundleIdentifier, "com.example.testapp")
        XCTAssertTrue(scan.candidates.contains { $0.url == app && $0.kind == .application })
        XCTAssertTrue(scan.candidates.contains { $0.url == support && $0.kind == .support })
        XCTAssertTrue(scan.candidates.contains { $0.url == cache && $0.kind == .caches })
        XCTAssertTrue(scan.candidates.contains { $0.url == preference && $0.kind == .preferences })
        XCTAssertTrue(scan.candidates.contains { $0.url == httpStorage && $0.kind == .caches })
        XCTAssertTrue(scan.candidates.contains { $0.url == crashReport && $0.kind == .support })
        XCTAssertTrue(scan.candidates.contains { $0.url == nestedLog && $0.kind == .logs })
        XCTAssertTrue(scan.candidates.contains { $0.url == daemonContainer && $0.kind == .containers && $0.scope == .user })
        XCTAssertTrue(scan.candidates.contains { $0.url == systemSupport && $0.kind == .support && $0.scope == .system })
        XCTAssertTrue(scan.candidates.contains { $0.url == systemPreference && $0.kind == .preferences && $0.scope == .system })
        XCTAssertTrue(scan.candidates.contains { $0.url == systemLaunchAgent && $0.kind == .other && $0.scope == .system })
        XCTAssertTrue(scan.candidates.contains { $0.url == systemLaunchDaemon && $0.kind == .other && $0.scope == .administrator })
        XCTAssertTrue(scan.candidates.contains { $0.url == privilegedHelper && $0.kind == .other && $0.scope == .administrator })

        try? FileManager.default.removeItem(at: root)
    }

    func testIgnoresGenericReverseDNSSystemMatches() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PixelCatPopScannerTests-\(UUID().uuidString)", isDirectory: true)
        let home = root.appendingPathComponent("Home", isDirectory: true)
        let systemLibrary = root.appendingPathComponent("Library", isDirectory: true)
        let app = root.appendingPathComponent("Antigravity IDE.app", isDirectory: true)
        let info = app.appendingPathComponent("Contents/Info.plist")
        let unrelatedAppleSupport = systemLibrary.appendingPathComponent("Application Support/com.apple.TCC", isDirectory: true)
        let unrelatedPasswordManager = systemLibrary.appendingPathComponent("Application Support/Mozilla/NativeMessagingHosts/com.apple.passwordmanager.json")
        let unrelatedLaunchAgent = systemLibrary.appendingPathComponent("LaunchAgents/com.oray.awesun.agent.plist")
        let unrelatedLaunchDaemon = systemLibrary.appendingPathComponent("LaunchDaemons/com.oray.awesun.helper.plist")
        let relatedSupport = systemLibrary.appendingPathComponent("Application Support/Google/Antigravity IDE", isDirectory: true)

        try FileManager.default.createDirectory(at: info.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: unrelatedAppleSupport, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: unrelatedPasswordManager.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: unrelatedLaunchAgent.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: unrelatedLaunchDaemon.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: relatedSupport, withIntermediateDirectories: true)

        let plist: [String: String] = [
            "CFBundleIdentifier": "com.google.antigravity-ide",
            "CFBundleName": "Antigravity IDE",
            "CFBundleExecutable": "Antigravity IDE"
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: info)
        try Data("apple".utf8).write(to: unrelatedAppleSupport.appendingPathComponent("state.db"))
        try Data("password manager".utf8).write(to: unrelatedPasswordManager)
        try Data("agent".utf8).write(to: unrelatedLaunchAgent)
        try Data("daemon".utf8).write(to: unrelatedLaunchDaemon)
        try Data("support".utf8).write(to: relatedSupport.appendingPathComponent("state.db"))

        let scanner = AppCleanerScanner(homeDirectory: home, systemLibraryDirectory: systemLibrary)
        let scan = try scanner.scan(appURL: app)
        let candidateURLs = Set(scan.candidates.map(\.url))

        XCTAssertTrue(candidateURLs.contains(app))
        XCTAssertTrue(candidateURLs.contains(relatedSupport))
        XCTAssertFalse(candidateURLs.contains(unrelatedAppleSupport))
        XCTAssertFalse(candidateURLs.contains(unrelatedPasswordManager))
        XCTAssertFalse(candidateURLs.contains(unrelatedLaunchAgent))
        XCTAssertFalse(candidateURLs.contains(unrelatedLaunchDaemon))

        try? FileManager.default.removeItem(at: root)
    }
}
