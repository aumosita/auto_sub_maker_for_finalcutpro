import Foundation

/// A single segment of transcribed text with timing information
struct TranscriptionSegment: Identifiable, Codable {
    let id: UUID
    var startTime: TimeInterval
    var endTime: TimeInterval
    var text: String
    
    init(id: UUID = UUID(), startTime: TimeInterval, endTime: TimeInterval, text: String) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
    
    var duration: TimeInterval {
        endTime - startTime
    }
    
    /// Format time as HH:MM:SS.mmm
    static func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
    }
    
    var formattedStartTime: String {
        Self.formatTime(startTime)
    }
    
    var formattedEndTime: String {
        Self.formatTime(endTime)
    }
}
