import SwiftUI
import Combine
import UniformTypeIdentifiers

/// Processing workflow state
enum ProcessingState: Equatable {
    case idle
    case extractingAudio
    case downloadingModel
    case transcribing
    case generating
    case completed
    case error(String)
    
    var displayName: String {
        switch self {
        case .idle: return "대기 중"
        case .extractingAudio: return "오디오 추출 중..."
        case .downloadingModel: return "모델 다운로드 중..."
        case .transcribing: return "트랜스크립션 중..."
        case .generating: return "FCPXML 생성 중..."
        case .completed: return "완료"
        case .error(let msg): return "오류: \(msg)"
        }
    }
}

/// Main ViewModel orchestrating the entire workflow
@MainActor
final class AppViewModel: ObservableObject {
    // Input
    @Published var videoURL: URL?
    @Published var videoFileName: String = ""
    
    // Settings
    @Published var subtitleStyle = SubtitleStyle()
    @Published var projectSettings = ProjectSettings()
    @Published var selectedModel: WhisperModel = .small
    @Published var language: String = "ko"
    
    // Style Presets
    @Published var savedStyles: [String: SubtitleStyle] = [:]
    @Published var selectedStylePresetName: String = "기본"
    
    // Template
    @Published var fcpxmlTemplate: FCPXMLTemplate?
    @Published var templateFileName: String = ""
    
    // State
    @Published var state: ProcessingState = .idle
    @Published var progress: Double = 0
    @Published var segments: [TranscriptionSegment] = []
    @Published var generatedFCPXML: String = ""
    
    // Model availability
    @Published var smallModelAvailable: Bool = false
    @Published var mediumModelAvailable: Bool = false
    
    // Services
    private let audioExtractor = AudioExtractor()
    private let whisperService = WhisperService()
    private let fcpxmlGenerator = FCPXMLGenerator()
    private let templateParser = FCPXMLTemplateParser()
    
    init() {
        checkModelAvailability()
        loadStylePresets()
    }
    
    // MARK: - Style Presets Management
    private func loadStylePresets() {
        if let data = UserDefaults.standard.data(forKey: "savedSubtitleStyles"),
           let decoded = try? JSONDecoder().decode([String: SubtitleStyle].self, from: data) {
            savedStyles = decoded
        }
        
        // Ensure default always exists
        if savedStyles["기본"] == nil {
            savedStyles["기본"] = SubtitleStyle()
        }
        
        if let lastPreset = UserDefaults.standard.string(forKey: "lastSubtitlePresetName"),
           savedStyles.keys.contains(lastPreset) {
            selectedStylePresetName = lastPreset
            subtitleStyle = savedStyles[lastPreset]!
        } else {
            selectedStylePresetName = "기본"
            subtitleStyle = savedStyles["기본"]!
        }
    }
    
    func saveCurrentStyleAsPreset(name: String) {
        savedStyles[name] = subtitleStyle
        selectedStylePresetName = name
        persistStylePresets()
    }
    
    func deleteStylePreset(name: String) {
        guard name != "기본" else { return } // Cannot delete default
        savedStyles.removeValue(forKey: name)
        
        if selectedStylePresetName == name {
            selectedStylePresetName = "기본"
            subtitleStyle = savedStyles["기본"]!
        }
        
        persistStylePresets()
    }
    
    func applyStylePreset(name: String) {
        if let style = savedStyles[name] {
            subtitleStyle = style
            selectedStylePresetName = name
            UserDefaults.standard.set(name, forKey: "lastSubtitlePresetName")
        }
    }
    
    private func persistStylePresets() {
        if let encoded = try? JSONEncoder().encode(savedStyles) {
            UserDefaults.standard.set(encoded, forKey: "savedSubtitleStyles")
            UserDefaults.standard.set(selectedStylePresetName, forKey: "lastSubtitlePresetName")
        }
    }
    
    func checkModelAvailability() {
        smallModelAvailable = WhisperService.isModelDownloaded(.small)
        mediumModelAvailable = WhisperService.isModelDownloaded(.medium)
    }
    
    /// Select video file via open panel
    func selectVideo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .movie, .mpeg4Movie, .quickTimeMovie, .avi, .mpeg2Video,
            .audio, .mp3, .wav,
            UTType(filenameExtension: "mkv")
        ].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "자막을 생성할 영상 또는 음성 파일을 선택하세요"
        
        if panel.runModal() == .OK, let url = panel.url {
            videoURL = url
            videoFileName = url.lastPathComponent
        }
    }
    
    /// Load FCPXML template file
    func loadTemplate() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.xml]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "FCP에서 내보낸 FCPXML 템플릿 파일을 선택하세요"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                fcpxmlTemplate = try templateParser.parse(fileURL: url)
                templateFileName = url.lastPathComponent
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }
    
    /// Remove loaded template
    func removeTemplate() {
        fcpxmlTemplate = nil
        templateFileName = ""
    }
    
    /// Run the full processing pipeline
    func startProcessing() async {
        guard let videoURL = videoURL else { return }
        
        do {
            // Step 1: Extract audio
            state = .extractingAudio
            progress = 0
            
            let audioURL = try await audioExtractor.extractAudio(from: videoURL) { [weak self] p in
                Task { @MainActor in
                    self?.progress = p
                }
            }
            
            // Step 2: Download model if needed
            if !WhisperService.isModelDownloaded(selectedModel) {
                state = .downloadingModel
                progress = 0
                
                try await WhisperService.downloadModel(selectedModel) { [weak self] p in
                    Task { @MainActor in
                        self?.progress = p
                    }
                }
                checkModelAvailability()
            }
            
            // Step 3: Transcribe
            state = .transcribing
            progress = 0
            
            let lang: String? = language == "auto" ? nil : language
            segments = try await whisperService.transcribe(
                audioURL: audioURL,
                model: selectedModel,
                language: lang
            ) { [weak self] p in
                Task { @MainActor in
                    self?.progress = p
                }
            }
            
            // Clean up temp audio
            try? FileManager.default.removeItem(at: audioURL)
            
            // Step 4: Generate FCPXML
            state = .generating
            progress = 0.5
            
            let projectName = videoURL.deletingPathExtension().lastPathComponent + " Subtitles"
            generatedFCPXML = fcpxmlGenerator.generate(
                segments: segments,
                style: subtitleStyle,
                settings: projectSettings,
                template: fcpxmlTemplate,
                projectName: projectName
            )
            
            progress = 1.0
            state = .completed
            
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    /// Re-generate FCPXML with current settings (after editing segments/style)
    func regenerateFCPXML() {
        guard !segments.isEmpty else { return }
        let projectName = (videoURL?.deletingPathExtension().lastPathComponent ?? "Video") + " Subtitles"
        generatedFCPXML = fcpxmlGenerator.generate(
            segments: segments,
            style: subtitleStyle,
            settings: projectSettings,
            template: fcpxmlTemplate,
            projectName: projectName
        )
    }
    
    /// Save FCPXML to user-chosen location
    func saveFCPXML() {
        guard !generatedFCPXML.isEmpty else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.xml]
        panel.nameFieldStringValue = (videoURL?.deletingPathExtension().lastPathComponent ?? "subtitles") + ".fcpxml"
        panel.message = "FCPXML 파일 저장 위치를 선택하세요"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try fcpxmlGenerator.save(content: generatedFCPXML, to: url)
            } catch {
                state = .error("저장 실패: \(error.localizedDescription)")
            }
        }
    }
    
    /// Download a specific model
    func downloadModel(_ model: WhisperModel) async {
        state = .downloadingModel
        progress = 0
        
        do {
            try await WhisperService.downloadModel(model) { [weak self] p in
                Task { @MainActor in
                    self?.progress = p
                }
            }
            checkModelAvailability()
            state = .idle
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    /// Reset to initial state
    func reset() {
        videoURL = nil
        videoFileName = ""
        segments = []
        generatedFCPXML = ""
        state = .idle
        progress = 0
        // Note: keep template loaded across resets
    }
}
