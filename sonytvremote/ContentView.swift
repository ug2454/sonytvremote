import SwiftUI
import OSLog

struct ContentView: View {
    @StateObject private var vm = RemoteViewModel()
    @State private var selectedTab = 0
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.app", category: "ContentView")

    var body: some View {
        TabView(selection: $selectedTab) {
            // Remote Control
            NavigationStack {
                RemoteView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink(destination: SettingsView().environmentObject(vm)) {
                                Image(systemName: "gear")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
            }
            .tabItem {
                Label("Remote", systemImage: "tv.remote.fill")
            }
            .tag(0)

            // Apps
            NavigationStack {
                AppsView()
            }
            .tabItem {
                Label("Apps", systemImage: "square.grid.2x2.fill")
            }
            .tag(1)

            // Inputs
            NavigationStack {
                InputsView()
            }
            .tabItem {
                Label("Inputs", systemImage: "cable.connector.horizontal")
            }
            .tag(2)

            // Settings
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(3)
        }
        .accentColor(.cyan)
        .preferredColorScheme(.dark)
        .environmentObject(vm)
        .task {
            logger.info("ContentView appeared - initializing app")
            await vm.loadSettings()
            vm.startPolling()
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            logger.debug("Tab changed from \(oldValue) to \(newValue)")
        }
    }
}

#Preview {
    ContentView()
}
