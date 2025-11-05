//
//  TimeSpentOnTile.swift
//  Dayflow
//
//  Dashboard tile showing custom query time breakdown
//

import SwiftUI

struct TimeSpentOnTile: View {
    let query: String
    let totalTime: TimeInterval
    let breakdownData: [AppTimeData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            VStack(alignment: .leading, spacing: 2) {
                Text("TIME SPENT ON \(query.uppercased())")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.black.opacity(0.5))
                    .tracking(0.5)
                    .lineLimit(1)
                
                Text(formatTotalTime())
                    .font(.custom("InstrumentSerif-Regular", size: 32))
                    .foregroundColor(.black)
            }
            
            if breakdownData.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Text("No activity matching '\(query)'")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.6))
                    
                    Text("Try a different query")
                        .font(.system(size: 11))
                        .foregroundColor(Color.black.opacity(0.4))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                HStack(spacing: 20) {
                    // Small donut chart
                    DonutChartView(data: breakdownData.prefix(3).map { $0.percentage })
                        .frame(width: 80, height: 80)
                    
                    // Breakdown list
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(breakdownData.prefix(3).enumerated()), id: \.offset) { index, item in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(colorForIndex(index))
                                    .frame(width: 8, height: 8)
                                
                                Text(item.appName)
                                    .font(.system(size: 12))
                                    .foregroundColor(.black)
                                    .lineLimit(1)
                                
                                Spacer(minLength: 0)
                                
                                Text(formatDuration(item.duration))
                                    .font(.system(size: 11, weight: .medium))
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
        let minutes = (Int(totalTime) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes)m"
    }
    
    private func colorForIndex(_ index: Int) -> Color {
        let colors: [Color] = [
            Color(hex: "#6AADFF"),
            Color(hex: "#FFD88D"),
            Color(hex: "#FFB0B0")
        ]
        return colors[index % colors.count]
    }
}

// MARK: - Previews

#Preview {
    VStack(spacing: 20) {
        TimeSpentOnTile(
            query: "Twitter",
            totalTime: 4500,
            breakdownData: [
                AppTimeData(appName: "Quick Updates", duration: 2400, percentage: 40),
                AppTimeData(appName: "Networking & DM", duration: 2100, percentage: 35),
                AppTimeData(appName: "Deep Dive Reading", duration: 600, percentage: 10)
            ]
        )
        .frame(width: 380, height: 240)
        
        TimeSpentOnTile(
            query: "Design",
            totalTime: 0,
            breakdownData: []
        )
        .frame(width: 380, height: 240)
    }
    .padding()
}

