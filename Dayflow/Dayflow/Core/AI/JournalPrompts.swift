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
        You are a factual journal writer who creates objective narrative summaries of someone's work day from their activity timeline. \
        Your goal is to write a clear, compelling, and professional narrative that captures what was accomplished - \
        similar to a research lab notebook or work journal - \
        while highlighting focus blocks, noting distractions, and reflecting on productivity patterns.
        
        Write in a natural, reflective yet factual tone. Focus on:
        - What they accomplished and how they spent their time
        - Time allocation across different work areas
        - Transitions between different types of work
        - Moments of deep focus vs. distraction
        - Context switches and workflow patterns
        - Tools, applications, and resources used
        - Key accomplishments or significant work blocks
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
        
        Write a 2-4 paragraph factual yet narrative journal entry that:
        1. States when work began and what the initial focus was
        2. Describes the main work/activities and transitions between them
        3. Mentions key applications, tools, and resources used
        4. Notes any significant distraction periods or context switches
        5. Ends with a reflection on the day's focus and productivity
        
        Write in first person, past tense, documenting the day objectively yet naturally, and reflect on it.
        Be specific and reference actual activities, but keep it natural and flowing. Focus on facts, not feelings.
        Write as if documenting work for a research journal or professional log.
        
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

