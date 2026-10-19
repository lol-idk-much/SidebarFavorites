import SwiftUI

/// Search-and-pick over 21,000+ icons across SF Symbols and vector icon packs
/// (Tabler, Simple Icons, Lucide, Phosphor, Heroicons).
struct SymbolBrowserSheet: View {
    @State private var query: String
    @State private var selectedPack: IconPack = .all
    @State private var selection: UnifiedIcon?

    @ObservedObject private var catalog = UnifiedIconCatalog.shared

    private let initialSymbol: String
    private let currentIconType: Favorite.IconType
    private let onPickIcon: ((_ type: Favorite.IconType, _ value: String, _ customSVGPath: String?) -> Void)?
    private let onPick: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss

    init(
        currentSymbol: String,
        currentIconType: Favorite.IconType = .sfSymbol,
        onPickIcon: ((_ type: Favorite.IconType, _ value: String, _ customSVGPath: String?) -> Void)? = nil,
        onPick: ((String) -> Void)? = nil
    ) {
        self.initialSymbol = currentSymbol
        self.currentIconType = currentIconType
        self.onPickIcon = onPickIcon
        self.onPick = onPick
        
        #if DEBUG
        _query = State(initialValue: ScreenshotMode.symbolBrowserQuery)
        #else
        _query = State(initialValue: "")
        #endif
    }

    private var results: [UnifiedIcon] {
        catalog.search(query: query, pack: selectedPack)
    }

    private let columns = Array(repeating: GridItem(.adaptive(minimum: 46), spacing: 10), count: 1)

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Icon Browser")
                    .font(.headline)
                
                Spacer()
                
                Picker("Pack", selection: $selectedPack) {
                    ForEach(IconPack.allCases) { pack in
                        Text(pack.rawValue).tag(pack)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 170)
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Search \(catalog.allIcons.count) icons by name or tags", text: $query)
                    .textFieldStyle(.plain)
                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(10)

            Divider()

            // Icon grid
            if !catalog.isLoaded {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Indexing 21,000+ vector icons…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if results.isEmpty {
                VStack(spacing: 6) {
                    Text("No icons match “\(query)” in \(selectedPack.rawValue)")
                        .foregroundColor(.secondary)
                    Text("Try searching in “All” or using a shorter term.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(results) { icon in
                            cell(icon)
                        }
                    }
                    .padding(12)
                }
            }

            Divider()

            // Footer
            HStack {
                if let sel = selection {
                    ZStack {
                        if sel.pack == .sfSymbols, let sym = sel.symbolName {
                            Image(systemName: sym)
                                .font(.system(size: 18))
                        } else if let img = catalog.renderImage(for: sel, targetSize: CGSize(width: 24, height: 24)) {
                            Image(nsImage: img)
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                        }
                    }
                    .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sel.name)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                        Text(sel.pack.rawValue)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Button("Use Icon") {
                    commitSelection()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selection == nil)
            }
            .padding()
        }
        .frame(width: 580, height: 600)
        .onAppear {
            if selection == nil, !initialSymbol.isEmpty {
                if let found = catalog.allIcons.first(where: { $0.name == initialSymbol || $0.symbolName == initialSymbol }) {
                    selection = found
                }
            }
        }
    }

    @ViewBuilder
    private func cell(_ icon: UnifiedIcon) -> some View {
        let isSelected = selection?.id == icon.id
        Button(action: { selection = icon }) {
            ZStack {
                if icon.pack == .sfSymbols, let sym = icon.symbolName {
                    Image(systemName: sym)
                        .font(.system(size: 20))
                } else if let img = catalog.renderImage(for: icon, targetSize: CGSize(width: 26, height: 26)) {
                    Image(nsImage: img)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                } else {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .help("\(icon.name) (\(icon.pack.rawValue))")
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            selection = icon
            commitSelection()
        })
    }

    private func commitSelection() {
        guard let sel = selection else { return }
        
        if sel.pack == .sfSymbols {
            let sym = sel.symbolName ?? sel.name
            if let onPickIcon {
                onPickIcon(.sfSymbol, sym, nil)
            }
            onPick?(sym)
        } else {
            // Non-SF-Symbol: export vector SVG to Icons directory
            do {
                let filename = try catalog.saveSVG(for: sel)
                if let onPickIcon {
                    onPickIcon(.custom, sel.name, filename)
                } else {
                    onPick?(sel.name)
                }
            } catch {
                NSLog("SymbolBrowserSheet: failed to save SVG for \(sel.name): \(error.localizedDescription)")
                if let onPickIcon {
                    onPickIcon(.custom, sel.name, nil)
                } else {
                    onPick?(sel.name)
                }
            }
        }
        dismiss()
    }
}
