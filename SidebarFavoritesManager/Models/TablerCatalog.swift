import AppKit
import Foundation

public struct TablerIcon: Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public let category: String
    public let tags: [String]
    public let unicode: String
    public let character: String
    
    public init(name: String, category: String, tags: [String], unicode: String) {
        self.name = name
        self.category = category
        self.tags = tags
        self.unicode = unicode
        if let val = UInt32(unicode, radix: 16), let scalar = UnicodeScalar(val) {
            self.character = String(scalar)
        } else {
            self.character = ""
        }
    }
}

public class TablerCatalog: ObservableObject {
    public static let shared = TablerCatalog()
    
    @Published public var icons: [TablerIcon] = []
    @Published public var categories: [String] = ["All"]
    public private(set) var iconMap: [String: TablerIcon] = [:]
    
    private init() {
        loadCatalog()
    }
    
    private func loadCatalog() {
        guard let url = ResourceLocator.resolveURL(forResource: "tabler_icons.json"),
              let data = try? Data(contentsOf: url) else {
            return
        }
        
        struct Root: Decodable {
            let categories: [String]
            let icons: [RawIcon]
        }
        
        struct RawIcon: Decodable {
            let name: String
            let category: String
            let tags: [String]
            let unicode: String
        }
        
        guard let root = try? JSONDecoder().decode(Root.self, from: data) else {
            return
        }
        
        var loaded: [TablerIcon] = []
        var map: [String: TablerIcon] = [:]
        
        for raw in root.icons {
            let item = TablerIcon(name: raw.name, category: raw.category, tags: raw.tags, unicode: raw.unicode)
            loaded.append(item)
            map[raw.name] = item
        }
        
        self.icons = loaded
        self.iconMap = map
        self.categories = ["All"] + root.categories
    }
    
    public func renderIcon(name: String, size: CGFloat = 44, color: NSColor? = nil) -> NSImage? {
        guard let icon = iconMap[name], !icon.character.isEmpty else { return nil }
        return FontGlyphVectorHelper.shared.renderPreview(
            character: icon.character,
            inFont: "tabler-icons",
            fileName: "tabler-icons.ttf",
            size: size,
            color: color
        )
    }
    
    public func svgString(for name: String) -> String? {
        guard let icon = iconMap[name], !icon.character.isEmpty else { return nil }
        return FontGlyphVectorHelper.shared.svgString(
            for: icon.character,
            inFont: "tabler-icons",
            fileName: "tabler-icons.ttf"
        )
    }
}
