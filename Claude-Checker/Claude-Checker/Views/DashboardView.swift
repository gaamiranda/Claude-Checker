import SwiftUI

// MARK: - Provider Tab

enum ProviderTab: String, CaseIterable {
    case claude = "Claude"
    case cursor = "Cursor"
}

// MARK: - Dashboard View

/// Main dashboard view displayed in the menu bar popover
struct DashboardView: View {
    
    // MARK: - Properties
    
    /// View model containing Claude usage data and state
    var usageViewModel: UsageViewModel
    
    /// View model containing Cursor usage data and state
    var cursorViewModel: CursorViewModel
    
    /// Currently selected tab
    @State private var selectedTab: ProviderTab = .claude
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Tab Picker
            tabPicker
            
            Divider()
            
            // Content based on selected tab
            switch selectedTab {
            case .claude:
                claudeContent
            case .cursor:
                cursorContent
            }
            
            Divider()
            
            // Footer
            footerSection
        }
        .padding()
        .frame(width: 300)
    }
    
    // MARK: - Tab Picker
    
    private var tabPicker: some View {
        Picker("Provider", selection: $selectedTab) {
            ForEach(ProviderTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
    
    // MARK: - Claude Content
    
    private var claudeContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            claudeHeaderSection
            
            // Content
            if usageViewModel.isFirstLoad && usageViewModel.isLoading {
                claudeLoadingSection
            } else if let error = usageViewModel.errorMessage {
                errorSection(error)
            } else {
                claudeUsageSection
            }
            
            // Last updated and refresh
            claudeStatusSection
        }
    }
    
    private var claudeHeaderSection: some View {
        HStack {
            Text("Claude Usage")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            // Plan tier badge
            Text(usageViewModel.planTier)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(claudePlanBadgeColor.opacity(0.2))
                .foregroundStyle(claudePlanBadgeColor)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
    
    /// Color for the Claude plan badge based on tier
    private var claudePlanBadgeColor: Color {
        switch usageViewModel.planTier.lowercased() {
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
    
    private var claudeLoadingSection: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            
            Text("Loading usage data...")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    private var claudeUsageSection: some View {
        VStack(spacing: 16) {
            // Session (5-hour window)
            UsageProgressBar(
                label: "Session (5-hour)",
                value: usageViewModel.sessionPercentage,
                subtitle: formatResetTime(usageViewModel.sessionResetsAt)
            )
            
            // Weekly (7-day aggregate)
            UsageProgressBar(
                label: "Weekly (7-day)",
                value: usageViewModel.weeklyPercentage,
                subtitle: formatResetTime(usageViewModel.weeklyResetsAt)
            )
            
            // Sonnet weekly
            UsageProgressBar(
                label: "Sonnet Weekly",
                value: usageViewModel.sonnetPercentage
            )
            
            // Extra usage (if available)
            if usageViewModel.hasExtraUsage {
                Divider()
                claudeExtraUsageSection
            }
        }
    }
    
    private var claudeExtraUsageSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Extra Usage")
                    .font(.headline)
                
                Text("Monthly spend")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            Text("$\(usageViewModel.extraSpend, specifier: "%.2f") / $\(usageViewModel.extraLimit, specifier: "%.2f")")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(claudeExtraUsageColor)
        }
    }
    
    /// Color for Claude extra usage based on spend percentage
    private var claudeExtraUsageColor: Color {
        switch usageViewModel.extraPercentage {
        case 0..<0.5:
            return .primary
        case 0.5..<0.8:
            return .yellow
        default:
            return .red
        }
    }
    
    private var claudeStatusSection: some View {
        HStack {
            if let lastUpdated = usageViewModel.lastUpdated {
                Text("Updated \(lastUpdated, format: .relative(presentation: .named))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else if !usageViewModel.isFirstLoad {
                Text("Not yet updated")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            Button {
                Task {
                    await usageViewModel.refresh()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .rotationEffect(.degrees(usageViewModel.isLoading ? 360 : 0))
                    .animation(
                        usageViewModel.isLoading
                            ? .linear(duration: 1).repeatForever(autoreverses: false)
                            : .default,
                        value: usageViewModel.isLoading
                    )
            }
            .buttonStyle(.plain)
            .disabled(usageViewModel.isLoading)
        }
    }
    
    // MARK: - Cursor Content
    
    private var cursorContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            cursorHeaderSection
            
            // Content based on configuration state
            if !cursorViewModel.isConfigured {
                cursorSetupSection
            } else if cursorViewModel.isFirstLoad && cursorViewModel.isLoading {
                cursorLoadingSection
            } else if let error = cursorViewModel.errorMessage {
                errorSection(error)
                cursorReconfigureSection
            } else {
                cursorUsageSection
            }
            
            // Status section (only if configured)
            if cursorViewModel.isConfigured {
                cursorStatusSection
            }
        }
    }
    
    private var cursorHeaderSection: some View {
        HStack {
            Text("Cursor Usage")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            if cursorViewModel.isConfigured {
                Text(cursorViewModel.membershipType)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(cursorPlanBadgeColor.opacity(0.2))
                    .foregroundStyle(cursorPlanBadgeColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Text("Not Configured")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .foregroundStyle(.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }
    
    /// Color for the Cursor plan badge based on membership
    private var cursorPlanBadgeColor: Color {
        switch cursorViewModel.membershipType.lowercased() {
        case "enterprise":
            return .green
        case "pro":
            return .blue
        case "team":
            return .orange
        case "hobby":
            return .purple
        default:
            return .gray
        }
    }
    
    private var cursorSetupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("To track Cursor usage, paste your cookie from browser:")
                .font(.callout)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("1. Open cursor.com in your browser")
                Text("2. Open DevTools (Cmd+Option+I)")
                Text("3. Go to Network tab, refresh page")
                Text("4. Click any request, copy 'Cookie' header")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            
            @Bindable var bindableCursor = cursorViewModel
            TextField("Paste cookie here...", text: $bindableCursor.cookieInput)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
            
            Button("Save Cookie") {
                cursorViewModel.saveCookie()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(cursorViewModel.cookieInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.vertical, 8)
    }
    
    private var cursorReconfigureSection: some View {
        VStack(spacing: 8) {
            Text("Cookie may have expired. Please paste a new one:")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            @Bindable var bindableCursor = cursorViewModel
            TextField("Paste cookie here...", text: $bindableCursor.cookieInput)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
            
            HStack {
                Button("Save Cookie") {
                    cursorViewModel.saveCookie()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(cursorViewModel.cookieInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Button("Clear Cookie") {
                    cursorViewModel.clearCookie()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
    
    private var cursorLoadingSection: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            
            Text("Loading Cursor data...")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    private var cursorUsageSection: some View {
        VStack(spacing: 16) {
            // Plan usage (included credits)
            UsageProgressBar(
                label: "Plan Usage",
                value: cursorViewModel.planPercentage,
                subtitle: cursorViewModel.planUsageText
            )
            
            // On-demand usage (if enabled/used)
            if cursorViewModel.hasOnDemandUsage {
                if cursorViewModel.hasOnDemandLimit {
                    UsageProgressBar(
                        label: "On-Demand",
                        value: cursorViewModel.onDemandPercentage,
                        subtitle: cursorViewModel.onDemandUsageText
                    )
                } else {
                    cursorOnDemandUnlimitedRow
                }
            }
            
            // Billing cycle reset
            if let resetDate = cursorViewModel.billingResetsAt {
                Divider()
                HStack {
                    Text("Billing Resets")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(resetDate, format: .relative(presentation: .named))
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
    
    private var cursorOnDemandUnlimitedRow: some View {
        HStack {
            Text("On-Demand")
                .font(.headline)
            
            Spacer()
            
            Text(cursorViewModel.onDemandUsageText)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("(no limit)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
    
    private var cursorStatusSection: some View {
        HStack {
            if let lastUpdated = cursorViewModel.lastUpdated {
                Text("Updated \(lastUpdated, format: .relative(presentation: .named))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else if !cursorViewModel.isFirstLoad {
                Text("Not yet updated")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            Button {
                cursorViewModel.clearCookie()
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Clear cookie")
            
            Button {
                Task {
                    await cursorViewModel.refresh()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .rotationEffect(.degrees(cursorViewModel.isLoading ? 360 : 0))
                    .animation(
                        cursorViewModel.isLoading
                            ? .linear(duration: 1).repeatForever(autoreverses: false)
                            : .default,
                        value: cursorViewModel.isLoading
                    )
            }
            .buttonStyle(.plain)
            .disabled(cursorViewModel.isLoading)
        }
    }
    
    // MARK: - Shared Components
    
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
    
    /// Formats reset time as relative text
    private func formatResetTime(_ date: Date?) -> String? {
        guard let date = date else { return nil }
        
        let now = Date()
        if date <= now {
            return nil
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Resets \(formatter.localizedString(for: date, relativeTo: now))"
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        VStack(spacing: 12) {
            // Launch at Login toggle
            @Bindable var bindableViewModel = usageViewModel
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
    let usageViewModel = UsageViewModel()
    usageViewModel.sessionPercentage = 0.45
    usageViewModel.weeklyPercentage = 0.72
    usageViewModel.sonnetPercentage = 0.25
    usageViewModel.extraSpend = 12.50
    usageViewModel.extraLimit = 100.00
    usageViewModel.planTier = "Max"
    usageViewModel.lastUpdated = Date()
    
    let cursorViewModel = CursorViewModel()
    cursorViewModel.planPercentage = 0.35
    cursorViewModel.planUsedUSD = 7.00
    cursorViewModel.planLimitUSD = 20.00
    cursorViewModel.onDemandUsedUSD = 2.50
    cursorViewModel.onDemandLimitUSD = 50.00
    cursorViewModel.membershipType = "Pro"
    cursorViewModel.lastUpdated = Date()
    
    return DashboardView(
        usageViewModel: usageViewModel,
        cursorViewModel: cursorViewModel
    )
}
