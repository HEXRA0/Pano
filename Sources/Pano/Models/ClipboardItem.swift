import Foundation

public enum ClipboardItemType: String, Codable, Sendable {
    case text
    case rtf
    case image
    case fileURL
}

public struct ClipboardItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let type: ClipboardItemType
    public let textContent: String?
    public let rtfData: Data?
    public let imageData: Data?
    public let filePaths: [String]?
    public let preview: String
    public let timestamp: Date
    public var isPinned: Bool

    public init(
        id: UUID = UUID(),
        type: ClipboardItemType,
        textContent: String? = nil,
        rtfData: Data? = nil,
        imageData: Data? = nil,
        filePaths: [String]? = nil,
        preview: String,
        timestamp: Date = Date(),
        isPinned: Bool = false
    ) {
        self.id = id
        self.type = type
        self.textContent = textContent
        self.rtfData = rtfData
        self.imageData = imageData
        self.filePaths = filePaths
        self.preview = preview
        self.timestamp = timestamp
        self.isPinned = isPinned
    }

    public var formattedTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    public var charCount: Int {
        textContent?.count ?? 0
    }

    public var cleanPreview: String {
        preview.replacingOccurrences(of: "🖼️ ", with: "")
    }
}
