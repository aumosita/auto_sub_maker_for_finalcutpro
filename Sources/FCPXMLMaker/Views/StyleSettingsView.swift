import SwiftUI

struct StyleSettingsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var fontColor: Color
    @State private var strokeColor: Color
    @State private var showingSaveAlert = false
    @State private var newPresetName = ""
    
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
                                TextField("폰트", text: $viewModel.subtitleStyle.fontName)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 200)
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
                        ZStack {
                            Rectangle()
                                .fill(Color.black)
                                .frame(height: 200)
                                .cornerRadius(8)
                            
                            VStack {
                                Spacer()
                                
                                let offsetRatio = CGFloat(viewModel.subtitleStyle.verticalPosition + 540) / 1080
                                
                                Text("자막 미리보기 텍스트")
                                    .font(.custom(viewModel.subtitleStyle.fontName, size: viewModel.subtitleStyle.fontSize * 0.3))
                                    .bold(viewModel.subtitleStyle.bold)
                                    .italic(viewModel.subtitleStyle.italic)
                                    .foregroundColor(viewModel.subtitleStyle.fontColor)
                                    .shadow(color: viewModel.subtitleStyle.strokeColor, radius: viewModel.subtitleStyle.strokeWidth * 0.3)
                                    .offset(y: -200 * (1 - offsetRatio) + 100)
                                
                                Spacer()
                            }
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
