import AVFoundation
import Foundation

/// Service to extract audio from video files using AVFoundation
final class AudioExtractor: @unchecked Sendable {
    
    enum AudioExtractorError: LocalizedError {
        case noAudioTrack
        case exportFailed(String)
        case conversionFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .noAudioTrack:
                return "영상에서 오디오 트랙을 찾을 수 없습니다."
            case .exportFailed(let reason):
                return "오디오 내보내기 실패: \(reason)"
            case .conversionFailed(let reason):
                return "오디오 변환 실패: \(reason)"
            }
        }
    }
    
    /// Extract audio from video and convert to 16kHz mono WAV for Whisper
    func extractAudio(from videoURL: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent(UUID().uuidString + ".wav")
        try? FileManager.default.removeItem(at: outputURL)

        // For MKV and explicit audio files like MP3, we should bypass AVFoundation
        let ext = videoURL.pathExtension.lowercased()
        if ["mkv", "mp3", "wav", "m4a", "flac"].contains(ext) {
            try await convertWithFFmpeg(inputURL: videoURL, outputURL: outputURL, progress: progress)
            return outputURL
        }

        // Try AVFoundation
        let asset = AVURLAsset(url: videoURL)
        do {
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            if audioTracks.isEmpty {
                // AVFoundation might not see audio, fallback to FFmpeg
                try await convertWithFFmpeg(inputURL: videoURL, outputURL: outputURL, progress: progress)
                return outputURL
            }
            try await convertToWhisperFormat(asset: asset, outputURL: outputURL, progress: progress)
            return outputURL
        } catch {
            // If AVFoundation fails entirely, fallback to FFmpeg
            try await convertWithFFmpeg(inputURL: videoURL, outputURL: outputURL, progress: progress)
            return outputURL
        }
    }
    
    private func convertWithFFmpeg(inputURL: URL, outputURL: URL, progress: @escaping @Sendable (Double) -> Void) async throws {
        // -y: overwrite output
        // -i: input
        // -vn: ignore video
        // -acodec pcm_s16le: 16-bit PCM
        // -ar 16000: 16kHz
        // -ac 1: mono
        
        // Find ffmpeg
        let ffmpegPaths = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"]
        guard let ffmpegPath = ffmpegPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            throw AudioExtractorError.conversionFailed("ffmpeg가 설치되어 있지 않습니다. 터미널에서 'brew install ffmpeg'을 실행해주세요.")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = [
            "-y",
            "-i", inputURL.path,
            "-vn",
            "-acodec", "pcm_s16le",
            "-ar", "16000",
            "-ac", "1",
            outputURL.path
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { p in
                if p.terminationStatus == 0 {
                    progress(1.0)
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AudioExtractorError.conversionFailed("FFmpeg 프로세스 실패 (코드 \(p.terminationStatus))"))
                }
            }
            
            do {
                // Simulate progress loosely
                Task {
                    var simulatedProgress = 0.0
                    while process.isRunning {
                        simulatedProgress += 0.05
                        if simulatedProgress > 0.9 { simulatedProgress = 0.1 }
                        progress(simulatedProgress)
                        try? await Task.sleep(nanoseconds: 500_000_000)
                    }
                }
                
                try process.run()
            } catch {
                continuation.resume(throwing: AudioExtractorError.conversionFailed("FFmpeg 실행 오류: \(error.localizedDescription)"))
            }
        }
    }
    
    private func convertToWhisperFormat(asset: AVURLAsset, outputURL: URL, progress: @escaping @Sendable (Double) -> Void) async throws {
        let duration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)
        
        // Setup reader
        let reader = try AVAssetReader(asset: asset)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        
        let readerOutput = AVAssetReaderTrackOutput(track: audioTracks[0], outputSettings: outputSettings)
        reader.add(readerOutput)
        
        // Setup writer
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .wav)
        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)
        writer.add(writerInput)
        
        // Start reading/writing
        reader.startReading()
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let processingQueue = DispatchQueue(label: "com.fcpxmlmaker.audioextraction")
            
            writerInput.requestMediaDataWhenReady(on: processingQueue) {
                while writerInput.isReadyForMoreMediaData {
                    if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                        let currentTime = CMTimeGetSeconds(timestamp)
                        let progressValue = min(currentTime / totalSeconds, 1.0)
                        progress(progressValue)
                        
                        writerInput.append(sampleBuffer)
                    } else {
                        writerInput.markAsFinished()
                        
                        if reader.status == .completed {
                            writer.finishWriting {
                                if writer.status == .completed {
                                    progress(1.0)
                                    continuation.resume()
                                } else {
                                    continuation.resume(throwing: AudioExtractorError.exportFailed(writer.error?.localizedDescription ?? "알 수 없는 오류"))
                                }
                            }
                        } else {
                            continuation.resume(throwing: AudioExtractorError.exportFailed(reader.error?.localizedDescription ?? "읽기 실패"))
                        }
                        return
                    }
                }
            }
        }
    }
}
