import Foundation

enum AppCleanupItemKind: String, CaseIterable {
    case application
    case preferences
    case caches
    case support
    case containers
    case logs
    case savedState
    case other
}

enum AppCleanupScope: String, CaseIterable {
    case user
    case system
    case administrator
}

struct AppCleanupCandidate: Identifiable, Hashable {
    let id: URL
    let url: URL
    let kind: AppCleanupItemKind
    let scope: AppCleanupScope
    let size: UInt64
    let isRequired: Bool

    init(
        url: URL,
        kind: AppCleanupItemKind,
        scope: AppCleanupScope = .user,
        size: UInt64,
        isRequired: Bool = false
    ) {
        self.id = url
        self.url = url
        self.kind = kind
        self.scope = scope
        self.size = size
        self.isRequired = isRequired
    }
}

struct AppCleanupScan: Equatable {
    let appURL: URL
    let appName: String
    let bundleIdentifier: String
    let candidates: [AppCleanupCandidate]
}
