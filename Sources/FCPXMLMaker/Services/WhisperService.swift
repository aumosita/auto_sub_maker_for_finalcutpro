import Foundation
import SwiftWhisper

/// Available Whisper model sizes
enum WhisperModel: String, CaseIterable, Codable {
    case small = "small"
    case medium = "medium"
    
    var displayName: String {
        switch self {
        case .small: return "Small (약 500MB)"
        case .medium: return "Medium (약 1.5GB)"
        }
    }
    
    var fileName: String {
        "ggml-\(rawValue).bin"
    }
    
    var downloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(fileName)")!
    }
}

/// Service for transcription using whisper.cpp via SwiftWhisper
final class WhisperService: @unchecked Sendable {
    
    enum WhisperServiceError: LocalizedError {
        case modelNotFound
        case transcriptionFailed(String)
        case downloadFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .modelNotFound:
                return "Whisper 모델 파일을 찾을 수 없습니다."
            case .transcriptionFailed(let reason):
                return "트랜스크립션 실패: \(reason)"
            case .downloadFailed(let reason):
                return "모델 다운로드 실패: \(reason)"
            }
        }
    }
    
    /// Directory where models are stored
    static var modelDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("FCPXMLMaker/Models")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    /// Check if a model is downloaded
    static func isModelDownloaded(_ model: WhisperModel) -> Bool {
        let path = modelDirectory.appendingPathComponent(model.fileName)
        return FileManager.default.fileExists(atPath: path.path)
    }
    
    /// Get model file path
    static func modelPath(_ model: WhisperModel) -> URL {
        modelDirectory.appendingPathComponent(model.fileName)
    }
    
    /// Download a Whisper model
    static func downloadModel(_ model: WhisperModel, progress: @escaping @Sendable (Double) -> Void) async throws {
        let destinationURL = modelPath(model)
        
        // Skip if already downloaded
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            progress(1.0)
            return
        }
        
        let (tempURL, response) = try await URLSession.shared.download(from: model.downloadURL, delegate: DownloadDelegate(progress: progress))
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WhisperServiceError.downloadFailed("HTTP 응답 오류")
        }
        
        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        
        progress(1.0)
    }
    
    /// Transcribe audio file using Whisper
    func transcribe(audioURL: URL, model: WhisperModel, language: String? = nil, progress: @escaping @Sendable (Double) -> Void) async throws -> [TranscriptionSegment] {
        let modelPath = Self.modelPath(model)
        
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw WhisperServiceError.modelNotFound
        }
        
        // Configure Whisper parameters
        var params = WhisperParams.default // swiftlint:disable:this redundant_var
        params.language = language.flatMap { WhisperLanguage(rawValue: $0) } ?? .auto
        params.print_progress = false
        params.print_realtime = false
        params.translate = false
        
        // Initialize Whisper
        let whisper = Whisper(fromFileURL: modelPath, withParams: params)
        
        // Load audio data
        let audioData = try loadAudioData(from: audioURL)
        
        // Transcribe
        let segments = try await whisper.transcribe(audioFrames: audioData)
        
        progress(1.0)
        
        return segments.map { segment in
            TranscriptionSegment(
                startTime: TimeInterval(segment.startTime) / 1000.0,
                endTime: TimeInterval(segment.endTime) / 1000.0,
                text: segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }
    
    /// Load audio data from WAV file as Float array
    private func loadAudioData(from url: URL) throws -> [Float] {
        let data = try Data(contentsOf: url)
        
        // Skip WAV header (44 bytes)
        let headerSize = 44
        guard data.count > headerSize else {
            throw WhisperServiceError.transcriptionFailed("오디오 파일이 비어있거나 손상되었습니다.")
        }
        
        let audioData = data.subdata(in: headerSize..<data.count)
        
        // Convert 16-bit PCM to Float
        var floats = [Float]()
        floats.reserveCapacity(audioData.count / 2)
        
        audioData.withUnsafeBytes { buffer in
            let int16Buffer = buffer.bindMemory(to: Int16.self)
            for sample in int16Buffer {
                floats.append(Float(sample) / 32768.0)
            }
        }
        
        return floats
    }
}

/// URLSession download delegate for progress tracking
final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let progressHandler: @Sendable (Double) -> Void
    
    init(progress: @escaping @Sendable (Double) -> Void) {
        self.progressHandler = progress
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Handled by the async download call
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        progressHandler(progress)
    }
}
