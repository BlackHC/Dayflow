//
//  DashboardView.swift
//  Dayflow
//
//  Dashboard view with analytics tiles
//

import SwiftUI
import AppKit

struct DashboardView: View {
    @EnvironmentObject private var dashboardStore: DashboardStore
    @State private var selectedDate = Date()
    @State private var analytics: AnalyticsSummary?
    @State private var isEditMode = false
    @State private var showAddTileSheet = false
    
    private let calculator = AnalyticsCalculator()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with edit button
            HStack(alignment: .center) {
                Text("Dashboard")
                    .font(.custom("InstrumentSerif-Regular", size: 42))
                    .foregroundColor(.black)
                    .padding(.leading, 10)
                
                Spacer()
                
                Button(action: {
                    isEditMode.toggle()
                }) {
                    Text(isEditMode ? "Done" : "Edit")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.black.opacity(0.7))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 10)
            }
            
            // Tiles grid
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ],
                    spacing: 16
                ) {
                    ForEach(dashboardStore.tiles) { tile in
                        tileView(for: tile)
                            .frame(height: 240)
                            .overlay(
                                Group {
                                    if isEditMode {
                                        Button(action: {
                                            dashboardStore.removeTile(id: tile.id)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(.white)
                                                .background(Circle().fill(Color.red))
                                        }
                                        .buttonStyle(.plain)
                                        .offset(x: 8, y: -8)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                    }
                                }
                            )
                    }
                    
                    // Add tile button
                    if isEditMode {
                        Button(action: {
                            showAddTileSheet = true
                        }) {
                            VStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(Color.black.opacity(0.3))
                                
                                Text("Add Tile")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.black.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(
                                        style: StrokeStyle(lineWidth: 2, dash: [8])
                                    )
                                    .foregroundColor(Color.black.opacity(0.15))
                            )
                        }
                        .buttonStyle(.plain)
                        .frame(height: 240)
                    }
                }
                .padding(.horizontal, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            loadAnalytics()
        }
        .sheet(isPresented: $showAddTileSheet) {
            AddTileSheet(dashboardStore: dashboardStore)
        }
    }
    
    @ViewBuilder
    private func tileView(for tile: DashboardTile) -> some View {
        if let analytics = analytics {
            switch tile.type {
            case .appTimeTracked:
                AppTimeTrackedTile(
                    data: analytics.appTimeData,
                    totalTime: analytics.totalTrackedTime
                )
            case .focusScoreToday:
                FocusScoreTile(data: analytics.focusScoreData)
            case .productivityTracker:
                ProductivityTrackerTile(data: analytics.productivityBreakdown)
            case .productiveTime:
                ProductiveTimeTile(data: analytics.productiveBlocks)
            case .focusMeter:
                FocusMeterTile(data: analytics.weeklyFocusData)
            case .timeSpentOn:
                let query = tile.customQuery ?? "Unknown"
                // Calculate custom query results on demand
                let totalTime = analytics.customQueryResults[query] ?? 0
                TimeSpentOnTile(
                    query: query,
                    totalTime: totalTime,
                    breakdownData: []
                )
            }
        } else {
            // Loading state
            VStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Loading analytics...")
                    .font(.system(size: 12))
                    .foregroundColor(Color.black.opacity(0.5))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    private func loadAnalytics() {
        print("[DashboardView] Loading analytics for \(selectedDate)")
        let result = calculator.calculateDayAnalytics(for: selectedDate)
        analytics = result
    }
}

// MARK: - Add Tile Sheet

struct AddTileSheet: View {
    @ObservedObject var dashboardStore: DashboardStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedType: DashboardTileType = .appTimeTracked
    @State private var customQuery: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Dashboard Tile")
                .font(.custom("InstrumentSerif-Regular", size: 28))
                .foregroundColor(.black)
            
            // Tile type picker
            VStack(alignment: .leading, spacing: 12) {
                Text("Tile Type")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.black.opacity(0.7))
                
                ForEach(DashboardTileType.allCases, id: \.self) { type in
                    Button(action: {
                        selectedType = type
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(type.displayName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.black)
                                
                                Text(type.description)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.black.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            if selectedType == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(12)
                        .background(selectedType == type ? Color.blue.opacity(0.1) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Custom query field for timeSpentOn type
            if selectedType == .timeSpentOn {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Query")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.7))
                    
                    TextField("e.g., Twitter, Figma, Email", text: $customQuery)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            Spacer()
            
            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Add Tile") {
                    let query = selectedType == .timeSpentOn ? customQuery : nil
                    dashboardStore.addTile(type: selectedType, customQuery: query)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedType == .timeSpentOn && customQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 500, height: 600)
    }
}
