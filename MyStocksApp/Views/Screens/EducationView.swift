//
//  EducationView.swift
//  MyStocksApp
//
//  Educational view for learning chart patterns
//

import SwiftUI

struct EducationView: View {
    @State private var selectedCategory: PatternCategory = .candlestick
    @State private var selectedPattern: PatternDefinition?
    @State private var searchText = ""
    
    private let patterns = PatternLibrary.allPatterns
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Progress Section
                    progressSection
                    
                    // Category Picker
                    categoryPicker
                    
                    // Patterns Grid
                    patternsGrid
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Learn")
            .searchable(text: $searchText, prompt: "Search patterns")
            .sheet(item: $selectedPattern) { pattern in
                PatternDetailSheet(pattern: pattern)
            }
        }
    }
    
    // MARK: - Progress Section
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Progress")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("5/\(patterns.count) learned")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
                    // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                    
                    Rectangle()
                        .fill(Color.brandPrimary)
                        .frame(width: geometry.size.width * 0.25) // 5/20 = 25%
                }
                .cornerRadius(4)
            }
            .frame(height: 8)
            
            // Quick Stats
            HStack(spacing: 20) {
                EducationStatItem(title: "Patterns Learned", value: "5", icon: "checkmark.circle.fill", color: .green)
                EducationStatItem(title: "Quiz Score", value: "87%", icon: "star.fill", color: .yellow)
                EducationStatItem(title: "Streak", value: "3 days", icon: "flame.fill", color: .orange)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(16)
    }
    
    // MARK: - Category Picker
    
    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(PatternCategory.allCases, id: \.self) { category in
                    CategoryPill(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
        }
    }
    
    // MARK: - Patterns Grid
    
    private var patternsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(selectedCategory.rawValue + " Patterns")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(filteredPatterns) { pattern in
                    PatternCard(pattern: pattern)
                        .onTapGesture {
                            selectedPattern = pattern
                        }
                }
            }
        }
    }
    
    // MARK: - Computed
    
    private var filteredPatterns: [PatternDefinition] {
        var result = patterns.filter { $0.category == selectedCategory }
        
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return result
    }
}

// MARK: - Supporting Views

struct EducationStatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CategoryPill: View {
    let category: PatternCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                Text(category.rawValue)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundColor(isSelected ? .black : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color.brandPrimary : Color.gray.opacity(0.3))
            .cornerRadius(20)
        }
    }
}

struct PatternCard: View {
    let pattern: PatternDefinition
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Pattern Type Badge
            HStack {
                Text(pattern.type.color == "green" ? "🟢" : pattern.type.color == "red" ? "🔴" : "🟡")
                
                Spacer()
                
                // Reliability
                Text(pattern.reliability.rawValue)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            // Pattern Name
            Text(pattern.name)
                .font(.headline)
                .foregroundColor(.white)
            
            // Pattern Type
            Text(pattern.type.rawValue)
                .font(.caption)
                .foregroundColor(.gray)
            
            // Reliability Stars
            Text(pattern.reliability.successRate)
                .font(.caption.weight(.medium))
                .foregroundColor(.yellow)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
}

// MARK: - Pattern Detail Sheet

struct PatternDetailSheet: View {
    let pattern: PatternDefinition
    @Environment(\.dismiss) private var dismiss
    @State private var showingQuiz = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        // Pattern Visual
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 64))
                            .foregroundColor(.brandPrimary)
                        
                        Text(pattern.name)
                            .font(.title.weight(.bold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 16) {
                            PatternTypeBadge(type: pattern.type)
                            ReliabilityBadge(reliability: pattern.reliability)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    
                    // Description
                    GroupBox("Description") {
                        Text(pattern.description)
                            .foregroundColor(.gray)
                    }
                    
                    // Key Characteristics
                    if !pattern.keyCharacteristics.isEmpty {
                        GroupBox("Key Characteristics") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(pattern.keyCharacteristics, id: \.self) { characteristic in
                                    HStack(alignment: .top) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        
                                        Text(characteristic)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Trading Strategy
                    GroupBox("Trading Strategy") {
                        VStack(alignment: .leading, spacing: 12) {
                            if !pattern.entryStrategy.isEmpty {
                                StrategyRow(title: "Entry", content: pattern.entryStrategy, icon: "arrow.right.circle.fill", color: .green)
                            }
                            
                            if !pattern.targetCalculation.isEmpty {
                                StrategyRow(title: "Target", content: pattern.targetCalculation, icon: "target", color: .blue)
                            }
                            
                            if !pattern.stopLoss.isEmpty {
                                StrategyRow(title: "Stop Loss", content: pattern.stopLoss, icon: "exclamationmark.shield.fill", color: .red)
                            }
                        }
                    }
                    
                    // Quiz Button
                    Button(action: { showingQuiz = true }) {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                            Text("Test Your Knowledge")
                        }
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brandPrimary)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingQuiz) {
                PatternQuizView(pattern: pattern)
            }
        }
    }
}

struct PatternTypeBadge: View {
    let type: PatternType
    
    var body: some View {
        Text(type.rawValue)
            .font(.caption.weight(.medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(type.color == "green" ? .green : type.color == "red" ? .red : .gray))
            .cornerRadius(8)
    }
}

struct ReliabilityBadge: View {
    let reliability: PatternReliability
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
            Text(reliability.successRate)
        }
        .font(.caption.weight(.medium))
        .foregroundColor(.yellow)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.yellow.opacity(0.2))
        .cornerRadius(8)
    }
}

struct StrategyRow: View {
    let title: String
    let content: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                
                Text(content)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Pattern Quiz View

struct PatternQuizView: View {
    let pattern: PatternDefinition
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentQuestion = 0
    @State private var selectedAnswer: Int?
    @State private var score = 0
    @State private var showResult = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Progress
                ProgressView(value: Double(currentQuestion + 1), total: 3)
                    .tint(.brandPrimary)
                
                Text("Question \(currentQuestion + 1) of 3")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                // Question
                Text("What type of pattern is \(pattern.name)?")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Answers
                VStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { index in
                        AnswerButton(
                            text: sampleAnswers[index],
                            isSelected: selectedAnswer == index,
                            isCorrect: index == 0 // First answer is correct
                        ) {
                            selectedAnswer = index
                        }
                    }
                }
                
                Spacer()
                
                // Next Button
                Button(action: {
                    if selectedAnswer == 0 {
                        score += 1
                    }
                    
                    if currentQuestion < 2 {
                        currentQuestion += 1
                        selectedAnswer = nil
                    } else {
                        showResult = true
                    }
                }) {
                    Text(currentQuestion < 2 ? "Next" : "Finish")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedAnswer != nil ? Color.brandPrimary : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(selectedAnswer == nil)
            }
            .padding()
            .background(Color.black)
            .navigationTitle("Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Quiz Complete!", isPresented: $showResult) {
                Button("Done") { dismiss() }
            } message: {
                Text("You scored \(score)/3")
            }
        }
    }
    
    private var sampleAnswers: [String] {
        [
            pattern.type.rawValue,
            "Neutral Pattern",
            "Volume Pattern",
            "Gap Pattern"
        ]
    }
}

struct AnswerButton: View {
    let text: String
    let isSelected: Bool
    let isCorrect: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .foregroundColor(.white)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.brandPrimary)
                }
            }
            .padding()
            .background(isSelected ? Color.brandPrimary.opacity(0.3) : Color.gray.opacity(0.2))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.brandPrimary : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    EducationView()
}
