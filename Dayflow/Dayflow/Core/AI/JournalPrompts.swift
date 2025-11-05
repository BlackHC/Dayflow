//
//  JournalPrompts.swift
//  Dayflow
//
//  Prompt templates for journal narrative generation
//

import Foundation

struct JournalPrompts {
    
    // MARK: - Gemini Prompts
    
    static func geminiSystemPrompt() -> String {
        """
        You are a thoughtful journal writer who creates narrative summaries of someone's day from their activity timeline. \
        Your goal is to write a compelling, first-person narrative that captures the essence of their day - \
        highlighting focus blocks, noting distractions, and reflecting on productivity patterns.
        
        Write in a natural, reflective tone that feels like a personal journal entry. Focus on:
        - What they accomplished and how they spent their time
        - Transitions between different types of work
        - Moments of deep focus vs. distraction
        - Key applications and tools they used
        - Overall patterns and themes in their day
        
        Keep the narrative concise but meaningful (2-4 paragraphs). Write in past tense, first person.
        """
    }
    
    static func geminiUserPrompt(cards: [TimelineCard], context: JournalGenerationContext) -> String {
        var prompt = """
        Generate a daily journal narrative for \(context.dayString). Here's the activity timeline:
        
        """
        
        // Add context summary
        if let firstTime = context.firstActivityTime, let lastTime = context.lastActivityTime {
            prompt += "Day started at \(firstTime) and ended at \(lastTime).\n"
        }
        
        if !context.focusAreas.isEmpty {
            prompt += "Main focus areas: \(context.focusAreas.joined(separator: ", ")).\n"
        }
        
        if context.distractionCount > 0 {
            prompt += "Distractions recorded: \(context.distractionCount).\n"
        }
        
        if context.contextSwitches > 0 {
            prompt += "Context switches: \(context.contextSwitches).\n"
        }
        
        prompt += "\n--- Timeline Activities ---\n\n"
        
        // Add timeline cards
        for (index, card) in cards.enumerated() {
            prompt += "\(index + 1). [\(card.startTimestamp) - \(card.endTimestamp)] \(card.category)\n"
            prompt += "   Title: \(card.title)\n"
            prompt += "   Summary: \(card.summary)\n"
            
            if let apps = card.appSites, let primary = apps.primary {
                prompt += "   Apps: \(primary)"
                if let secondary = apps.secondary {
                    prompt += ", \(secondary)"
                }
                prompt += "\n"
            }
            
            if let distractions = card.distractions, !distractions.isEmpty {
                prompt += "   Distractions: \(distractions.count) recorded\n"
            }
            
            prompt += "\n"
        }
        
        prompt += """
        
        --- Instructions ---
        
        Write a 2-4 paragraph narrative journal entry that:
        1. Starts with what time the day began and the initial focus
        2. Describes the main work/activities and transitions between them
        3. Mentions key applications or tools used
        4. Notes any significant distraction periods or context switches
        5. Ends with a reflection on the day's focus and productivity
        
        Write in first person, past tense, as if the person is reflecting on their day.
        Be specific and reference actual activities, but keep it natural and flowing.
        
        Return ONLY the narrative text, with no preamble or meta-commentary.
        """
        
        return prompt
    }
    
    // MARK: - Ollama Prompts
    
    static func ollamaPrompt(cards: [TimelineCard], context: JournalGenerationContext) -> String {
        var prompt = """
        Write a personal journal entry for my day on \(context.dayString).
        
        Here's what I did today:
        
        """
        
        // Add simplified timeline
        for card in cards {
            prompt += "• \(card.startTimestamp)-\(card.endTimestamp): \(card.title) (\(card.category))\n"
        }
        
        prompt += """
        
        Write a 2-3 paragraph journal entry in first person about my day. \
        Mention when I started, what I focused on, key transitions, and how productive I felt. \
        Write naturally and reflectively, like I'm writing in my personal journal.
        """
        
        return prompt
    }
}

