import AppKit
import Foundation

public struct Heroicon: Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public let baseName: String
    public let style: String // "outline" or "solid"
    public let category: String
    public let tags: [String]
    public let svg: String
    
    public init(name: String, baseName: String, style: String, category: String, tags: [String], svg: String) {
        self.name = name
        self.baseName = baseName
        self.style = style
        self.category = category
        self.tags = tags
        self.svg = svg
    }
}

public class HeroiconsCatalog: ObservableObject {
    public static let shared = HeroiconsCatalog()
    
    @Published public var icons: [Heroicon] = []
    @Published public var categories: [String] = ["All"]
    public private(set) var iconMap: [String: Heroicon] = [:]
    
    private let cache = NSCache<NSString, NSImage>()
    
    private init() {
        loadCatalog()
    }
    
    private func loadCatalog() {
        guard let url = ResourceLocator.resolveURL(forResource: "heroicons.json"),
              let data = try? Data(contentsOf: url) else {
            return
        }
        
        struct RawIcon: Decodable {
            let name: String
            let baseName: String
            let style: String
            let category: String
            let tags: [String]
            let svg: String
        }
        
        guard let rawIcons = try? JSONDecoder().decode([RawIcon].self, from: data) else {
            return
        }
        
        var loaded: [Heroicon] = []
        var map: [String: Heroicon] = [:]
        var categorySet = Set<String>()
        
        for raw in rawIcons {
            let item = Heroicon(
                name: raw.name,
                baseName: raw.baseName,
                style: raw.style,
                category: raw.category,
                tags: raw.tags,
                svg: raw.svg
            )
            loaded.append(item)
            map[raw.name] = item
            categorySet.insert(raw.category)
        }
        
        self.icons = loaded
        self.iconMap = map
        self.categories = ["All"] + categorySet.sorted()
    }
    
    /// Renders any Heroicon SVG as an NSImage at target size
    public func renderIcon(name: String, size: CGFloat = 44, color: NSColor? = nil, isTemplate: Bool = true) -> NSImage? {
        let cacheKey = "\(name)_\(Int(size))_\(color?.description ?? "template")" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        
        guard let icon = iconMap[name] else { return nil }
        
        var svgStr = icon.svg
        if let col = color {
            let srgb = col.usingColorSpace(.sRGB) ?? col
            let hex = String(format: "#%02X%02X%02X", Int(srgb.redComponent * 255), Int(srgb.greenComponent * 255), Int(srgb.blueComponent * 255))
            svgStr = svgStr.replacingOccurrences(of: "currentColor", with: hex)
        } else {
            svgStr = svgStr.replacingOccurrences(of: "currentColor", with: "#FFFFFF")
        }
        
        guard let data = svgStr.data(using: .utf8),
              let svgImg = NSImage(data: data) else {
            return nil
        }
        
        let targetImg = NSImage(size: NSSize(width: size, height: size))
        targetImg.lockFocus()
        
        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        svgImg.draw(in: rect, from: .zero, operation: .copy, fraction: 1.0)
        
        targetImg.unlockFocus()
        targetImg.isTemplate = isTemplate
        
        cache.setObject(targetImg, forKey: cacheKey)
        return targetImg
    }
    
    public func svgString(for name: String) -> String? {
        guard let icon = iconMap[name] else { return nil }
        return icon.svg
    }
}
