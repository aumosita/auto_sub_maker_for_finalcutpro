import SwiftUI

struct StyleSettingsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var fontColor: Color
    @State private var strokeColor: Color
    @State private var showingSaveAlert = false
    @State private var newPresetName = ""
    @State private var showingFontPicker = false
    @State private var previewDarkBackground = true
    
    init() {
        _fontColor = State(initialValue: .white)
        _strokeColor = State(initialValue: .black)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("자막 스타일 설정")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button("완료") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Presets
                    GroupBox("프리셋") {
                        HStack {
                            Picker("", selection: Binding(
                                get: { viewModel.selectedStylePresetName },
                                set: { newValue in
                                    viewModel.applyStylePreset(name: newValue)
                                    // Update local editing colors
                                    fontColor = viewModel.subtitleStyle.fontColor
                                    strokeColor = viewModel.subtitleStyle.strokeColor
                                }
                            )) {
                                ForEach(Array(viewModel.savedStyles.keys).sorted(), id: \.self) { key in
                                    Text(key).tag(key)
                                }
                            }
                            .frame(width: 150)
                            
                            Spacer()
                            
                            Button("현재 설정으로 저장") {
                                // Just save if it's already a custom preset, or ask for save if default
                                if viewModel.selectedStylePresetName != "기본" {
                                    viewModel.saveCurrentStyleAsPreset(name: viewModel.selectedStylePresetName)
                                } else {
                                    newPresetName = ""
                                    showingSaveAlert = true
                                }
                            }
                            
                            Button("새로 저장...") {
                                newPresetName = ""
                                showingSaveAlert = true
                            }
                            
                            if viewModel.selectedStylePresetName != "기본" {
                                Button("삭제") {
                                    viewModel.deleteStylePreset(name: viewModel.selectedStylePresetName)
                                    fontColor = viewModel.subtitleStyle.fontColor
                                    strokeColor = viewModel.subtitleStyle.strokeColor
                                }
                                .foregroundColor(.red)
                            }
                        }
                        .padding(8)
                    }
                    // Font selection
                    GroupBox("폰트") {
                        VStack(spacing: 12) {
                            HStack {
                                Text("폰트 이름")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button(action: { showingFontPicker = true }) {
                                    HStack {
                                        Text(viewModel.subtitleStyle.fontName)
                                            .font(.custom(viewModel.subtitleStyle.fontName, size: 12))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(width: 180, alignment: .leading)
                                }
                                .buttonStyle(.bordered)
                                .popover(isPresented: $showingFontPicker) {
                                    FontPickerView(selectedFont: $viewModel.subtitleStyle.fontName)
                                }
                            }
                            
                            HStack {
                                Text("크기")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Slider(value: $viewModel.subtitleStyle.fontSize, in: 20...200, step: 1)
                                    .frame(width: 150)
                                Text("\(Int(viewModel.subtitleStyle.fontSize))pt")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .frame(width: 45)
                            }
                            
                            HStack {
                                Text("색상")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                ColorPicker("", selection: $fontColor, supportsOpacity: false)
                                    .labelsHidden()
                                    .onChange(of: fontColor) { _, newValue in
                                        viewModel.subtitleStyle.fontColorHex = newValue.toHex()
                                    }
                            }
                            
                            HStack(spacing: 16) {
                                Toggle("볼드", isOn: $viewModel.subtitleStyle.bold)
                                    .toggleStyle(.checkbox)
                                Toggle("이탤릭", isOn: $viewModel.subtitleStyle.italic)
                                    .toggleStyle(.checkbox)
                                Spacer()
                            }
                        }
                        .padding(8)
                    }
                    
                    // Alignment
                    GroupBox("정렬") {
                        HStack {
                            Text("텍스트 정렬")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Picker("", selection: $viewModel.subtitleStyle.alignment) {
                                ForEach(SubtitleStyle.SubtitleAlignment.allCases, id: \.self) { alignment in
                                    Text(alignment.displayName).tag(alignment)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 220)
                        }
                        .padding(8)
                    }
                    
                    // Stroke
                    GroupBox("외곽선") {
                        VStack(spacing: 12) {
                            HStack {
                                Text("외곽선 색상")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                ColorPicker("", selection: $strokeColor, supportsOpacity: false)
                                    .labelsHidden()
                                    .onChange(of: strokeColor) { _, newValue in
                                        viewModel.subtitleStyle.strokeColorHex = newValue.toHex()
                                    }
                            }
                            
                            HStack {
                                Text("외곽선 두께")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Slider(value: $viewModel.subtitleStyle.strokeWidth, in: 0...10, step: 0.5)
                                    .frame(width: 150)
                                Text(String(format: "%.1f", viewModel.subtitleStyle.strokeWidth))
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .frame(width: 35)
                            }
                        }
                        .padding(8)
                    }
                    
                    // Position
                    GroupBox("위치") {
                        HStack {
                            Text("수직 위치")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Slider(value: $viewModel.subtitleStyle.verticalPosition, in: -540...540, step: 10)
                                .frame(width: 200)
                            Text("\(Int(viewModel.subtitleStyle.verticalPosition))")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .frame(width: 45)
                        }
                        .padding(8)
                    }
                    
                    // Preview
                    GroupBox("미리보기") {
                        let aspectRatio = CGFloat(viewModel.projectSettings.width) / CGFloat(max(viewModel.projectSettings.height, 1))
                        let previewWidth: CGFloat = aspectRatio >= 1 ? 420 : 420 * aspectRatio
                        let previewHeight: CGFloat = previewWidth / aspectRatio
                        
                        VStack(spacing: 8) {
                            ZStack {
                                Rectangle()
                                    .fill(previewDarkBackground ? Color.black : Color.white)
                                    .frame(width: previewWidth, height: min(previewHeight, 350))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: previewDarkBackground ? 0 : 1)
                                    )
                                
                                VStack {
                                    // Resolution label
                                    HStack {
                                        Text("\(viewModel.projectSettings.width)×\(viewModel.projectSettings.height)")
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .foregroundColor(.gray)
                                            .padding(4)
                                        Spacer()
                                    }
                                    
                                    Spacer()
                                    
                                    let effectiveHeight = min(previewHeight, 350)
                                    let offsetRatio = CGFloat(viewModel.subtitleStyle.verticalPosition + 540) / 1080
                                    
                                    Text("자막 미리보기 텍스트")
                                        .font(.custom(viewModel.subtitleStyle.fontName, size: viewModel.subtitleStyle.fontSize * 0.3))
                                        .bold(viewModel.subtitleStyle.bold)
                                        .italic(viewModel.subtitleStyle.italic)
                                        .foregroundColor(viewModel.subtitleStyle.fontColor)
                                        .shadow(color: viewModel.subtitleStyle.strokeColor, radius: viewModel.subtitleStyle.strokeWidth * 0.3)
                                        .offset(y: -effectiveHeight * (1 - offsetRatio) + effectiveHeight / 2)
                                    
                                    Spacer()
                                }
                                .frame(width: previewWidth, height: min(previewHeight, 350))
                                .clipped()
                            }
                            
                            Toggle("어두운 배경", isOn: $previewDarkBackground)
                                .toggleStyle(.switch)
                                .font(.system(size: 11))
                        }
                        .padding(8)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 500, height: 740)
        .onAppear {
            fontColor = viewModel.subtitleStyle.fontColor
            strokeColor = viewModel.subtitleStyle.strokeColor
        }
        .alert("새 프리셋 저장", isPresented: $showingSaveAlert) {
            TextField("프리셋 이름", text: $newPresetName)
            Button("저장") {
                let trimmed = newPresetName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    viewModel.saveCurrentStyleAsPreset(name: trimmed)
                }
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("새로운 자막 스타일 프리셋의 이름을 입력하세요.")
        }
    }
}

struct FontPickerView: View {
    @Binding var selectedFont: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    let allFonts = NSFontManager.shared.availableFontFamilies
    
    var filteredFonts: [String] {
        if searchText.isEmpty {
            return allFonts
        } else {
            return allFonts.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TextField("폰트 검색", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding()
            
            Divider()
            
            List(filteredFonts, id: \.self) { font in
                Button(action: {
                    selectedFont = font
                    dismiss()
                }) {
                    HStack {
                        Text(font)
                            .font(.custom(font, size: 14))
                            .foregroundColor(.primary)
                        Spacer()
                        if font == selectedFont {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 300, height: 400)
    }
}
