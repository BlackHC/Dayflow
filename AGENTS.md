# AGENTS.md - Dayflow Developer Guide

**Version:** 1.0  
**Last Updated:** 2025-01-04

This document serves as a comprehensive guide for AI assistants and developers working with the Dayflow codebase. It covers architecture, patterns, key components, gotchas, and development workflows.

---

## Table of Contents

1. [Project Introduction](#project-introduction)
2. [Architecture Overview](#architecture-overview)
3. [Core Components Deep Dive](#core-components-deep-dive)
4. [Critical Patterns & Conventions](#critical-patterns--conventions)
5. [Key File Reference Guide](#key-file-reference-guide)
6. [Common Development Tasks](#common-development-tasks)
7. [Important Gotchas & Constraints](#important-gotchas--constraints)
8. [Build & Configuration](#build--configuration)
9. [Testing & Quality](#testing--quality)
10. [Privacy & Data Handling](#privacy--data-handling)

---

## Project Introduction

### What is Dayflow?

Dayflow is a **native macOS application** that automatically records your screen at 1 FPS, analyzes the footage with AI every 15 minutes, and generates a beautiful timeline of your day with activity summaries and distraction highlights.

**Core Value Proposition:**
- Privacy-first: You control your data and choose your AI provider
- Lightweight: ~25MB app size, <100MB RAM, <1% CPU
- Calm UX: Non-intrusive background recording with clean, organized timeline
- Open Source: GPL-3.0-or-later license for full transparency

### Technology Stack

- **UI Framework:** SwiftUI (macOS 13.0+)
- **Screen Recording:** ScreenCaptureKit
- **Video Processing:** AVFoundation
- **Database:** GRDB (SQLite wrapper)
- **AI Providers:** Google Gemini API, Ollama, LM Studio
- **Auto-Updates:** Sparkle framework
- **Crash Reporting:** Sentry (optional, disabled by default)
- **Analytics:** PostHog (stubbed out in source builds)

### Key Features

1. **1 FPS Recording:** Minimal resource impact, ~60 frames per minute
2. **15-Minute Analysis Batches:** Efficient AI processing intervals
3. **Multiple AI Providers:** Cloud (Gemini) or Local (Ollama, LM Studio)
4. **Timeline Generation:** Automatic activity cards with summaries and categories
5. **Distraction Tracking:** Highlights time spent on unfocused activities
6. **Video Timelapses:** Review your day as a sped-up video
7. **Auto Storage Cleanup:** Removes recordings older than 3 days
8. **Deep Link Automation:** `dayflow://` URL scheme for scripting

---

## Architecture Overview

### High-Level Data Flow

```
Screen → ScreenRecorder → Video Chunks → StorageManager (SQLite)
                                              ↓
                                        AnalysisManager
                                              ↓
                                         LLMService
                                              ↓
                    ┌─────────────────────────┴─────────────────────────┐
                    ↓                                                   ↓
            Transcribe Video                                  Generate Activity Cards
         (Observations from frames)                        (Timeline cards with categories)
                    ↓                                                   ↓
            StorageManager (observations table)              StorageManager (timeline_cards table)
                                                                        ↓
                                                                Timeline UI (MainView)
```

### Component Responsibilities

| Component | Purpose | Thread Safety |
|-----------|---------|---------------|
| **ScreenRecorder** | 1 FPS capture, 15-second chunks | Serial queue, coordinates with MainActor |
| **StorageManager** | SQLite persistence (GRDB) | Thread-safe (Sendable) |
| **AnalysisManager** | Batch scheduling, 15-min intervals | Utility queue |
| **LLMService** | AI provider coordination | Task-based async |
| **AppState** | Global recording state | @MainActor |
| **CategoryStore** | User categories management | @MainActor |
| **MainView** | Timeline UI rendering | @MainActor (SwiftUI) |

### Key Architectural Patterns

1. **Protocol-Oriented Design:** `LLMProvider`, `StorageManaging`, `AnalysisManaging`
2. **State Machine:** Recording states (idle → starting → recording → finishing → paused)
3. **Actor Isolation:** `@MainActor` for UI-touching state, `Sendable` for shared services
4. **Dependency Injection:** Protocols allow testing and provider swapping
5. **Async/Await:** Modern concurrency throughout
6. **Sliding Window Analysis:** 1-hour lookback for context-aware timeline generation

---

## Core Components Deep Dive

### App Layer (`Dayflow/App/`)

#### DayflowApp.swift
**Purpose:** SwiftUI app entry point, window configuration, onboarding flow control

**Key Responsibilities:**
- Window setup with custom title bar style
- Video launch animation sequence
- Onboarding vs. main app routing
- Sparkle updater integration
- Menu bar commands (Reset Onboarding, Check for Updates)

**Notable Patterns:**
- `@StateObject` for `CategoryStore` lifecycle
- Environment object propagation for `AppState`, `CategoryStore`, `UpdaterManager`
- Animation timing with overlapping transitions

```swift
// File: Dayflow/Dayflow/App/DayflowApp.swift
// Entry point structure with onboarding routing
```

#### AppState.swift
**Purpose:** Centralized recording state management

**Key Details:**
- `@MainActor` isolated singleton
- `@Published var isRecording: Bool` triggers reactive updates
- Persistence controlled by `enablePersistence()` (only after onboarding)
- `getSavedPreference()` retrieves previous recording state
- Observed by `ScreenRecorder` via Combine publisher

**State Lifecycle:**
1. Initialize with `isRecording = false`
2. After onboarding → call `enablePersistence()`
3. Restore saved preference or default to `true`
4. All toggles automatically persist to UserDefaults

```swift
// File: Dayflow/Dayflow/App/AppState.swift
// @MainActor singleton with @Published isRecording
```

#### AppDelegate.swift
**Purpose:** Application lifecycle, permissions, system events, deep links

**Key Responsibilities:**
- Screen recording permission checks
- ScreenRecorder initialization and auto-start logic
- AnalysisManager job startup
- Login item registration (macOS 13+)
- Deep link routing (`dayflow://start-recording`, `dayflow://stop-recording`)
- Power event observation (shutdown, sleep)
- Analytics initialization (stubbed in source builds)
- Sentry initialization (optional, DSN-gated)

**Onboarding Step Logic:**
- Steps: 0=welcome, 1=howItWorks, 2=llmSelection, 3=llmSetup, 4=categories, 5=screen, 6=completion
- Recording only starts after step 5 (screen permission granted) or full onboarding
- `AppState.enablePersistence()` called after onboarding complete

**Termination Behavior:**
- `allowTermination = false` by default (Cmd+Q hides app, keeps recording)
- On soft-quit: hides windows, removes dock icon, keeps status bar + background tasks
- Only allows termination on: system shutdown, power off, user requests via "Reset Onboarding"

```swift
// File: Dayflow/Dayflow/App/AppDelegate.swift
// Lifecycle management, permission checks, deep links
```

### Recording System (`Core/Recording/`)

#### ScreenRecorder.swift
**Purpose:** Screen capture at 1 FPS using ScreenCaptureKit

**Architecture:**
- **State Machine:** Explicit `RecorderState` enum (idle, starting, recording, finishing, paused)
- **Serial Queue:** All recording operations on `recorderQueue`
- **MainActor Coordination:** Observes `AppState.shared.$isRecording` publisher
- **Chunk-Based:** 15-second video files (C.chunk = 15.0)

**Recording Configuration:**
```
- Resolution: ~1080p (targetHeight = 1080)
- Frame Rate: 1 FPS (intentionally low)
- Chunk Duration: 15 seconds
- Format: H.264 in MP4 container
- Active Display Tracking: Follows focused display
```

**State Transitions:**
- `idle` ↔ `starting` ↔ `recording` ↔ `finishing` ↔ `idle`
- `recording` → `paused` (system sleep/lock)
- `paused` → `idle` → `starting` → `recording` (auto-resume)

**Error Handling:**
- SCStream error codes mapped to `SCStreamErrorCode` enum
- User-initiated stops (code -3808, -3817) vs. transient errors (code -3807, -3815)
- Auto-restart logic for transient errors
- Exponential backoff for repeated failures

**System Events:**
- Sleep/Lock → pause recording
- Wake/Unlock → resume recording
- Display change → switch to active display
- Screen saver → pause recording

```swift
// File: Dayflow/Dayflow/Core/Recording/ScreenRecorder.swift
// State machine: idle, starting, recording, finishing, paused
// Constants: targetHeight=1080, chunk=15s, fps=1
```

#### StorageManager.swift
**Purpose:** SQLite database operations via GRDB

**Database Schema:**
- `chunks`: Recording file metadata (id, startTs, endTs, fileUrl, status, batchId)
- `analysis_batches`: 15-minute analysis groups (id, startTs, endTs, status, reason)
- `observations`: AI transcription results (id, batchId, startTs, endTs, observation)
- `timeline_cards`: Generated activity cards (id, batchId, startTimestamp, category, title, summary, etc.)
- `llm_calls`: AI API call logs (id, batchId, provider, model, latency, input, output)
- `batch_chunks`: Join table (batchId, chunkId)

**Key Methods:**
- Chunk lifecycle: `nextFileURL()`, `registerChunk()`, `markChunkCompleted()`
- Batch management: `saveBatch()`, `updateBatchStatus()`, `fetchBatches()`
- Observations: `saveObservations()`, `fetchObservationsByTimeRange()`
- Timeline cards: `saveTimelineCardShell()`, `fetchTimelineCards()`, `replaceTimelineCardsInRange()`
- Reprocessing: `resetBatchStatuses()`, `deleteTimelineCards()`, `deleteObservations()`

**Thread Safety:**
- Protocol: `StorageManaging: Sendable`
- GRDB handles concurrent access with internal locking
- No `@MainActor` isolation → callable from any thread

**Day Boundary:**
- Uses 4 AM boundary for "day" calculations
- `getDayInfoFor4AMBoundary()` extension on Date
- Timeline grouped by "day" string (YYYY-MM-DD format)

```swift
// File: Dayflow/Dayflow/Core/Recording/StorageManager.swift
// GRDB-based SQLite persistence, thread-safe
// Tables: chunks, analysis_batches, observations, timeline_cards, llm_calls
```

#### VideoProcessingService.swift
**Purpose:** Video chunk stitching and timelapse generation

**Key Responsibilities:**
- Combine multiple 15-second chunks into batch videos
- Generate timelapse videos for timeline cards
- Handle video export with AVFoundation

#### StoragePreferences.swift
**Purpose:** User preferences for storage management

**Settings:**
- Recording retention period (default: 3 days)
- Auto-cleanup schedule
- Storage path management

### AI/LLM System (`Core/AI/`)

#### LLMProvider Protocol
**Purpose:** Unified interface for all AI providers

**Required Methods:**
```swift
protocol LLMProvider {
    func transcribeVideo(videoData: Data, mimeType: String, prompt: String, 
                        batchStartTime: Date, videoDuration: TimeInterval, 
                        batchId: Int64?) async throws 
        -> (observations: [Observation], log: LLMCall)
    
    func generateActivityCards(observations: [Observation], 
                              context: ActivityGenerationContext, 
                              batchId: Int64?) async throws 
        -> (cards: [ActivityCardData], log: LLMCall)
}
```

**Two-Phase Analysis:**
1. **Transcribe Video:** Convert video frames to text observations
2. **Generate Activity Cards:** Create timeline entries from observations

**Context Structure:**
```swift
struct ActivityGenerationContext {
    let batchObservations: [Observation]      // Current batch
    let existingCards: [ActivityCardData]     // Last hour's cards
    let currentTime: Date                     // Prevent future timestamps
    let categories: [LLMCategoryDescriptor]   // User's category system
}
```

#### LLMService.swift
**Purpose:** Batch processing coordinator and provider lifecycle

**Provider Selection:**
- Reads `llmProviderType` from UserDefaults (JSON-encoded `LLMProviderType`)
- Falls back to Gemini Direct if not configured
- Migrates deprecated ChatGPT/Claude provider to Gemini

**Provider Types:**
- `.geminiDirect`: Google Gemini API with user's API key
- `.ollamaLocal(endpoint: String)`: Local Ollama server (default: http://localhost:11434)
- `.chatGPTClaude`: Deprecated, auto-migrated

**Batch Processing Flow:**
1. Fetch batch info from StorageManager
2. Retrieve chunk files for batch
3. Combine chunks into single MP4 using AVFoundation
4. Call `provider.transcribeVideo()` → get observations
5. Fetch last hour of observations (sliding window)
6. Call `provider.generateActivityCards()` with context
7. Replace old timeline cards in time range (prevents duplicates)
8. Mark batch as "analyzed" or "failed"
9. Clean up deleted timelapse videos

**Sliding Window Analysis:**
- Analyzes 1 hour of observations (not just current 15-min batch)
- Includes existing timeline cards for context
- Replaces cards in analyzed time range
- Enables merging/splitting activities across batches

**Error Handling:**
- Detailed error domain mapping (GeminiError, OllamaProvider, LLMService)
- Human-readable error messages via `getHumanReadableError()`
- Creates error timeline cards for failed batches
- Tracks analytics for analysis_batch_failed events

```swift
// File: Dayflow/Dayflow/Core/AI/LLMService.swift
// Coordinates AI providers, sliding window analysis
// processBatch() is main entry point
```

#### GeminiDirectProvider.swift
**Purpose:** Google Gemini API integration

**API Flow:**
1. Upload video to Gemini Files API (`/upload/v1beta/files`)
2. Poll for upload completion (state: PROCESSING → ACTIVE)
3. Call generateContent with video URI
4. Parse JSON response to observations/cards

**Model Preference:**
- Supports multiple Gemini models (gemini-1.5-flash, gemini-1.5-pro, gemini-2.0-flash-exp)
- Model cascade: tries flash first, falls back to pro on capacity errors (403, 429, 503)
- Preference stored in `GeminiModelPreference` (UserDefaults)

**Prompt Engineering:**
- Separate prompts for transcription and card generation
- `GeminiPromptPreferences` allows customization
- Category normalization handles LLM variation in category names

**Error Codes:**
- 400: Invalid API key
- 401: Unauthorized
- 403: Forbidden / capacity
- 429: Rate limit
- 503: Service unavailable (common during high load)

**Efficiency:**
- **2 LLM calls per batch** (native video understanding)
- No frame extraction needed
- Fast processing (~30-60 seconds per batch)

```swift
// File: Dayflow/Dayflow/Core/AI/GeminiDirectProvider.swift
// Gemini API integration, 2 LLM calls per batch
```

#### OllamaProvider.swift
**Purpose:** Local LLM integration (Ollama, LM Studio)

**API Flow:**
1. Extract ~30 frames from video (1 per 30 seconds)
2. Encode each frame as base64 JPEG
3. Call local LLM for each frame (vision model required)
4. Merge frame descriptions into observations
5. Generate timeline cards from observations

**Efficiency:**
- **30+ LLM calls per batch** (frame-by-frame analysis)
- Requires vision-capable model (llava, bakllava, etc.)
- Slower processing (~5-10 minutes per batch)
- Higher GPU usage on Apple Silicon

**Endpoint:**
- Default: `http://localhost:11434`
- Configurable via `.ollamaLocal(endpoint:)`
- Compatible with LM Studio (same API format)

**Prompt Engineering:**
- `OllamaPromptPreferences` for customization
- Frame-level prompts vs. batch-level prompts

```swift
// File: Dayflow/Dayflow/Core/AI/OllamaProvider.swift
// Local LLM integration, 30+ calls per batch
```

#### AnalysisManager.swift
**Purpose:** Batch scheduling and background job coordination

**Job Configuration:**
- Check interval: 60 seconds
- Target batch duration: 15 minutes (900 seconds)
- Max lookback: 24 hours (only process recent recordings)
- Minimum batch duration: 5 minutes (skip shorter batches)

**Background Job:**
1. Timer fires every 60 seconds (`checkInterval`)
2. Fetch unprocessed chunks from last 24 hours
3. Group chunks into 15-minute batches
4. Save batch metadata to database
5. Queue LLM processing for each batch
6. Update batch status: pending → processing → analyzed/failed

**Reprocessing:**
- `reprocessDay()`: Reprocess all batches for a given day
- `reprocessSpecificBatches()`: Reprocess selected batches
- Deletes existing timeline cards and observations
- Resets batch statuses to "pending"
- Processes sequentially with progress callbacks

**Performance Tracking:**
- Sentry transaction tracking for batch processing
- Breadcrumbs for debugging
- Timing statistics for reprocessing

```swift
// File: Dayflow/Dayflow/Core/Analysis/AnalysisManager.swift
// Timer-based batch scheduling, 15-min intervals
// startAnalysisJob() called from AppDelegate
```

### Models (`Models/`)

#### TimelineCategory.swift
**Purpose:** User-defined activity categories

**Data Model:**
```swift
struct TimelineCategory: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var colorHex: String
    var details: String           // Description for AI classification
    var order: Int
    var isSystem: Bool            // Can't be deleted
    var isIdle: Bool              // Special idle category
    var isNew: Bool               // Just created, show in UI
    var createdAt: Date
    var updatedAt: Date
}
```

**CategoryStore (MainActor):**
- `@Published private(set) var categories: [TimelineCategory]`
- CRUD operations: `addCategory()`, `updateCategory()`, `removeCategory()`, `reorderCategories()`
- Persistence: JSON-encoded in UserDefaults (key: "colorCategories")
- LLM snapshot: `snapshotForLLM()` → `[LLMCategoryDescriptor]`
- Static accessor: `descriptorsForLLM()` for background threads

**Default Categories:**
1. **Work** (#B984FF): Career, school, productivity
2. **Personal** (#6AADFF): Life tasks, hobbies, fitness
3. **Distraction** (#FF5950): Passive consumption, aimless browsing
4. **Idle** (#A0AEC0): System category for inactivity

**Idle Category:**
- Automatically added if missing (`ensureIdleCategoryPresent()`)
- Used when user is idle for >50% of time period
- System category, can't be deleted

**LLM Integration:**
```swift
struct LLMCategoryDescriptor: Codable, Sendable {
    let id: UUID
    let name: String
    let description: String?      // Sent to AI for classification
    let isSystem: Bool
    let isIdle: Bool
}
```

```swift
// File: Dayflow/Dayflow/Models/TimelineCategory.swift
// CategoryStore is @MainActor, categories in UserDefaults
```

#### AnalysisModels.swift
**Purpose:** Core data structures for recording and analysis

**Key Types:**
```swift
struct RecordingChunk: Codable {
    let id: Int64
    let startTs: Int              // Unix timestamp
    let endTs: Int
    let fileUrl: String
    let status: String            // "pending", "completed", "failed"
    var duration: TimeInterval    // Computed
}

struct Observation: Codable, Sendable {
    let id: Int64?
    let batchId: Int64
    let startTs: Int
    let endTs: Int
    let observation: String       // AI transcription text
    let metadata: String?
    let llmModel: String?
    let createdAt: Date?
}

struct ActivityCardData: Codable {
    let startTime: String         // "h:mm a" format
    let endTime: String
    let category: String
    let subcategory: String
    let title: String
    let summary: String
    let detailedSummary: String
    let distractions: [Distraction]?
    let appSites: AppSites?
}

struct Distraction: Codable, Identifiable {
    let id: UUID
    let startTime: String
    let endTime: String
    let title: String
    let summary: String
    let videoSummaryURL: String?
}

struct AppSites: Codable {
    let primary: String?          // Main app/site used
    let secondary: String?        // Secondary app/site
}
```

### Views (`Views/`)

#### UI/MainView.swift
**Purpose:** Primary application interface with timeline

**Structure:**
- Sidebar: Date navigation, tab selection (Timeline/Dashboard/Journal/Settings)
- Main content: Timeline cards for selected day
- Video player modal for card timelapses

**Timeline Display:**
- Cards grouped by 4 AM boundary "day"
- Chronological order (newest first)
- Color-coded by category
- Duration badges
- Distraction indicators

**Navigation:**
- Date picker for day selection
- Previous/Next day buttons
- Analytics tracking for `date_navigation` events

```swift
// File: Dayflow/Dayflow/Views/UI/MainView.swift
// Primary timeline interface
```

#### UI/CanvasTimelineDataView.swift
**Purpose:** Timeline card rendering and layout

#### UI/SettingsView.swift
**Purpose:** Configuration panel

**Settings Sections:**
- LLM Provider selection and API key management
- Category management (CRUD operations)
- Recording preferences
- Storage management
- Privacy and analytics opt-in/out
- Reprocessing controls

#### Onboarding/OnboardingFlow.swift
**Purpose:** First-run setup wizard

**Steps:**
1. Welcome screen
2. How it works (explanation)
3. LLM provider selection (Gemini, Ollama, Dayflow)
4. LLM setup (API key or endpoint configuration)
5. Category setup (optional customization)
6. Screen recording permission request
7. Completion (ready to use)

**State Persistence:**
- Current step in UserDefaults (key: "onboardingStep")
- Completion flag (key: "didOnboard")
- LLM provider choice (key: "llmProviderType")

**Permission Handling:**
- Uses `ScreenCaptureKit` permission check
- Guides user to System Settings if permission denied
- Shows visual guide with screenshots

```swift
// File: Dayflow/Dayflow/Views/Onboarding/OnboardingFlow.swift
// Multi-step onboarding, persists progress
```

---

## Critical Patterns & Conventions

### Actor Isolation

**MainActor Requirement:**

Components that MUST be accessed on `@MainActor`:
- `AppState.shared` (recording state)
- `CategoryStore` (category management)
- All SwiftUI Views
- `InactivityMonitor.shared`

**Coordinating with MainActor:**

```swift
// From background thread → MainActor
Task { @MainActor in
    AppState.shared.isRecording = true
}

// Or with async function
await MainActor.run {
    AppState.shared.isRecording = false
}
```

**Sendable Types:**

Thread-safe components:
- `StorageManager` (GRDB handles locking)
- `LLMProvider` implementations
- All model structs (Codable + Sendable)

### State Management

**@Published for Reactive Updates:**

```swift
@MainActor
final class AppState: ObservableObject {
    @Published var isRecording: Bool {
        didSet {
            if shouldPersist {
                UserDefaults.standard.set(isRecording, forKey: recordingKey)
            }
        }
    }
}
```

**Combine Publishers:**

```swift
// ScreenRecorder observes AppState
sub = AppState.shared.$isRecording
    .removeDuplicates()
    .sink { [weak self] enabled in
        // React to state changes
    }
```

**UserDefaults Keys:**

- `isRecording`: Recording state (Bool)
- `didOnboard`: Onboarding completion (Bool)
- `onboardingStep`: Current onboarding step (Int)
- `selectedLLMProvider`: Deprecated, use `llmProviderType`
- `llmProviderType`: Current LLM provider (JSON-encoded LLMProviderType)
- `colorCategories`: User categories (JSON-encoded [TimelineCategory])
- `hasUsedApp`: Has user created a category (Bool)
- `lastRunBuild`: Last app build number (String)

**Keychain Storage:**

- Key: "gemini" → Gemini API key
- Access via `KeychainManager.shared.retrieve(for:)` and `.store(value:for:)`

### Error Handling

**NSError Domains:**

- `LLMService`: Service-level errors (codes 1-6)
- `GeminiError` / `GeminiProvider`: Gemini API errors
- `OllamaProvider`: Ollama/local model errors
- `AnalysisManager`: Analysis coordination errors

**Error Code Examples:**

```swift
// LLMService
case 1: "No LLM provider configured"
case 2: "Batch not found"
case 3: "No recordings in batch"

// GeminiError
case 400: "Invalid API key"
case 429: "Rate limited"
case 503: "Service temporarily unavailable"

// See LLMService.getHumanReadableError() for full mapping
```

**Error Card Generation:**

When batch processing fails, an error card is created and inserted into the timeline:
- Category: "System"
- Subcategory: "Error"
- Title: "Processing failed"
- Summary: Human-readable error message
- DetailedSummary: Technical error details + batch ID

This prevents "missing time" in the timeline and provides user feedback.

### Database Access

**GRDB Patterns:**

```swift
// Reading (any thread)
let chunks = StorageManager.shared.fetchUnprocessedChunks(olderThan: timestamp)

// Writing (any thread, GRDB handles concurrency)
let batchId = StorageManager.shared.saveBatch(startTs: start, endTs: end, chunkIds: ids)

// Transactions (implicit in StorageManager methods)
try dbQueue.write { db in
    try chunk.insert(db)
}
```

**Date Handling:**

- Database stores Unix timestamps (Int)
- Swift uses Date objects
- Conversion: `Date(timeIntervalSince1970: TimeInterval(unixTs))`
- "Day" grouping: 4 AM boundary via `getDayInfoFor4AMBoundary()`

### Analytics & Telemetry

**PostHog Analytics (Stubbed):**

```swift
AnalyticsService.shared.capture("event_name", [
    "property": value
])
```

**Important:** In source builds, `AnalyticsService` is stubbed:
- All methods are no-ops
- No data sent anywhere
- Only functional if `PHPostHogApiKey` is set in Info.plist

**Event Naming:**
- snake_case convention
- See `AnalyticsEventDictionary.md` for complete list
- Common events: `app_opened`, `recording_toggled`, `analysis_batch_completed`

**Sentry Crash Reporting:**

- Optional, gated by `SentryDSN` in Info.plist
- Disabled by default in source builds
- `SentryHelper.isEnabled` flag controls usage
- Transaction tracking for performance monitoring

---

## Key File Reference Guide

### By Common Task

#### Adding a New AI Provider

1. Create provider class implementing `LLMProvider` protocol
   - File: `Dayflow/Dayflow/Core/AI/YourProvider.swift`
2. Implement `transcribeVideo()` and `generateActivityCards()`
3. Add provider type to `LLMProviderType` enum
   - File: `Dayflow/Dayflow/Core/AI/LLMProvider.swift`
4. Update provider selection in `LLMService.provider` computed property
   - File: `Dayflow/Dayflow/Core/AI/LLMService.swift`
5. Add UI for provider configuration
   - File: `Dayflow/Dayflow/Views/UI/SettingsView.swift`
   - File: `Dayflow/Dayflow/Views/Onboarding/OnboardingFlow.swift`

#### Modifying Recording Settings

**Frame Rate / Resolution:**
- File: `Dayflow/Dayflow/Core/Recording/ScreenRecorder.swift`
- Constants at top: `C.targetHeight`, `C.fps`
- **Warning:** Changing FPS impacts storage and processing time

**Chunk Duration:**
- File: `Dayflow/Dayflow/Core/Recording/ScreenRecorder.swift`
- Constant: `C.chunk = 15.0` (seconds)
- Also update `AnalysisManager` if batch timing changes

**Batch Interval:**
- File: `Dayflow/Dayflow/Core/Analysis/AnalysisManager.swift`
- `targetBatchDuration = 15*60` (seconds)
- `checkInterval = 60` (timer frequency)

#### Changing Timeline UI

**Timeline Card Layout:**
- File: `Dayflow/Dayflow/Views/UI/CanvasTimelineDataView.swift`
- Card rendering, spacing, colors

**Timeline Logic:**
- File: `Dayflow/Dayflow/Views/UI/MainView.swift`
- Date navigation, card fetching, modal presentation

**Timeline Data Models:**
- File: `Dayflow/Dayflow/Views/UI/TimelineDataModels.swift`
- View models for timeline cards

#### Adding/Modifying Categories

**Category CRUD:**
- File: `Dayflow/Dayflow/Models/TimelineCategory.swift`
- `CategoryStore` methods: `addCategory()`, `updateCategory()`, `removeCategory()`

**Default Categories:**
- File: `Dayflow/Dayflow/Models/TimelineCategory.swift`
- `CategoryPersistence.defaultCategories` static property

**UI for Categories:**
- Settings: `Dayflow/Dayflow/Views/UI/SettingsView.swift`
- Onboarding: `Dayflow/Dayflow/Views/Onboarding/OnboardingFlow.swift`

#### Database Schema Changes

**Add Table/Column:**
1. Modify schema in `StorageManager.swift`
2. Increment database version
3. Add migration in `migrate(_ db:)` method
4. Update relevant model structs
5. Add accessor methods to `StorageManaging` protocol

**File:** `Dayflow/Dayflow/Core/Recording/StorageManager.swift`

#### Deep Link Handling

**Register New Action:**
1. Update `AppDeepLinkRouter.swift` to handle new URL pattern
2. Add routing logic in `handle(_ url: URL)`
3. Update `Info.plist` if adding new URL scheme

**Files:**
- `Dayflow/Dayflow/App/AppDeepLinkRouter.swift`
- `Dayflow/Dayflow/Info.plist` (CFBundleURLTypes)

### Critical Files by Category

**Application Core:**
- `Dayflow/Dayflow/App/DayflowApp.swift` - App entry point
- `Dayflow/Dayflow/App/AppState.swift` - Global recording state
- `Dayflow/Dayflow/App/AppDelegate.swift` - Lifecycle and system events

**Recording:**
- `Dayflow/Dayflow/Core/Recording/ScreenRecorder.swift` - Screen capture
- `Dayflow/Dayflow/Core/Recording/StorageManager.swift` - Database persistence
- `Dayflow/Dayflow/Core/Recording/VideoProcessingService.swift` - Video stitching

**AI/Analysis:**
- `Dayflow/Dayflow/Core/AI/LLMProvider.swift` - Provider protocol
- `Dayflow/Dayflow/Core/AI/LLMService.swift` - Batch coordination
- `Dayflow/Dayflow/Core/AI/GeminiDirectProvider.swift` - Gemini integration
- `Dayflow/Dayflow/Core/AI/OllamaProvider.swift` - Local LLM integration
- `Dayflow/Dayflow/Core/Analysis/AnalysisManager.swift` - Batch scheduling

**Data Models:**
- `Dayflow/Dayflow/Models/TimelineCategory.swift` - Categories
- `Dayflow/Dayflow/Models/AnalysisModels.swift` - Core data structures

**UI:**
- `Dayflow/Dayflow/Views/UI/MainView.swift` - Timeline interface
- `Dayflow/Dayflow/Views/UI/SettingsView.swift` - Configuration panel
- `Dayflow/Dayflow/Views/Onboarding/OnboardingFlow.swift` - Setup wizard

---

## Common Development Tasks

### Working with the AI Pipeline

#### Understanding the Two-Phase Process

**Phase 1: Video Transcription**
- Input: Combined video from 15-minute batch
- Output: Array of `Observation` objects (text descriptions with timestamps)
- Provider method: `transcribeVideo(videoData:mimeType:prompt:batchStartTime:videoDuration:batchId:)`

**Phase 2: Activity Card Generation**
- Input: Observations from last hour (sliding window) + existing timeline cards + user categories
- Output: Array of `ActivityCardData` (timeline entries)
- Provider method: `generateActivityCards(observations:context:batchId:)`

**Why Two Phases?**
1. Separation of concerns: transcription vs. interpretation
2. Reusability: same observations can generate different cards
3. Context: card generation sees broader time window
4. Efficiency: only transcribe once, can regenerate cards

#### Sliding Window Approach

**Key Concept:** Instead of generating cards only for the current 15-minute batch, the system analyzes the last hour of observations.

**Benefits:**
- **Context awareness:** AI sees what happened before/after current batch
- **Activity merging:** Can combine related activities across batch boundaries
- **Activity splitting:** Can split long activities that span batches
- **Correction:** Can fix misclassifications based on later context

**Implementation:**
```swift
// File: LLMService.swift, processBatch() method

// Calculate 1-hour window
let currentTime = Date(timeIntervalSince1970: TimeInterval(batchEndTs))
let oneHourAgo = currentTime.addingTimeInterval(-3600)

// Fetch observations from last hour
let recentObservations = StorageManager.shared.fetchObservationsByTimeRange(
    from: oneHourAgo,
    to: currentTime
)

// Fetch existing cards in same window
let existingCards = StorageManager.shared.fetchTimelineCardsByTimeRange(
    from: oneHourAgo,
    to: currentTime
)

// Generate new cards with full context
let context = ActivityGenerationContext(
    batchObservations: observations,      // Just current batch
    existingCards: existingActivityCards, // Last hour's cards
    currentTime: currentTime,
    categories: categories
)

// Replace old cards with new ones in time range
StorageManager.shared.replaceTimelineCardsInRange(
    from: oneHourAgo,
    to: currentTime,
    with: newCards,
    batchId: batchId
)
```

**Important:** `replaceTimelineCardsInRange()` deletes old cards in the time range before inserting new ones, preventing duplicates.

#### Passing Context to Providers

**ActivityGenerationContext:**
```swift
struct ActivityGenerationContext {
    let batchObservations: [Observation]      // Current batch only
    let existingCards: [ActivityCardData]     // Last hour's cards for context
    let currentTime: Date                     // Prevent future timestamps
    let categories: [LLMCategoryDescriptor]   // User's category system
}
```

**Usage in Provider:**
```swift
func generateActivityCards(
    observations: [Observation],  // All observations in sliding window
    context: ActivityGenerationContext,
    batchId: Int64?
) async throws -> (cards: [ActivityCardData], log: LLMCall) {
    // Build prompt with:
    // - observations (full hour)
    // - context.categories (user's category definitions)
    // - context.existingCards (for merging/splitting decisions)
    // - context.currentTime (to prevent future timestamps)
    
    // Return new cards that replace the time range
}
```

### State Machine Management

#### Recording States

```swift
private enum RecorderState: Equatable {
    case idle           // Not recording, no active resources
    case starting       // Initiating stream creation (async)
    case recording      // Active stream + writer
    case finishing      // Cleaning up current segment
    case paused         // System event pause (sleep/lock)
}
```

#### State Transition Rules

**Valid Transitions:**
- `idle` → `starting` (user starts recording)
- `starting` → `recording` (stream created successfully)
- `starting` → `idle` (stream creation failed)
- `recording` → `finishing` (user stops recording)
- `recording` → `paused` (system sleep/lock)
- `finishing` → `idle` (cleanup complete)
- `paused` → `idle` (giving up on resume)
- `paused` → `starting` (attempting resume)

**Guards:**
```swift
var canStart: Bool {
    switch self {
    case .idle, .paused: return true
    case .starting, .recording, .finishing: return false
    }
}

var canStop: Bool {
    switch self {
    case .starting, .recording, .finishing: return true
    case .idle, .paused: return false
    }
}
```

**Pattern:** Always check `canStart`/`canStop` before initiating transition to avoid invalid states.

### Permission Handling

#### Screen Recording Permission

**Check Permission:**
```swift
do {
    _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    // Permission granted
} catch {
    // Permission denied or not yet granted
}
```

**Request Permission:**
- Permission requested automatically on first `SCStream` creation attempt
- System shows permission dialog
- If denied, guide user to System Settings > Privacy & Security > Screen & System Audio Recording

**Onboarding Flow:**
- Step 5: Screen Recording Permission
- Shows visual guide with screenshot
- "Request Permission" button triggers permission check
- Polls for permission grant (checks every second)
- Auto-advances when permission granted

**Post-Onboarding:**
- AppDelegate checks permission on launch
- If denied, sets `AppState.shared.isRecording = false`
- User can manually enable in System Settings
- Recording auto-starts when permission granted (if user preference was ON)

---

## Important Gotchas & Constraints

### MainActor Requirements

**Problem:** `AppState` and `CategoryStore` are `@MainActor` isolated. Accessing from background threads causes runtime error.

**Solution:**
```swift
// ❌ WRONG - will crash
let isRecording = AppState.shared.isRecording  // From background thread

// ✅ CORRECT - wrap in MainActor
let isRecording = await MainActor.run {
    AppState.shared.isRecording
}

// Or use Task
Task { @MainActor in
    AppState.shared.isRecording = true
}
```

**Affected Components:**
- `AppState.shared.*`
- `CategoryStore` instance methods
- Any SwiftUI View access
- `InactivityMonitor.shared.*`

**Exception:** `CategoryStore.descriptorsForLLM()` is a static method marked `nonisolated`, safe from any thread.

### Video Processing Constraints

#### 1 FPS is Intentional

**Why 1 FPS?**
- Storage efficiency: ~60 frames/minute vs. 1800 frames/minute at 30 FPS
- CPU/battery efficiency: Minimal encoding overhead
- AI processing: 1 frame/second provides sufficient context
- 15-minute batch = ~900 frames, manageable for AI

**Don't Change Unless:**
- You understand storage implications (30x increase at 30 FPS)
- You update batch processing logic
- You adjust AI prompts (more frames = different context)

#### 15-Minute Batches are Tuned

**Why 15 minutes?**
- Balance: Frequent enough for timely updates, infrequent enough for efficiency
- AI context window: ~15 minutes is a natural "activity" duration
- Gemini video limits: Fits comfortably within Gemini's video processing limits
- User experience: Updates timeline 4 times/hour

**Implications:**
- Shorter batches: More frequent updates but higher API costs
- Longer batches: Less frequent updates, may miss activity boundaries
- Affects `AnalysisManager.targetBatchDuration` and `ScreenRecorder.C.chunk`

#### Timelapse Video Cleanup

**Problem:** When timeline cards are replaced (sliding window regeneration), old timelapse videos become orphaned.

**Solution:** `replaceTimelineCardsInRange()` returns `deletedVideoPaths: [String]`, which LLMService uses to clean up:

```swift
let (insertedCardIds, deletedVideoPaths) = StorageManager.shared.replaceTimelineCardsInRange(...)

for path in deletedVideoPaths {
    try? FileManager.default.removeItem(at: URL(fileURLWithPath: path))
}
```

**Important:** Always clean up returned video paths to avoid storage bloat.

### Provider-Specific Behaviors

#### Gemini Efficiency

**Processing:**
- 2 LLM calls per batch (transcribe + generate cards)
- Native video understanding (no frame extraction)
- Fast: ~30-60 seconds per batch

**Rate Limits:**
- Free tier: 15 requests/minute
- Flash model: Lower cost, faster
- Pro model: Higher cost, better quality
- Model cascade helps with capacity errors

**Common Errors:**
- 503: Service temporarily unavailable (Google's end, wait and retry)
- 429: Rate limit exceeded (wait ~1 minute)
- 400/401: API key issue

#### Local Model Constraints

**Processing:**
- 30+ LLM calls per batch (1 per frame + merging)
- Frame extraction required
- Slow: ~5-10 minutes per batch
- GPU-intensive on Apple Silicon

**Requirements:**
- Vision-capable model (llava, bakllava, etc.)
- Sufficient VRAM (8GB+ recommended)
- Local server (Ollama or LM Studio) running

**Trade-offs:**
- ✅ Privacy: Everything local
- ✅ No API costs
- ❌ Slower processing
- ❌ Battery drain
- ❌ Quality depends on model

### Deep Links

**URL Scheme:** `dayflow://`

**Supported Actions:**
- `dayflow://start-recording` - Enable recording
- `dayflow://stop-recording` - Pause recording

**Testing:**
```bash
open "dayflow://start-recording"
open "dayflow://stop-recording"
```

**Implementation:**
- Handled by `AppDeepLinkRouter`
- Calls back to `AppDelegate` via `AppDeepLinkRouterDelegate`
- Sets analytics reason to "deeplink"
- No-op if already in target state

**Use Cases:**
- Shortcuts integration
- Alfred/Raycast workflows
- AppleScript automation
- Time-based scheduling (cron + `open` command)

### Update System (Sparkle)

**Configuration:**
- Framework: Sparkle 2.x via Swift Package Manager
- Appcast URL: `https://jerryzliu.github.io/Dayflow/docs/appcast.xml`
- Auto-check: Daily
- Auto-download: Yes
- Auto-install: User approval required

**Appcast Management:**
- File: `docs/appcast.xml`
- Script: `scripts/update_appcast.sh`
- Signing: `scripts/sparkle_sign_from_keychain.sh`

**Release Process:**
1. Build and archive in Xcode
2. Export signed .app
3. Create DMG with `scripts/release_dmg.sh`
4. Sign DMG with Sparkle EdDSA key
5. Update appcast.xml with new version
6. Push to GitHub Pages

**Menu Integration:**
- "Check for Updates…" in app menu
- Shows update UI if available
- Downloads in background

---

## Build & Configuration

### Environment Variables

**For Development (Xcode Scheme):**

Set in Xcode scheme editor: Product > Scheme > Edit Scheme > Run > Arguments > Environment Variables

| Variable | Purpose | Required | Example |
|----------|---------|----------|---------|
| `GEMINI_API_KEY` | Gemini API key for testing | No (can configure via UI) | `AIza...` |

**For Release Builds (Info.plist):**

Set in `Dayflow/Dayflow/Info.plist` or via build settings:

| Key | Purpose | Default |
|-----|---------|---------|
| `SentryDSN` | Sentry crash reporting endpoint | Empty (disabled) |
| `SentryEnvironment` | Sentry environment tag | "production" |
| `PHPostHogApiKey` | PostHog analytics key | Empty (stubbed) |
| `PHPostHogHost` | PostHog API endpoint | "https://us.i.posthog.com" |

**Important:** Source builds have empty values for all optional keys, meaning:
- No crash reporting (unless you add your own Sentry DSN)
- No analytics (PostHog methods are stubbed)

### Project Structure

**Xcode Project:**
- Location: `Dayflow/Dayflow.xcodeproj`
- Target: Dayflow (macOS app)
- Minimum deployment: macOS 13.0
- Swift version: 5.9+
- Xcode version: 15.0+

**Dependencies (Swift Package Manager):**
- GRDB: SQLite wrapper
- Sparkle: Auto-updates
- Sentry: Crash reporting (optional)

**Build Settings:**
- Code signing: Automatic (Xcode managed)
- Entitlements: `Dayflow/Dayflow/Dayflow.entitlements`
  - Screen Recording permission
  - Audio capture permission
  - Network access (for AI providers)
  - File access (for recordings)

**Project Organization:**
```
Dayflow/
├── Dayflow/                    # Xcode project
│   ├── Dayflow/                # App sources
│   │   ├── App/                # Application core
│   │   ├── Core/               # Business logic
│   │   │   ├── AI/             # AI providers
│   │   │   ├── Analysis/       # Batch scheduling
│   │   │   ├── Recording/      # Screen capture
│   │   │   ├── Security/       # Keychain, permissions
│   │   │   └── Thumbnails/     # Video thumbnail generation
│   │   ├── Models/             # Data models
│   │   ├── Views/              # SwiftUI views
│   │   │   ├── UI/             # Main app UI
│   │   │   ├── Onboarding/     # Setup wizard
│   │   │   └── Components/     # Reusable UI
│   │   ├── System/             # System integration
│   │   ├── Utilities/          # Helpers
│   │   ├── Assets.xcassets/    # Images, icons
│   │   ├── Fonts/              # Custom fonts
│   │   ├── Info.plist          # App configuration
│   │   └── Dayflow.entitlements
│   ├── DayflowTests/           # Unit tests
│   └── DayflowUITests/         # UI tests
├── docs/                       # GitHub Pages site
│   ├── appcast.xml             # Sparkle update feed
│   └── assets/                 # DMG background, etc.
├── scripts/                    # Build/release automation
│   ├── release.sh              # Full release pipeline
│   ├── release_dmg.sh          # Create DMG
│   ├── update_appcast.sh       # Update Sparkle feed
│   └── sparkle_sign_from_keychain.sh
├── README.md
├── LICENSE
├── LICENSE-MIT
└── NOTICE
```

### Data Locations

**Default (Non-Sandboxed):**
```
~/Library/Application Support/Dayflow/
├── recordings/                 # Video chunks (.mp4)
├── chunks.sqlite               # GRDB database
├── chunks.sqlite-wal           # Write-ahead log
└── chunks.sqlite-shm           # Shared memory
```

**Sandboxed (App Store / DMG with sandbox):**
```
~/Library/Containers/teleportlabs.com.Dayflow/Data/Library/Application Support/Dayflow/
└── (same structure)
```

**UserDefaults:**
- Domain: Standard UserDefaults
- Keys: See "State Management" section

**Keychain:**
- Service: App bundle identifier
- Keys: "gemini", "dayflow"

**Finding Data:**
- In-app: Dayflow menu bar icon > "Open Recordings..."
- Terminal: `open ~/Library/Application\ Support/Dayflow/`

**Resetting:**
```bash
# Quit app first
killall Dayflow

# Delete all data
rm -rf ~/Library/Application\ Support/Dayflow/
rm -rf ~/Library/Containers/teleportlabs.com.Dayflow/

# Relaunch app
open /Applications/Dayflow.app
```

---

## Testing & Quality

### Test Files

**Unit Tests (`DayflowTests/`):**
- `MockDataTests.swift`: Mock data generation for development/preview
- `TimeParsingTests.swift`: Date/time parsing validation

**UI Tests (`DayflowUITests/`):**
- `DayflowUITests.swift`: Basic UI flows
- `DayflowUITestsLaunchTests.swift`: Launch performance

**Running Tests:**
```bash
# Open project
open Dayflow/Dayflow.xcodeproj

# Run tests in Xcode: Cmd+U
# Or run specific test plan
xcodebuild test -project Dayflow/Dayflow.xcodeproj -scheme Dayflow -testPlan Dayflow
```

### Linting & Style

**Swift Style:**
- Follow Apple's Swift API Design Guidelines
- Use SwiftLint (if configured)
- Prefer Swift naming conventions (camelCase for variables/methods, PascalCase for types)

**Actor Isolation:**
- Compiler enforces `@MainActor` requirements
- Use `@preconcurrency` for legacy imports
- Mark protocols `Sendable` when appropriate

**Code Organization:**
- Group by feature (App, Core, Views, Models)
- Use `// MARK: -` for section headers
- Extensions in same file for small additions, separate file for large ones

**Comments:**
- Prefer self-documenting code
- Add comments for non-obvious logic
- Document public APIs with doc comments (`///`)

### Debug Tools

**Debug UI:**
- Settings > Debug section
- View recent timeline cards
- View recent LLM calls
- View analysis batches
- Reprocess day/batches

**Logging:**
- Console app: Filter for "Dayflow"
- Search for `[LLMService]`, `[Recorder]`, `[AnalysisManager]` prefixes
- Debug builds have more verbose logging

**Database Inspection:**
```bash
sqlite3 ~/Library/Application\ Support/Dayflow/chunks.sqlite

# Useful queries:
.tables
SELECT * FROM analysis_batches ORDER BY id DESC LIMIT 10;
SELECT * FROM timeline_cards ORDER BY id DESC LIMIT 10;
SELECT * FROM observations ORDER BY id DESC LIMIT 10;
```

---

## Privacy & Data Handling

### Zero Telemetry by Default

**Source Builds:**
- All analytics methods are no-ops (stubbed)
- No data sent to PostHog or any analytics service
- `AnalyticsService.shared.capture()` does nothing

**Crash Reporting:**
- Sentry is disabled by default (empty DSN)
- Only enabled if you set `SentryDSN` in Info.plist
- Source builds have no crash reporting

**Verification:**
```swift
// File: System/AnalyticsService.swift
// All methods are stubbed, no actual tracking
```

### Storage Management

**Automatic Cleanup:**
- Recordings older than 3 days are auto-deleted
- Cleanup runs during batch processing
- Configurable via `StoragePreferences`

**Retention Policy:**
- Recording chunks: 3 days
- Timeline cards: Permanent (until user deletes)
- Observations: Permanent (tied to batches)
- LLM call logs: Permanent (for debugging)

**Manual Cleanup:**
- Settings > Storage Management
- Delete specific days
- Delete all recordings
- Reprocess generates new cards but keeps old recordings (within retention)

### AI Provider Privacy

**Gemini (Cloud):**
- Your data sent to Google Gemini API
- Uses your own API key
- Subject to Google's Gemini API Terms
- "Paid Services" data handling if billing enabled (no training on your data)

**Ollama/LM Studio (Local):**
- All processing on your machine
- No data leaves your computer
- Network traffic only to local server (localhost)
- Fully offline after model download

**Recommendation:** Use local providers for maximum privacy, Gemini for best quality/speed.

---

## Appendix: Quick Reference

### File Paths (Relative to Repository Root)

| Path | Description |
|------|-------------|
| `Dayflow/Dayflow/App/` | Application core (entry point, state, lifecycle) |
| `Dayflow/Dayflow/Core/AI/` | AI provider implementations |
| `Dayflow/Dayflow/Core/Recording/` | Screen recording and storage |
| `Dayflow/Dayflow/Core/Analysis/` | Batch scheduling |
| `Dayflow/Dayflow/Models/` | Data models |
| `Dayflow/Dayflow/Views/UI/` | Main application UI |
| `Dayflow/Dayflow/Views/Onboarding/` | Setup wizard |
| `Dayflow/Dayflow/System/` | System integration (status bar, analytics, updates) |
| `Dayflow/Dayflow/Utilities/` | Helper functions |
| `scripts/` | Build and release automation |
| `docs/` | GitHub Pages site (appcast, assets) |

### Common Commands

```bash
# Open project
open Dayflow/Dayflow.xcodeproj

# Build
xcodebuild -project Dayflow/Dayflow.xcodeproj -scheme Dayflow -configuration Release

# Run tests
xcodebuild test -project Dayflow/Dayflow.xcodeproj -scheme Dayflow

# Create release DMG (requires signing)
cd scripts
./release_dmg.sh

# Update appcast (after release)
./update_appcast.sh

# Full release (all steps)
./release.sh
```

### Key Classes Summary

| Class | File | Purpose |
|-------|------|---------|
| `DayflowApp` | `App/DayflowApp.swift` | SwiftUI app entry, window setup |
| `AppState` | `App/AppState.swift` | Global recording state (@MainActor) |
| `AppDelegate` | `App/AppDelegate.swift` | Lifecycle, permissions, deep links |
| `ScreenRecorder` | `Core/Recording/ScreenRecorder.swift` | 1 FPS screen capture |
| `StorageManager` | `Core/Recording/StorageManager.swift` | SQLite persistence (GRDB) |
| `AnalysisManager` | `Core/Analysis/AnalysisManager.swift` | Batch scheduling, timer |
| `LLMService` | `Core/AI/LLMService.swift` | AI provider coordinator |
| `GeminiDirectProvider` | `Core/AI/GeminiDirectProvider.swift` | Gemini API integration |
| `OllamaProvider` | `Core/AI/OllamaProvider.swift` | Local LLM integration |
| `CategoryStore` | `Models/TimelineCategory.swift` | Category management (@MainActor) |
| `MainView` | `Views/UI/MainView.swift` | Timeline interface |
| `SettingsView` | `Views/UI/SettingsView.swift` | Configuration panel |
| `OnboardingFlow` | `Views/Onboarding/OnboardingFlow.swift` | Setup wizard |

---

## Conclusion

This guide covers the essential architecture, patterns, and practices for working with Dayflow. When in doubt:

1. **Check the code:** Dayflow is open source, read the implementation
2. **Follow patterns:** Use existing patterns (protocols, actor isolation, error handling)
3. **Test thoroughly:** Screen recording and AI integration have many edge cases
4. **Respect privacy:** Maintain zero-telemetry default in source builds
5. **Document changes:** Update this guide when architecture changes

For questions or contributions, see the main README.md and CONTRIBUTING guidelines (if available).

**Happy coding!** 🚀

