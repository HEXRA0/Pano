import Foundation
import Combine

@MainActor
public final class SelectionManager: ObservableObject {
    public static let shared = SelectionManager()

    @Published public var selectedIndex: Int = 0
    @Published public var scrollTargetId: UUID? = nil

    private init() {}

    public func moveDown(totalCount: Int, items: [ClipboardItem] = []) {
        guard totalCount > 0 else { return }
        if selectedIndex < totalCount - 1 {
            selectedIndex += 1
            if selectedIndex < items.count {
                scrollTargetId = items[selectedIndex].id
            }
        }
    }

    public func moveUp(totalCount: Int, items: [ClipboardItem] = []) {
        guard totalCount > 0 else { return }
        if selectedIndex > 0 {
            selectedIndex -= 1
            if selectedIndex < items.count {
                scrollTargetId = items[selectedIndex].id
            }
        }
    }

    public func reset() {
        selectedIndex = 0
        scrollTargetId = nil
    }

    public func clamp(totalCount: Int) {
        if totalCount == 0 {
            selectedIndex = 0
        } else if selectedIndex >= totalCount {
            selectedIndex = totalCount - 1
        }
    }
}
