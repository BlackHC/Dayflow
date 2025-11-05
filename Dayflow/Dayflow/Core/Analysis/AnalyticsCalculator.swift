//
//  AnalyticsCalculator.swift
//  Dayflow
//
//  Computes analytics from timeline cards for dashboard tiles
//

import Foundation

final class AnalyticsCalculator {
    
    private let storage: StorageManaging
    
    init(storage: StorageManaging = StorageManager.shared) {
        self.storage = storage
    }
    
    // MARK: - Main Analytics Method
    
    func calculateDayAnalytics(for date: Date) -> AnalyticsSummary {
        let startTime = Date()
        print("[AnalyticsCalculator] 📊 Computing analytics for \(date)")
        
        // Get day boundaries (4 AM to 4 AM)
        let dayInfo = date.getDayInfoFor4AMBoundary()
        let cards = storage.fetchTimelineCardsByTimeRange(from: dayInfo.startOfDay, to: dayInfo.endOfDay)
        
        print("[AnalyticsCalculator]    Found \(cards.count) cards")
        
        let totalTime = calculateTotalTime(cards: cards)
        let appTime = calculateAppTime(cards: cards)
        let focusScore = calculateFocusScore(cards: cards, date: date)
        let productivity = calculateProductivityBreakdown(cards: cards)
        let productive = calculateProductiveBlocks(cards: cards, date: date)
        let weeklyFocus = calculateWeeklyFocus(date: date)
        
        let elapsed = Date().timeIntervalSince(startTime)
        print("[AnalyticsCalculator] ✅ Completed in \(String(format: "%.2f", elapsed))s")
        
        return AnalyticsSummary(
            date: date,
            totalTrackedTime: totalTime,
            appTimeData: appTime,
            focusScoreData: focusScore,
            productivityBreakdown: productivity,
            productiveBlocks: productive,
            weeklyFocusData: weeklyFocus,
            customQueryResults: [:]
        )
    }
    
    // MARK: - Calculation Methods
    
    private func calculateTotalTime(cards: [TimelineCard]) -> TimeInterval {
        var total: TimeInterval = 0
        
        for card in cards {
            let start = parseTimeString(card.startTimestamp)
            let end = parseTimeString(card.endTimestamp)
            if let startDate = start, let endDate = end {
                total += endDate.timeIntervalSince(startDate)
            }
        }
        
        return max(0, total)
    }
    
    func calculateAppTime(cards: [TimelineCard]) -> [AppTimeData] {
        var appDurations: [String: TimeInterval] = [:]
        
        for card in cards {
            // Parse appSites if available
            if let primary = card.appSites?.primary, !primary.isEmpty {
                let duration = cardDuration(card)
                appDurations[primary, default: 0] += duration
            }
        }
        
        let totalTime = appDurations.values.reduce(0, +)
        guard totalTime > 0 else { return [] }
        
        // Convert to AppTimeData and calculate percentages
        let results = appDurations.map { app, duration in
            AppTimeData(
                appName: app,
                duration: duration,
                percentage: (duration / totalTime) * 100.0
            )
        }
        .sorted { $0.duration > $1.duration }
        .prefix(10) // Top 10 apps
        
        return Array(results)
    }
    
    func calculateFocusScore(cards: [TimelineCard], date: Date) -> [FocusScoreData] {
        // Mock implementation: generate hourly focus scores based on card categories
        var scores: [FocusScoreData] = []
        let calendar = Calendar.current
        let dayInfo = date.getDayInfoFor4AMBoundary()
        
        // Group cards by hour
        var hourlyCards: [Int: [TimelineCard]] = [:]
        for card in cards {
            if let startDate = parseTimeString(card.startTimestamp) {
                let hour = calendar.component(.hour, from: startDate)
                hourlyCards[hour, default: []].append(card)
            }
        }
        
        // Calculate focus score for each hour
        for hour in 0...23 {
            guard let hourCards = hourlyCards[hour], !hourCards.isEmpty else { continue }
            
            var baseDate = dayInfo.startOfDay
            if hour < 4 {
                // Hours 0-3 belong to next day
                baseDate = calendar.date(byAdding: .day, value: 1, to: baseDate)!
            }
            guard let timestamp = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: baseDate) else {
                continue
            }
            
            // Focus score based on category (mock calculation)
            let focusCards = hourCards.filter { card in
                card.category.lowercased() == "work" || card.category.lowercased() == "personal"
            }
            let score = Double(focusCards.count) / Double(hourCards.count)
            
            scores.append(FocusScoreData(timestamp: timestamp, score: score))
        }
        
        return scores.sorted { $0.timestamp < $1.timestamp }
    }
    
    func calculateProductivityBreakdown(cards: [TimelineCard]) -> [ProductivityBreakdown] {
        var categoryDurations: [String: (duration: TimeInterval, color: String)] = [:]
        
        for card in cards {
            let duration = cardDuration(card)
            let category = card.category.isEmpty ? "Uncategorized" : card.category
            
            // Use first occurrence's color for each category
            if categoryDurations[category] == nil {
                // Extract color from category or use default
                let color = extractCategoryColor(card)
                categoryDurations[category] = (duration, color)
            } else {
                categoryDurations[category]?.duration += duration
            }
        }
        
        let totalTime = categoryDurations.values.reduce(0) { $0 + $1.duration }
        guard totalTime > 0 else { return [] }
        
        let results = categoryDurations.map { category, info in
            ProductivityBreakdown(
                categoryName: category,
                categoryColor: info.color,
                duration: info.duration,
                percentage: (info.duration / totalTime) * 100.0
            )
        }
        .sorted { $0.duration > $1.duration }
        
        return results
    }
    
    func calculateProductiveBlocks(cards: [TimelineCard], date: Date) -> [ProductiveBlock] {
        // Generate heatmap data for the current week
        var blocks: [ProductiveBlock] = []
        let calendar = Calendar.current
        
        // Get start of week (Sunday)
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start else {
            return []
        }
        
        // For each day of the week
        for dayOffset in 0...6 {
            guard let currentDay = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else {
                continue
            }
            
            let dayInfo = currentDay.getDayInfoFor4AMBoundary()
            let dayCards = storage.fetchTimelineCardsByTimeRange(from: dayInfo.startOfDay, to: dayInfo.endOfDay)
            
            // Group cards by hour
            var hourlyActivity: [Int: TimeInterval] = [:]
            for card in dayCards {
                if let startDate = parseTimeString(card.startTimestamp) {
                    let hour = calendar.component(.hour, from: startDate)
                    hourlyActivity[hour, default: 0] += cardDuration(card)
                }
            }
            
            // Create blocks for hours with activity
            for (hour, duration) in hourlyActivity {
                let intensity = min(1.0, duration / 3600.0) // Normalize to 1 hour
                blocks.append(ProductiveBlock(hour: hour, dayOfWeek: dayOffset, intensity: intensity))
            }
        }
        
        return blocks
    }
    
    func calculateWeeklyFocus(date: Date) -> [WeeklyFocusData] {
        let calendar = Calendar.current
        var weeklyData: [WeeklyFocusData] = []
        
        // Get the past 5 weekdays
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri"]
        
        for i in 0..<5 {
            guard let dayDate = calendar.date(byAdding: .day, value: -(4-i), to: date) else {
                continue
            }
            
            let dayInfo = dayDate.getDayInfoFor4AMBoundary()
            let dayCards = storage.fetchTimelineCardsByTimeRange(from: dayInfo.startOfDay, to: dayInfo.endOfDay)
            
            guard !dayCards.isEmpty else {
                weeklyData.append(WeeklyFocusData(dayName: dayNames[i], focusPercentage: 0))
                continue
            }
            
            // Calculate focus percentage based on productive categories
            let focusCards = dayCards.filter { card in
                let cat = card.category.lowercased()
                return cat == "work" || cat == "personal"
            }
            
            let focusTime = focusCards.reduce(0.0) { $0 + cardDuration($1) }
            let totalTime = dayCards.reduce(0.0) { $0 + cardDuration($1) }
            
            let percentage = totalTime > 0 ? focusTime / totalTime : 0
            weeklyData.append(WeeklyFocusData(dayName: dayNames[i], focusPercentage: percentage))
        }
        
        return weeklyData
    }
    
    func calculateCustomQuery(query: String, cards: [TimelineCard]) -> TimeInterval {
        // Simple mock: search for query in title, summary, or appSites
        let matchingCards = cards.filter { card in
            let searchText = "\(card.title) \(card.summary) \(card.appSites?.primary ?? "") \(card.appSites?.secondary ?? "")"
            return searchText.localizedCaseInsensitiveContains(query)
        }
        
        return matchingCards.reduce(0) { $0 + cardDuration($1) }
    }
    
    // MARK: - Helper Methods
    
    private func cardDuration(_ card: TimelineCard) -> TimeInterval {
        guard let start = parseTimeString(card.startTimestamp),
              let end = parseTimeString(card.endTimestamp) else {
            return 0
        }
        return end.timeIntervalSince(start)
    }
    
    private func parseTimeString(_ timeStr: String) -> Date? {
        // Timeline cards use "h:mm a" format
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        // Since we don't have the full date, we need to parse relative to today
        // This is okay for duration calculations since we only care about time differences
        guard let time = formatter.date(from: timeStr) else {
            return nil
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        
        // Create date with same day as card's context
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = components.hour
        dateComponents.minute = components.minute
        
        return calendar.date(from: dateComponents)
    }
    
    private func extractCategoryColor(_ card: TimelineCard) -> String {
        // Try to map category name to known colors
        // This is a simplified approach - in production, would use CategoryStore
        // TODO: Use CategoryStore
        let category = card.category.lowercased()
        
        switch category {
        case "work":
            return "#B984FF"
        case "personal":
            return "#6AADFF"
        case "distraction":
            return "#FF5950"
        case "idle":
            return "#A0AEC0"
        default:
            return "#E5E7EB"
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension AnalyticsCalculator {
    /// Mock calculator that returns deterministic data for previews
    static var mock: AnalyticsCalculator {
        return AnalyticsCalculator()
    }
}
#endif

