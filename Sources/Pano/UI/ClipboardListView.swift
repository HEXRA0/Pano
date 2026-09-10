import SwiftUI
import AppKit

public struct ClipboardListView: View {
    @ObservedObject var store = ClipboardStore.shared
    @ObservedObject var selection = SelectionManager.shared
    @Binding var searchText: String
    var onSelectItem: (ClipboardItem) -> Void
    var onClose: () -> Void
    var onPreviewItem: ((ClipboardItem) -> Void)?
    var onDismissPreview: (() -> Void)?

    @FocusState private var isSearchFocused: Bool
    @State private var isConfirmingClear: Bool = false

    public init(
        searchText: Binding<String>,
        onSelectItem: @escaping (ClipboardItem) -> Void,
        onClose: @escaping () -> Void,
        onPreviewItem: ((ClipboardItem) -> Void)? = nil,
        onDismissPreview: (() -> Void)? = nil
    ) {
        self._searchText = searchText
        self.onSelectItem = onSelectItem
        self.onClose = onClose
        self.onPreviewItem = onPreviewItem
        self.onDismissPreview = onDismissPreview
    }

    private var filteredItems: [ClipboardItem] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return store.items
        } else {
            return store.items.filter { item in
                item.preview.localizedCaseInsensitiveContains(searchText) ||
                (item.textContent?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header: Search Bar
            searchHeader
                .onHover { hovering in
                    if hovering {
                        onDismissPreview?()
                    }
                }

            Divider()
                .opacity(0.4)

            // Content: List of clips
            if filteredItems.isEmpty {
                emptyView
                    .onHover { hovering in
                        if hovering {
                            onDismissPreview?()
                        }
                    }
            } else {
                itemsList
            }

            Divider()
                .opacity(0.4)

            // Footer: Info & Quick actions
            footerView
                .onHover { hovering in
                    if hovering {
                        onDismissPreview?()
                    }
                }
        }
        .frame(width: 360, height: 460)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFocused = true
            }
        }
        .onDisappear {
            isConfirmingClear = false
            onDismissPreview?()
        }
    }

    // MARK: - Search Header
    private var searchHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 14))

            TextField("Pano'da ara...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isSearchFocused)
                .onSubmit {
                    let index = selection.selectedIndex
                    if index >= 0 && index < filteredItems.count {
                        onSelectItem(filteredItems[index])
                    } else if let first = filteredItems.first {
                        onSelectItem(first)
                    }
                }

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    selection.reset()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
            }

            // Settings Menu Button
            Menu {
                Toggle("Girişte Otomatik Başlat", isOn: Binding(
                    get: { SettingsManager.shared.launchAtLogin },
                    set: { _ in SettingsManager.shared.toggleLaunchAtLogin() }
                ))

                Menu("Geçmiş Hafızası (\(store.maxHistoryCount) öğe)") {
                    Button("50 öğe") { store.maxHistoryCount = 50 }
                    Button("100 öğe") { store.maxHistoryCount = 100 }
                    Button("150 öğe") { store.maxHistoryCount = 150 }
                    Button("300 öğe") { store.maxHistoryCount = 300 }
                    Button("500 öğe") { store.maxHistoryCount = 500 }
                }

                Divider()

                Button("Sabitlenmeyenleri Temizle") {
                    store.clearUnpinned()
                    selection.reset()
                }

                Button("Tüm Geçmişi Temizle", role: .destructive) {
                    store.clearAll()
                    selection.reset()
                }

                Divider()

                Menu("Kısayol Bilgisi") {
                    Text("Pano'yu Aç: ⇧⌘C veya ⇧⌘V")
                    Text("Öğe Seç / Kopyala: Enter veya Tıkla")
                    Text("Hızlı Seçim: ⌘1 ... ⌘9")
                    Text("Pencereyi Kapat: ESC")
                }

                Divider()

                Button(action: {
                    if let url = URL(string: "https://github.com/HEXRA0/Pano") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Label("GitHub Sayfası", systemImage: "link")
                }

                Button("Pano'dan Çık") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Image(systemName: "gearshape")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                    .padding(4)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Ayarlar")

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11, weight: .bold))
                    .padding(4)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Kapat (ESC)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Items List
    private var itemsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                        itemRow(item: item, index: index)
                            .id(item.id)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
            }
            .onChange(of: selection.selectedIndex) { newIndex in
                if newIndex >= 0 && newIndex < filteredItems.count {
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(filteredItems[newIndex].id, anchor: .center)
                    }
                    let current = filteredItems[newIndex]
                    if isImageItem(current) {
                        onPreviewItem?(current)
                    } else {
                        onDismissPreview?()
                    }
                }
            }
        }
    }

    // MARK: - Single Item Row
    private func itemRow(item: ClipboardItem, index: Int) -> some View {
        let isSelected = selection.selectedIndex == index
        let shortcutNumber = index < 9 ? "\(index + 1)" : nil

        return Button(action: {
            onSelectItem(item)
        }) {
            HStack(spacing: 10) {
                // Type Icon
                itemTypeIcon(for: item, isSelected: isSelected)

                // Preview Text & Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.cleanPreview)
                        .font(.system(size: 12.5, weight: item.isPinned ? .semibold : .regular))
                        .lineLimit(2)
                        .foregroundColor(isSelected ? .white : .primary)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Text(item.formattedTime)
                            .font(.system(size: 10))
                            .foregroundColor(isSelected ? .white.opacity(0.75) : .secondary)

                        if item.type == .text, item.charCount > 0 {
                            Text("• \(item.charCount) karakter")
                                .font(.system(size: 10))
                                .foregroundColor(isSelected ? .white.opacity(0.65) : .secondary.opacity(0.8))
                        }
                    }
                }

                Spacer(minLength: 4)

                // Actions: Pin / Delete
                HStack(spacing: 6) {
                    if isSelected {
                        Button(action: {
                            store.delete(id: item.id)
                            selection.clamp(totalCount: filteredItems.count - 1)
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(isSelected ? .white.opacity(0.85) : .red.opacity(0.8))
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                        .help("Sil (⌫ veya ⌘⌫)")
                    }

                    if item.isPinned || isSelected {
                        Button(action: {
                            store.togglePin(id: item.id)
                        }) {
                            Image(systemName: item.isPinned ? "pin.fill" : "pin")
                                .font(.system(size: 11))
                                .foregroundColor(
                                    isSelected
                                        ? (item.isPinned ? .yellow : .white.opacity(0.85))
                                        : (item.isPinned ? .orange : .secondary)
                                )
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                        .help(item.isPinned ? "Sabitlemeyi Kaldır" : "Yukarı Sabitle")
                    }

                    // Shortcut Badge (⌘1 ... ⌘9)
                    if let num = shortcutNumber {
                        Text("⌘\(num)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(isSelected ? .white : .secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(isSelected ? Color.white.opacity(0.25) : Color.primary.opacity(0.07))
                            .cornerRadius(4)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isSelected
                            ? Color.accentColor
                            : (item.isPinned ? Color.primary.opacity(0.04) : Color.clear)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                selection.selectedIndex = index
                if isImageItem(item) {
                    onPreviewItem?(item)
                } else {
                    onDismissPreview?()
                }
            } else {
                onDismissPreview?()
            }
        }
    }

    private func isImageItem(_ item: ClipboardItem) -> Bool {
        if item.type == .image { return true }
        if let paths = item.filePaths, let first = paths.first {
            let ext = (first as NSString).pathExtension.lowercased()
            return ["png", "jpg", "jpeg", "gif", "webp", "tiff", "heic"].contains(ext)
        }
        return false
    }

    // MARK: - Type Icon
    @ViewBuilder
    private func itemTypeIcon(for item: ClipboardItem, isSelected: Bool) -> some View {
        switch item.type {
        case .text:
            Image(systemName: "text.alignleft")
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .white : .blue)
                .frame(width: 18)
        case .image:
            if let data = item.imageData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                    )
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white : .indigo)
                    .frame(width: 18)
            }
        case .fileURL:
            Image(systemName: "doc")
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .white : .green)
                .frame(width: 18)
        case .rtf:
            Image(systemName: "doc.richtext")
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .white : .orange)
                .frame(width: 18)
        }
    }

    // MARK: - Empty State
    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: searchText.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.5))

            Text(searchText.isEmpty ? "Pano Geçmişi Boş" : "Sonuç bulunamadı")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            Text(searchText.isEmpty ? "Kopyaladığınız metinler ve görseller burada görünecektir." : "Farklı bir arama terimi deneyin.")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer View (With Inline Confirmation)
    private var footerView: some View {
        VStack(spacing: 0) {
            if isConfirmingClear {
                HStack(spacing: 6) {
                    Text("Temizle:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer(minLength: 2)

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            store.clearUnpinned()
                            selection.reset()
                            isConfirmingClear = false
                        }
                    }) {
                        Text("Sabitlenenler Hariç")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.12))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            store.clearAll()
                            selection.reset()
                            isConfirmingClear = false
                        }
                    }) {
                        Text("Tümü")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.12))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isConfirmingClear = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(4)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Vazgeç")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.03))
            } else {
                HStack(spacing: 8) {
                    Text("\(filteredItems.count) öğe")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isConfirmingClear = true
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Temizle")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        Image(systemName: "power")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(4)
                            .help("Pano'dan Çık")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Visual Effect View for Native Frosted Glass Look
public struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
