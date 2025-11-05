//
//  ProductiveTimeTile.swift
//  Dayflow
//
//  Dashboard tile showing productive time heatmap
//

import SwiftUI

struct ProductiveTimeTile: View {
    let data: [ProductiveBlock]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            VStack(alignment: .leading, spacing: 2) {
                Text("PRODUCTIVE TIME")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.black.opacity(0.5))
                    .tracking(0.5)
                
                Text(productivePercentage())
                    .font(.custom("InstrumentSerif-Regular", size: 32))
                    .foregroundColor(.black)
                
                Text(blocksSummary())
                    .font(.system(size: 12))
                    .foregroundColor(Color.black.opacity(0.6))
            }
            
            Spacer(minLength: 8)
            
            if data.isEmpty {
                Text("No activity blocks recorded")
                    .font(.system(size: 13))
                    .foregroundColor(Color.black.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                // Heatmap grid
                HeatmapGridView(data: data)
                    .frame(height: 100)
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
    
    private func productivePercentage() -> String {
        guard !data.isEmpty else { return "0%" }
        
        let avgIntensity = data.map { $0.intensity }.reduce(0, +) / Double(data.count)
        return "\(Int(avgIntensity * 100))%"
    }
    
    private func blocksSummary() -> String {
        let totalBlocks = data.count
        if totalBlocks == 0 {
            return "No blocks tracked"
        }
        
        let highIntensityBlocks = data.filter { $0.intensity > 0.7 }.count
        return "\(highIntensityBlocks) of \(totalBlocks) blocks"
    }
}

struct HeatmapGridView: View {
    let data: [ProductiveBlock]
    
    private let hours = Array(4...23) + Array(0...3) // 4 AM to 4 AM
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<7, id: \.self) { day in
                HStack(spacing: 2) {
                    ForEach(hours.indices, id: \.self) { hourIndex in
                        let hour = hours[hourIndex]
                        let block = data.first { $0.hour == hour && $0.dayOfWeek == day }
                        
                        Rectangle()
                            .fill(intensityColor(block?.intensity ?? 0))
                            .frame(width: 8, height: 8)
                            .clipShape(RoundedRectangle(cornerRadius: 1.5, style: .continuous))
                    }
                }
            }
        }
    }
    
    private func intensityColor(_ intensity: Double) -> Color {
        if intensity == 0 {
            return Color.black.opacity(0.05)
        } else if intensity < 0.3 {
            return Color(hex: "#FFE8D6")
        } else if intensity < 0.6 {
            return Color(hex: "#FFB84D")
        } else {
            return Color(hex: "#FF8C42")
        }
    }
}

// MARK: - Previews

#Preview {
    ProductiveTimeTile(
        data: [
            ProductiveBlock(hour: 9, dayOfWeek: 1, intensity: 0.8),
            ProductiveBlock(hour: 10, dayOfWeek: 1, intensity: 0.9),
            ProductiveBlock(hour: 14, dayOfWeek: 1, intensity: 0.6),
            ProductiveBlock(hour: 9, dayOfWeek: 2, intensity: 0.7),
            ProductiveBlock(hour: 15, dayOfWeek: 2, intensity: 0.5),
            ProductiveBlock(hour: 10, dayOfWeek: 3, intensity: 0.4),
            ProductiveBlock(hour: 11, dayOfWeek: 3, intensity: 0.8)
        ]
    )
    .frame(width: 380, height: 240)
    .padding()
}

