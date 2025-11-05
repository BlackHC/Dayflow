//
//  FocusScoreTile.swift
//  Dayflow
//
//  Dashboard tile showing focus score with line chart and trend
//

import SwiftUI

struct FocusScoreTile: View {
    let data: [FocusScoreData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            VStack(alignment: .leading, spacing: 2) {
                Text("FOCUS SCORE TODAY")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.black.opacity(0.5))
                    .tracking(0.5)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(trendLabel())
                        .font(.custom("InstrumentSerif-Regular", size: 32))
                        .foregroundColor(.black)
                    
                    Text(trendEmoji())
                        .font(.system(size: 20))
                }
                
                Text(trendDescription())
                    .font(.system(size: 12))
                    .foregroundColor(Color.black.opacity(0.6))
            }
            
            Spacer(minLength: 8)
            
            if data.isEmpty {
                Text("No focus data available")
                    .font(.system(size: 13))
                    .foregroundColor(Color.black.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                // Line chart
                LineChartView(data: data.map { $0.score })
                    .frame(height: 80)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "#FFE8D6"),
                    Color(hex: "#FFDCC0")
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
    
    private func trendLabel() -> String {
        guard !data.isEmpty else { return "—" }
        
        let avgScore = data.map { $0.score }.reduce(0, +) / Double(data.count)
        
        if avgScore > 0.7 {
            return "Rising"
        } else if avgScore > 0.4 {
            return "Steady"
        } else {
            return "Low"
        }
    }
    
    private func trendEmoji() -> String {
        guard !data.isEmpty else { return "" }
        
        let avgScore = data.map { $0.score }.reduce(0, +) / Double(data.count)
        
        if avgScore > 0.7 {
            return "🔥"
        } else if avgScore > 0.4 {
            return "📈"
        } else {
            return "📉"
        }
    }
    
    private func trendDescription() -> String {
        guard data.count >= 2 else { return "Collecting data..." }
        
        let firstHalf = data.prefix(data.count / 2)
        let secondHalf = data.suffix(data.count / 2)
        
        let firstAvg = firstHalf.map { $0.score }.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.map { $0.score }.reduce(0, +) / Double(secondHalf.count)
        
        if secondAvg > firstAvg + 0.1 {
            return "Started low, but reached sky high"
        } else if secondAvg < firstAvg - 0.1 {
            return "Strong start, but momentum faded"
        } else {
            return "Consistent throughout the day"
        }
    }
}

struct LineChartView: View {
    let data: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard data.count >= 2 else { return }
                
                let stepX = geometry.size.width / CGFloat(data.count - 1)
                let maxValue = data.max() ?? 1.0
                let minValue = data.min() ?? 0.0
                let range = maxValue - minValue
                let scale = range > 0 ? geometry.size.height / CGFloat(range) : geometry.size.height
                
                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = geometry.size.height - CGFloat(value - minValue) * scale
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color(hex: "#FF8C42"), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            
            // Fill area under the line
            Path { path in
                guard data.count >= 2 else { return }
                
                let stepX = geometry.size.width / CGFloat(data.count - 1)
                let maxValue = data.max() ?? 1.0
                let minValue = data.min() ?? 0.0
                let range = maxValue - minValue
                let scale = range > 0 ? geometry.size.height / CGFloat(range) : geometry.size.height
                
                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = geometry.size.height - CGFloat(value - minValue) * scale
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: geometry.size.height))
                        path.addLine(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                
                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: "#FF8C42").opacity(0.3),
                        Color(hex: "#FF8C42").opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

// MARK: - Previews

#Preview {
    FocusScoreTile(
        data: [
            FocusScoreData(timestamp: Date(), score: 0.3),
            FocusScoreData(timestamp: Date().addingTimeInterval(3600), score: 0.5),
            FocusScoreData(timestamp: Date().addingTimeInterval(7200), score: 0.8),
            FocusScoreData(timestamp: Date().addingTimeInterval(10800), score: 0.9),
            FocusScoreData(timestamp: Date().addingTimeInterval(14400), score: 0.7)
        ]
    )
    .frame(width: 380, height: 240)
    .padding()
}

