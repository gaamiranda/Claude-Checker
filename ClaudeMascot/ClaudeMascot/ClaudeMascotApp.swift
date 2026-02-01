import SwiftUI

@main
struct ClaudeMascotApp: App {
    
    // MARK: - State
    
    /// Main view model for usage data
    @State private var viewModel: UsageViewModel
    
    // MARK: - Initialization
    
    init() {
        // Create and store the view model
        let vm = UsageViewModel()
        _viewModel = State(initialValue: vm)
        
        // Start auto-refresh immediately on app launch
        vm.startAutoRefresh()
    }
    
    // MARK: - Body
    
    var body: some Scene {
        MenuBarExtra {
            DashboardView(viewModel: viewModel)
        } label: {
            // Dynamic colored circle based on usage
            Image(systemName: "circle.fill")
                .foregroundStyle(viewModel.statusColor)
        }
        .menuBarExtraStyle(.window)
    }
}
