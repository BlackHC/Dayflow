//
//  JournalModels.swift
//  Dayflow
//
//  Journal data models and generation context
//

import Foundation

// MARK: - Journal Entry

struct JournalEntry: Codable, Identifiable, Equatable {
    let id: Int64
    let date: String  // YYYY-MM-DD format (4 AM boundary)
    let narrative: String
    let generatedAt: Date
    let regenerationCount: Int
    
    init(
        id: Int64,
        date: String,
        narrative: String,
        generatedAt: Date = Date(),
        regenerationCount: Int = 0
    ) {
        self.id = id
        self.date = date
        self.narrative = narrative
        self.generatedAt = generatedAt
        self.regenerationCount = regenerationCount
    }
}

// MARK: - Journal Generation Context

struct JournalGenerationContext: Codable {
    let date: Date
    let dayString: String  // YYYY-MM-DD format
    let totalCards: Int
    let firstActivityTime: String?  // "h:mm a" format
    let lastActivityTime: String?   // "h:mm a" format
    let focusAreas: [String]  // Top categories by time
    let distractionCount: Int
    let contextSwitches: Int
    
    init(
        date: Date,
        dayString: String,
        totalCards: Int,
        firstActivityTime: String? = nil,
        lastActivityTime: String? = nil,
        focusAreas: [String] = [],
        distractionCount: Int = 0,
        contextSwitches: Int = 0
    ) {
        self.date = date
        self.dayString = dayString
        self.totalCards = totalCards
        self.firstActivityTime = firstActivityTime
        self.lastActivityTime = lastActivityTime
        self.focusAreas = focusAreas
        self.distractionCount = distractionCount
        self.contextSwitches = contextSwitches
    }
}

// MARK: - Context Building

extension JournalGenerationContext {
    static func build(from cards: [TimelineCard], date: Date) -> JournalGenerationContext {
        let dayInfo = date.getDayInfoFor4AMBoundary()
        
        // Extract time range
        let firstTime = cards.first?.startTimestamp
        let lastTime = cards.last?.endTimestamp
        
        // Calculate focus areas (top categories by count)
        var categoryCounts: [String: Int] = [:]
        for card in cards {
            let category = card.category.isEmpty ? "Uncategorized" : card.category
            categoryCounts[category, default: 0] += 1
        }
        let focusAreas = categoryCounts
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }
        
        // Count distractions
        let distractionCount = cards.filter { card in
            card.category.lowercased() == "distraction" ||
            (card.distractions?.count ?? 0) > 0
        }.count
        
        // Estimate context switches (category changes)
        var switches = 0
        for i in 1..<cards.count {
            if cards[i].category != cards[i-1].category {
                switches += 1
            }
        }
        
        return JournalGenerationContext(
            date: date,
            dayString: dayInfo.dayString,
            totalCards: cards.count,
            firstActivityTime: firstTime,
            lastActivityTime: lastTime,
            focusAreas: Array(focusAreas),
            distractionCount: distractionCount,
            contextSwitches: switches
        )
    }
}

