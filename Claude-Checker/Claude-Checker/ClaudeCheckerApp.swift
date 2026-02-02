import SwiftUI

@main
struct ClaudeCheckerApp: App {
    
    // MARK: - State
    
    /// Main view model for Claude usage data
    @State private var usageViewModel: UsageViewModel
    
    /// View model for Cursor usage data
    @State private var cursorViewModel: CursorViewModel
    
    // MARK: - Initialization
    
    init() {
        // Create and store the view models
        let vm = UsageViewModel()
        let cursorVm = CursorViewModel()
        _usageViewModel = State(initialValue: vm)
        _cursorViewModel = State(initialValue: cursorVm)
        
        // Initialize launch at login on first launch (enabled by default)
        LaunchAtLoginService.initializeOnFirstLaunch()
        
        // Start auto-refresh for both providers
        vm.startAutoRefresh()
        cursorVm.startAutoRefresh()
    }
    
    // MARK: - Body
    
    var body: some Scene {
        MenuBarExtra {
            DashboardView(
                usageViewModel: usageViewModel,
                cursorViewModel: cursorViewModel
            )
        } label: {
            // Static "C" in square icon
            Image(systemName: "c.square.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
