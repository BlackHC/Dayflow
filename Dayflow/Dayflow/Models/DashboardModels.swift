//
//  DashboardModels.swift
//  Dayflow
//
//  Dashboard data models and analytics structures
//

import Foundation

// MARK: - Dashboard Tile Models

enum DashboardTileType: String, Codable, CaseIterable {
    case appTimeTracked
    case focusScoreToday
    case productivityTracker
    case productiveTime
    case focusMeter
    case timeSpentOn
    
    var displayName: String {
        switch self {
        case .appTimeTracked: return "App Time Tracked"
        case .focusScoreToday: return "Focus Score Today"
        case .productivityTracker: return "Productivity Tracker"
        case .productiveTime: return "Productive Time"
        case .focusMeter: return "Focus Meter"
        case .timeSpentOn: return "Time Spent On"
        }
    }
    
    var description: String {
        switch self {
        case .appTimeTracked: return "See how much time you spent in different apps"
        case .focusScoreToday: return "Track your focus score throughout the day"
        case .productivityTracker: return "View productivity breakdown by category"
        case .productiveTime: return "Heatmap of productive time blocks"
        case .focusMeter: return "Weekly focus meter comparison"
        case .timeSpentOn: return "Custom query for specific activities"
        }
    }
}

struct DashboardTile: Identifiable, Codable, Equatable {
    var id: UUID
    var type: DashboardTileType
    var position: Int
    var customQuery: String?
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        type: DashboardTileType,
        position: Int,
        customQuery: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.position = position
        self.customQuery = customQuery
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    func validate() -> Bool {
        // Ensure position is non-negative
        guard position >= 0 else { return false }
        
        // If type is timeSpentOn, customQuery should not be empty
        if type == .timeSpentOn {
            guard let query = customQuery?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !query.isEmpty else {
                return false
            }
        }
        
        return true
    }
}

// MARK: - Analytics Data Models

struct AppTimeData: Codable, Equatable {
    let appName: String
    let duration: TimeInterval
    let percentage: Double
}

struct FocusScoreData: Codable, Equatable {
    let timestamp: Date
    let score: Double // 0.0 to 1.0
}

struct ProductivityBreakdown: Codable, Equatable {
    let categoryName: String
    let categoryColor: String
    let duration: TimeInterval
    let percentage: Double
}

struct ProductiveBlock: Codable, Equatable {
    let hour: Int // 0-23
    let dayOfWeek: Int // 0-6 (Sunday-Saturday)
    let intensity: Double // 0.0 to 1.0
}

struct WeeklyFocusData: Codable, Equatable {
    let dayName: String
    let focusPercentage: Double // 0.0 to 1.0
}

struct AnalyticsSummary: Codable, Equatable {
    let date: Date
    let totalTrackedTime: TimeInterval
    let appTimeData: [AppTimeData]
    let focusScoreData: [FocusScoreData]
    let productivityBreakdown: [ProductivityBreakdown]
    let productiveBlocks: [ProductiveBlock]
    let weeklyFocusData: [WeeklyFocusData]
    let customQueryResults: [String: TimeInterval]
    
    init(
        date: Date,
        totalTrackedTime: TimeInterval = 0,
        appTimeData: [AppTimeData] = [],
        focusScoreData: [FocusScoreData] = [],
        productivityBreakdown: [ProductivityBreakdown] = [],
        productiveBlocks: [ProductiveBlock] = [],
        weeklyFocusData: [WeeklyFocusData] = [],
        customQueryResults: [String: TimeInterval] = [:]
    ) {
        self.date = date
        self.totalTrackedTime = totalTrackedTime
        self.appTimeData = appTimeData
        self.focusScoreData = focusScoreData
        self.productivityBreakdown = productivityBreakdown
        self.productiveBlocks = productiveBlocks
        self.weeklyFocusData = weeklyFocusData
        self.customQueryResults = customQueryResults
    }
    
    func validate() -> Bool {
        // Check for negative durations
        guard totalTrackedTime >= 0 else { return false }
        
        for app in appTimeData {
            guard app.duration >= 0, app.percentage >= 0, app.percentage <= 100 else {
                return false
            }
        }
        
        // Check focus scores are in valid range
        for score in focusScoreData {
            guard score.score >= 0, score.score <= 1 else {
                return false
            }
        }
        
        // Check productivity percentages sum to approximately 100% (allow small floating point error)
        let totalPercentage = productivityBreakdown.reduce(0) { $0 + $1.percentage }
        if !productivityBreakdown.isEmpty {
            guard abs(totalPercentage - 100.0) < 0.1 else {
                return false
            }
        }
        
        // Check productive block intensities
        for block in productiveBlocks {
            guard block.intensity >= 0, block.intensity <= 1,
                  block.hour >= 0, block.hour <= 23,
                  block.dayOfWeek >= 0, block.dayOfWeek <= 6 else {
                return false
            }
        }
        
        // Check weekly focus percentages
        for weekDay in weeklyFocusData {
            guard weekDay.focusPercentage >= 0, weekDay.focusPercentage <= 1 else {
                return false
            }
        }
        
        return true
    }
}

// MARK: - Default Configuration

extension DashboardTile {
    static var defaultTiles: [DashboardTile] {
        [
            DashboardTile(type: .appTimeTracked, position: 0),
            DashboardTile(type: .focusScoreToday, position: 1),
            DashboardTile(type: .productivityTracker, position: 2),
            DashboardTile(type: .productiveTime, position: 3),
            DashboardTile(type: .focusMeter, position: 4),
            DashboardTile(type: .timeSpentOn, position: 5, customQuery: "Twitter")
        ]
    }
}

