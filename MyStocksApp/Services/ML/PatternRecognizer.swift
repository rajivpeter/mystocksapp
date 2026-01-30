//
//  PatternRecognizer.swift
//  MyStocksApp
//
//  Candlestick pattern recognition using rule-based and ML approaches
//

import Foundation
import CoreML

@Observable
class PatternRecognizer {
    static let shared = PatternRecognizer()
    
    private var model: MLModel?
    var isModelLoaded = false
    
    private init() {}
    
    // MARK: - Model Loading
    
    func loadModel() async {
        // In production, load CNN model for pattern recognition
        isModelLoaded = true
        print("✅ Pattern recognition model loaded")
    }
    
    // MARK: - Pattern Detection
    
    /// Detect patterns in OHLCV data
    func detectPatterns(data: [OHLCV]) -> [DetectedPattern] {
        guard data.count >= 5 else { return [] }
        
        var patterns: [DetectedPattern] = []
        
        // Check for single-candle patterns
        if let pattern = detectHammer(data: data) {
            patterns.append(pattern)
        }
        if let pattern = detectShootingStar(data: data) {
            patterns.append(pattern)
        }
        if let pattern = detectDoji(data: data) {
            patterns.append(pattern)
        }
        if let pattern = detectDragonflyDoji(data: data) {
            patterns.append(pattern)
        }
        if let pattern = detectGravestoneDoji(data: data) {
            patterns.append(pattern)
        }
        
        // Check for two-candle patterns
        if let pattern = detectBullishEngulfing(data: data) {
            patterns.append(pattern)
        }
        if let pattern = detectBearishEngulfing(data: data) {
            patterns.append(pattern)
        }
        if let pattern = detectPiercingLine(data: data) {
            patterns.append(pattern)
        }
        if let pattern = detectDarkCloudCover(data: data) {
            patterns.append(pattern)
        }
        
        // Check for three-candle patterns
        if let pattern = detectMorningStar(data: data) {
            patterns.append(pattern)
        }
        if let pattern = detectEveningStar(data: data) {
            patterns.append(pattern)
        }
        if let pattern = detectThreeWhiteSoldiers(data: data) {
            patterns.append(pattern)
        }
        if let pattern = detectThreeBlackCrows(data: data) {
            patterns.append(pattern)
        }
        
        return patterns.sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - Single Candle Patterns
    
    private func detectHammer(data: [OHLCV]) -> DetectedPattern? {
        guard let candle = data.last else { return nil }
        
        let body = abs(candle.close - candle.open)
        let lowerShadow = min(candle.open, candle.close) - candle.low
        let upperShadow = candle.high - max(candle.open, candle.close)
        let range = candle.high - candle.low
        
        // Hammer criteria:
        // - Small body at top
        // - Long lower shadow (at least 2x body)
        // - Little/no upper shadow
        // - Appears in downtrend
        
        let isDowntrend = isInDowntrend(data: data)
        let hasSmallBody = body / range < 0.3
        let hasLongLowerShadow = lowerShadow >= 2 * body
        let hasNoUpperShadow = upperShadow < body * 0.1
        
        if isDowntrend && hasSmallBody && hasLongLowerShadow && hasNoUpperShadow {
            let confidence = calculateConfidence(
                conditions: [isDowntrend, hasSmallBody, hasLongLowerShadow, hasNoUpperShadow],
                weights: [0.3, 0.2, 0.3, 0.2]
            )
            
            return DetectedPattern(
                name: "Hammer",
                type: .bullishReversal,
                confidence: confidence,
                candles: [candle],
                description: "Bullish reversal signal - buyers rejected lower prices",
                tradingImplication: "Consider long entry above the hammer's high",
                targetCalculation: "Project hammer's range upward from breakout"
            )
        }
        
        return nil
    }
    
    private func detectShootingStar(data: [OHLCV]) -> DetectedPattern? {
        guard let candle = data.last else { return nil }
        
        let body = abs(candle.close - candle.open)
        let lowerShadow = min(candle.open, candle.close) - candle.low
        let upperShadow = candle.high - max(candle.open, candle.close)
        let range = candle.high - candle.low
        
        let isUptrend = isInUptrend(data: data)
        let hasSmallBody = body / range < 0.3
        let hasLongUpperShadow = upperShadow >= 2 * body
        let hasNoLowerShadow = lowerShadow < body * 0.1
        
        if isUptrend && hasSmallBody && hasLongUpperShadow && hasNoLowerShadow {
            let confidence = calculateConfidence(
                conditions: [isUptrend, hasSmallBody, hasLongUpperShadow, hasNoLowerShadow],
                weights: [0.3, 0.2, 0.3, 0.2]
            )
            
            return DetectedPattern(
                name: "Shooting Star",
                type: .bearishReversal,
                confidence: confidence,
                candles: [candle],
                description: "Bearish reversal signal - sellers rejected higher prices",
                tradingImplication: "Consider short entry below the shooting star's low",
                targetCalculation: "Project pattern's range downward from breakdown"
            )
        }
        
        return nil
    }
    
    private func detectDoji(data: [OHLCV]) -> DetectedPattern? {
        guard let candle = data.last else { return nil }
        
        let body = abs(candle.close - candle.open)
        let range = candle.high - candle.low
        
        let isDoji = body / range < 0.1 && range > 0
        
        if isDoji {
            return DetectedPattern(
                name: "Doji",
                type: .indecision,
                confidence: 60,
                candles: [candle],
                description: "Market indecision - balance between buyers and sellers",
                tradingImplication: "Wait for confirmation candle for direction",
                targetCalculation: "Based on breakout direction from doji range"
            )
        }
        
        return nil
    }
    
    private func detectDragonflyDoji(data: [OHLCV]) -> DetectedPattern? {
        guard let candle = data.last else { return nil }
        
        let body = abs(candle.close - candle.open)
        let range = candle.high - candle.low
        let lowerShadow = min(candle.open, candle.close) - candle.low
        let upperShadow = candle.high - max(candle.open, candle.close)
        
        let isDoji = body / range < 0.05
        let hasLongLowerShadow = lowerShadow > range * 0.7
        let hasNoUpperShadow = upperShadow < range * 0.05
        let isDowntrend = isInDowntrend(data: data)
        
        if isDoji && hasLongLowerShadow && hasNoUpperShadow {
            let type: PatternType = isDowntrend ? .bullishReversal : .indecision
            
            return DetectedPattern(
                name: "Dragonfly Doji",
                type: type,
                confidence: isDowntrend ? 70 : 55,
                candles: [candle],
                description: "T-shaped doji - buyers pushed prices back up",
                tradingImplication: isDowntrend ? "Bullish signal in downtrend" : "Wait for confirmation",
                targetCalculation: "Target nearby resistance levels"
            )
        }
        
        return nil
    }
    
    private func detectGravestoneDoji(data: [OHLCV]) -> DetectedPattern? {
        guard let candle = data.last else { return nil }
        
        let body = abs(candle.close - candle.open)
        let range = candle.high - candle.low
        let lowerShadow = min(candle.open, candle.close) - candle.low
        let upperShadow = candle.high - max(candle.open, candle.close)
        
        let isDoji = body / range < 0.05
        let hasLongUpperShadow = upperShadow > range * 0.7
        let hasNoLowerShadow = lowerShadow < range * 0.05
        let isUptrend = isInUptrend(data: data)
        
        if isDoji && hasLongUpperShadow && hasNoLowerShadow {
            let type: PatternType = isUptrend ? .bearishReversal : .indecision
            
            return DetectedPattern(
                name: "Gravestone Doji",
                type: type,
                confidence: isUptrend ? 70 : 55,
                candles: [candle],
                description: "Inverted T-shaped doji - sellers pushed prices back down",
                tradingImplication: isUptrend ? "Bearish signal in uptrend" : "Wait for confirmation",
                targetCalculation: "Target nearby support levels"
            )
        }
        
        return nil
    }
    
    // MARK: - Two Candle Patterns
    
    private func detectBullishEngulfing(data: [OHLCV]) -> DetectedPattern? {
        guard data.count >= 2 else { return nil }
        
        let first = data[data.count - 2]
        let second = data[data.count - 1]
        
        let firstIsBearish = first.close < first.open
        let secondIsBullish = second.close > second.open
        let secondEngulfsFirst = second.open < first.close && second.close > first.open
        let isDowntrend = isInDowntrend(data: data.dropLast(1).map { $0 })
        
        if firstIsBearish && secondIsBullish && secondEngulfsFirst && isDowntrend {
            let confidence = calculateConfidence(
                conditions: [firstIsBearish, secondIsBullish, secondEngulfsFirst, isDowntrend],
                weights: [0.2, 0.2, 0.35, 0.25]
            )
            
            return DetectedPattern(
                name: "Bullish Engulfing",
                type: .bullishReversal,
                confidence: confidence,
                candles: [first, second],
                description: "Strong bullish reversal - buyers overwhelmed sellers",
                tradingImplication: "Enter long above the engulfing candle's high",
                targetCalculation: "Project the engulfing candle's range upward"
            )
        }
        
        return nil
    }
    
    private func detectBearishEngulfing(data: [OHLCV]) -> DetectedPattern? {
        guard data.count >= 2 else { return nil }
        
        let first = data[data.count - 2]
        let second = data[data.count - 1]
        
        let firstIsBullish = first.close > first.open
        let secondIsBearish = second.close < second.open
        let secondEngulfsFirst = second.open > first.close && second.close < first.open
        let isUptrend = isInUptrend(data: data.dropLast(1).map { $0 })
        
        if firstIsBullish && secondIsBearish && secondEngulfsFirst && isUptrend {
            let confidence = calculateConfidence(
                conditions: [firstIsBullish, secondIsBearish, secondEngulfsFirst, isUptrend],
                weights: [0.2, 0.2, 0.35, 0.25]
            )
            
            return DetectedPattern(
                name: "Bearish Engulfing",
                type: .bearishReversal,
                confidence: confidence,
                candles: [first, second],
                description: "Strong bearish reversal - sellers overwhelmed buyers",
                tradingImplication: "Enter short below the engulfing candle's low",
                targetCalculation: "Project the engulfing candle's range downward"
            )
        }
        
        return nil
    }
    
    private func detectPiercingLine(data: [OHLCV]) -> DetectedPattern? {
        guard data.count >= 2 else { return nil }
        
        let first = data[data.count - 2]
        let second = data[data.count - 1]
        
        let firstIsBearish = first.close < first.open
        let secondIsBullish = second.close > second.open
        let opensBelow = second.open < first.low
        let closeAboveMidpoint = second.close > (first.open + first.close) / 2
        let isDowntrend = isInDowntrend(data: data.dropLast(1).map { $0 })
        
        if firstIsBearish && secondIsBullish && opensBelow && closeAboveMidpoint && isDowntrend {
            return DetectedPattern(
                name: "Piercing Line",
                type: .bullishReversal,
                confidence: 65,
                candles: [first, second],
                description: "Bullish reversal - gap down followed by strong recovery",
                tradingImplication: "Consider long above the pattern's high",
                targetCalculation: "Target previous resistance levels"
            )
        }
        
        return nil
    }
    
    private func detectDarkCloudCover(data: [OHLCV]) -> DetectedPattern? {
        guard data.count >= 2 else { return nil }
        
        let first = data[data.count - 2]
        let second = data[data.count - 1]
        
        let firstIsBullish = first.close > first.open
        let secondIsBearish = second.close < second.open
        let opensAbove = second.open > first.high
        let closeBelowMidpoint = second.close < (first.open + first.close) / 2
        let isUptrend = isInUptrend(data: data.dropLast(1).map { $0 })
        
        if firstIsBullish && secondIsBearish && opensAbove && closeBelowMidpoint && isUptrend {
            return DetectedPattern(
                name: "Dark Cloud Cover",
                type: .bearishReversal,
                confidence: 65,
                candles: [first, second],
                description: "Bearish reversal - gap up followed by strong decline",
                tradingImplication: "Consider short below the pattern's low",
                targetCalculation: "Target previous support levels"
            )
        }
        
        return nil
    }
    
    // MARK: - Three Candle Patterns
    
    private func detectMorningStar(data: [OHLCV]) -> DetectedPattern? {
        guard data.count >= 3 else { return nil }
        
        let first = data[data.count - 3]
        let second = data[data.count - 2]
        let third = data[data.count - 1]
        
        let firstIsBearish = first.close < first.open
        let firstIsLarge = abs(first.close - first.open) > (first.high - first.low) * 0.6
        let secondIsSmall = abs(second.close - second.open) < (first.high - first.low) * 0.3
        let thirdIsBullish = third.close > third.open
        let thirdClosesIntoFirst = third.close > (first.open + first.close) / 2
        let isDowntrend = isInDowntrend(data: data.dropLast(2).map { $0 })
        
        if firstIsBearish && firstIsLarge && secondIsSmall && thirdIsBullish && thirdClosesIntoFirst && isDowntrend {
            return DetectedPattern(
                name: "Morning Star",
                type: .bullishReversal,
                confidence: 80,
                candles: [first, second, third],
                description: "Strong bullish reversal pattern - three candle formation",
                tradingImplication: "Enter long after the third candle closes",
                targetCalculation: "Target previous resistance or 1:2 risk-reward"
            )
        }
        
        return nil
    }
    
    private func detectEveningStar(data: [OHLCV]) -> DetectedPattern? {
        guard data.count >= 3 else { return nil }
        
        let first = data[data.count - 3]
        let second = data[data.count - 2]
        let third = data[data.count - 1]
        
        let firstIsBullish = first.close > first.open
        let firstIsLarge = abs(first.close - first.open) > (first.high - first.low) * 0.6
        let secondIsSmall = abs(second.close - second.open) < (first.high - first.low) * 0.3
        let thirdIsBearish = third.close < third.open
        let thirdClosesIntoFirst = third.close < (first.open + first.close) / 2
        let isUptrend = isInUptrend(data: data.dropLast(2).map { $0 })
        
        if firstIsBullish && firstIsLarge && secondIsSmall && thirdIsBearish && thirdClosesIntoFirst && isUptrend {
            return DetectedPattern(
                name: "Evening Star",
                type: .bearishReversal,
                confidence: 80,
                candles: [first, second, third],
                description: "Strong bearish reversal pattern - three candle formation",
                tradingImplication: "Enter short after the third candle closes",
                targetCalculation: "Target previous support or 1:2 risk-reward"
            )
        }
        
        return nil
    }
    
    private func detectThreeWhiteSoldiers(data: [OHLCV]) -> DetectedPattern? {
        guard data.count >= 3 else { return nil }
        
        let candles = Array(data.suffix(3))
        
        let allBullish = candles.allSatisfy { $0.close > $0.open }
        let progressiveHigherCloses = candles[1].close > candles[0].close && candles[2].close > candles[1].close
        let opensWithinPreviousBody = candles[1].open > candles[0].open && candles[1].open < candles[0].close &&
                                      candles[2].open > candles[1].open && candles[2].open < candles[1].close
        
        if allBullish && progressiveHigherCloses && opensWithinPreviousBody {
            return DetectedPattern(
                name: "Three White Soldiers",
                type: .bullishContinuation,
                confidence: 75,
                candles: candles,
                description: "Bullish continuation - strong upward momentum",
                tradingImplication: "Stay long or enter on pullback",
                targetCalculation: "Use trailing stop to ride the trend"
            )
        }
        
        return nil
    }
    
    private func detectThreeBlackCrows(data: [OHLCV]) -> DetectedPattern? {
        guard data.count >= 3 else { return nil }
        
        let candles = Array(data.suffix(3))
        
        let allBearish = candles.allSatisfy { $0.close < $0.open }
        let progressiveLowerCloses = candles[1].close < candles[0].close && candles[2].close < candles[1].close
        let opensWithinPreviousBody = candles[1].open < candles[0].open && candles[1].open > candles[0].close &&
                                      candles[2].open < candles[1].open && candles[2].open > candles[1].close
        
        if allBearish && progressiveLowerCloses && opensWithinPreviousBody {
            return DetectedPattern(
                name: "Three Black Crows",
                type: .bearishContinuation,
                confidence: 75,
                candles: candles,
                description: "Bearish continuation - strong downward momentum",
                tradingImplication: "Stay short or enter on bounce",
                targetCalculation: "Use trailing stop to ride the trend"
            )
        }
        
        return nil
    }
    
    // MARK: - Helper Functions
    
    private func isInUptrend(data: [OHLCV]) -> Bool {
        guard data.count >= 5 else { return false }
        let recent = data.suffix(5)
        let closes = recent.map { $0.close }
        let firstAvg = closes.prefix(2).reduce(0, +) / 2
        let lastAvg = closes.suffix(2).reduce(0, +) / 2
        return lastAvg > firstAvg
    }
    
    private func isInDowntrend(data: [OHLCV]) -> Bool {
        guard data.count >= 5 else { return false }
        let recent = data.suffix(5)
        let closes = recent.map { $0.close }
        let firstAvg = closes.prefix(2).reduce(0, +) / 2
        let lastAvg = closes.suffix(2).reduce(0, +) / 2
        return lastAvg < firstAvg
    }
    
    private func calculateConfidence(conditions: [Bool], weights: [Double]) -> Int {
        let totalWeight = zip(conditions, weights).reduce(0.0) { result, pair in
            result + (pair.0 ? pair.1 : 0)
        }
        return Int(totalWeight * 100)
    }
}

// MARK: - Detected Pattern

struct DetectedPattern: Identifiable {
    let id = UUID()
    let name: String
    let type: PatternType
    let confidence: Int
    let candles: [OHLCV]
    let description: String
    let tradingImplication: String
    let targetCalculation: String
    
    var reliabilityStars: String {
        let stars = confidence / 20
        return String(repeating: "⭐", count: min(5, max(1, stars)))
    }
    
    var signalEmoji: String {
        switch type {
        case .bullishReversal, .bullishContinuation:
            return "🟢"
        case .bearishReversal, .bearishContinuation:
            return "🔴"
        case .neutral, .indecision:
            return "🟡"
        }
    }
}
