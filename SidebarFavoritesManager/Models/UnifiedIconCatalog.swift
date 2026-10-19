import AppKit
import Foundation
import Combine

public enum IconPack: String, CaseIterable, Identifiable {
    case all = "All (21k)"
    case sfSymbols = "SF Symbols (8.3k)"
    case tabler = "Tabler (5.1k)"
    case simple = "Simple Icons (3.4k)"
    case lucide = "Lucide (2.1k)"
    case phosphor = "Phosphor (1.5k)"
    case heroicons = "Heroicons (648)"
    
    public var id: String { rawValue }
    
    public var shortName: String {
        switch self {
        case .all: return "all"
        case .sfSymbols: return "sf"
        case .tabler: return "tabler"
        case .simple: return "simple"
        case .lucide: return "lucide"
        case .phosphor: return "phosphor"
        case .heroicons: return "heroicons"
        }
    }
}

public struct UnifiedIcon: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let pack: IconPack
    public let character: String
    public let symbolName: String?
    public let searchTokens: String
    
    public init(name: String, pack: IconPack, character: String = "", symbolName: String? = nil, tags: [String] = []) {
        self.id = "\(pack.shortName):\(name)"
        self.name = name
        self.pack = pack
        self.character = character
        self.symbolName = symbolName
        let combined = "\(name) \(tags.joined(separator: " "))".lowercased()
        self.searchTokens = combined
    }
}

public class UnifiedIconCatalog: ObservableObject {
    public static let shared = UnifiedIconCatalog()
    
    @Published public var allIcons: [UnifiedIcon] = []
    @Published public var isLoaded: Bool = false
    
    private init() {
        buildIndex()
    }
    
    public func buildIndex() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var items: [UnifiedIcon] = []
            
            // 1. SF Symbols from SymbolCatalog
            for sym in SymbolCatalog.all {
                items.append(UnifiedIcon(name: sym.name, pack: .sfSymbols, symbolName: sym.name, tags: sym.keywords))
            }
            
            // 2. Tabler Icons
            for tab in TablerCatalog.shared.icons {
                items.append(UnifiedIcon(name: tab.name, pack: .tabler, character: tab.character, tags: tab.tags))
            }
            
            // 3. Simple Icons
            for simp in SimpleIconsCatalog.shared.icons {
                items.append(UnifiedIcon(name: simp.name, pack: .simple, character: simp.character, tags: simp.tags))
            }
            
            // 4. Lucide Icons
            for luc in LucideCatalog.shared.icons {
                items.append(UnifiedIcon(name: luc.name, pack: .lucide, character: luc.character, tags: luc.tags))
            }
            
            // 5. Phosphor Icons
            for phos in PhosphorCatalog.shared.icons {
                items.append(UnifiedIcon(name: phos.name, pack: .phosphor, character: phos.character, tags: phos.tags))
            }
            
            // 6. Heroicons
            for hero in HeroiconsCatalog.shared.icons {
                items.append(UnifiedIcon(name: hero.name, pack: .heroicons, character: "", tags: hero.tags))
            }
            
            DispatchQueue.main.async {
                self?.allIcons = items
                self?.isLoaded = true
            }
        }
    }
    
    public func search(query: String, pack: IconPack) -> [UnifiedIcon] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        let pool: [UnifiedIcon]
        if pack == .all {
            pool = allIcons
        } else {
            pool = allIcons.filter { $0.pack == pack }
        }
        
        if q.isEmpty {
            return pool
        }
        
        // Exact prefix matches first, then token search
        var prefix: [UnifiedIcon] = []
        var other: [UnifiedIcon] = []
        
        for item in pool {
            if item.name.hasPrefix(q) {
                prefix.append(item)
            } else if item.searchTokens.contains(q) {
                other.append(item)
            }
        }
        
        return prefix + other
    }
    
    public func renderImage(for icon: UnifiedIcon, targetSize: CGSize = CGSize(width: 44, height: 44)) -> NSImage? {
        switch icon.pack {
        case .sfSymbols:
            if let sym = icon.symbolName {
                let conf = NSImage.SymbolConfiguration(pointSize: targetSize.width * 0.72, weight: .regular)
                if let sysImg = NSImage(systemSymbolName: sym, accessibilityDescription: nil)?.withSymbolConfiguration(conf) {
                    return sysImg
                }
            }
            return nil
            
        case .heroicons:
            return HeroiconsCatalog.shared.renderIcon(name: icon.name, size: targetSize.width, isTemplate: true)
            
        case .tabler:
            return TablerCatalog.shared.renderIcon(name: icon.name, size: targetSize.width)
            
        case .simple:
            return SimpleIconsCatalog.shared.renderIcon(name: icon.name, size: targetSize.width)
            
        case .lucide:
            return LucideCatalog.shared.renderIcon(name: icon.name, size: targetSize.width)
            
        case .phosphor:
            return PhosphorCatalog.shared.renderIcon(name: icon.name, size: targetSize.width)
            
        case .all:
            return nil
        }
    }
    
    /// Returns the SVG string for any vector icon (non-SF-Symbol)
    public func exportSVG(for icon: UnifiedIcon) -> (svg: String, filename: String)? {
        let cleanName = icon.name.replacingOccurrences(of: "/", with: "-")
        let filename = "\(icon.pack.shortName).\(cleanName).svg"
        
        switch icon.pack {
        case .heroicons:
            if let svg = HeroiconsCatalog.shared.svgString(for: icon.name) {
                return (svg, filename)
            }
        case .tabler:
            if let svg = TablerCatalog.shared.svgString(for: icon.name) {
                return (svg, filename)
            }
        case .simple:
            if let svg = SimpleIconsCatalog.shared.svgString(for: icon.name) {
                return (svg, filename)
            }
        case .lucide:
            if let svg = LucideCatalog.shared.svgString(for: icon.name) {
                return (svg, filename)
            }
        case .phosphor:
            if let svg = PhosphorCatalog.shared.svgString(for: icon.name) {
                return (svg, filename)
            }
        default:
            return nil
        }
        return nil
    }
    
    /// Saves the vector SVG for a chosen non-SF icon into SidebarFavorites' custom icons directory
    @discardableResult
    public func saveSVG(for icon: UnifiedIcon) throws -> String {
        guard let (svgContent, filename) = exportSVG(for: icon) else {
            throw NSError(domain: "UnifiedIconCatalog", code: 1, userInfo: [NSLocalizedDescriptionKey: "Icon has no SVG representation"])
        }
        
        let iconsDir = ConfigManager.shared.iconsDirectoryURL
        try FileManager.default.createDirectory(at: iconsDir, withIntermediateDirectories: true)
        let destinationURL = iconsDir.appendingPathComponent(filename)
        try svgContent.write(to: destinationURL, atomically: true, encoding: .utf8)
        return filename
    }
}
