import Foundation

public struct ResourceLocator {
    public static func resolveURL(forResource name: String) -> URL? {
        let fileManager = FileManager.default
        
        // 1. Bundle main resources directory
        if let bundleRes = Bundle.main.resourceURL?.appendingPathComponent(name),
           fileManager.fileExists(atPath: bundleRes.path) {
            return bundleRes
        }
        
        // 2. Direct Contents/Resources inside bundle URL
        let directRes = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/\(name)")
        if fileManager.fileExists(atPath: directRes.path) {
            return directRes
        }
        
        // 3. Fallback to known development/resource paths
        let candidates = [
            "/Applications/SidebarFavorites Manager.app/Contents/Resources/\(name)",
            "/Users/richardmcewan/programs/SidebarFavorites/SidebarFavoritesManager/Resources/\(name)",
            "/Users/richardmcewan/programs/sidebarcraft/app/src/Resources/\(name)"
        ]
        
        for candidate in candidates {
            if fileManager.fileExists(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }
        
        return nil
    }
}
