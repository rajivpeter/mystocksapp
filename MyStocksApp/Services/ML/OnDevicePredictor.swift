//
//  OnDevicePredictor.swift
//  MyStocksApp
//
//  Lightweight on-device ML for battery-efficient stock predictions
//  Data stays on phone - no external API calls
//

import Foundation
import CoreML
import Accelerate

/// On-device prediction engine using lightweight algorithms
/// Designed for battery efficiency - only runs during trading hours and on-demand
@Observable
class OnDevicePredictor {
    static let shared = OnDevicePredictor()
    
    private var isModelReady = false
    private var lastPredictionTime: Date?
    
    // Prediction cache to avoid repeated calculations
    private var predictionCache: [String: CachedPrediction] = [:]
    private let cacheExpiry: TimeInterval = 900 // 15 minutes
    
    private init() {}
    
    // MARK: - Battery-Aware Processing
    
    /// Check if we should run predictions (trading hours only)
    var shouldRunPredictions: Bool {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)
        
        // Skip weekends
        if weekday == 1 || weekday == 7 { return false }
        
        // UK market: 8:00 - 16:30 GMT
        // US market: 14:30 - 21:00 GMT (9:30 - 16:00 EST)
        // Combined window: 8:00 - 21:00 GMT
        return hour >= 8 && hour <= 21
    }
    
    // MARK: - Prediction Methods
    
    /// Generate on-device price prediction using technical analysis
    func predictPrice(
        symbol: String,
        historicalPrices: [Double],
        volumes: [Double] = []
    ) -> OnDevicePrediction? {
        guard shouldRunPredictions else {
            print("⏸️ Predictions paused - outside trading hours")
            return nil
        }
        
        // Check cache
        if let cached = predictionCache[symbol],
           Date().timeIntervalSince(cached.timestamp) < cacheExpiry {
            return cached.prediction
        }
        
        guard historicalPrices.count >= 20 else {
            print("⚠️ Insufficient data for prediction")
            return nil
        }
        
        // Run lightweight prediction algorithms
        let prediction = calculatePrediction(
            prices: historicalPrices,
            volumes: volumes
        )
        
        // Cache the result
        predictionCache[symbol] = CachedPrediction(
            prediction: prediction,
            timestamp: Date()
        )
        
        return prediction
    }
    
    /// Detect patterns using on-device rules (no network)
    func detectPatternsOnDevice(candles: [CandleData]) -> [DetectedPatternSimple] {
        var patterns: [DetectedPatternSimple] = []
        
        guard candles.count >= 3 else { return patterns }
        
        // Check last few candles for patterns
        let recent = Array(candles.suffix(5))
        
        // Hammer detection
        if let hammer = detectHammerSimple(recent) {
            patterns.append(hammer)
        }
        
        // Shooting Star detection
        if let shootingStar = detectShootingStarSimple(recent) {
            patterns.append(shootingStar)
        }
        
        // Doji detection
        if let doji = detectDojiSimple(recent) {
            patterns.append(doji)
        }
        
        // Engulfing patterns
        if let engulfing = detectEngulfingSimple(recent) {
            patterns.append(engulfing)
        }
        
        return patterns
    }
    
    // MARK: - Core Prediction Logic (On-Device)
    
    private func calculatePrediction(prices: [Double], volumes: [Double]) -> OnDevicePrediction {
        // 1. Calculate moving averages
        let sma5 = simpleMovingAverage(prices: prices, period: 5)
        let sma20 = simpleMovingAverage(prices: prices, period: 20)
        let ema12 = exponentialMovingAverage(prices: prices, period: 12)
        let ema26 = exponentialMovingAverage(prices: prices, period: 26)
        
        // 2. Calculate RSI
        let rsi = calculateRSI(prices: prices, period: 14)
        
        // 3. Calculate MACD
        let macd = ema12 - ema26
        let signalLine = exponentialMovingAverage(prices: [macd], period: 9)
        
        // 4. Calculate Bollinger Bands position
        let (_, upper, lower) = bollingerBands(prices: prices, period: 20)
        let currentPrice = prices.last ?? 0
        let bbPosition = (currentPrice - lower) / (upper - lower)
        
        // 5. Trend detection
        let trend = detectTrend(prices: prices)
        
        // 6. Momentum
        let momentum = calculateMomentum(prices: prices)
        
        // 7. Combine signals for prediction
        var score = 50.0 // Start neutral
        
        // RSI signals
        if rsi < 30 { score += 15 } // Oversold - bullish
        else if rsi > 70 { score -= 15 } // Overbought - bearish
        else if rsi < 40 { score += 5 }
        else if rsi > 60 { score -= 5 }
        
        // MACD signals
        if macd > signalLine { score += 10 } // Bullish crossover
        else if macd < signalLine { score -= 10 } // Bearish crossover
        
        // Moving average signals
        if sma5 > sma20 { score += 10 } // Bullish trend
        else { score -= 10 }
        
        // Bollinger position
        if bbPosition < 0.2 { score += 10 } // Near lower band - potential bounce
        else if bbPosition > 0.8 { score -= 10 } // Near upper band - potential pullback
        
        // Trend continuation
        if trend == .uptrend { score += 5 }
        else if trend == .downtrend { score -= 5 }
        
        // Momentum
        score += momentum * 10
        
        // Clamp score to 0-100
        score = max(0, min(100, score))
        
        // Determine action
        let action: PredictedAction
        if score >= 70 { action = .buy }
        else if score >= 60 { action = .weakBuy }
        else if score <= 30 { action = .sell }
        else if score <= 40 { action = .weakSell }
        else { action = .hold }
        
        // Calculate predicted price change
        let avgDailyChange = calculateAverageChange(prices: prices)
        let directionMultiplier = score > 50 ? 1.0 : -1.0
        let predictedChange = avgDailyChange * directionMultiplier * (abs(score - 50) / 50)
        
        let predictedPrice1D = currentPrice * (1 + predictedChange)
        let predictedPrice5D = currentPrice * (1 + predictedChange * 3)
        
        return OnDevicePrediction(
            action: action,
            confidence: Int(abs(score - 50) * 2),
            currentPrice: currentPrice,
            predictedPrice1D: predictedPrice1D,
            predictedPrice5D: predictedPrice5D,
            rsi: rsi,
            macdSignal: macd > signalLine ? "Bullish" : "Bearish",
            trend: trend,
            generatedAt: Date()
        )
    }
    
    // MARK: - Technical Indicators (Vectorized for efficiency)
    
    private func simpleMovingAverage(prices: [Double], period: Int) -> Double {
        guard prices.count >= period else { return prices.last ?? 0 }
        let slice = Array(prices.suffix(period))
        return slice.reduce(0, +) / Double(period)
    }
    
    private func exponentialMovingAverage(prices: [Double], period: Int) -> Double {
        guard !prices.isEmpty else { return 0 }
        let multiplier = 2.0 / Double(period + 1)
        var ema = prices[0]
        for price in prices.dropFirst() {
            ema = (price - ema) * multiplier + ema
        }
        return ema
    }
    
    private func calculateRSI(prices: [Double], period: Int) -> Double {
        guard prices.count > period else { return 50 }
        
        var gains: [Double] = []
        var losses: [Double] = []
        
        for i in 1..<prices.count {
            let change = prices[i] - prices[i-1]
            if change > 0 {
                gains.append(change)
                losses.append(0)
            } else {
                gains.append(0)
                losses.append(abs(change))
            }
        }
        
        let recentGains = Array(gains.suffix(period))
        let recentLosses = Array(losses.suffix(period))
        
        let avgGain = recentGains.reduce(0, +) / Double(period)
        let avgLoss = recentLosses.reduce(0, +) / Double(period)
        
        if avgLoss == 0 { return 100 }
        let rs = avgGain / avgLoss
        return 100 - (100 / (1 + rs))
    }
    
    private func bollingerBands(prices: [Double], period: Int) -> (middle: Double, upper: Double, lower: Double) {
        let sma = simpleMovingAverage(prices: prices, period: period)
        let slice = Array(prices.suffix(period))
        
        // Calculate standard deviation
        let variance = slice.map { pow($0 - sma, 2) }.reduce(0, +) / Double(period)
        let stdDev = sqrt(variance)
        
        return (sma, sma + 2 * stdDev, sma - 2 * stdDev)
    }
    
    private func detectTrend(prices: [Double]) -> Trend {
        guard prices.count >= 10 else { return .sideways }
        
        let recent = Array(prices.suffix(10))
        let first5Avg = recent.prefix(5).reduce(0, +) / 5
        let last5Avg = recent.suffix(5).reduce(0, +) / 5
        
        let changePercent = (last5Avg - first5Avg) / first5Avg * 100
        
        if changePercent > 2 { return .uptrend }
        else if changePercent < -2 { return .downtrend }
        else { return .sideways }
    }
    
    private func calculateMomentum(prices: [Double]) -> Double {
        guard prices.count >= 10 else { return 0 }
        let momentum = (prices.last! - prices[prices.count - 10]) / prices[prices.count - 10]
        return max(-1, min(1, momentum * 10))
    }
    
    private func calculateAverageChange(prices: [Double]) -> Double {
        guard prices.count >= 2 else { return 0 }
        var changes: [Double] = []
        for i in 1..<prices.count {
            changes.append(abs(prices[i] - prices[i-1]) / prices[i-1])
        }
        return changes.reduce(0, +) / Double(changes.count)
    }
    
    // MARK: - Simple Pattern Detection
    
    private func detectHammerSimple(_ candles: [CandleData]) -> DetectedPatternSimple? {
        guard let last = candles.last else { return nil }
        
        let body = abs(last.close - last.open)
        let lowerShadow = min(last.open, last.close) - last.low
        let upperShadow = last.high - max(last.open, last.close)
        let range = last.high - last.low
        
        guard range > 0 else { return nil }
        
        if body / range < 0.3 && lowerShadow >= 2 * body && upperShadow < body * 0.5 {
            return DetectedPatternSimple(
                name: "Hammer",
                isBullish: true,
                confidence: 75,
                description: "Bullish reversal signal - buyers rejected lower prices"
            )
        }
        return nil
    }
    
    private func detectShootingStarSimple(_ candles: [CandleData]) -> DetectedPatternSimple? {
        guard let last = candles.last else { return nil }
        
        let body = abs(last.close - last.open)
        let lowerShadow = min(last.open, last.close) - last.low
        let upperShadow = last.high - max(last.open, last.close)
        let range = last.high - last.low
        
        guard range > 0 else { return nil }
        
        if body / range < 0.3 && upperShadow >= 2 * body && lowerShadow < body * 0.5 {
            return DetectedPatternSimple(
                name: "Shooting Star",
                isBullish: false,
                confidence: 75,
                description: "Bearish reversal signal - sellers rejected higher prices"
            )
        }
        return nil
    }
    
    private func detectDojiSimple(_ candles: [CandleData]) -> DetectedPatternSimple? {
        guard let last = candles.last else { return nil }
        
        let body = abs(last.close - last.open)
        let range = last.high - last.low
        
        guard range > 0 else { return nil }
        
        if body / range < 0.1 {
            return DetectedPatternSimple(
                name: "Doji",
                isBullish: false, // Neutral
                confidence: 60,
                description: "Market indecision - wait for confirmation"
            )
        }
        return nil
    }
    
    private func detectEngulfingSimple(_ candles: [CandleData]) -> DetectedPatternSimple? {
        guard candles.count >= 2 else { return nil }
        
        let prev = candles[candles.count - 2]
        let curr = candles[candles.count - 1]
        
        let prevIsBearish = prev.close < prev.open
        let currIsBullish = curr.close > curr.open
        
        if prevIsBearish && currIsBullish &&
           curr.open < prev.close && curr.close > prev.open {
            return DetectedPatternSimple(
                name: "Bullish Engulfing",
                isBullish: true,
                confidence: 80,
                description: "Strong bullish reversal - buyers took control"
            )
        }
        
        let prevIsBullish = prev.close > prev.open
        let currIsBearish = curr.close < curr.open
        
        if prevIsBullish && currIsBearish &&
           curr.open > prev.close && curr.close < prev.open {
            return DetectedPatternSimple(
                name: "Bearish Engulfing",
                isBullish: false,
                confidence: 80,
                description: "Strong bearish reversal - sellers took control"
            )
        }
        
        return nil
    }
    
    // MARK: - Cache Cleanup
    
    func clearCache() {
        predictionCache.removeAll()
    }
}

// MARK: - Models

struct OnDevicePrediction {
    let action: PredictedAction
    let confidence: Int
    let currentPrice: Double
    let predictedPrice1D: Double
    let predictedPrice5D: Double
    let rsi: Double
    let macdSignal: String
    let trend: Trend
    let generatedAt: Date
    
    var predictedChange1D: Double {
        (predictedPrice1D - currentPrice) / currentPrice * 100
    }
    
    var predictedChange5D: Double {
        (predictedPrice5D - currentPrice) / currentPrice * 100
    }
}

enum PredictedAction: String {
    case buy = "Buy"
    case weakBuy = "Weak Buy"
    case hold = "Hold"
    case weakSell = "Weak Sell"
    case sell = "Sell"
    
    var emoji: String {
        switch self {
        case .buy: return "🚀"
        case .weakBuy: return "📈"
        case .hold: return "⏸️"
        case .weakSell: return "📉"
        case .sell: return "🔴"
        }
    }
    
    var colorName: String {
        switch self {
        case .buy, .weakBuy: return "green"
        case .hold: return "orange"
        case .sell, .weakSell: return "red"
        }
    }
}

enum Trend: String {
    case uptrend = "Uptrend"
    case downtrend = "Downtrend"
    case sideways = "Sideways"
}

struct CandleData {
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
}

struct DetectedPatternSimple {
    let name: String
    let isBullish: Bool
    let confidence: Int
    let description: String
}

struct CachedPrediction {
    let prediction: OnDevicePrediction
    let timestamp: Date
}
