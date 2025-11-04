//
//  MockDataGenerator.swift
//  Dayflow
//
//  Mock data generator for UI development and testing
//

#if DEBUG
import Foundation
import GRDB

/// Generates realistic mock data for timeline cards, batches, and observations
final class MockDataGenerator {
    private let storage = StorageManager.shared
    
    // Sample data for different activity categories
    private let workActivities = [
        ("Code Review", "Reviewing pull requests and providing feedback on team code", "Went through 3 PRs from the backend team, focusing on API endpoint changes and database migrations. Left detailed comments on error handling patterns."),
        ("Sprint Planning", "Planning upcoming sprint tasks and estimating work", "Discussed upcoming features with the team, broke down user stories into tasks, and estimated story points. Agreed on sprint goals."),
        ("Writing Documentation", "Documenting new features and updating technical specs", "Updated API documentation for the new authentication flow. Added code examples and clarified edge cases."),
        ("Client Meeting", "Video call with client to discuss project progress", "Presented the latest demo, gathered feedback on UI changes, and discussed timeline for the next milestone."),
        ("Bug Fixing", "Investigating and resolving production issues", "Fixed a race condition in the data sync logic that was causing occasional crashes. Added unit tests to prevent regression."),
        ("Design Work", "Creating mockups and prototyping interfaces", "Worked on redesigning the onboarding flow in Figma. Created high-fidelity mockups for mobile and desktop views."),
        ("Research", "Researching new technologies and best practices", "Explored different approaches to implementing real-time collaboration. Read documentation for WebRTC and operational transforms."),
        ("Email Management", "Processing inbox and responding to work emails", "Cleared backlog of emails, responded to vendor inquiries, and coordinated with HR on upcoming team expansion."),
        ("Database Optimization", "Improving query performance and schema design", "Analyzed slow queries using the profiler, added appropriate indexes, and refactored some N+1 query patterns."),
        ("Code Implementation", "Building new features and functionality", "Implemented the new export functionality, including CSV and JSON formats. Added progress tracking and error recovery.")
    ]
    
    private let personalActivities = [
        ("Recipe Research", "Looking up recipes and meal planning", "Browsed cooking sites for new dinner ideas, saved a few pasta recipes, and made a grocery list for the week."),
        ("Online Shopping", "Researching and purchasing items online", "Compared prices for a new desk chair, read reviews, and finally ordered one with good ergonomic support."),
        ("Fitness Tracking", "Logging workout and checking health stats", "Reviewed this week's exercise data in the fitness app, noticed improvement in cardio endurance, and planned next week's routine."),
        ("Reading Articles", "Reading long-form content and blogs", "Read several articles about productivity systems and time management. Bookmarked a few interesting pieces about deep work."),
        ("Financial Planning", "Managing budget and reviewing expenses", "Updated the monthly budget spreadsheet, categorized expenses, and reviewed credit card statements. On track for savings goals."),
        ("Learning New Skill", "Taking online courses or tutorials", "Completed two lessons in the Spanish course, practiced vocabulary with flashcards, and did the pronunciation exercises."),
        ("Home Organization", "Planning home improvements and organization", "Researched storage solutions for the home office, compared different shelving units, and created a layout plan."),
        ("Trip Planning", "Researching and booking travel", "Looked at flight options for summer vacation, compared hotel prices, and made a list of things to see at the destination."),
        ("Photo Editing", "Editing and organizing personal photos", "Imported photos from last weekend, did basic color correction and cropping, and organized them into albums."),
        ("Side Project", "Working on personal coding project", "Made progress on the personal website redesign, implemented the new navigation structure, and started on the blog layout.")
    ]
    
    private let distractionActivities = [
        ("Social Media Browsing", "Scrolling through social feeds", "Lost track of time scrolling through Twitter and Instagram, watching random videos and reading threads about various topics."),
        ("YouTube Watching", "Watching random YouTube videos", "Watched several recommended videos, including tech reviews, funny clips, and a long documentary that autoplay suggested."),
        ("News Browsing", "Reading various news sites and articles", "Clicked through multiple news sites, reading headlines and getting caught up in article rabbit holes without much purpose."),
        ("Reddit Browsing", "Browsing Reddit threads and comments", "Went through several subreddits, reading comment threads and getting pulled into discussions about random topics."),
        ("Online Games", "Playing casual browser or mobile games", "Played several rounds of a puzzle game, then switched to a word game, and lost track of time with one-more-round syndrome."),
        ("Meme Browsing", "Looking at memes and funny content", "Scrolled through meme pages and funny content compilations, sharing a few with friends and getting lost in the recommendations."),
        ("Window Shopping", "Browsing online stores without intent to buy", "Looked through various online stores without any specific needs, adding items to cart but not purchasing, just browsing."),
        ("Comment Reading", "Reading comment sections and discussions", "Got caught up reading comment threads under articles and videos, including arguments and debates in the replies."),
        ("Chat Scrolling", "Checking multiple chat apps and servers", "Switched between Discord, Slack, and messaging apps, reading backlog and random conversations without contributing much."),
        ("Mindless Browsing", "Opening random tabs and clicking around", "Opened many tabs following links with no clear goal, jumping between topics and sites without finishing anything.")
    ]
    
    /// Generate mock data for a specified number of days
    /// - Parameters:
    ///   - days: Number of days to generate (counting backward from today)
    ///   - startDate: Optional start date (defaults to today)
    func generateMockData(days: Int, startDate: Date = Date()) {
        print("📊 Starting mock data generation for \(days) days...")
        
        for dayOffset in 0..<days {
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: startDate)!
            generateDayData(for: date)
        }
        
        print("✅ Mock data generation complete!")
    }
    
    /// Generate a full day of activity data
    private func generateDayData(for date: Date) {
        let dayInfo = date.getDayInfoFor4AMBoundary()
        print("Generating data for day: \(dayInfo.dayString)")
        
        // Generate activities throughout the day
        var currentTime = dayInfo.startOfDay
        let endTime = dayInfo.endOfDay
        
        // Create a batch for the day's data
        let batchStartTs = Int(dayInfo.startOfDay.timeIntervalSince1970)
        let batchEndTs = Int(dayInfo.endOfDay.timeIntervalSince1970)
        
        // Create dummy chunks for the batch (we need chunks to create batches)
        let chunkIds = createDummyChunks(from: batchStartTs, to: batchEndTs)
        
        guard let batchId = storage.saveBatch(startTs: batchStartTs, endTs: batchEndTs, chunkIds: chunkIds) else {
            print("Failed to create batch for \(dayInfo.dayString)")
            return
        }
        
        storage.updateBatchStatus(batchId: batchId, status: "completed")
        
        var timelineCards: [TimelineCardShell] = []
        var observations: [Observation] = []
        
        // Morning work session (8 AM - 12 PM)
        currentTime = addHours(4, to: dayInfo.startOfDay) // 8 AM
        timelineCards.append(contentsOf: generateActivities(
            startTime: currentTime,
            duration: 4 * 60,
            category: "Work",
            activities: workActivities
        ))
        
        // Lunch break (12 PM - 1 PM)
        currentTime = addHours(8, to: dayInfo.startOfDay) // 12 PM
        timelineCards.append(generateActivity(
            startTime: currentTime,
            duration: 60,
            category: "Personal",
            activity: ("Lunch Break", "Taking a break and having lunch", "Stepped away from the desk, prepared and ate lunch while listening to a podcast.")
        ))
        
        // Afternoon work (1 PM - 3 PM)
        currentTime = addHours(9, to: dayInfo.startOfDay) // 1 PM
        timelineCards.append(contentsOf: generateActivities(
            startTime: currentTime,
            duration: 2 * 60,
            category: "Work",
            activities: workActivities
        ))
        
        // Distraction period (3 PM - 3:30 PM)
        currentTime = addHours(11, to: dayInfo.startOfDay) // 3 PM
        timelineCards.append(generateActivity(
            startTime: currentTime,
            duration: 30,
            category: "Distraction",
            activity: distractionActivities.randomElement()!
        ))
        
        // Late afternoon work (3:30 PM - 6 PM)
        currentTime = addHours(11.5, to: dayInfo.startOfDay) // 3:30 PM
        timelineCards.append(contentsOf: generateActivities(
            startTime: currentTime,
            duration: 150,
            category: "Work",
            activities: workActivities
        ))
        
        // Evening personal time (6 PM - 9 PM)
        currentTime = addHours(14, to: dayInfo.startOfDay) // 6 PM
        timelineCards.append(contentsOf: generateActivities(
            startTime: currentTime,
            duration: 3 * 60,
            category: "Personal",
            activities: personalActivities
        ))
        
        // Evening distraction (9 PM - 10 PM)
        currentTime = addHours(17, to: dayInfo.startOfDay) // 9 PM
        timelineCards.append(generateActivity(
            startTime: currentTime,
            duration: 60,
            category: "Distraction",
            activity: distractionActivities.randomElement()!
        ))
        
        // Late evening personal (10 PM - 11 PM)
        currentTime = addHours(18, to: dayInfo.startOfDay) // 10 PM
        timelineCards.append(generateActivity(
            startTime: currentTime,
            duration: 60,
            category: "Personal",
            activity: personalActivities.randomElement()!
        ))
        
        // Idle time overnight
        currentTime = addHours(19, to: dayInfo.startOfDay) // 11 PM
        timelineCards.append(generateActivity(
            startTime: currentTime,
            duration: 3 * 60, // Until 3 AM next day
            category: "Idle",
            activity: ("Sleep", "Sleeping overnight", "Computer was idle during sleeping hours.")
        ))
        
        // Save all timeline cards
        for card in timelineCards {
            if let cardId = storage.saveTimelineCardShell(batchId: batchId, card: card) {
                // Generate corresponding observations
                let obs = generateObservation(for: card, batchId: batchId)
                observations.append(obs)
            }
        }
        
        // Save observations
        storage.saveObservations(batchId: batchId, observations: observations)
        
        print("  Created \(timelineCards.count) timeline cards and \(observations.count) observations")
    }
    
    /// Generate multiple activities for a time period
    private func generateActivities(startTime: Date, duration: Int, category: String, activities: [(String, String, String)]) -> [TimelineCardShell] {
        var cards: [TimelineCardShell] = []
        var currentTime = startTime
        var remainingMinutes = duration
        
        while remainingMinutes > 0 {
            let activityDuration = min(Int.random(in: 15...45), remainingMinutes)
            let activity = activities.randomElement()!
            
            cards.append(generateActivity(
                startTime: currentTime,
                duration: activityDuration,
                category: category,
                activity: activity
            ))
            
            currentTime = currentTime.addingTimeInterval(TimeInterval(activityDuration * 60))
            remainingMinutes -= activityDuration
        }
        
        return cards
    }
    
    /// Generate a single activity
    private func generateActivity(startTime: Date, duration: Int, category: String, activity: (String, String, String)) -> TimelineCardShell {
        let endTime = startTime.addingTimeInterval(TimeInterval(duration * 60))
        
        let startTimeString = formatAsClockTime(startTime)
        let endTimeString = formatAsClockTime(endTime)
        
        // Generate distractions for some work activities
        var distractions: [Distraction]? = nil
        if category == "Work" && Bool.random() && duration > 20 {
            distractions = generateDistractions(within: startTime, and: endTime)
        }
        
        return TimelineCardShell(
            startTimestamp: startTimeString,
            endTimestamp: endTimeString,
            category: category,
            subcategory: generateSubcategory(for: category),
            title: activity.0,
            summary: activity.1,
            detailedSummary: activity.2,
            distractions: distractions,
            appSites: generateAppSites(for: category)
        )
    }
    
    /// Generate distractions for an activity
    private func generateDistractions(within startTime: Date, and endTime: Date) -> [Distraction] {
        let count = Int.random(in: 1...2)
        var distractions: [Distraction] = []
        
        for _ in 0..<count {
            let distractionStart = startTime.addingTimeInterval(TimeInterval.random(in: 0...(endTime.timeIntervalSince(startTime) * 0.7)))
            let distractionDuration = TimeInterval.random(in: 3...8) * 60 // 3-8 minutes
            let distractionEnd = distractionStart.addingTimeInterval(distractionDuration)
            
            let activity = distractionActivities.randomElement()!
            
            distractions.append(Distraction(
                startTime: formatAsClockTime(distractionStart),
                endTime: formatAsClockTime(distractionEnd),
                title: activity.0,
                summary: activity.1
            ))
        }
        
        return distractions
    }
    
    /// Generate subcategory based on main category
    private func generateSubcategory(for category: String) -> String {
        switch category {
        case "Work":
            return ["Development", "Meetings", "Email", "Planning", "Documentation"].randomElement()!
        case "Personal":
            return ["Learning", "Health", "Finance", "Hobbies", "Planning"].randomElement()!
        case "Distraction":
            return ["Social Media", "Entertainment", "Browsing", "Gaming"].randomElement()!
        case "Idle":
            return "Idle"
        default:
            return ""
        }
    }
    
    /// Generate app/site information for activity
    private func generateAppSites(for category: String) -> AppSites? {
        let sites: [String]
        
        switch category {
        case "Work":
            sites = ["github.com", "stackoverflow.com", "developer.apple.com", "docs.google.com", "notion.so", "figma.com", "slack.com"]
        case "Personal":
            sites = ["amazon.com", "youtube.com", "wikipedia.org", "medium.com", "reddit.com", "gmail.com"]
        case "Distraction":
            sites = ["twitter.com", "reddit.com", "youtube.com", "instagram.com", "netflix.com", "tiktok.com"]
        default:
            return nil
        }
        
        let shuffled = sites.shuffled()
        return AppSites(
            primary: shuffled.first,
            secondary: shuffled.count > 1 ? shuffled[1] : nil
        )
    }
    
    /// Generate observation for a timeline card
    private func generateObservation(for card: TimelineCardShell, batchId: Int64) -> Observation {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        guard let startTime = formatter.date(from: card.startTimestamp),
              let endTime = formatter.date(from: card.endTimestamp) else {
            fatalError("Invalid time format in card")
        }
        
        // Use current date as base to calculate timestamps
        let calendar = Calendar.current
        let now = Date()
        let startTs = Int(calendar.date(bySettingHour: calendar.component(.hour, from: startTime),
                                        minute: calendar.component(.minute, from: startTime),
                                        second: 0,
                                        of: now)?.timeIntervalSince1970 ?? 0)
        let endTs = Int(calendar.date(bySettingHour: calendar.component(.hour, from: endTime),
                                      minute: calendar.component(.minute, from: endTime),
                                      second: 0,
                                      of: now)?.timeIntervalSince1970 ?? 0)
        
        let observation = """
        [\(card.startTimestamp) - \(card.endTimestamp)] \(card.category): \(card.title)
        \(card.detailedSummary)
        """
        
        return Observation(
            id: nil,
            batchId: batchId,
            startTs: startTs,
            endTs: endTs,
            observation: observation,
            metadata: nil,
            llmModel: "mock-generator",
            createdAt: Date()
        )
    }
    
    /// Create dummy chunks for batch creation (required by database schema)
    private func createDummyChunks(from startTs: Int, to endTs: Int) -> [Int64] {
        var chunkIds: [Int64] = []
        var currentTs = startTs
        
        // Create 15-minute chunks
        while currentTs < endTs {
            let chunkEndTs = min(currentTs + 900, endTs) // 900 seconds = 15 minutes
            
            // Create a dummy file path
            let dummyPath = storage.recordingsRoot.appendingPathComponent("mock_\(currentTs).mp4").path
            
            // Insert chunk directly into database
            try? storage.timedWrite("createMockChunk") { db in
                try db.execute(
                    sql: "INSERT INTO chunks(start_ts, end_ts, file_url, status) VALUES (?, ?, ?, 'completed')",
                    arguments: [currentTs, chunkEndTs, dummyPath]
                )
                chunkIds.append(db.lastInsertedRowID)
            }
            
            currentTs = chunkEndTs
        }
        
        return chunkIds
    }
    
    /// Clear only mock data (batches with mock chunks only)
    func clearAllData() {
        print("🗑️ Clearing mock timeline data...")
        
        let manager = storage
        
        // Find batches that contain ONLY mock chunks
        var mockBatchIds: [Int64] = []
        try? manager.timedRead("findMockBatches") { db in
            mockBatchIds = try Int64.fetchAll(db, sql: """
                SELECT DISTINCT b.id
                FROM analysis_batches b
                INNER JOIN batch_chunks bc ON bc.batch_id = b.id
                INNER JOIN chunks c ON c.id = bc.chunk_id
                GROUP BY b.id
                HAVING COUNT(CASE WHEN c.file_url NOT LIKE '%mock_%' THEN 1 END) = 0
            """)
        }
        
        if !mockBatchIds.isEmpty {
            // Delete timeline cards for mock batches
            let videoPaths = storage.deleteTimelineCards(forBatchIds: mockBatchIds)
            print("  Deleted \(videoPaths.count) timeline cards")
            
            // Delete observations for mock batches
            storage.deleteObservations(forBatchIds: mockBatchIds)
            print("  Deleted observations")
            
            // Delete mock batches and their associations, then mock chunks
            try? manager.timedWrite("clearMockData") { db in
                let placeholders = mockBatchIds.map { _ in "?" }.joined(separator: ",")
                
                // Delete batch-chunk associations
                try db.execute(sql: "DELETE FROM batch_chunks WHERE batch_id IN (\(placeholders))", 
                              arguments: StatementArguments(mockBatchIds))
                
                // Delete mock batches
                try db.execute(sql: "DELETE FROM analysis_batches WHERE id IN (\(placeholders))", 
                              arguments: StatementArguments(mockBatchIds))
                
                // Delete mock chunks (only those with mock file URLs)
                try db.execute(sql: "DELETE FROM chunks WHERE file_url LIKE '%mock_%'")
            }
            print("  Deleted \(mockBatchIds.count) mock batches and associated chunks")
        } else {
            print("  No mock batches found")
        }
        
        print("✅ Mock data clearing complete!")
    }
    
    /// Get database statistics
    func getDatabaseStats() -> (cards: Int, batches: Int, observations: Int, chunks: Int) {
        let manager = storage
        
        var stats = (cards: 0, batches: 0, observations: 0, chunks: 0)
        
        try? manager.timedRead("getStats") { db in
            stats.cards = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM timeline_cards WHERE is_deleted = 0") ?? 0
            stats.batches = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM analysis_batches") ?? 0
            stats.observations = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM observations") ?? 0
            stats.chunks = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM chunks WHERE is_deleted = 0 OR is_deleted IS NULL") ?? 0
        }
        
        return stats
    }
    
    // MARK: - Helper Methods
    
    private func addHours(_ hours: Double, to date: Date) -> Date {
        return date.addingTimeInterval(hours * 3600)
    }
    
    private func formatAsClockTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}

#endif

