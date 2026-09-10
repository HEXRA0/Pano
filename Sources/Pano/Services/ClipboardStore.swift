import Foundation
import Combine

@MainActor
public final class ClipboardStore: ObservableObject {
    public static let shared = ClipboardStore()

    @Published public private(set) var items: [ClipboardItem] = []
    @Published public var maxHistoryCount: Int = 150

    private let storageURL: URL

    public init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let panoFolder = appSupport.appendingPathComponent("Pano", isDirectory: true)

        if !fileManager.fileExists(atPath: panoFolder.path) {
            try? fileManager.createDirectory(at: panoFolder, withIntermediateDirectories: true)
        }

        self.storageURL = panoFolder.appendingPathComponent("history.json")
        load()
    }

    public func add(item: ClipboardItem) {
        // If the same content already exists in history, remove it and put updated at front (or top of unpinned)
        if let existingIndex = items.firstIndex(where: {
            if $0.type == item.type {
                if let t1 = $0.textContent, let t2 = item.textContent {
                    return t1 == t2
                }
                if let d1 = $0.imageData, let d2 = item.imageData {
                    return d1 == d2
                }
            }
            return false
        }) {
            let existing = items.remove(at: existingIndex)
            // Preserve pinned state if it was pinned
            let updatedItem = ClipboardItem(
                id: existing.id,
                type: item.type,
                textContent: item.textContent,
                rtfData: item.rtfData,
                imageData: item.imageData,
                filePaths: item.filePaths,
                preview: item.preview,
                timestamp: Date(),
                isPinned: existing.isPinned
            )
            insertPreservingPinnedOrder(updatedItem)
        } else {
            insertPreservingPinnedOrder(item)
        }

        enforceLimit()
        save()
    }

    private func insertPreservingPinnedOrder(_ item: ClipboardItem) {
        if item.isPinned {
            items.insert(item, at: 0)
        } else {
            // Insert after the last pinned item
            if let firstUnpinnedIndex = items.firstIndex(where: { !$0.isPinned }) {
                items.insert(item, at: firstUnpinnedIndex)
            } else {
                items.append(item)
            }
        }
    }

    public func delete(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    public func togglePin(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned.toggle()

        // Re-sort: pinned first, then by timestamp descending
        items.sort { item1, item2 in
            if item1.isPinned != item2.isPinned {
                return item1.isPinned && !item2.isPinned
            }
            return item1.timestamp > item2.timestamp
        }
        save()
    }

    public func clearUnpinned() {
        items.removeAll { !$0.isPinned }
        save()
    }

    public func clearAll() {
        items.removeAll()
        save()
    }

    private func enforceLimit() {
        let pinnedCount = items.filter(\.isPinned).count
        let allowedUnpinned = max(0, maxHistoryCount - pinnedCount)
        var unpinnedSeen = 0

        items = items.filter { item in
            if item.isPinned { return true }
            unpinnedSeen += 1
            return unpinnedSeen <= allowedUnpinned
        }
    }

    private func save() {
        let itemsToSave = items
        let url = storageURL

        Task.detached(priority: .background) {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(itemsToSave)
                try data.write(to: url, options: .atomic)
            } catch {
                print("Failed to save clipboard history: \(error)")
            }
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            self.items = try decoder.decode([ClipboardItem].self, from: data)
        } catch {
            print("Failed to load clipboard history: \(error)")
        }
    }
}
