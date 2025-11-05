//
//  FocusMeterTile.swift
//  Dayflow
//
//  Dashboard tile showing weekly focus meter with bar chart
//

import SwiftUI

struct FocusMeterTile: View {
    let data: [WeeklyFocusData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            VStack(alignment: .leading, spacing: 2) {
                Text("FOCUS METER")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.black.opacity(0.5))
                    .tracking(0.5)
                
                Text(averageFocusPercentage())
                    .font(.custom("InstrumentSerif-Regular", size: 32))
                    .foregroundColor(.black)
            }
            
            Spacer(minLength: 8)
            
            if data.isEmpty {
                Text("No weekly focus data available")
                    .font(.system(size: 13))
                    .foregroundColor(Color.black.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                // Bar chart
                BarChartView(data: data)
                    .frame(height: 120)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "#F0F8FF"),
                    Color(hex: "#E8F4FF")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
    
    private func averageFocusPercentage() -> String {
        guard !data.isEmpty else { return "0%" }
        
        let avg = data.map { $0.focusPercentage }.reduce(0, +) / Double(data.count)
        return "\(Int(avg * 100))%"
    }
}

struct BarChartView: View {
    let data: [WeeklyFocusData]
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(data.enumerated()), id: \.offset) { index, dayData in
                    VStack(spacing: 4) {
                        Spacer(minLength: 0)
                        
                        // Bar
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(barColor(for: dayData.focusPercentage))
                            .frame(
                                width: (geometry.size.width - CGFloat(data.count - 1) * 8) / CGFloat(data.count),
                                height: max(8, geometry.size.height * 0.7 * CGFloat(dayData.focusPercentage))
                            )
                        
                        // Percentage label
                        Text("\(Int(dayData.focusPercentage * 100))%")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color.black.opacity(0.5))
                        
                        // Day label
                        Text(dayData.dayName)
                            .font(.system(size: 10))
                            .foregroundColor(Color.black.opacity(0.6))
                    }
                }
            }
        }
    }
    
    private func barColor(for percentage: Double) -> Color {
        if percentage < 0.4 {
            return Color(hex: "#FFB0B0")
        } else if percentage < 0.7 {
            return Color(hex: "#FFD88D")
        } else {
            return Color(hex: "#6AADFF")
        }
    }
}

// MARK: - Previews

#Preview {
    FocusMeterTile(
        data: [
            WeeklyFocusData(dayName: "Mon", focusPercentage: 0.5),
            WeeklyFocusData(dayName: "Tue", focusPercentage: 0.8),
            WeeklyFocusData(dayName: "Wed", focusPercentage: 1.0),
            WeeklyFocusData(dayName: "Thu", focusPercentage: 0.4),
            WeeklyFocusData(dayName: "Fri", focusPercentage: 0.38)
        ]
    )
    .frame(width: 380, height: 240)
    .padding()
}

