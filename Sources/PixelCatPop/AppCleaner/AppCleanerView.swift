import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AppCleanerView: View {
    @ObservedObject var settings: SettingsStore

    @State private var scan: AppCleanupScan?
    @State private var selectedItems = Set<URL>()
    @State private var message: String?
    @State private var isCleaning = false

    private let scanner = AppCleanerScanner()

    var body: some View {
        let language = settings.interfaceLanguage

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                BrandLogoView(size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.text(.appCleaner, language: language))
                        .font(.headline)
                    Text(L10n.text(.appCleanerHint, language: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    chooseApplication(language: language)
                } label: {
                    Label(L10n.text(.chooseApplication, language: language), systemImage: "app.badge")
                }
            }
            .frame(height: 48)
            .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 8) {
                if let scan {
                    Text("\(scan.appName)  \(scan.bundleIdentifier)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    List {
                        ForEach(AppCleanupScope.allCases, id: \.self) { scope in
                            let items = scan.candidates.filter { $0.scope == scope }
                            if !items.isEmpty {
                                Section(scopeTitle(scope, language: language)) {
                                    ForEach(items) { item in
                                        Toggle(isOn: binding(for: item)) {
                                            HStack {
                                                Image(systemName: iconName(for: item))
                                                    .frame(width: 18)
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(item.url.lastPathComponent)
                                                        .lineLimit(1)
                                                    Text(item.url.path)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                }
                                                Spacer()
                                                if item.scope == .administrator {
                                                    Image(systemName: "lock.shield")
                                                        .foregroundStyle(.orange)
                                                }
                                                Text(formatBytes(item.size))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .disabled(item.isRequired)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                    .scrollContentBackground(.hidden)
                } else {
                    ContentUnavailableView(
                        L10n.text(.noApplicationSelected, language: language),
                        systemImage: "trash",
                        description: Text(L10n.text(.appCleanerEmptyHint, language: language))
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 8)

            HStack {
                if let message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Text(formatBytes(selectedSize))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(role: .destructive) {
                    cleanSelected(language: language)
                } label: {
                    Label(L10n.text(.moveToTrash, language: language), systemImage: "trash")
                }
                .disabled(selectedItems.isEmpty || isCleaning)
            }
            .frame(height: 42)
            .padding(.top, 12)
        }
        .padding(20)
        .frame(width: 720, height: 520)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
    }

    private var selectedSize: UInt64 {
        scan?.candidates
            .filter { selectedItems.contains($0.url) }
            .reduce(0) { $0 + $1.size } ?? 0
    }

    private func chooseApplication(language: AppLanguage) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)

        guard panel.runModal() == .OK, let url = panel.url else { return }

        scanApplication(url, language: language)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = item as? URL
            }

            guard let url else { return }
            Task { @MainActor in
                scanApplication(url, language: settings.interfaceLanguage)
            }
        }
        return true
    }

    private func scanApplication(_ url: URL, language: AppLanguage) {
        do {
            let result = try scanner.scan(appURL: url)
            scan = result
            selectedItems = Set(result.candidates.filter(shouldSelectByDefault).map(\.url))
            message = L10n.text(.appCleanerScanComplete, language: language)
        } catch {
            message = error.localizedDescription
        }
    }

    private func shouldSelectByDefault(_ item: AppCleanupCandidate) -> Bool {
        if item.isRequired { return true }
        guard item.scope == .user else { return false }
        switch item.kind {
        case .application:
            return true
        case .preferences:
            return settings.appCleanerSelectsPreferences
        case .caches:
            return settings.appCleanerSelectsCaches
        case .support:
            return settings.appCleanerSelectsSupportFiles
        case .containers:
            return settings.appCleanerSelectsContainers
        case .logs:
            return settings.appCleanerSelectsLogs
        case .savedState:
            return settings.appCleanerSelectsSavedState
        case .other:
            return false
        }
    }

    private func cleanSelected(language: AppLanguage) {
        guard let scan else { return }
        let items = scan.candidates.filter { selectedItems.contains($0.url) }
        guard !items.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = L10n.text(.confirmMoveToTrash, language: language)
        alert.informativeText = cleanupConfirmationText(appName: scan.appName, items: items, language: language)
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.text(.moveToTrash, language: language))
        alert.addButton(withTitle: L10n.text(.cancel, language: language))

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        isCleaning = true
        defer { isCleaning = false }

        var failed: [String] = []
        for item in items {
            do {
                var resultURL: NSURL?
                try FileManager.default.trashItem(at: item.url, resultingItemURL: &resultURL)
                selectedItems.remove(item.url)
            } catch {
                failed.append(item.url.lastPathComponent)
            }
        }

        if failed.isEmpty {
            message = L10n.text(.appCleanerTrashComplete, language: language)
            self.scan = AppCleanupScan(
                appURL: scan.appURL,
                appName: scan.appName,
                bundleIdentifier: scan.bundleIdentifier,
                candidates: scan.candidates.filter { selectedItems.contains($0.url) }
            )
        } else {
            message = "\(L10n.text(.appCleanerTrashFailed, language: language)): \(failed.joined(separator: ", "))"
        }
    }

    private func binding(for item: AppCleanupCandidate) -> Binding<Bool> {
        Binding {
            selectedItems.contains(item.url)
        } set: { isSelected in
            if isSelected {
                selectedItems.insert(item.url)
            } else {
                selectedItems.remove(item.url)
            }
        }
    }

    private func iconName(for item: AppCleanupCandidate) -> String {
        if item.scope == .administrator {
            return "lock.shield"
        }

        return switch item.kind {
        case .application:
            "app"
        case .preferences:
            "slider.horizontal.3"
        case .caches:
            "externaldrive"
        case .support:
            "folder"
        case .containers:
            "shippingbox"
        case .logs:
            "doc.text"
        case .savedState:
            "clock"
        case .other:
            "questionmark.folder"
        }
    }

    private func scopeTitle(_ scope: AppCleanupScope, language: AppLanguage) -> String {
        switch scope {
        case .user:
            return isChinese(language) ? "用户级" : "User"
        case .system:
            return isChinese(language) ? "系统级" : "System"
        case .administrator:
            return isChinese(language) ? "需要管理员权限" : "Requires Administrator"
        }
    }

    private func cleanupConfirmationText(appName: String, items: [AppCleanupCandidate], language: AppLanguage) -> String {
        let userCount = items.filter { $0.scope == .user }.count
        let systemCount = items.filter { $0.scope == .system }.count
        let adminCount = items.filter { $0.scope == .administrator }.count

        if isChinese(language) {
            var text = "\(appName)\n用户级 \(userCount) 项，系统级 \(systemCount) 项，需要管理员权限 \(adminCount) 项。"
            if systemCount > 0 || adminCount > 0 {
                text += "\n系统级项目可能需要手动授权；如果移动失败，请在 Finder 中确认权限。"
            }
            return text
        }

        var text = "\(appName)\nUser \(userCount), system \(systemCount), administrator \(adminCount)."
        if systemCount > 0 || adminCount > 0 {
            text += "\nSystem-level items may require manual authorization. If moving fails, confirm permissions in Finder."
        }
        return text
    }

    private func isChinese(_ language: AppLanguage) -> Bool {
        language.resolvedCode.lowercased().hasPrefix("zh")
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let value = Double(bytes)
        if value >= 1_073_741_824 {
            return String(format: "%.1f GB", value / 1_073_741_824)
        }
        if value >= 1_048_576 {
            return String(format: "%.1f MB", value / 1_048_576)
        }
        if value >= 1_024 {
            return String(format: "%.0f KB", value / 1_024)
        }
        return "\(bytes) B"
    }
}
