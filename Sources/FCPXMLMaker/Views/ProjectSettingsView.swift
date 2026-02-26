import SwiftUI

struct ProjectSettingsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPreset: ProjectSettings.ResolutionPreset = .hd1080p
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("해상도 / 프레임레이트 설정")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button("완료") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
            
            Divider()
            
            VStack(spacing: 20) {
                // Resolution preset
                GroupBox("해상도") {
                    VStack(spacing: 12) {
                        Picker("프리셋", selection: $selectedPreset) {
                            ForEach(ProjectSettings.ResolutionPreset.allCases, id: \.self) { preset in
                                Text(preset.rawValue).tag(preset)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .onChange(of: selectedPreset) { _, newValue in
                            if let size = newValue.size {
                                viewModel.projectSettings.width = size.width
                                viewModel.projectSettings.height = size.height
                            }
                        }
                        
                        if selectedPreset == .custom {
                            HStack(spacing: 12) {
                                HStack {
                                    Text("너비")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                    TextField("", value: $viewModel.projectSettings.width, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                }
                                
                                Text("×")
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Text("높이")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                    TextField("", value: $viewModel.projectSettings.height, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                }
                            }
                        }
                        
                        // Display current resolution
                        HStack {
                            Spacer()
                            Text("현재: \(viewModel.projectSettings.width) × \(viewModel.projectSettings.height)")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(8)
                }
                
                // Frame rate
                GroupBox("프레임레이트") {
                    VStack(spacing: 12) {
                        Picker("프레임레이트", selection: $viewModel.projectSettings.frameRate) {
                            ForEach(ProjectSettings.FrameRate.allCases, id: \.self) { rate in
                                Text(rate.displayName).tag(rate)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        
                        HStack {
                            Spacer()
                            Text("Frame Duration: \(viewModel.projectSettings.frameRate.frameDuration)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                }
                
                Spacer()
            }
            .padding(20)
        }
        .frame(width: 450, height: 520)
        .onAppear {
            // Determine current preset
            let w = viewModel.projectSettings.width
            let h = viewModel.projectSettings.height
            selectedPreset = ProjectSettings.ResolutionPreset.allCases.first { preset in
                preset.size?.width == w && preset.size?.height == h
            } ?? .custom
        }
    }
}
