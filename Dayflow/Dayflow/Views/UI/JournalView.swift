//
//  JournalView.swift
//  Dayflow
//
//  Daily journal narrative view
//

import SwiftUI

struct JournalView: View {
    @State private var selectedDate = Date()
    @State private var entry: JournalEntry?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    
    private let llmService = LLMService.shared
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(hex: "#FFE8D6"),
                    Color(hex: "#FFDCC0"),
                    Color(hex: "#FFF5E8")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with date selector
                HStack(alignment: .center, spacing: 16) {
                    JournalHeaderBadge()
                    
                    Spacer()
                    
                    // Date navigation
                    HStack(spacing: 8) {
                        Button(action: previousDay) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#5C3A21").opacity(0.7))
                                .frame(width: 28, height: 28)
                                .background(Color.white.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Text(formatDate(selectedDate))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#5C3A21"))
                            .frame(minWidth: 120)
                        
                        Button(action: nextDay) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#5C3A21").opacity(0.7))
                                .frame(width: 28, height: 28)
                                .background(Color.white.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isToday())
                    }
                    .padding(.trailing, 10)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                
                // Content
                ZStack {
                    if isGenerating {
                        JournalLoadingView()
                    } else if let error = errorMessage {
                        JournalErrorView(error: error) {
                            generateJournal()
                        }
                    } else if let entry = entry {
                        VStack(spacing: 0) {
                            JournalNarrativeView(narrative: entry.narrative)
                            
                            // Regenerate button at bottom
                            HStack {
                                Spacer()
                                
                                Button(action: regenerateJournal) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 12, weight: .medium))
                                        Text("Regenerate")
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundColor(Color(hex: "#5C3A21").opacity(0.7))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.6))
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                
                                Spacer()
                            }
                            .padding(.vertical, 16)
                        }
                    } else {
                        JournalEmptyState(date: selectedDate) {
                            generateJournal()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            loadEntry()
        }
        .onChange(of: selectedDate) { _, _ in
            loadEntry()
        }
    }
    
    // MARK: - Actions
    
    private func previousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }
    
    private func nextDay() {
        guard !isToday() else { return }
        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
    }
    
    private func isToday() -> Bool {
        Calendar.current.isDate(selectedDate, inSameDayAs: Date())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
    }
    
    private func loadEntry() {
        let dayInfo = selectedDate.getDayInfoFor4AMBoundary()
        entry = StorageManager.shared.fetchJournalEntry(for: dayInfo.dayString)
        errorMessage = nil
        
        if entry != nil {
            print("[JournalView] Loaded entry for \(dayInfo.dayString)")
        }
    }
    
    private func generateJournal() {
        isGenerating = true
        errorMessage = nil
        
        llmService.generateJournal(for: selectedDate) { result in
            DispatchQueue.main.async {
                isGenerating = false
                
                switch result {
                case .success(let narrative):
                    print("[JournalView] Successfully generated journal: \(narrative.prefix(100))...")
                    loadEntry() // Reload from storage
                    
                case .failure(let error):
                    print("[JournalView] Generation failed: \(error)")
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func regenerateJournal() {
        generateJournal()
    }
}

// MARK: - Previews

#Preview("Empty State") {
    JournalView()
        .frame(width: 800, height: 600)
}
