import AppKit
import CoreText
import Foundation

public final class FontGlyphVectorHelper {
    public static let shared = FontGlyphVectorHelper()
    
    private var registeredFonts = Set<String>()
    private var loadedFonts: [String: CTFont] = [:]
    private let cache = NSCache<NSString, NSImage>()
    
    private init() {}
    
    public func registerFontIfNeeded(fileName: String, fontPostScriptName: String) {
        if registeredFonts.contains(fileName) { return }
        
        guard let url = ResourceLocator.resolveURL(forResource: fileName) else {
            return
        }
        
        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            registeredFonts.insert(fileName)
        }
        
        if let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
           let desc = descriptors.first {
            let ctFont = CTFontCreateWithFontDescriptor(desc, 100, nil)
            loadedFonts[fontPostScriptName] = ctFont
        }
    }
    
    public func getCTFont(postScriptName: String, fileName: String) -> CTFont? {
        registerFontIfNeeded(fileName: fileName, fontPostScriptName: postScriptName)
        return loadedFonts[postScriptName]
    }
    
    public func pathForCharacter(_ character: String, inFont postScriptName: String, fileName: String) -> CGPath? {
        guard let font = getCTFont(postScriptName: postScriptName, fileName: fileName) else {
            return nil
        }
        let utf16Chars = Array(character.utf16)
        guard !utf16Chars.isEmpty else { return nil }
        var glyphs = [CGGlyph](repeating: 0, count: utf16Chars.count)
        guard CTFontGetGlyphsForCharacters(font, utf16Chars, &glyphs, utf16Chars.count), glyphs[0] != 0 else {
            return nil
        }
        return CTFontCreatePathForGlyph(font, glyphs[0], nil)
    }
    
    /// Normalizes any glyph CGPath to fit within a 100x100 canvas (centered 80x80), flipped Y-down for standard SVG
    public func normalizedSVGPath(for path: CGPath, canvasSize: CGFloat = 100, padding: CGFloat = 10) -> (svgPathString: String, viewBox: CGRect)? {
        let box = path.boundingBox
        guard !box.isEmpty, box.width > 0, box.height > 0 else { return nil }
        
        let targetSpan = canvasSize - (padding * 2.0)
        let scale = targetSpan / max(box.width, box.height)
        
        var t = CGAffineTransform.identity
        t = t.translatedBy(x: (canvasSize - box.width * scale) / 2.0, y: (canvasSize - box.height * scale) / 2.0 + box.height * scale)
        t = t.scaledBy(x: scale, y: -scale)
        t = t.translatedBy(x: -box.origin.x, y: -box.origin.y)
        
        guard let normPath = path.copy(using: &t) else { return nil }
        
        var d = ""
        normPath.applyWithBlock { element in
            let points = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                d += String(format: "M %.2f %.2f ", points[0].x, points[0].y)
            case .addLineToPoint:
                d += String(format: "L %.2f %.2f ", points[0].x, points[0].y)
            case .addQuadCurveToPoint:
                d += String(format: "Q %.2f %.2f %.2f %.2f ", points[0].x, points[0].y, points[1].x, points[1].y)
            case .addCurveToPoint:
                d += String(format: "C %.2f %.2f %.2f %.2f %.2f %.2f ", points[0].x, points[0].y, points[1].x, points[1].y, points[2].x, points[2].y)
            case .closeSubpath:
                d += "Z "
            @unknown default:
                break
            }
        }
        
        return (d, CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))
    }
    
    public func svgString(for character: String, inFont postScriptName: String, fileName: String) -> String? {
        guard let path = pathForCharacter(character, inFont: postScriptName, fileName: fileName),
              let (d, box) = normalizedSVGPath(for: path) else {
            return nil
        }
        return """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(Int(box.width)) \(Int(box.height))">
          <path d="\(d)" fill="currentColor"/>
        </svg>
        """
    }
    
    public func renderPreview(character: String, inFont postScriptName: String, fileName: String, size: CGFloat = 44, color: NSColor? = nil) -> NSImage? {
        let cacheKey = "\(postScriptName)_\(character)_\(Int(size))_\(color?.description ?? "template")" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        
        registerFontIfNeeded(fileName: fileName, fontPostScriptName: postScriptName)
        
        let canvasW = size * 2.0
        let canvasH = size * 2.0
        let img = NSImage(size: NSSize(width: canvasW, height: canvasH))
        img.lockFocus()
        
        let font = NSFont(name: postScriptName, size: canvasH * 0.72) ?? NSFont.systemFont(ofSize: canvasH * 0.72)
        let textColor = color ?? NSColor.white
        let astr = NSAttributedString(string: character, attributes: [
            .font: font,
            .foregroundColor: textColor
        ])
        let strSize = astr.size()
        let pt = NSPoint(x: (canvasW - strSize.width) / 2.0, y: (canvasH - strSize.height) / 2.0)
        astr.draw(at: pt)
        img.unlockFocus()
        
        let out = NSImage(size: NSSize(width: size, height: size))
        out.lockFocus()
        img.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero, operation: .copy, fraction: 1.0)
        out.unlockFocus()
        out.isTemplate = true
        
        cache.setObject(out, forKey: cacheKey)
        return out
    }
}
