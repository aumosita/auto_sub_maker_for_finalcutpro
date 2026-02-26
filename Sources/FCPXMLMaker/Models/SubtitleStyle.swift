import SwiftUI

/// Subtitle font and style configuration
struct SubtitleStyle: Codable {
    var fontName: String = "Helvetica Neue"
    var fontSize: CGFloat = 60
    var fontColorHex: String = "#FFFFFF"
    var bold: Bool = false
    var italic: Bool = false
    var alignment: SubtitleAlignment = .center
    var strokeColorHex: String = "#000000"
    var strokeWidth: CGFloat = 2
    var verticalPosition: CGFloat = -450 // negative = lower on screen
    
    enum SubtitleAlignment: String, Codable, CaseIterable {
        case left, center, right
        
        var displayName: String {
            switch self {
            case .left: return "왼쪽"
            case .center: return "가운데"
            case .right: return "오른쪽"
            }
        }
        
        var fcpxmlValue: String {
            switch self {
            case .left: return "left"
            case .center: return "center"
            case .right: return "right"
            }
        }
    }
    
    // FCPXML color format: "R G B A" with values 0-1
    var fcpxmlFontColor: String {
        colorToFCPXML(fontColorHex)
    }
    
    var fcpxmlStrokeColor: String {
        colorToFCPXML(strokeColorHex)
    }
    
    private func colorToFCPXML(_ hex: String) -> String {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        return String(format: "%.4f %.4f %.4f 1", r, g, b)
    }
    
    var fontColor: Color {
        Color(hex: fontColorHex)
    }
    
    var strokeColor: Color {
        Color(hex: strokeColorHex)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
    
    func toHex() -> String {
        let nsColor = NSColor(self)
        guard let rgb = nsColor.usingColorSpace(.sRGB) else { return "#FFFFFF" }
        let r = Int(rgb.redComponent * 255)
        let g = Int(rgb.greenComponent * 255)
        let b = Int(rgb.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
