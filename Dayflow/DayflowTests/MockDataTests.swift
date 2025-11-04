//
//  MockDataTests.swift
//  DayflowTests
//
//  Unit tests for mock data generation
//

import XCTest
@testable import Dayflow

final class MockDataTests: XCTestCase {
    
    #if DEBUG
    var generator: MockDataGenerator!
    var storage: StorageManager!
    
    override func setUp() {
        super.setUp()
        generator = MockDataGenerator()
        storage = StorageManager.shared
    }
    
    override func tearDown() {
        // Clean up test data after each test
        generator.clearAllData()
        super.tearDown()
    }
    
    // MARK: - Database Stats Tests
    
    func testGetDatabaseStatsReturnsValidData() {
        let stats = generator.getDatabaseStats()
        
        // Stats should be non-negative
        XCTAssertGreaterThanOrEqual(stats.cards, 0, "Cards count should be non-negative")
        XCTAssertGreaterThanOrEqual(stats.batches, 0, "Batches count should be non-negative")
        XCTAssertGreaterThanOrEqual(stats.observations, 0, "Observations count should be non-negative")
        XCTAssertGreaterThanOrEqual(stats.chunks, 0, "Chunks count should be non-negative")
    }
    
    func testClearAllDataRemovesAllRecords() {
        let initialStats = generator.getDatabaseStats()
        
        // Generate some data first
        generator.generateMockData(days: 1)
        
        let intermediateStats = generator.getDatabaseStats()
        // Verify data was created
        XCTAssertGreaterThan(intermediateStats.cards, initialStats.cards, "Should have created timeline cards")
        XCTAssertGreaterThan(intermediateStats.batches, initialStats.batches, "Should have created batches")
        
        // Clear all data
        generator.clearAllData()
        
        // Verify data was cleared
        let finalStats = generator.getDatabaseStats()
        XCTAssertEqual(finalStats.cards, initialStats.cards, "All timeline cards should be deleted")
        XCTAssertEqual(finalStats.batches, initialStats.batches, "All batches should be deleted")
        XCTAssertEqual(finalStats.observations, initialStats.observations, "All observations should be deleted")
    }
    
    // MARK: - Data Generation Tests
    
    func testGenerateMockDataCreatesTimelinesCards() {
        generator.generateMockData(days: 1)
        
        let stats = generator.getDatabaseStats()
        
        XCTAssertGreaterThan(stats.cards, 0, "Should create timeline cards")
        XCTAssertGreaterThan(stats.batches, 0, "Should create batches")
        XCTAssertGreaterThan(stats.observations, 0, "Should create observations")
        XCTAssertGreaterThan(stats.chunks, 0, "Should create chunks")
    }
    
    func testGenerateMultipleDaysCreatesMoreData() {
        // Generate 1 day
        generator.generateMockData(days: 1)
        let stats1 = generator.getDatabaseStats()
        
        // Clear and generate 3 days
        generator.clearAllData()
        generator.generateMockData(days: 3)
        let stats3 = generator.getDatabaseStats()
        
        // 3 days should have more data than 1 day
        XCTAssertGreaterThan(stats3.cards, stats1.cards, "3 days should have more cards than 1 day")
        XCTAssertGreaterThan(stats3.batches, stats1.batches, "3 days should have more batches than 1 day")
    }
    
//    func testGeneratedCardsHaveValidTimestamps() {
//        generator.generateMockData(days: 1)
//        
//        // Fetch generated cards
//        let today = Date()
//        let dayInfo = today.getDayInfoFor4AMBoundary()
//        let cards = storage.fetchTimelineCards(forDay: dayInfo.dayString)
//        
//        XCTAssertFalse(cards.isEmpty, "Should have generated cards for today")
//        
//        // Verify all cards have valid timestamps
//        let formatter = DateFormatter()
//        formatter.dateFormat = "h:mm a"
//        formatter.locale = Locale(identifier: "en_US_POSIX")
//        
//        for card in cards {
//            let startTime = formatter.date(from: card.startTimestamp)
//            let endTime = formatter.date(from: card.endTimestamp)
//            
//            XCTAssertNotNil(startTime, "Start time should be valid: \(card.startTimestamp)")
//            XCTAssertNotNil(endTime, "End time should be valid: \(card.endTimestamp)")
//            
//            if let start = startTime, let end = endTime {
//                XCTAssertLessThan(start, end, "End time should be after start time")
//            }
//        }
//    }
    
    func testGeneratedCardsHaveValidCategories() {
        generator.generateMockData(days: 1)
        
        let today = Date()
        let dayInfo = today.getDayInfoFor4AMBoundary()
        let cards = storage.fetchTimelineCards(forDay: dayInfo.dayString)
        
        XCTAssertFalse(cards.isEmpty, "Should have generated cards")
        
        let validCategories = ["Work", "Personal", "Distraction", "Idle"]
        
        for card in cards {
            XCTAssertTrue(validCategories.contains(card.category),
                         "Category '\(card.category)' should be one of: \(validCategories)")
            XCTAssertFalse(card.title.isEmpty, "Card should have a title")
            XCTAssertFalse(card.summary.isEmpty, "Card should have a summary")
        }
    }
    
    func testGeneratedCardsFollowDayBoundaries() {
        // Generate data for yesterday
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        generator.generateMockData(days: 1, startDate: yesterday)
        
        let dayInfo = yesterday.getDayInfoFor4AMBoundary()
        let cards = storage.fetchTimelineCards(forDay: dayInfo.dayString)
        
        XCTAssertFalse(cards.isEmpty, "Should have cards for yesterday")
        
        // All cards should have the same day string
        for card in cards {
            XCTAssertEqual(card.day, dayInfo.dayString,
                          "All cards should belong to the same day: \(dayInfo.dayString)")
        }
    }
    
    func testGeneratedObservationsMatchCards() {
        generator.generateMockData(days: 1)
        
        let stats = generator.getDatabaseStats()
        
        // Number of observations should match number of cards
        // (each card gets one observation)
        XCTAssertEqual(stats.observations, stats.cards,
                      "Should have one observation per timeline card")
    }
    
    // MARK: - Edge Cases
    
    func testGenerateZeroDaysCreatesNoData() {
        let initialStats = generator.getDatabaseStats()
        
        generator.generateMockData(days: 0)
        
        let finalStats = generator.getDatabaseStats()
        
        // No new data should be created
        XCTAssertEqual(initialStats.cards, finalStats.cards,
                      "Should not create new cards")
        XCTAssertEqual(initialStats.batches, finalStats.batches,
                      "Should not create new batches")
    }
    
    func testMultiplePopulationsAreAdditive() {
        // First population
        generator.generateMockData(days: 1)
        let stats1 = generator.getDatabaseStats()
        
        // Second population (should add more data)
        generator.generateMockData(days: 1)
        let stats2 = generator.getDatabaseStats()
        
        // Stats should increase
        XCTAssertGreaterThan(stats2.cards, stats1.cards,
                            "Second population should add more cards")
        XCTAssertGreaterThan(stats2.batches, stats1.batches,
                            "Second population should add more batches")
    }
    
    // MARK: - Preview Helpers Tests
    
    func testPreviewHelpersGenerateSampleCards() {
        let cards = PreviewHelpers.sampleTimelineCards(count: 5)
        
        XCTAssertEqual(cards.count, 5, "Should generate requested number of cards")
        
        for card in cards {
            XCTAssertFalse(card.title.isEmpty, "Card should have a title")
            XCTAssertFalse(card.summary.isEmpty, "Card should have a summary")
            XCTAssertFalse(card.startTimestamp.isEmpty, "Card should have a start timestamp")
            XCTAssertFalse(card.endTimestamp.isEmpty, "Card should have an end timestamp")
        }
    }
    
    func testPreviewHelpersGenerateSingleCard() {
        let card = PreviewHelpers.sampleTimelineCard()
        
        XCTAssertFalse(card.title.isEmpty, "Card should have a title")
        XCTAssertFalse(card.category.isEmpty, "Card should have a category")
    }
    
    func testPreviewHelpersGenerateCardWithDistraction() {
        let card = PreviewHelpers.sampleTimelineCardWithDistraction()
        
        XCTAssertNotNil(card.distractions, "Card should have distractions")
        XCTAssertFalse(card.distractions!.isEmpty, "Distractions should not be empty")
        
        for distraction in card.distractions! {
            XCTAssertFalse(distraction.title.isEmpty, "Distraction should have a title")
            XCTAssertFalse(distraction.summary.isEmpty, "Distraction should have a summary")
        }
    }
    
    func testPreviewHelpersGenerateObservations() {
        let observations = PreviewHelpers.sampleObservations(count: 3)
        
        XCTAssertEqual(observations.count, 3, "Should generate requested number of observations")
        
        for observation in observations {
            XCTAssertFalse(observation.observation.isEmpty, "Observation should have text")
            XCTAssertGreaterThan(observation.endTs, observation.startTs,
                               "End timestamp should be after start timestamp")
        }
    }
    
    #endif
}

