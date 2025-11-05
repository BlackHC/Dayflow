//
//  AppTimeTrackedTile.swift
//  Dayflow
//
//  Dashboard tile showing app time breakdown with donut chart
//

import SwiftUI

struct AppTimeTrackedTile: View {
    let data: [AppTimeData]
    let totalTime: TimeInterval
    
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
                    DonutChartView(data: data.prefix(4).map { $0.percentage })
                        .frame(width: 100, height: 100)
                    
                    // Legend
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(data.prefix(4).enumerated()), id: \.offset) { index, app in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(colorForIndex(index))
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
    
    private func colorForIndex(_ index: Int) -> Color {
        let colors: [Color] = [
            Color(hex: "#FF8C42"), // Orange
            Color(hex: "#6AADFF"), // Blue
            Color(hex: "#FFB84D"), // Yellow
            Color(hex: "#D4D4D4")  // Gray
        ]
        return colors[index % colors.count]
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
                        color: colorForIndex(index)
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
    
    private func colorForIndex(_ index: Int) -> Color {
        let colors: [Color] = [
            Color(hex: "#FF8C42"),
            Color(hex: "#6AADFF"),
            Color(hex: "#FFB84D"),
            Color(hex: "#D4D4D4")
        ]
        return colors[index % colors.count]
    }
}

struct DonutSegment: View {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let radius = min(geometry.size.width, geometry.size.height) / 2
                let innerRadius = radius * 0.6
                
                path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                path.addLine(to: CGPoint(
                    x: center.x + innerRadius * cos(endAngle.radians),
                    y: center.y + innerRadius * sin(endAngle.radians)
                ))
                path.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
                path.closeSubpath()
            }
            .fill(color)
        }
    }
}

// MARK: - Previews

#Preview {
    AppTimeTrackedTile(
        data: [
            AppTimeData(appName: "Chrome", duration: 15480, percentage: 43),
            AppTimeData(appName: "VS Code", duration: 6480, percentage: 18),
            AppTimeData(appName: "Slack", duration: 5400, percentage: 15),
            AppTimeData(appName: "Other", duration: 1440, percentage: 4)
        ],
        totalTime: 28800
    )
    .frame(width: 380, height: 240)
    .padding()
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

