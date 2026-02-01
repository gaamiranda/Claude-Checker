import SwiftUI

/// Main dashboard view displayed in the menu bar popover
struct DashboardView: View {
    
    // MARK: - Properties
    
    /// View model containing usage data and state
    var viewModel: UsageViewModel
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            headerSection
            
            Divider()
            
            // Content
            if let error = viewModel.errorMessage {
                errorSection(error)
            } else {
                usageSection
            }
            
            Divider()
            
            // Footer
            footerSection
        }
        .padding()
        .frame(width: 300)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            Text("Claude Usage")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            // Plan tier badge
            Text(viewModel.planTier)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(planBadgeColor.opacity(0.2))
                .foregroundStyle(planBadgeColor)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
    
    /// Color for the plan badge based on tier
    private var planBadgeColor: Color {
        switch viewModel.planTier.lowercased() {
        case "max":
            return .purple
        case "pro":
            return .blue
        case "team":
            return .orange
        case "enterprise":
            return .green
        default:
            return .gray
        }
    }
    
    // MARK: - Error Section
    
    private func errorSection(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            
            Text(error)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Usage Section
    
    private var usageSection: some View {
        VStack(spacing: 16) {
            // Session (5-hour window)
            UsageProgressBar(
                label: "Session (5-hour)",
                value: viewModel.sessionPercentage
            )
            
            // Weekly (7-day aggregate)
            UsageProgressBar(
                label: "Weekly (7-day)",
                value: viewModel.weeklyPercentage
            )
            
            // Sonnet weekly
            UsageProgressBar(
                label: "Sonnet Weekly",
                value: viewModel.sonnetPercentage
            )
            
            // Extra usage (if available)
            if viewModel.hasExtraUsage {
                Divider()
                extraUsageSection
            }
        }
    }
    
    // MARK: - Extra Usage Section
    
    private var extraUsageSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Extra Usage")
                    .font(.headline)
                
                Text("Monthly spend")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            Text("$\(viewModel.extraSpend, specifier: "%.2f") / $\(viewModel.extraLimit, specifier: "%.2f")")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(extraUsageColor)
        }
    }
    
    /// Color for extra usage based on spend percentage
    private var extraUsageColor: Color {
        switch viewModel.extraPercentage {
        case 0..<0.5:
            return .primary
        case 0.5..<0.8:
            return .yellow
        default:
            return .red
        }
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        VStack(spacing: 12) {
            // Last updated and refresh button
            HStack {
                if let lastUpdated = viewModel.lastUpdated {
                    Text("Updated \(lastUpdated, format: .relative(presentation: .named))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("Not yet updated")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                Button {
                    Task {
                        await viewModel.refresh()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)
                .opacity(viewModel.isLoading ? 0.5 : 1.0)
            }
            
            // Launch at Login toggle
            @Bindable var bindableViewModel = viewModel
            Toggle("Launch at Login", isOn: $bindableViewModel.launchAtLogin)
                .toggleStyle(.checkbox)
                .font(.caption)
            
            // Quit button
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Preview

#Preview {
    let viewModel = UsageViewModel()
    viewModel.sessionPercentage = 0.45
    viewModel.weeklyPercentage = 0.72
    viewModel.sonnetPercentage = 0.25
    viewModel.extraSpend = 12.50
    viewModel.extraLimit = 100.00
    viewModel.planTier = "Max"
    viewModel.lastUpdated = Date()
    
    return DashboardView(viewModel: viewModel)
}
