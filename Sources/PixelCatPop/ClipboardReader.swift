import AppKit

struct ClipboardReader {
    private let readableFileExtensions: Set<String> = [
        "swift", "md", "txt", "json", "yaml", "yml", "toml", "xml", "html", "css", "js", "ts"
    ]

    func latestText() -> String? {
        let pasteboard = NSPasteboard.general

        if let text = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty {
            return text
        }

        return readableTextFileContent(from: pasteboard)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    private func readableTextFileContent(from pasteboard: NSPasteboard) -> String {
        guard let fileURLString = pasteboard.string(forType: .fileURL),
              let url = URL(string: fileURLString),
              url.isFileURL,
              readableFileExtensions.contains(url.pathExtension.lowercased()),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? NSNumber,
              fileSize.intValue <= 64_000,
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }

        return content
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
