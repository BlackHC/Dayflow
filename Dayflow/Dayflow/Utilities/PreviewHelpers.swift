//
//  PreviewHelpers.swift
//  Dayflow
//
//  SwiftUI preview helpers with sample data
//

#if DEBUG
import Foundation
import SwiftUI

/// Mock data and helpers for SwiftUI previews
enum PreviewHelpers {
    
    // MARK: - Sample Timeline Cards
    
    /// Generate sample timeline cards for preview purposes
    static func sampleTimelineCards(count: Int = 5) -> [TimelineCard] {
        let now = Date()
        let calendar = Calendar.current
        var cards: [TimelineCard] = []
        
        let sampleActivities: [(category: String, title: String, summary: String, detailed: String)] = [
            (
                "Work",
                "Code Review",
                "Reviewing pull requests and providing feedback",
                "Went through 3 PRs from the backend team, focusing on API endpoint changes and database migrations. Left detailed comments on error handling patterns."
            ),
            (
                "Work",
                "Sprint Planning",
                "Planning upcoming sprint tasks",
                "Discussed upcoming features with the team, broke down user stories into tasks, and estimated story points. Agreed on sprint goals."
            ),
            (
                "Personal",
                "Recipe Research",
                "Looking up recipes and meal planning",
                "Browsed cooking sites for new dinner ideas, saved a few pasta recipes, and made a grocery list for the week."
            ),
            (
                "Distraction",
                "Social Media Browsing",
                "Scrolling through social feeds",
                "Lost track of time scrolling through Twitter and Instagram, watching random videos and reading threads about various topics."
            ),
            (
                "Work",
                "Writing Documentation",
                "Documenting new features",
                "Updated API documentation for the new authentication flow. Added code examples and clarified edge cases."
            ),
            (
                "Personal",
                "Fitness Tracking",
                "Logging workout and checking stats",
                "Reviewed this week's exercise data, noticed improvement in cardio endurance, and planned next week's routine."
            ),
            (
                "Distraction",
                "YouTube Watching",
                "Watching random YouTube videos",
                "Watched several recommended videos, including tech reviews and a long documentary that autoplay suggested."
            ),
            (
                "Work",
                "Client Meeting",
                "Video call with client",
                "Presented the latest demo, gathered feedback on UI changes, and discussed timeline for the next milestone."
            )
        ]
        
        var currentTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now)!
        
        for i in 0..<min(count, sampleActivities.count) {
            let activity = sampleActivities[i]
            let duration = [20, 30, 45, 60].randomElement()!
            let endTime = currentTime.addingTimeInterval(TimeInterval(duration * 60))
            
            let startTimeString = formatAsClockTime(currentTime)
            let endTimeString = formatAsClockTime(endTime)
            
            // Generate day string
            let dayInfo = currentTime.getDayInfoFor4AMBoundary()
            
            cards.append(TimelineCard(
                batchId: Int64(i + 1),
                startTimestamp: startTimeString,
                endTimestamp: endTimeString,
                category: activity.category,
                subcategory: activity.category == "Work" ? "Development" : activity.category,
                title: activity.title,
                summary: activity.summary,
                detailedSummary: activity.detailed,
                day: dayInfo.dayString,
                distractions: nil,
                videoSummaryURL: nil,
                otherVideoSummaryURLs: nil,
                appSites: sampleAppSites(for: activity.category)
            ))
            
            currentTime = endTime
        }
        
        return cards
    }
    
    /// Generate a single sample timeline card
    static func sampleTimelineCard() -> TimelineCard {
        return sampleTimelineCards(count: 1).first!
    }
    
    /// Generate sample timeline card with distraction
    static func sampleTimelineCardWithDistraction() -> TimelineCard {
        let now = Date()
        let calendar = Calendar.current
        let startTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now)!
        let endTime = startTime.addingTimeInterval(3600) // 1 hour
        
        let distractions = [
            Distraction(
                startTime: "10:15 AM",
                endTime: "10:22 AM",
                title: "Social Media Check",
                summary: "Quick scroll through Twitter"
            ),
            Distraction(
                startTime: "10:45 AM",
                endTime: "10:52 AM",
                title: "News Browsing",
                summary: "Reading news headlines"
            )
        ]
        
        let dayInfo = startTime.getDayInfoFor4AMBoundary()
        
        return TimelineCard(
            batchId: 1,
            startTimestamp: formatAsClockTime(startTime),
            endTimestamp: formatAsClockTime(endTime),
            category: "Work",
            subcategory: "Development",
            title: "Feature Implementation",
            summary: "Building new export functionality",
            detailedSummary: "Implemented the new export functionality, including CSV and JSON formats. Added progress tracking and error recovery. Had a couple of brief distractions.",
            day: dayInfo.dayString,
            distractions: distractions,
            videoSummaryURL: nil,
            otherVideoSummaryURLs: nil,
            appSites: sampleAppSites(for: "Work")
        )
    }
    
    // MARK: - Sample Categories
    
    /// Mock CategoryStore pre-populated with default categories
    @MainActor
    static func mockCategoryStore() -> CategoryStore {
        let store = CategoryStore()
        // The CategoryStore automatically loads with default categories
        return store
    }
    
    // MARK: - Sample Observations
    
    /// Generate sample observations
    static func sampleObservations(count: Int = 3) -> [Observation] {
        var observations: [Observation] = []
        let now = Date()
        
        let sampleTexts = [
            "[9:00 AM - 10:30 AM] Work: Code Review\nReviewed pull requests from team members, focusing on code quality and best practices.",
            "[10:30 AM - 11:00 AM] Personal: Coffee Break\nTook a break to prepare and enjoy coffee while catching up on news.",
            "[11:00 AM - 12:30 PM] Work: Feature Development\nImplemented new authentication flow with improved error handling and user feedback."
        ]
        
        for i in 0..<min(count, sampleTexts.count) {
            let startTs = Int(now.addingTimeInterval(TimeInterval(i * 3600)).timeIntervalSince1970)
            let endTs = startTs + 3600
            
            observations.append(Observation(
                id: Int64(i + 1),
                batchId: 1,
                startTs: startTs,
                endTs: endTs,
                observation: sampleTexts[i],
                metadata: nil,
                llmModel: "gemini-2.0-flash-exp",
                createdAt: Date()
            ))
        }
        
        return observations
    }
    
    // MARK: - Sample App/Site Data
    
    private static func sampleAppSites(for category: String) -> AppSites? {
        switch category {
        case "Work":
            return AppSites(
                primary: "github.com",
                secondary: "stackoverflow.com"
            )
        case "Personal":
            return AppSites(
                primary: "amazon.com",
                secondary: "youtube.com"
            )
        case "Distraction":
            return AppSites(
                primary: "twitter.com",
                secondary: "reddit.com"
            )
        default:
            return nil
        }
    }
    
    // MARK: - Helper Methods
    
    private static func formatAsClockTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}

// MARK: - Preview Extensions

extension CategoryStore {
    /// Create a mock category store for previews
    @MainActor
    static var preview: CategoryStore {
        PreviewHelpers.mockCategoryStore()
    }
}

extension TimelineCard {
    /// Sample timeline card for previews
    static var preview: TimelineCard {
        PreviewHelpers.sampleTimelineCard()
    }
    
    /// Sample timeline card with distractions
    static var previewWithDistraction: TimelineCard {
        PreviewHelpers.sampleTimelineCardWithDistraction()
    }
    
    /// Multiple sample cards
    static var previewArray: [TimelineCard] {
        PreviewHelpers.sampleTimelineCards(count: 5)
    }
}

extension Observation {
    /// Sample observation for previews
    static var preview: Observation {
        PreviewHelpers.sampleObservations(count: 1).first!
    }
    
    /// Multiple sample observations
    static var previewArray: [Observation] {
        PreviewHelpers.sampleObservations(count: 3)
    }
}

// MARK: - Preview Provider Helpers

/// Convenience wrapper for preview providers
struct PreviewWrapper<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
    }
}

#endif

