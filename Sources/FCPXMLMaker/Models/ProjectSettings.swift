import Foundation

/// Project-level settings for resolution and frame rate
struct ProjectSettings: Codable {
    var width: Int = 1920
    var height: Int = 1080
    var frameRate: FrameRate = .fps30
    
    enum FrameRate: String, Codable, CaseIterable {
        case fps23_976 = "23.976"
        case fps24 = "24"
        case fps25 = "25"
        case fps29_97 = "29.97"
        case fps30 = "30"
        case fps50 = "50"
        case fps59_94 = "59.94"
        case fps60 = "60"
        
        var displayName: String { rawValue + " fps" }
        
        /// Frame duration in FCPXML rational format
        var frameDuration: String {
            switch self {
            case .fps23_976: return "1001/24000s"
            case .fps24: return "100/2400s"
            case .fps25: return "100/2500s"
            case .fps29_97: return "1001/30000s"
            case .fps30: return "100/3000s"
            case .fps50: return "100/5000s"
            case .fps59_94: return "1001/60000s"
            case .fps60: return "100/6000s"
            }
        }
        
        /// Frames per second as Double
        var fps: Double {
            switch self {
            case .fps23_976: return 24000.0 / 1001.0
            case .fps24: return 24.0
            case .fps25: return 25.0
            case .fps29_97: return 30000.0 / 1001.0
            case .fps30: return 30.0
            case .fps50: return 50.0
            case .fps59_94: return 60000.0 / 1001.0
            case .fps60: return 60.0
            }
        }
        
        /// Timebase numerator for rational time format
        var timebaseNumerator: Int {
            switch self {
            case .fps23_976: return 1001
            case .fps24: return 100
            case .fps25: return 100
            case .fps29_97: return 1001
            case .fps30: return 100
            case .fps50: return 100
            case .fps59_94: return 1001
            case .fps60: return 100
            }
        }
        
        /// Timebase denominator for rational time format
        var timebaseDenominator: Int {
            switch self {
            case .fps23_976: return 24000
            case .fps24: return 2400
            case .fps25: return 2500
            case .fps29_97: return 30000
            case .fps30: return 3000
            case .fps50: return 5000
            case .fps59_94: return 60000
            case .fps60: return 6000
            }
        }
    }
    
    enum ResolutionPreset: String, CaseIterable {
        case hd720p = "720p (1280×720)"
        case hd1080p = "1080p (1920×1080)"
        case uhd4k = "4K (3840×2160)"
        case dci4k = "DCI 4K (4096×2160)"
        case shorts1080p = "Shorts 1080p (1080×1920)"
        case shorts4k = "Shorts 4K (2160×3840)"
        case custom = "커스텀"
        
        var size: (width: Int, height: Int)? {
            switch self {
            case .hd720p: return (1280, 720)
            case .hd1080p: return (1920, 1080)
            case .uhd4k: return (3840, 2160)
            case .dci4k: return (4096, 2160)
            case .shorts1080p: return (1080, 1920)
            case .shorts4k: return (2160, 3840)
            case .custom: return nil
            }
        }
    }
    
    /// Convert TimeInterval to FCPXML rational time string
    func timeToFCPXML(_ time: TimeInterval) -> String {
        let totalFrames = Int(round(time * Double(frameRate.timebaseDenominator) / Double(frameRate.timebaseNumerator)))
        let ticks = totalFrames * frameRate.timebaseNumerator
        return "\(ticks)/\(frameRate.timebaseDenominator)s"
    }
    
    /// FCPXML format name — must match FCP's built-in format identifiers
    var formatName: String {
        // FCP uses specific naming conventions for known resolutions
        let fpsString = frameRate.rawValue.replacingOccurrences(of: ".", with: "")
        
        switch (width, height) {
        case (1280, 720):
            return "FFVideoFormat720p\(fpsString)"
        case (1920, 1080):
            return "FFVideoFormat1080p\(fpsString)"
        case (3840, 2160):
            return "FFVideoFormatRateUndefined"
        case (4096, 2160):
            return "FFVideoFormatRateUndefined"
        default:
            // For non-standard resolutions (shorts, custom), use rate-undefined 
            // and rely on explicit width/height attributes in the format element
            return "FFVideoFormatRateUndefined"
        }
    }
}
