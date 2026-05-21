import Foundation

struct AppCleanerScanner {
    var fileManager: FileManager = .default
    var homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    var systemLibraryDirectory: URL = URL(fileURLWithPath: "/Library", isDirectory: true)

    func scan(appURL: URL) throws -> AppCleanupScan {
        let standardizedAppURL = appURL.standardizedFileURL
        guard standardizedAppURL.pathExtension == "app" else {
            throw AppCleanerError.notAnApplication
        }

        let infoURL = standardizedAppURL.appendingPathComponent("Contents/Info.plist")
        let infoData = try Data(contentsOf: infoURL)
        guard
            let plist = try PropertyListSerialization.propertyList(from: infoData, options: [], format: nil) as? [String: Any],
            let bundleIdentifier = plist["CFBundleIdentifier"] as? String,
            !bundleIdentifier.isEmpty
        else {
            throw AppCleanerError.missingBundleIdentifier
        }

        let displayName = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? standardizedAppURL.deletingPathExtension().lastPathComponent

        let executableName = plist["CFBundleExecutable"] as? String
        let helperBundleInfos = helperBundleInfos(in: standardizedAppURL)

        let candidates = cleanupCandidates(
            appURL: standardizedAppURL,
            appName: displayName,
            bundleIdentifier: bundleIdentifier,
            executableName: executableName,
            helperBundleInfos: helperBundleInfos
        )

        return AppCleanupScan(
            appURL: standardizedAppURL,
            appName: displayName,
            bundleIdentifier: bundleIdentifier,
            candidates: candidates.sorted { $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending }
        )
    }

    func cleanupCandidates(
        appURL: URL,
        appName: String,
        bundleIdentifier: String,
        executableName: String? = nil,
        helperBundleInfos: [BundleInfo] = []
    ) -> [AppCleanupCandidate] {
        var seen = Set<String>()
        var candidates: [AppCleanupCandidate] = []

        func add(_ url: URL, kind: AppCleanupItemKind, scope: AppCleanupScope = .user, required: Bool = false) {
            let normalized = url.standardizedFileURL
            guard seen.insert(normalized.path).inserted else { return }
            guard fileManager.fileExists(atPath: normalized.path) else { return }
            candidates.append(.init(url: normalized, kind: kind, scope: scope, size: sizeOfItem(at: normalized), isRequired: required))
        }

        add(appURL, kind: .application, required: true)

        let userLibrary = homeDirectory.appendingPathComponent("Library", isDirectory: true)
        let appSupport = userLibrary.appendingPathComponent("Application Support", isDirectory: true)
        let caches = userLibrary.appendingPathComponent("Caches", isDirectory: true)
        let preferences = userLibrary.appendingPathComponent("Preferences", isDirectory: true)
        let containers = userLibrary.appendingPathComponent("Containers", isDirectory: true)
        let groupContainers = userLibrary.appendingPathComponent("Group Containers", isDirectory: true)
        let logs = userLibrary.appendingPathComponent("Logs", isDirectory: true)
        let savedState = userLibrary.appendingPathComponent("Saved Application State", isDirectory: true)
        let httpStorages = userLibrary.appendingPathComponent("HTTPStorages", isDirectory: true)
        let webKit = userLibrary.appendingPathComponent("WebKit", isDirectory: true)
        let cookies = userLibrary.appendingPathComponent("Cookies", isDirectory: true)
        let crashReporter = appSupport.appendingPathComponent("CrashReporter", isDirectory: true)
        let applicationScripts = userLibrary.appendingPathComponent("Application Scripts", isDirectory: true)
        let launchAgents = userLibrary.appendingPathComponent("LaunchAgents", isDirectory: true)
        let daemonContainers = userLibrary.appendingPathComponent("Daemon Containers", isDirectory: true)
        let userPrivilegedHelperTools = userLibrary.appendingPathComponent("PrivilegedHelperTools", isDirectory: true)
        let systemAppSupport = systemLibraryDirectory.appendingPathComponent("Application Support", isDirectory: true)
        let systemPreferences = systemLibraryDirectory.appendingPathComponent("Preferences", isDirectory: true)
        let systemLaunchAgents = systemLibraryDirectory.appendingPathComponent("LaunchAgents", isDirectory: true)
        let systemLaunchDaemons = systemLibraryDirectory.appendingPathComponent("LaunchDaemons", isDirectory: true)
        let systemPrivilegedHelperTools = systemLibraryDirectory.appendingPathComponent("PrivilegedHelperTools", isDirectory: true)

        add(appSupport.appendingPathComponent(bundleIdentifier), kind: .support)
        add(appSupport.appendingPathComponent(appName), kind: .support)
        add(caches.appendingPathComponent(bundleIdentifier), kind: .caches)
        add(httpStorages.appendingPathComponent(bundleIdentifier), kind: .caches)
        add(webKit.appendingPathComponent(bundleIdentifier), kind: .caches)
        add(cookies.appendingPathComponent("\(bundleIdentifier).binarycookies"), kind: .caches)
        add(preferences.appendingPathComponent("\(bundleIdentifier).plist"), kind: .preferences)
        add(preferences.appendingPathComponent("ByHost/\(bundleIdentifier).plist"), kind: .preferences)
        add(savedState.appendingPathComponent("\(bundleIdentifier).savedState"), kind: .savedState)
        add(logs.appendingPathComponent(bundleIdentifier), kind: .logs)
        add(logs.appendingPathComponent(appName), kind: .logs)
        add(containers.appendingPathComponent(bundleIdentifier), kind: .containers)
        add(groupContainers.appendingPathComponent(bundleIdentifier), kind: .containers)
        add(applicationScripts.appendingPathComponent(bundleIdentifier), kind: .support)
        add(launchAgents.appendingPathComponent("\(bundleIdentifier).plist"), kind: .other)
        add(daemonContainers.appendingPathComponent(bundleIdentifier), kind: .containers)
        add(userPrivilegedHelperTools.appendingPathComponent(bundleIdentifier), kind: .other)
        add(systemAppSupport.appendingPathComponent(bundleIdentifier), kind: .support, scope: .system)
        add(systemAppSupport.appendingPathComponent(appName), kind: .support, scope: .system)
        add(systemPreferences.appendingPathComponent("\(bundleIdentifier).plist"), kind: .preferences, scope: .system)
        add(systemLaunchAgents.appendingPathComponent("\(bundleIdentifier).plist"), kind: .other, scope: .system)
        add(systemLaunchDaemons.appendingPathComponent("\(bundleIdentifier).plist"), kind: .other, scope: .administrator)
        add(systemPrivilegedHelperTools.appendingPathComponent(bundleIdentifier), kind: .other, scope: .administrator)

        let helperIdentifiers = helperBundleInfos.map(\.bundleIdentifier)
        let helperNames = helperBundleInfos.flatMap { [$0.displayName, $0.executableName] }
        let bundleParts = bundleIdentifier.components(separatedBy: ".")
        let vendorTokens = bundleParts.dropLast().filter { isMeaningfulMatchToken($0) }
        let identifierTokens = ([bundleIdentifier, bundleParts.last] + helperIdentifiers)
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        let nameTokens = ([appName, executableName] + helperNames)
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        let broadTokens = identifierTokens + nameTokens + vendorTokens

        for url in matchingChildren(in: caches, matchingAny: identifierTokens) {
            add(url, kind: .caches)
        }
        for url in matchingChildren(in: httpStorages, matchingAny: identifierTokens) {
            add(url, kind: .caches)
        }
        for url in matchingChildren(in: webKit, matchingAny: identifierTokens) {
            add(url, kind: .caches)
        }
        for url in matchingChildren(in: cookies, matchingAny: identifierTokens) {
            add(url, kind: .caches)
        }
        for url in matchingChildren(in: preferences, matchingAny: identifierTokens) {
            add(url, kind: .preferences)
        }
        for url in matchingChildren(in: preferences.appendingPathComponent("ByHost", isDirectory: true), matchingAny: identifierTokens) {
            add(url, kind: .preferences)
        }
        for url in matchingChildren(in: containers, matchingAny: identifierTokens) {
            add(url, kind: .containers)
        }
        for url in matchingChildren(in: groupContainers, matchingAny: identifierTokens) {
            add(url, kind: .containers)
        }
        for url in matchingChildren(in: daemonContainers, matchingAny: identifierTokens) {
            add(url, kind: .containers)
        }
        for url in matchingChildren(in: applicationScripts, matchingAny: identifierTokens) {
            add(url, kind: .support)
        }
        for url in matchingChildren(in: launchAgents, matchingAny: identifierTokens) {
            add(url, kind: .other)
        }
        for url in matchingChildren(in: userPrivilegedHelperTools, matchingAny: broadTokens) {
            add(url, kind: .other)
        }
        for url in matchingChildren(in: logs, matchingAny: broadTokens) {
            add(url, kind: .logs)
        }
        for url in matchingDescendants(in: logs, matchingAny: nameTokens, maximumDepth: 2) {
            add(url, kind: .logs)
        }
        for url in matchingDescendants(in: logs, matchingAny: vendorTokens + nameTokens, maximumDepth: 2) {
            add(url, kind: .logs)
        }
        for url in matchingChildren(in: crashReporter, matchingAny: broadTokens) {
            add(url, kind: .support)
        }
        for url in matchingChildren(in: systemAppSupport, matchingAny: broadTokens) {
            add(url, kind: .support, scope: .system)
        }
        for url in matchingDescendants(in: systemAppSupport, matchingAny: vendorTokens + nameTokens, maximumDepth: 2) {
            add(url, kind: .support, scope: .system)
        }
        for url in matchingChildren(in: systemPreferences, matchingAny: identifierTokens) {
            add(url, kind: .preferences, scope: .system)
        }
        for url in matchingChildren(in: systemLaunchAgents, matchingAny: broadTokens) {
            add(url, kind: .other, scope: .system)
        }
        for url in matchingChildren(in: systemLaunchDaemons, matchingAny: broadTokens) {
            add(url, kind: .other, scope: .administrator)
        }
        for url in matchingChildren(in: systemPrivilegedHelperTools, matchingAny: broadTokens) {
            add(url, kind: .other, scope: .administrator)
        }

        return candidates
    }

    private func helperBundleInfos(in appURL: URL) -> [BundleInfo] {
        let loginItemsURL = appURL.appendingPathComponent("Contents/Library/LoginItems", isDirectory: true)
        guard let helperApps = try? fileManager.contentsOfDirectory(
            at: loginItemsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return helperApps
            .filter { $0.pathExtension == "app" }
            .compactMap(bundleInfo)
    }

    private func bundleInfo(for appURL: URL) -> BundleInfo? {
        let infoURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard
            let infoData = try? Data(contentsOf: infoURL),
            let plist = try? PropertyListSerialization.propertyList(from: infoData, options: [], format: nil) as? [String: Any],
            let bundleIdentifier = plist["CFBundleIdentifier"] as? String,
            !bundleIdentifier.isEmpty
        else {
            return nil
        }

        return BundleInfo(
            bundleIdentifier: bundleIdentifier,
            displayName: (plist["CFBundleDisplayName"] as? String)
                ?? (plist["CFBundleName"] as? String)
                ?? appURL.deletingPathExtension().lastPathComponent,
            executableName: plist["CFBundleExecutable"] as? String
        )
    }

    private func matchingChildren(in directory: URL, matchingAny tokens: [String]) -> [URL] {
        let normalizedTokens = normalized(tokens: tokens)
        guard !normalizedTokens.isEmpty else { return [] }
        guard let children = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return children.filter {
            matches($0.lastPathComponent, tokens: normalizedTokens)
        }
    }

    private func matchingDescendants(in directory: URL, matchingAny tokens: [String], maximumDepth: Int) -> [URL] {
        let normalizedTokens = normalized(tokens: tokens)
        guard !normalizedTokens.isEmpty else { return [] }
        return matchingDescendants(in: directory, matchingAny: normalizedTokens, remainingDepth: maximumDepth)
    }

    private func matchingDescendants(in directory: URL, matchingAny tokens: [String], remainingDepth: Int) -> [URL] {
        guard remainingDepth >= 0,
              let children = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
              )
        else {
            return []
        }

        var matches: [URL] = []
        for child in children {
            if self.matches(child.lastPathComponent, tokens: tokens) {
                matches.append(child)
            }
            if remainingDepth > 0,
               (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                matches.append(contentsOf: matchingDescendants(in: child, matchingAny: tokens, remainingDepth: remainingDepth - 1))
            }
        }
        return matches
    }

    private func normalized(tokens: [String]) -> [String] {
        Array(Set(tokens.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { isMeaningfulMatchToken($0) }))
    }

    private func matches(_ name: String, tokens: [String]) -> Bool {
        let normalizedName = name.lowercased()
        return tokens.contains { normalizedName.localizedCaseInsensitiveContains($0) }
    }

    private func isMeaningfulMatchToken(_ token: String) -> Bool {
        let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.count >= 3 else { return false }

        let genericReverseDNSParts: Set<String> = [
            "app",
            "com",
            "dev",
            "edu",
            "gov",
            "inc",
            "io",
            "net",
            "org"
        ]
        return !genericReverseDNSParts.contains(normalized)
    }

    private func sizeOfItem(at url: URL) -> UInt64 {
        var total: UInt64 = 0
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return fileSize(at: url)
        }

        total += fileSize(at: url)
        for case let child as URL in enumerator {
            total += fileSize(at: child)
        }
        return total
    }

    private func fileSize(at url: URL) -> UInt64 {
        guard
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey]),
            let size = values.totalFileAllocatedSize ?? values.fileSize
        else {
            return 0
        }
        return UInt64(size)
    }
}

enum AppCleanerError: LocalizedError {
    case notAnApplication
    case missingBundleIdentifier

    var errorDescription: String? {
        switch self {
        case .notAnApplication:
            "Please choose a .app bundle."
        case .missingBundleIdentifier:
            "The selected app does not expose a bundle identifier."
        }
    }
}

struct BundleInfo {
    let bundleIdentifier: String
    let displayName: String
    let executableName: String?
}
