import SwiftUI

@main
struct FCPXMLMakerApp: App {
    @StateObject private var viewModel = AppViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 900, minHeight: 700)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1000, height: 800)
    }
}
