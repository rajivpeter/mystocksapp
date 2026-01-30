//
//  ChartPattern.swift
//  MyStocksApp
//
//  Chart pattern models for technical analysis and education
//

import Foundation
import SwiftData

@Model
final class ChartPattern {
    // MARK: - Identifiers
    @Attribute(.unique) var id: UUID
    var name: String
    var category: PatternCategory
    var type: PatternType
    
    // MARK: - Detection
    var symbol: String?
    var detectedAt: Date?
    var confidence: Int // 0-100
    var priceAtDetection: Double?
    
    // MARK: - Pattern Details
    var patternDescription: String
    var bullishImplication: String
    var bearishImplication: String
    var reliability: PatternReliability
    var timeframe: String // e.g., "1D", "4H", "1W"
    
    // MARK: - Trading Guidance
    var entryStrategy: String
    var targetCalculation: String
    var stopLossStrategy: String
    var expectedMove: Double? // Expected % move
    
    // MARK: - Visual
    var iconName: String
    var exampleImageData: Data?
    
    // MARK: - Educational Content
    var lessonContent: String?
    var keyCharacteristics: [String]
    var commonMistakes: [String]
    var realWorldExamples: [String]
    
    // MARK: - Computed Properties
    var isBullish: Bool {
        type == .bullishReversal || type == .bullishContinuation
    }
    
    var isBearish: Bool {
        type == .bearishReversal || type == .bearishContinuation
    }
    
    var reliabilityStars: String {
        switch reliability {
        case .veryHigh: return "⭐⭐⭐⭐⭐"
        case .high: return "⭐⭐⭐⭐"
        case .moderate: return "⭐⭐⭐"
        case .low: return "⭐⭐"
        case .veryLow: return "⭐"
        }
    }
    
    var signalEmoji: String {
        if isBullish {
            return "🟢"
        } else if isBearish {
            return "🔴"
        } else {
            return "🟡"
        }
    }
    
    // MARK: - Initializer
    init(
        name: String,
        category: PatternCategory,
        type: PatternType,
        description: String,
        reliability: PatternReliability = .moderate
    ) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.type = type
        self.patternDescription = description
        self.bullishImplication = ""
        self.bearishImplication = ""
        self.reliability = reliability
        self.timeframe = "1D"
        self.entryStrategy = ""
        self.targetCalculation = ""
        self.stopLossStrategy = ""
        self.iconName = "chart.bar.fill"
        self.confidence = 0
        self.keyCharacteristics = []
        self.commonMistakes = []
        self.realWorldExamples = []
    }
}

// MARK: - Pattern Category
enum PatternCategory: String, Codable, CaseIterable {
    case candlestick = "Candlestick"
    case chart = "Chart"
    case harmonic = "Harmonic"
    case volumePrice = "Volume-Price"
    
    var icon: String {
        switch self {
        case .candlestick: return "chart.bar.doc.horizontal"
        case .chart: return "chart.xyaxis.line"
        case .harmonic: return "waveform.path.ecg"
        case .volumePrice: return "chart.bar.fill"
        }
    }
}

// MARK: - Pattern Type
enum PatternType: String, Codable, CaseIterable {
    case bullishReversal = "Bullish Reversal"
    case bearishReversal = "Bearish Reversal"
    case bullishContinuation = "Bullish Continuation"
    case bearishContinuation = "Bearish Continuation"
    case neutral = "Neutral"
    case indecision = "Indecision"
    
    var color: String {
        switch self {
        case .bullishReversal, .bullishContinuation:
            return "green"
        case .bearishReversal, .bearishContinuation:
            return "red"
        case .neutral, .indecision:
            return "gray"
        }
    }
}

// MARK: - Pattern Reliability
enum PatternReliability: String, Codable, CaseIterable {
    case veryHigh = "Very High"
    case high = "High"
    case moderate = "Moderate"
    case low = "Low"
    case veryLow = "Very Low"
    
    var successRate: String {
        switch self {
        case .veryHigh: return "80%+"
        case .high: return "70-80%"
        case .moderate: return "55-70%"
        case .low: return "45-55%"
        case .veryLow: return "<45%"
        }
    }
}

// MARK: - Prediction Model
@Model
final class Prediction {
    @Attribute(.unique) var id: UUID
    var stock: Stock?
    var symbol: String
    
    // Prediction Details
    var predictedPrice1D: Double?
    var predictedPrice5D: Double?
    var predictedPrice30D: Double?
    var confidence: Double // 0-1
    
    // Model Info
    var modelVersion: String
    var features: [String]
    var generatedAt: Date
    
    // Accuracy Tracking
    var actualPrice1D: Double?
    var actualPrice5D: Double?
    var actualPrice30D: Double?
    var accuracy1D: Double?
    var accuracy5D: Double?
    var accuracy30D: Double?
    
    var formattedConfidence: String {
        "\(Int(confidence * 100))%"
    }
    
    var predictedChange1D: Double? {
        guard let current = stock?.currentPrice, let predicted = predictedPrice1D else { return nil }
        return ((predicted - current) / current) * 100
    }
    
    init(symbol: String, stock: Stock? = nil) {
        self.id = UUID()
        self.symbol = symbol
        self.stock = stock
        self.confidence = 0
        self.modelVersion = "1.0"
        self.features = []
        self.generatedAt = Date()
    }
}

// MARK: - Candlestick Pattern Library
struct PatternLibrary {
    static let allPatterns: [PatternDefinition] = [
        // Bullish Reversal Patterns
        PatternDefinition(
            name: "Hammer",
            category: .candlestick,
            type: .bullishReversal,
            description: "A single candle pattern with a small body at the top and a long lower shadow (at least 2x the body). Indicates potential reversal from a downtrend.",
            reliability: .high,
            keyCharacteristics: [
                "Small real body at the upper end of trading range",
                "Long lower shadow (2-3x body length)",
                "Little or no upper shadow",
                "Appears after a downtrend"
            ],
            entryStrategy: "Enter long above the hammer's high with confirmation",
            targetCalculation: "Measure the hammer's range and project upward",
            stopLoss: "Place stop below the hammer's low"
        ),
        PatternDefinition(
            name: "Morning Star",
            category: .candlestick,
            type: .bullishReversal,
            description: "A three-candle pattern: bearish candle, small-bodied candle (star), and bullish candle. Strong reversal signal at the end of a downtrend.",
            reliability: .veryHigh,
            keyCharacteristics: [
                "First candle: Large bearish candle in downtrend",
                "Second candle: Small body that gaps down",
                "Third candle: Large bullish candle closing into first candle's body"
            ],
            entryStrategy: "Enter long after the third candle closes",
            targetCalculation: "Target previous resistance or 1:2 risk-reward",
            stopLoss: "Below the low of the star candle"
        ),
        PatternDefinition(
            name: "Bullish Engulfing",
            category: .candlestick,
            type: .bullishReversal,
            description: "A two-candle pattern where a bullish candle completely engulfs the previous bearish candle. Strong reversal signal.",
            reliability: .high,
            keyCharacteristics: [
                "First candle: Bearish candle in downtrend",
                "Second candle: Bullish candle that opens below and closes above first candle",
                "Second candle's body completely covers first candle's body"
            ],
            entryStrategy: "Enter long above the engulfing candle's high",
            targetCalculation: "Project the engulfing candle's range upward",
            stopLoss: "Below the engulfing pattern's low"
        ),
        PatternDefinition(
            name: "Piercing Line",
            category: .candlestick,
            type: .bullishReversal,
            description: "A two-candle pattern where a bullish candle opens below the prior low and closes above the midpoint of the previous bearish candle.",
            reliability: .moderate,
            keyCharacteristics: [
                "First candle: Strong bearish candle",
                "Second candle: Opens below first candle's low",
                "Second candle: Closes above midpoint of first candle's body"
            ],
            entryStrategy: "Enter long above the second candle's high",
            targetCalculation: "Target previous resistance levels",
            stopLoss: "Below the pattern's low"
        ),
        PatternDefinition(
            name: "Dragonfly Doji",
            category: .candlestick,
            type: .bullishReversal,
            description: "A doji with a long lower shadow and no upper shadow. Open, high, and close are at the same level. Bullish when appearing after a downtrend.",
            reliability: .moderate,
            keyCharacteristics: [
                "Open, high, and close at same price",
                "Long lower shadow",
                "No upper shadow",
                "T-shaped appearance"
            ],
            entryStrategy: "Wait for bullish confirmation candle",
            targetCalculation: "Target nearby resistance",
            stopLoss: "Below the dragonfly's low"
        ),
        
        // Bearish Reversal Patterns
        PatternDefinition(
            name: "Shooting Star",
            category: .candlestick,
            type: .bearishReversal,
            description: "A single candle pattern with a small body at the bottom and a long upper shadow. Indicates potential reversal from an uptrend.",
            reliability: .high,
            keyCharacteristics: [
                "Small real body at the lower end",
                "Long upper shadow (2-3x body)",
                "Little or no lower shadow",
                "Appears after an uptrend"
            ],
            entryStrategy: "Enter short below the shooting star's low",
            targetCalculation: "Measure pattern range and project downward",
            stopLoss: "Above the shooting star's high"
        ),
        PatternDefinition(
            name: "Evening Star",
            category: .candlestick,
            type: .bearishReversal,
            description: "A three-candle pattern: bullish candle, small-bodied star, and bearish candle. Strong reversal signal at the end of an uptrend.",
            reliability: .veryHigh,
            keyCharacteristics: [
                "First candle: Large bullish candle in uptrend",
                "Second candle: Small body that gaps up",
                "Third candle: Large bearish candle closing into first candle's body"
            ],
            entryStrategy: "Enter short after the third candle closes",
            targetCalculation: "Target previous support or 1:2 risk-reward",
            stopLoss: "Above the high of the star candle"
        ),
        PatternDefinition(
            name: "Bearish Engulfing",
            category: .candlestick,
            type: .bearishReversal,
            description: "A two-candle pattern where a bearish candle completely engulfs the previous bullish candle. Strong reversal signal.",
            reliability: .high,
            keyCharacteristics: [
                "First candle: Bullish candle in uptrend",
                "Second candle: Bearish candle that opens above and closes below first candle",
                "Second candle's body completely covers first candle's body"
            ],
            entryStrategy: "Enter short below the engulfing candle's low",
            targetCalculation: "Project the engulfing candle's range downward",
            stopLoss: "Above the engulfing pattern's high"
        ),
        PatternDefinition(
            name: "Dark Cloud Cover",
            category: .candlestick,
            type: .bearishReversal,
            description: "A two-candle pattern where a bearish candle opens above the prior high and closes below the midpoint of the previous bullish candle.",
            reliability: .moderate,
            keyCharacteristics: [
                "First candle: Strong bullish candle",
                "Second candle: Opens above first candle's high",
                "Second candle: Closes below midpoint of first candle's body"
            ],
            entryStrategy: "Enter short below the second candle's low",
            targetCalculation: "Target previous support levels",
            stopLoss: "Above the pattern's high"
        ),
        PatternDefinition(
            name: "Gravestone Doji",
            category: .candlestick,
            type: .bearishReversal,
            description: "A doji with a long upper shadow and no lower shadow. Open, low, and close are at the same level. Bearish when appearing after an uptrend.",
            reliability: .moderate,
            keyCharacteristics: [
                "Open, low, and close at same price",
                "Long upper shadow",
                "No lower shadow",
                "Inverted T-shape"
            ],
            entryStrategy: "Wait for bearish confirmation candle",
            targetCalculation: "Target nearby support",
            stopLoss: "Above the gravestone's high"
        ),
        
        // Continuation Patterns
        PatternDefinition(
            name: "Three White Soldiers",
            category: .candlestick,
            type: .bullishContinuation,
            description: "Three consecutive long bullish candles, each opening within the previous body and closing near its high.",
            reliability: .high,
            keyCharacteristics: [
                "Three consecutive bullish candles",
                "Each candle opens within previous candle's body",
                "Each candle closes near its high",
                "Progressive higher closes"
            ],
            entryStrategy: "Enter long after the pattern completes",
            targetCalculation: "Use momentum to ride the trend",
            stopLoss: "Below the first soldier's low"
        ),
        PatternDefinition(
            name: "Three Black Crows",
            category: .candlestick,
            type: .bearishContinuation,
            description: "Three consecutive long bearish candles, each opening within the previous body and closing near its low.",
            reliability: .high,
            keyCharacteristics: [
                "Three consecutive bearish candles",
                "Each candle opens within previous candle's body",
                "Each candle closes near its low",
                "Progressive lower closes"
            ],
            entryStrategy: "Enter short after the pattern completes",
            targetCalculation: "Use momentum to ride the trend",
            stopLoss: "Above the first crow's high"
        ),
        
        // Indecision Patterns
        PatternDefinition(
            name: "Doji",
            category: .candlestick,
            type: .indecision,
            description: "A candle where open and close are virtually equal, creating a cross shape. Signals market indecision.",
            reliability: .low,
            keyCharacteristics: [
                "Open and close at virtually same price",
                "Can have upper and lower shadows",
                "Cross or plus sign shape",
                "Indicates balance between buyers and sellers"
            ],
            entryStrategy: "Wait for next candle for direction confirmation",
            targetCalculation: "Depends on confirmation direction",
            stopLoss: "Beyond the doji's range"
        ),
        PatternDefinition(
            name: "Spinning Top",
            category: .candlestick,
            type: .indecision,
            description: "A candle with a small body and upper/lower shadows of similar length. Indicates market uncertainty.",
            reliability: .low,
            keyCharacteristics: [
                "Small real body",
                "Upper and lower shadows of similar length",
                "Shows market indecision",
                "Neither bulls nor bears in control"
            ],
            entryStrategy: "Wait for breakout from the range",
            targetCalculation: "Based on breakout direction",
            stopLoss: "Opposite side of the range"
        )
    ]
}

// MARK: - Pattern Definition (for library)
struct PatternDefinition: Identifiable {
    let id = UUID()
    let name: String
    let category: PatternCategory
    let type: PatternType
    let description: String
    let reliability: PatternReliability
    let keyCharacteristics: [String]
    let entryStrategy: String
    let targetCalculation: String
    let stopLoss: String
    
    init(
        name: String,
        category: PatternCategory,
        type: PatternType,
        description: String,
        reliability: PatternReliability,
        keyCharacteristics: [String] = [],
        entryStrategy: String = "",
        targetCalculation: String = "",
        stopLoss: String = ""
    ) {
        self.name = name
        self.category = category
        self.type = type
        self.description = description
        self.reliability = reliability
        self.keyCharacteristics = keyCharacteristics
        self.entryStrategy = entryStrategy
        self.targetCalculation = targetCalculation
        self.stopLoss = stopLoss
    }
}
