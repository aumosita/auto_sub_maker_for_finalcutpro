import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showStyleSettings = false
    @State private var showProjectSettings = false
    @State private var isDragging = false
    
    var body: some View {
        ZStack {
            // Background using native window color
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                Divider()
                
                // Main content
                ScrollView {
                    VStack(spacing: 24) {
                        videoInputSection
                        settingsSection
                        
                        // Start button
                        if viewModel.videoURL != nil && viewModel.state == .idle && viewModel.segments.isEmpty {
                            Button(action: {
                                Task { await viewModel.startProcessing() }
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 16))
                                    Text("자막 생성 시작")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.accentColor)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if viewModel.state != .idle || !viewModel.segments.isEmpty {
                            processingSection
                        }
                        
                        if !viewModel.segments.isEmpty {
                            transcriptionResultSection
                        }
                    }
                    .padding(24)
                }
            }
        }
        .sheet(isPresented: $showStyleSettings) {
            StyleSettingsView()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showProjectSettings) {
            ProjectSettingsView()
                .environmentObject(viewModel)
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("FCPXML Subtitle Maker")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("영상/음성 → Whisper 트랜스크립션 → FCPXML 자막")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Model status indicators
            HStack(spacing: 12) {
                modelBadge(.small, available: viewModel.smallModelAvailable)
                modelBadge(.medium, available: viewModel.mediumModelAvailable)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    private func modelBadge(_ model: WhisperModel, available: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(available ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            Text(model.rawValue.capitalized)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
        )
    }
    
    // MARK: - Video Input Section
    
    private var videoInputSection: some View {
        VStack(spacing: 16) {
            sectionHeader(title: "1. 미디어 파일", icon: "play.rectangle")
            
            // Drop zone
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(isDragging ? 0.8 : 0.5))
                    .stroke(
                        isDragging ? Color.accentColor : Color.secondary.opacity(0.2),
                        style: StrokeStyle(lineWidth: isDragging ? 2 : 1, dash: isDragging ? [8, 4] : [])
                    )
                    .animation(.easeInOut(duration: 0.2), value: isDragging)
                
                if let _ = viewModel.videoURL {
                    HStack(spacing: 12) {
                        Image(systemName: "film.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.videoFileName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("클릭하여 다른 파일 선택")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: { viewModel.reset() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.accentColor)
                        
                        Text("영상 또는 음성 파일을 드래그하거나 클릭하여 선택")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("MKV, MP4, MOV, MP3, WAV 등 지원")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .padding(32)
                }
            }
            .frame(height: viewModel.videoURL != nil ? 80 : 140)
            .onTapGesture { viewModel.selectVideo() }
            .onDrop(of: [.movie, .mpeg4Movie, .quickTimeMovie, .audio, .mp3, .wav, UTType(filenameExtension: "mkv")].compactMap { $0 }, isTargeted: $isDragging) { providers in
                handleDrop(providers)
            }
        }
        .cardStyle()
    }
    
    // MARK: - Settings Section
    
    private var settingsSection: some View {
        VStack(spacing: 16) {
            sectionHeader(title: "2. 설정", icon: "gearshape")
            
            HStack(spacing: 12) {
                // Model selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Whisper 모델")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $viewModel.selectedModel) {
                        ForEach(WhisperModel.allCases, id: \.self) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .frame(maxWidth: .infinity)
                
                // Language
                VStack(alignment: .leading, spacing: 8) {
                    Text("언어")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $viewModel.language) {
                        Text("자동 감지").tag("auto")
                        Text("한국어").tag("ko")
                        Text("English").tag("en")
                        Text("日本語").tag("ja")
                        Text("中文").tag("zh")
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
            }
            
            HStack(spacing: 12) {
                // Style settings button
                settingsButton(
                    title: "자막 스타일",
                    subtitle: "\(viewModel.subtitleStyle.fontName), \(Int(viewModel.subtitleStyle.fontSize))pt",
                    icon: "textformat",
                    action: { showStyleSettings = true }
                )
                
                // Project settings button
                settingsButton(
                    title: "해상도 / 프레임레이트",
                    subtitle: "\(viewModel.projectSettings.width)×\(viewModel.projectSettings.height), \(viewModel.projectSettings.frameRate.displayName)",
                    icon: "display",
                    action: { showProjectSettings = true }
                )
            }
            
            // FCP Template
            if let template = viewModel.fcpxmlTemplate {
                HStack(spacing: 10) {
                    Image(systemName: "doc.badge.gearshape.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.purple)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.purple.opacity(0.15))
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FCP 템플릿")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        Text("\(template.effectName) — \(viewModel.templateFileName)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.purple.opacity(0.8))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button(action: { viewModel.removeTemplate() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.purple.opacity(0.06))
                        .stroke(Color.purple.opacity(0.2), lineWidth: 0.5)
                )
            } else {
                Button(action: { viewModel.loadTemplate() }) {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.badge.gearshape")
                            .font(.system(size: 16))
                            .foregroundColor(.purple.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.purple.opacity(0.1))
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("FCP 템플릿 불러오기")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                            Text("FCP에서 내보낸 .fcpxml 파일의 타이틀 스타일 사용")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.35))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.purple.opacity(0.4))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.03))
                            .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [6, 3]))
                    )
                }
                .buttonStyle(.plain)
            }
            
            // Download model button (if needed)
            if !WhisperService.isModelDownloaded(viewModel.selectedModel) {
                Button(action: {
                    Task { await viewModel.downloadModel(viewModel.selectedModel) }
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("\(viewModel.selectedModel.rawValue.capitalized) 모델 다운로드")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.3))
                            .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .cardStyle()
    }
    
    private func settingsButton(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.15))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Processing Section
    
    private var processingSection: some View {
        VStack(spacing: 16) {
            sectionHeader(title: "3. 처리", icon: "waveform")
            
            // Progress bar
            if viewModel.state != .idle && viewModel.state != .completed {
                VStack(spacing: 10) {
                    HStack {
                        Text(viewModel.state.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(Int(viewModel.progress * 100))%")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.blue)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.1))
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.accentColor)
                                .frame(width: geo.size.width * viewModel.progress)
                                .animation(.easeInOut(duration: 0.3), value: viewModel.progress)
                        }
                    }
                    .frame(height: 6)
                    
                    if !viewModel.statusDetail.isEmpty {
                        HStack {
                            Text(viewModel.statusDetail)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                if viewModel.state == .idle {
                    Button(action: {
                        Task { await viewModel.startProcessing() }
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("트랜스크립션 시작")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accentColor)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.videoURL == nil)
                    .opacity(viewModel.videoURL == nil ? 0.5 : 1)
                }
                
                if viewModel.state == .completed {
                    Button(action: { viewModel.saveFCPXML() }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down.fill")
                            Text("FCPXML 저장")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [.green.opacity(0.8), .green.opacity(0.5)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { viewModel.reset() }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("새로 시작")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Error display
            if case .error(let message) = viewModel.state {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.1))
                        .stroke(Color.red.opacity(0.2), lineWidth: 0.5)
                )
            }
        }
        .cardStyle()
    }
    
    // MARK: - Transcription Result
    
    private var transcriptionResultSection: some View {
        VStack(spacing: 16) {
            HStack {
                sectionHeader(title: "4. 트랜스크립션 결과", icon: "text.bubble")
                Spacer()
                Text("\(viewModel.segments.count)개 세그먼트")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                
                if viewModel.state == .completed {
                    Button("FCPXML 다시 생성") {
                        viewModel.regenerateFCPXML()
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.blue)
                    .buttonStyle(.plain)
                }
            }
            
            ForEach(Array(viewModel.segments.enumerated()), id: \.element.id) { index, segment in
                SegmentRow(segment: $viewModel.segments[index])
            }
        }
        .cardStyle()
    }
    
    // MARK: - Helpers
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.accentColor)
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.primary)
            Spacer()
        }
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: UTType.movie.identifier, options: nil) { data, error in
            if let url = data as? URL {
                Task { @MainActor in
                    viewModel.videoURL = url
                    viewModel.videoFileName = url.lastPathComponent
                }
            }
        }
        return true
    }
}

// MARK: - Segment Row
struct SegmentRow: View {
    @Binding var segment: TranscriptionSegment
    @State private var isEditing = false
    @State private var editText = ""
    
    var body: some View {
        HStack(spacing: 12) {
            // Time range
            VStack(alignment: .trailing, spacing: 2) {
                Text(segment.formattedStartTime)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.accentColor)
                Text(segment.formattedEndTime)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(width: 90)
            
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 1)
            
            // Text
            if isEditing {
                TextField("자막 텍스트", text: $editText, onCommit: {
                    segment.text = editText
                    isEditing = false
                })
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.white)
            } else {
                Text(segment.text)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture {
                        editText = segment.text
                        isEditing = true
                    }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
        )
    }
}

// MARK: - Card Style Modifier
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}
