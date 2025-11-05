//
//  ProductivityTrackerTile.swift
//  Dayflow
//
//  Dashboard tile showing productivity breakdown with bubble chart
//

import SwiftUI

struct ProductivityTrackerTile: View {
    let data: [ProductivityBreakdown]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            VStack(alignment: .leading, spacing: 2) {
                Text("PRODUCTIVITY TRACKER")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.black.opacity(0.5))
                    .tracking(0.5)
                
                if let topCategory = data.first {
                    Text("\(Int(topCategory.percentage))% productive today")
                        .font(.custom("InstrumentSerif-Regular", size: 26))
                        .foregroundColor(.black)
                } else {
                    Text("No data")
                        .font(.custom("InstrumentSerif-Regular", size: 26))
                        .foregroundColor(.black.opacity(0.4))
                }
            }
            
            Spacer(minLength: 8)
            
            if data.isEmpty {
                Text("No productivity data available")
                    .font(.system(size: 13))
                    .foregroundColor(Color.black.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                // Bubble chart and legend
                HStack(spacing: 20) {
                    // Bubble visualization
                    BubbleChartView(data: data.prefix(3).map { (percentage: $0.percentage, color: $0.categoryColor) })
                        .frame(width: 120, height: 120)
                    
                    // Legend
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(data.prefix(3).enumerated()), id: \.offset) { _, category in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(hex: category.categoryColor))
                                    .frame(width: 8, height: 8)
                                
                                Text(category.categoryName)
                                    .font(.system(size: 13))
                                    .foregroundColor(.black)
                                    .lineLimit(1)
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
}

struct BubbleChartView: View {
    let data: [(percentage: Double, color: String)]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Draw overlapping circles sized by percentage
                ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                    Circle()
                        .fill(Color(hex: item.color).opacity(0.7))
                        .frame(
                            width: bubbleSize(for: item.percentage, in: geometry.size),
                            height: bubbleSize(for: item.percentage, in: geometry.size)
                        )
                        .offset(bubbleOffset(for: index, in: geometry.size))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    private func bubbleSize(for percentage: Double, in size: CGSize) -> CGFloat {
        let minSize = min(size.width, size.height)
        return minSize * CGFloat(percentage / 100.0) * 0.8
    }
    
    private func bubbleOffset(for index: Int, in size: CGSize) -> CGSize {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let offsets: [CGSize] = [
            CGSize(width: -size.width * 0.15, height: -size.height * 0.1),
            CGSize(width: size.width * 0.1, height: size.height * 0.05),
            CGSize(width: -size.width * 0.05, height: size.height * 0.15)
        ]
        return index < offsets.count ? offsets[index] : .zero
    }
}

// MARK: - Previews

#Preview {
    ProductivityTrackerTile(
        data: [
            ProductivityBreakdown(categoryName: "Productive", categoryColor: "#FF8C42", duration: 18000, percentage: 50),
            ProductivityBreakdown(categoryName: "Personal", categoryColor: "#6AADFF", duration: 10800, percentage: 30),
            ProductivityBreakdown(categoryName: "Other", categoryColor: "#FFB0B0", duration: 7200, percentage: 20)
        ]
    )
    .frame(width: 380, height: 240)
    .padding()
}

