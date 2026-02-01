import SwiftUI

/// A reusable progress bar component for displaying usage percentages
struct UsageProgressBar: View {
    
    // MARK: - Properties
    
    /// Label displayed above the progress bar
    let label: String
    
    /// Progress value (0.0 to 1.0)
    let value: Double
    
    /// Optional subtitle text below the bar
    var subtitle: String? = nil
    
    // MARK: - Private Properties
    
    /// Color based on progress value
    private var barColor: Color {
        switch value {
        case 0..<0.5:
            return .green
        case 0.5..<0.8:
            return .yellow
        default:
            return .red
        }
    }
    
    /// Formatted percentage string
    private var percentageText: String {
        "\(Int(value * 100))%"
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header row with label and percentage
            HStack {
                Text(label)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text(percentageText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                    
                    // Filled progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor.gradient)
                        .frame(width: max(0, geometry.size.width * min(value, 1.0)))
                }
            }
            .frame(height: 10)
            
            // Optional subtitle
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        UsageProgressBar(
            label: "Session (5-hour)",
            value: 0.25,
            subtitle: "Low usage"
        )
        
        UsageProgressBar(
            label: "Weekly (7-day)",
            value: 0.65,
            subtitle: "Moderate usage"
        )
        
        UsageProgressBar(
            label: "Sonnet Weekly",
            value: 0.85,
            subtitle: "High usage"
        )
    }
    .padding()
    .frame(width: 280)
}
