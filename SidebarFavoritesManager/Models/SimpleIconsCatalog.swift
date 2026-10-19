import AppKit
import Foundation

public struct SimpleIcon: Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public let title: String
    public let category: String
    public let tags: [String]
    public let unicode: String
    public let hex: String
    public let character: String
    
    public init(name: String, title: String, category: String, tags: [String], unicode: String, hex: String) {
        self.name = name
        self.title = title
        self.category = category
        self.tags = tags
        self.unicode = unicode
        self.hex = hex
        if let val = UInt32(unicode, radix: 16), let scalar = UnicodeScalar(val) {
            self.character = String(scalar)
        } else {
            self.character = ""
        }
    }
}

public class SimpleIconsCatalog: ObservableObject {
    public static let shared = SimpleIconsCatalog()
    
    @Published public var icons: [SimpleIcon] = []
    @Published public var categories: [String] = ["All"]
    public private(set) var iconMap: [String: SimpleIcon] = [:]
    
    private init() {
        loadCatalog()
    }
    
    private func loadCatalog() {
        guard let url = ResourceLocator.resolveURL(forResource: "simple_icons.json"),
              let data = try? Data(contentsOf: url) else {
            return
        }
        
        struct Root: Decodable {
            let categories: [String]
            let icons: [RawIcon]
        }
        
        struct RawIcon: Decodable {
            let name: String
            let title: String
            let category: String
            let tags: [String]
            let unicode: String
            let hex: String
        }
        
        guard let root = try? JSONDecoder().decode(Root.self, from: data) else {
            return
        }
        
        var loaded: [SimpleIcon] = []
        var map: [String: SimpleIcon] = [:]
        
        for raw in root.icons {
            let item = SimpleIcon(name: raw.name, title: raw.title, category: raw.category, tags: raw.tags, unicode: raw.unicode, hex: raw.hex)
            loaded.append(item)
            map[raw.name] = item
            map[raw.title.lowercased()] = item
        }
        
        self.icons = loaded
        self.iconMap = map
        self.categories = ["All"] + root.categories
    }
    
    public func renderIcon(name: String, size: CGFloat = 44, color: NSColor? = nil) -> NSImage? {
        guard let icon = iconMap[name], !icon.character.isEmpty else { return nil }
        return FontGlyphVectorHelper.shared.renderPreview(
            character: icon.character,
            inFont: "SimpleIcons",
            fileName: "SimpleIcons.ttf",
            size: size,
            color: color
        )
    }
    
    public func svgString(for name: String) -> String? {
        guard let icon = iconMap[name], !icon.character.isEmpty else { return nil }
        return FontGlyphVectorHelper.shared.svgString(
            for: icon.character,
            inFont: "SimpleIcons",
            fileName: "SimpleIcons.ttf"
        )
    }
}
