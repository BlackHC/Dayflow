//
//  AppTimeTrackedTile.swift
//  Dayflow
//
//  Dashboard tile showing app time breakdown with donut chart
//

import SwiftUI

// MARK: - Shared Color Palette

/// Shared color palette for app time visualization
/// Cycles through colors if more than 8 categories are displayed
private let appTimeColors: [Color] = [
    Color(hex: "#FF8C42"), // Orange
    Color(hex: "#6AADFF"), // Blue
    Color(hex: "#FFB84D"), // Yellow
    Color(hex: "#60D394"), // Green
    Color(hex: "#B984FF"), // Purple
    Color(hex: "#FF6B9D"), // Pink
    Color(hex: "#4ECDC4"), // Teal
    Color(hex: "#FFE66D")  // Light Yellow
]

/// Returns color for given index with cyclic wrap-around
private func colorForAppTimeIndex(_ index: Int) -> Color {
    appTimeColors[index % appTimeColors.count]
}

// MARK: - App Time Tracked Tile

struct AppTimeTrackedTile: View {
    let data: [AppTimeData]
    let totalTime: TimeInterval
    
    /// Processes data to show top categories until 75% coverage, then groups rest as "Other"
    private var processedData: [AppTimeData] {
        guard !data.isEmpty else { return [] }
        
        var result: [AppTimeData] = []
        var cumulativePercentage: Double = 0.0
        var remainingItems: [AppTimeData] = []
        
        for item in data {
            if cumulativePercentage < 75.0 {
                result.append(item)
                cumulativePercentage += item.percentage
            } else {
                remainingItems.append(item)
            }
        }
        
        // If there are remaining items, create an "Other" category
        if remainingItems.count == 1 {
            // Just add the single remaining item directly
            result.append(remainingItems[0])
        } else if remainingItems.count > 1 {
            // Combine multiple remaining items into an "Other" category
            let otherDuration = remainingItems.reduce(0) { $0 + $1.duration }
            let otherPercentage = remainingItems.reduce(0) { $0 + $1.percentage }
            
            let otherCategory = AppTimeData(
                appName: "Other",
                duration: otherDuration,
                percentage: otherPercentage
            )
            result.append(otherCategory)
        }
        
        // Limit to 4 items for display
        return Array(result.prefix(4))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            VStack(alignment: .leading, spacing: 2) {
                Text("APP TIME TRACKED")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.black.opacity(0.5))
                    .tracking(0.5)
                
                Text(formatTotalTime())
                    .font(.custom("InstrumentSerif-Regular", size: 32))
                    .foregroundColor(.black)
            }
            
            if data.isEmpty {
                Spacer()
                Text("No app data available")
                    .font(.system(size: 13))
                    .foregroundColor(Color.black.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                HStack(spacing: 20) {
                    // Donut chart
                    DonutChartView(data: processedData.map { $0.percentage })
                        .frame(width: 100, height: 100)
                    
                    // Legend
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(processedData.enumerated()), id: \.offset) { index, app in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(colorForAppTimeIndex(index))
                                    .frame(width: 8, height: 8)
                                
                                Text(app.appName)
                                    .font(.system(size: 13))
                                    .foregroundColor(.black)
                                    .lineLimit(1)
                                
                                Spacer(minLength: 0)
                                
                                Text(formatDuration(app.duration))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.black.opacity(0.6))
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
    
    private func formatTotalTime() -> String {
        let hours = Int(totalTime) / 3600
        return "\(hours)h tracked"
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "(\(hours).\(minutes/6)h)"
        } else {
            return "(\(minutes)m)"
        }
    }
}

struct DonutChartView: View {
    let data: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                 ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                     DonutSegment(
                         startAngle: startAngle(for: index),
                         endAngle: endAngle(for: index),
                         color: colorForAppTimeIndex(index)
                     )
                 }
            }
        }
    }
    
    private func startAngle(for index: Int) -> Angle {
        let sum = data.prefix(index).reduce(0, +)
        return Angle(degrees: sum * 3.6 - 90)
    }
    
    private func endAngle(for index: Int) -> Angle {
        let sum = data.prefix(index + 1).reduce(0, +)
        return Angle(degrees: sum * 3.6 - 90)
    }
}

struct DonutSegment: View {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let innerRadius = radius * 0.6

            // Convert once to radians
            let start = CGFloat(startAngle.radians)
            let end = CGFloat(endAngle.radians)

            // Guard against degenerate arcs
            let epsilon: CGFloat = 0.0001
            let span = abs(end - start)
            let hasSpan = span > epsilon

            Path { path in
                guard hasSpan else { return }

                // Outer arc start/end points
                let outerStart = CGPoint(x: center.x + radius * cos(start),
                                         y: center.y + radius * sin(start))
                let outerEnd   = CGPoint(x: center.x + radius * cos(end),
                                         y: center.y + radius * sin(end))

                // Inner arc start/end points (reverse direction)
                let innerStart = CGPoint(x: center.x + innerRadius * cos(end),
                                         y: center.y + innerRadius * sin(end))
                let innerEnd   = CGPoint(x: center.x + innerRadius * cos(start),
                                         y: center.y + innerRadius * sin(start))

                // Start at outer start
                path.move(to: outerStart)

                // Draw outer arc (counterclockwise if end > start). SwiftUI’s addArc uses Angle,
                // but Path here uses Core Graphics-style addArc with CG types via addArc(center:radius:startAngle:endAngle:clockwise:)
                // The SwiftUI Path API provides addArc with Angle too, but to avoid any conversions,
                // we construct arcs using addArc with CGFloat radians by bridging via CGPathAddArc-style.
                path.addArc(center: center,
                            radius: radius,
                            startAngle: Angle(radians: Double(start)),
                            endAngle: Angle(radians: Double(end)),
                            clockwise: false)

                // Line to inner start
                path.addLine(to: innerStart)

                // Draw inner arc back to inner end (reverse direction)
                path.addArc(center: center,
                            radius: innerRadius,
                            startAngle: Angle(radians: Double(end)),
                            endAngle: Angle(radians: Double(start)),
                            clockwise: true)

                // Close back to outer start
                path.addLine(to: outerStart)
                path.closeSubpath()
            }
            .fill(color)
        }
    }
}
// MARK: - Previews

#Preview("With Other Category") {
    // This demonstrates the 75% threshold: First 3 apps = 75%, rest grouped as "Other"
    AppTimeTrackedTile(
        data: [
            AppTimeData(appName: "Chrome", duration: 10800, percentage: 30),    // 30%
            AppTimeData(appName: "VS Code", duration: 9000, percentage: 25),     // 25%
            AppTimeData(appName: "Slack", duration: 7200, percentage: 20),       // 20%
            AppTimeData(appName: "Spotify", duration: 3600, percentage: 10),     // 10% (will be in Other)
            AppTimeData(appName: "Mail", duration: 2700, percentage: 7.5),       // 7.5% (will be in Other)
            AppTimeData(appName: "Safari", duration: 2700, percentage: 7.5)      // 7.5% (will be in Other)
        ],
        totalTime: 36000
    )
    .frame(width: 380, height: 240)
    .padding()
}

#Preview("No Other") {
    // All items shown since total is under 75% with just 2 items
    AppTimeTrackedTile(
        data: [
            AppTimeData(appName: "Chrome", duration: 18000, percentage: 50),
            AppTimeData(appName: "VS Code", duration: 7200, percentage: 50),
        ],
        totalTime: 36000
    )
    .frame(width: 380, height: 240)
    .padding()
}

#Preview("Single Remainder") {
    // All items shown since total is under 75% with just 2 items
    AppTimeTrackedTile(
        data: [
            AppTimeData(appName: "Chrome", duration: 18000, percentage: 50),
            AppTimeData(appName: "VS Code", duration: 7200, percentage: 30),
            AppTimeData(appName: "Spotify", duration: 3600, percentage: 20),
        ],
        totalTime: 36000
    )
    .frame(width: 380, height: 240)
    .padding()
}



