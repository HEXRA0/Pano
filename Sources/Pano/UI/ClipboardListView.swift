import SwiftUI
import AppKit

public struct ClipboardListView: View {
    @ObservedObject var store = ClipboardStore.shared
    @ObservedObject var selection = SelectionManager.shared
    @ObservedObject var settings = SettingsManager.shared
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
            // Header: Spotlight-Style Search Bar
            searchHeader
                .onHover { hovering in
                    if hovering {
                        onDismissPreview?()
                    }
                }

            hairlineDivider

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

            hairlineDivider

            // Footer: Control Strip
            footerView
                .onHover { hovering in
                    if hovering {
                        onDismissPreview?()
                    }
                }
        }
        .frame(width: settings.windowSizeOption.size.width, height: settings.windowSizeOption.size.height)
        .background(
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
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

    private var hairlineDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 0.5)
    }

    // MARK: - Spotlight-Style Search Header
    private var searchHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 15, weight: .medium))

            TextField("Pano'da ara veya yapıştır...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .regular))
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
                    onDismissPreview?()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
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

                Menu("Pencere Boyutu (\(settings.windowSizeOption.title))") {
                    ForEach(WindowSizeOption.allCases) { option in
                        Button(action: {
                            settings.setWindowSize(option)
                        }) {
                            Text("\(option.title)\(settings.windowSizeOption == option ? " ✓" : "")")
                        }
                    }
                }

                Menu("Pencere Opaklığı (%\(Int(settings.windowOpacity * 100)))") {
                    Button(action: { settings.setOpacity(1.0) }) {
                        Text("%100 (Tam Opak)\(settings.windowOpacity == 1.0 ? " ✓" : "")")
                    }
                    Button(action: { settings.setOpacity(0.95) }) {
                        Text("%95 (Hafif Şeffaf)\(settings.windowOpacity == 0.95 ? " ✓" : "")")
                    }
                    Button(action: { settings.setOpacity(0.85) }) {
                        Text("%85 (Buzlu Cam)\(settings.windowOpacity == 0.85 ? " ✓" : "")")
                    }
                    Button(action: { settings.setOpacity(0.75) }) {
                        Text("%75 (Daha Şeffaf)\(settings.windowOpacity == 0.75 ? " ✓" : "")")
                    }
                    Button(action: { settings.setOpacity(0.65) }) {
                        Text("%65 (Ultra Şeffaf)\(settings.windowOpacity == 0.65 ? " ✓" : "")")
                    }
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
                    Text("Öğeyi Sil: Delete veya ⌘⌫")
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
                    .font(.system(size: 13))
                    .padding(5)
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
                    .padding(5)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Kapat (ESC)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
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

    // MARK: - Single Item Row (macOS Spotlight / Shortcuts Style)
    private func itemRow(item: ClipboardItem, index: Int) -> some View {
        let isSelected = selection.selectedIndex == index
        let shortcutNumber = index < 9 ? "\(index + 1)" : nil

        return Button(action: {
            onSelectItem(item)
        }) {
            HStack(spacing: 11) {
                // Apple-style Squircle Type Badge
                itemTypeBadge(for: item, isSelected: isSelected)

                // Text & Metadata
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.cleanPreview)
                        .font(.system(size: 12.5, weight: item.isPinned ? .semibold : .regular))
                        .lineLimit(2)
                        .foregroundColor(isSelected ? .white : .primary)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Text(item.formattedTime)
                            .font(.system(size: 10.5))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)

                        if item.type == .text, item.charCount > 0 {
                            Text("•  \(item.charCount) karakter")
                                .font(.system(size: 10.5))
                                .foregroundColor(isSelected ? .white.opacity(0.65) : .secondary.opacity(0.75))
                        }
                    }
                }

                Spacer(minLength: 4)

                // Actions: Delete & Pin
                HStack(spacing: 5) {
                    if isSelected {
                        Button(action: {
                            store.delete(id: item.id)
                            selection.clamp(totalCount: filteredItems.count - 1)
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 10.5))
                                .foregroundColor(isSelected ? .white.opacity(0.9) : .red.opacity(0.8))
                                .padding(4)
                                .background(Color.white.opacity(0.18))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Sil (⌫ veya ⌘⌫)")
                    }

                    if item.isPinned || isSelected {
                        Button(action: {
                            store.togglePin(id: item.id)
                        }) {
                            Image(systemName: item.isPinned ? "pin.fill" : "pin")
                                .font(.system(size: 10.5))
                                .foregroundColor(
                                    isSelected
                                        ? (item.isPinned ? .yellow : .white.opacity(0.9))
                                        : (item.isPinned ? .orange : .secondary)
                                )
                                .padding(4)
                                .background(isSelected ? Color.white.opacity(0.18) : Color.clear)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help(item.isPinned ? "Sabitlemeyi Kaldır" : "Yukarı Sabitle")
                    }

                    // Apple-style Keyboard Keycap Badge (⌘1 ... ⌘9)
                    if let num = shortcutNumber {
                        Text("⌘\(num)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(isSelected ? .white : .secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2.5)
                            .background(
                                isSelected
                                    ? Color.white.opacity(0.25)
                                    : Color.primary.opacity(0.06)
                            )
                            .cornerRadius(5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(
                                        isSelected
                                            ? Color.white.opacity(0.3)
                                            : Color.primary.opacity(0.08),
                                        lineWidth: 0.5
                                    )
                            )
                    }
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
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

    // MARK: - Apple Squircle Type Badge
    @ViewBuilder
    private func itemTypeBadge(for item: ClipboardItem, isSelected: Bool) -> some View {
        switch item.type {
        case .text:
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.25) : Color.blue.opacity(0.14))
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white : .blue)
            }
            .frame(width: 26, height: 26)

        case .image:
            if let data = item.imageData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                    )
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? Color.white.opacity(0.25) : Color.purple.opacity(0.14))
                    Image(systemName: "photo.fill")
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? .white : .purple)
                }
                .frame(width: 26, height: 26)
            }

        case .fileURL:
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.25) : Color.green.opacity(0.14))
                Image(systemName: "doc.fill")
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white : .green)
            }
            .frame(width: 26, height: 26)

        case .rtf:
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.25) : Color.orange.opacity(0.14))
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white : .orange)
            }
            .frame(width: 26, height: 26)
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

    // MARK: - Empty State (Apple System Style)
    private var emptyView: some View {
        VStack(spacing: 14) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.04))
                    .frame(width: 68, height: 68)

                Image(systemName: searchText.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary.opacity(0.7))
            }

            VStack(spacing: 4) {
                Text(searchText.isEmpty ? "Pano Geçmişi Boş" : "Eşleşen Sonuç Yok")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text(searchText.isEmpty ? "Kopyaladığınız metinler ve görseller burada listelenecektir." : "Farklı bir arama terimi deneyin.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if searchText.isEmpty {
                HStack(spacing: 5) {
                    Text("⇧⌘C")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(5)

                    Text("veya")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text("⇧⌘V")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(5)
                }
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer Control Strip
    private var footerView: some View {
        VStack(spacing: 0) {
            if isConfirmingClear {
                HStack(spacing: 8) {
                    Text("Geçmişi temizle:")
                        .font(.system(size: 11.5, weight: .medium))
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
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

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
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

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
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.03))
            } else {
                HStack(spacing: 8) {
                    Text("\(filteredItems.count) öğe")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("↵ kopyala  •  ⌫ sil")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary.opacity(0.7))

                    Spacer()

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isConfirmingClear = true
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                            Text("Temizle")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        Image(systemName: "power")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(5)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(Circle())
                            .help("Pano'dan Çık")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
            }
        }
    }
}

// MARK: - Visual Effect View for Native macOS Frosted Glass
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
