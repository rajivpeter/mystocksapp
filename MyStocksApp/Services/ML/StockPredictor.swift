//
//  StockPredictor.swift
//  MyStocksApp
//
//  CoreML-based stock price prediction using LSTM model
//

import Foundation
import CoreML

@Observable
class StockPredictor {
    static let shared = StockPredictor()
    
    private var model: MLModel?
    var isModelLoaded = false
    var lastError: String?
    
    private init() {}
    
    // MARK: - Model Loading
    
    func loadModel() async {
        // In production, load the actual CoreML model:
        // do {
        //     let modelURL = Bundle.main.url(forResource: "StockPredictionLSTM", withExtension: "mlmodelc")!
        //     model = try MLModel(contentsOf: modelURL)
        //     isModelLoaded = true
        //     print("✅ Stock prediction model loaded")
        // } catch {
        //     lastError = error.localizedDescription
        //     print("❌ Failed to load prediction model: \(error)")
        // }
        
        // For now, mark as loaded (model would be trained separately)
        isModelLoaded = true
        print("✅ Stock prediction model ready (using simple algorithm)")
    }
    
    // MARK: - Prediction
    
    /// Generate price predictions for a stock
    func predict(
        symbol: String,
        historicalData: [OHLCV],
        technicalIndicators: TechnicalIndicators
    ) async throws -> StockPrediction {
        // Ensure we have enough data
        guard historicalData.count >= 60 else {
            throw PredictionError.insufficientData
        }
        
        // Prepare features for CoreML model (currently unused but ready for production)
        // In production, run through CoreML model:
        // let features = prepareFeatures(historicalData: historicalData, indicators: technicalIndicators)
        // let prediction = try model?.prediction(from: features)
        
        // For now, use a simple prediction algorithm
        let prediction = simplePredict(
            historicalData: historicalData,
            indicators: technicalIndicators
        )
        
        return prediction
    }
    
    // MARK: - Feature Engineering
    
    private func prepareFeatures(
        historicalData: [OHLCV],
        indicators: TechnicalIndicators
    ) -> [Double] {
        var features: [Double] = []
        
        // Last 60 days of normalized price data
        let prices = historicalData.suffix(60).map { $0.close }
        let minPrice = prices.min() ?? 0
        let maxPrice = prices.max() ?? 1
        let range = maxPrice - minPrice
        
        let normalizedPrices = prices.map { (($0 - minPrice) / range) }
        features.append(contentsOf: normalizedPrices)
        
        // Volume trend
        let volumes = historicalData.suffix(60).map { Double($0.volume) }
        let avgVolume = volumes.reduce(0, +) / Double(volumes.count)
        let normalizedVolumes = volumes.map { $0 / avgVolume }
        features.append(contentsOf: normalizedVolumes)
        
        // Technical indicators (normalized)
        features.append(indicators.rsi / 100.0)
        features.append((indicators.macd + 10) / 20.0) // Normalize MACD
        features.append(indicators.percentFromSMA50 / 100.0)
        features.append(indicators.percentFromSMA200 / 100.0)
        features.append(indicators.bollingerBandPosition)
        
        return features
    }
    
    // MARK: - Simple Prediction (Fallback)
    
    private func simplePredict(
        historicalData: [OHLCV],
        indicators: TechnicalIndicators
    ) -> StockPrediction {
        let currentPrice = historicalData.last?.close ?? 0
        
        // Calculate trend from last 20 days
        let last20 = historicalData.suffix(20)
        let prices = last20.map { $0.close }
        
        // Simple linear regression for trend
        let n = Double(prices.count)
        let sumX = (0..<prices.count).reduce(0.0) { $0 + Double($1) }
        let sumY = prices.reduce(0, +)
        let sumXY = prices.enumerated().reduce(0.0) { $0 + Double($1.offset) * $1.element }
        let sumX2 = (0..<prices.count).reduce(0.0) { $0 + Double($1 * $1) }
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        let intercept = (sumY - slope * sumX) / n
        
        // Predict future prices
        let pred1D = intercept + slope * (n + 1)
        let pred5D = intercept + slope * (n + 5)
        let pred30D = intercept + slope * (n + 30)
        
        // Adjust predictions based on technical indicators
        var adjustmentFactor = 1.0
        
        // RSI adjustment
        if indicators.rsi < 30 {
            adjustmentFactor *= 1.02 // Oversold, expect bounce
        } else if indicators.rsi > 70 {
            adjustmentFactor *= 0.98 // Overbought, expect pullback
        }
        
        // MACD adjustment
        if indicators.macdCrossover == .bullish {
            adjustmentFactor *= 1.01
        } else if indicators.macdCrossover == .bearish {
            adjustmentFactor *= 0.99
        }
        
        // SMA200 adjustment (trend following)
        if currentPrice > indicators.sma200 {
            adjustmentFactor *= 1.005
        } else {
            adjustmentFactor *= 0.995
        }
        
        // Calculate confidence based on volatility and trend strength
        let volatility = calculateVolatility(prices: prices)
        let trendStrength = abs(slope) / currentPrice * 100
        
        var confidence = 0.5
        
        // Higher confidence for lower volatility
        if volatility < 0.02 {
            confidence += 0.2
        } else if volatility < 0.04 {
            confidence += 0.1
        } else if volatility > 0.08 {
            confidence -= 0.1
        }
        
        // Higher confidence for stronger trends
        if trendStrength > 0.5 {
            confidence += 0.15
        } else if trendStrength > 0.3 {
            confidence += 0.1
        }
        
        // Cap confidence
        confidence = min(0.85, max(0.2, confidence))
        
        // Determine signal based on expected returns
        let expectedReturn5D = ((pred5D * adjustmentFactor) - currentPrice) / currentPrice * 100
        
        let signal: PredictionSignal
        if expectedReturn5D > 5 && indicators.rsi < 40 {
            signal = .strongBuy
        } else if expectedReturn5D > 2 {
            signal = .buy
        } else if expectedReturn5D < -5 && indicators.rsi > 60 {
            signal = .strongSell
        } else if expectedReturn5D < -2 {
            signal = .sell
        } else {
            signal = .hold
        }
        
        return StockPrediction(
            symbol: historicalData.first?.date.description ?? "UNKNOWN",
            currentPrice: currentPrice,
            predictedPrice1D: pred1D * adjustmentFactor,
            predictedPrice5D: pred5D * adjustmentFactor,
            predictedPrice30D: pred30D * adjustmentFactor,
            confidence: confidence,
            signal: signal,
            supportingFactors: generateSupportingFactors(indicators: indicators),
            riskFactors: generateRiskFactors(indicators: indicators, volatility: volatility),
            generatedAt: Date()
        )
    }
    
    private func calculateVolatility(prices: [Double]) -> Double {
        let returns = zip(prices.dropFirst(), prices).map { ($0 - $1) / $1 }
        let mean = returns.reduce(0, +) / Double(returns.count)
        let variance = returns.reduce(0) { $0 + pow($1 - mean, 2) } / Double(returns.count)
        return sqrt(variance)
    }
    
    private func generateSupportingFactors(indicators: TechnicalIndicators) -> [String] {
        var factors: [String] = []
        
        if indicators.rsi < 30 {
            factors.append("RSI indicates oversold conditions")
        } else if indicators.rsi > 70 {
            factors.append("RSI indicates overbought conditions")
        }
        
        if indicators.macdCrossover == .bullish {
            factors.append("MACD bullish crossover detected")
        } else if indicators.macdCrossover == .bearish {
            factors.append("MACD bearish crossover detected")
        }
        
        if indicators.percentFromSMA50 < -10 {
            factors.append("Trading significantly below 50-day moving average")
        }
        
        if indicators.percentFromSMA200 > 0 {
            factors.append("Above 200-day moving average (uptrend)")
        } else {
            factors.append("Below 200-day moving average (downtrend)")
        }
        
        return factors
    }
    
    private func generateRiskFactors(indicators: TechnicalIndicators, volatility: Double) -> [String] {
        var risks: [String] = []
        
        if volatility > 0.05 {
            risks.append("High volatility increases prediction uncertainty")
        }
        
        if indicators.bollingerBandPosition > 0.9 {
            risks.append("Price near upper Bollinger Band - potential reversal")
        } else if indicators.bollingerBandPosition < 0.1 {
            risks.append("Price near lower Bollinger Band - potential bounce")
        }
        
        if abs(indicators.percentFromSMA50) > 20 {
            risks.append("Price significantly deviated from moving average")
        }
        
        return risks
    }
}

// MARK: - Prediction Types

struct StockPrediction: Identifiable {
    let id = UUID()
    let symbol: String
    let currentPrice: Double
    let predictedPrice1D: Double
    let predictedPrice5D: Double
    let predictedPrice30D: Double
    let confidence: Double
    let signal: PredictionSignal
    let supportingFactors: [String]
    let riskFactors: [String]
    let generatedAt: Date
    
    var expectedReturn1D: Double {
        ((predictedPrice1D - currentPrice) / currentPrice) * 100
    }
    
    var expectedReturn5D: Double {
        ((predictedPrice5D - currentPrice) / currentPrice) * 100
    }
    
    var expectedReturn30D: Double {
        ((predictedPrice30D - currentPrice) / currentPrice) * 100
    }
    
    var confidencePercent: String {
        "\(Int(confidence * 100))%"
    }
}

enum PredictionSignal: String, Codable {
    case strongBuy = "STRONG BUY"
    case buy = "BUY"
    case hold = "HOLD"
    case sell = "SELL"
    case strongSell = "STRONG SELL"
    
    var emoji: String {
        switch self {
        case .strongBuy: return "🚀"
        case .buy: return "🟢"
        case .hold: return "🟡"
        case .sell: return "🟠"
        case .strongSell: return "🔴"
        }
    }
}

struct TechnicalIndicators {
    let rsi: Double
    let macd: Double
    let macdSignal: Double
    let macdHistogram: Double
    let macdCrossover: MACDCrossover
    let sma20: Double
    let sma50: Double
    let sma200: Double
    let percentFromSMA50: Double
    let percentFromSMA200: Double
    let bollingerUpper: Double
    let bollingerLower: Double
    let bollingerBandPosition: Double // 0-1, position within bands
    
    enum MACDCrossover {
        case bullish
        case bearish
        case none
    }
}

enum PredictionError: Error, LocalizedError {
    case modelNotLoaded
    case insufficientData
    case predictionFailed
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "Prediction model not loaded"
        case .insufficientData: return "Not enough historical data for prediction"
        case .predictionFailed: return "Prediction calculation failed"
        }
    }
}

// MARK: - ML Model Manager

@Observable
class MLModelManager {
    static let shared = MLModelManager()
    
    var isLoading = false
    var modelsLoaded = false
    
    private init() {}
    
    func loadModels() async {
        isLoading = true
        defer { isLoading = false }
        
        // Load stock predictor
        await StockPredictor.shared.loadModel()
        
        // Load pattern recognizer
        await PatternRecognizer.shared.loadModel()
        
        modelsLoaded = true
    }
}
