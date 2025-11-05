//
//  JournalComponents.swift
//  Dayflow
//
//  Reusable components for Journal view
//

import SwiftUI

// MARK: - Journal Header Badge

struct JournalHeaderBadge: View {
    var body: some View {
        Text("Daily Journal")
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color(hex: "#FF8C42"), Color(hex: "#FFB84D")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.white.opacity(0.9), Color.white.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Journal Narrative View

struct JournalNarrativeView: View {
    let narrative: String
    @State private var opacity: Double = 0
    
    var body: some View {
        ScrollView {
            Text(narrative)
                .font(.custom("InstrumentSerif-Regular", size: 18))
                .foregroundColor(Color(hex: "#5C3A21"))
                .lineSpacing(8)
                .padding(32)
                .frame(maxWidth: 600)
                .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.6)) {
                opacity = 1
            }
        }
    }
}

// MARK: - Journal Loading View

struct JournalLoadingView: View {
    @State private var dots = ""
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color(hex: "#FF8C42"))
            
            VStack(spacing: 8) {
                Text("Generating your journal\(dots)")
                    .font(.custom("InstrumentSerif-Regular", size: 20))
                    .foregroundColor(Color(hex: "#5C3A21"))
                
                Text("Reading through your day's activities...")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#5C3A21").opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startDotAnimation()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startDotAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation {
                if dots.count >= 3 {
                    dots = ""
                } else {
                    dots += "."
                }
            }
        }
    }
}

// MARK: - Journal Empty State

struct JournalEmptyState: View {
    let date: Date
    let onGenerate: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "book.pages")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "#FF8C42").opacity(0.6))
            
            VStack(spacing: 12) {
                Text("No Journal Entry Yet")
                    .font(.custom("InstrumentSerif-Regular", size: 28))
                    .foregroundColor(Color(hex: "#5C3A21"))
                
                Text("Generate a narrative summary of your day")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "#5C3A21").opacity(0.6))
            }
            
            Button(action: onGenerate) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .medium))
                    Text("Generate Journal")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#FF8C42"), Color(hex: "#FFB84D")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: Color(hex: "#FF8C42").opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Journal Error View

struct JournalErrorView: View {
    let error: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundColor(Color.red.opacity(0.6))
            
            VStack(spacing: 12) {
                Text("Generation Failed")
                    .font(.custom("InstrumentSerif-Regular", size: 28))
                    .foregroundColor(Color(hex: "#5C3A21"))
                
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#5C3A21").opacity(0.7))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            
            Button(action: onRetry) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                    Text("Try Again")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(hex: "#FF8C42"))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("Header Badge") {
    JournalHeaderBadge()
        .padding()
        .background(Color.gray.opacity(0.1))
}

#Preview("Narrative") {
    JournalNarrativeView(
        narrative: """
        Started the morning deep in debugging mode around 8:45 AM, wrestling with dashboard cards that refused to show up. \
        Classic case of "why isn't this simple thing working?" Had to dig through using Claude as a sounding board for ideas. \
        Eventually broke through around mid-morning and shifted gears.
        
        The afternoon was more productive - focused work blocks analyzing code and iterating on the dashboard implementation. \
        Some context switching between different components, but maintained good momentum overall. \
        Wrapped up around 5:30 PM feeling like solid progress was made, even if the morning was a bit rough.
        """
    )
    .frame(width: 600, height: 400)
}

#Preview("Loading") {
    JournalLoadingView()
        .frame(width: 600, height: 400)
}

#Preview("Empty State") {
    JournalEmptyState(date: Date()) {
        print("Generate tapped")
    }
    .frame(width: 600, height: 400)
}

#Preview("Error") {
    JournalErrorView(error: "No timeline cards found for this date") {
        print("Retry tapped")
    }
    .frame(width: 600, height: 400)
}

