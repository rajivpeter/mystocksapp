//
//  AIAnalysisService.swift
//  MyStocksApp
//
//  AI-powered analysis service using OpenAI with local Ollama fallback
//  Based on: https://github.com/virattt/ai-hedge-fund
//

import Foundation

@Observable
class AIAnalysisService {
    static let shared = AIAnalysisService()
    
    private let openAIKey: String?
    private let ollamaBaseURL = "http://localhost:11434"
    
    var isProcessing = false
    var lastError: String?
    
    private init() {
        self.openAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
    }
    
    // MARK: - Pattern Analysis
    
    /// Generate AI-powered pattern explanation specific to the stock and current market context
    func analyzePattern(
        patternName: String,
        symbol: String,
        currentPrice: Double,
        patternPrice: Double,
        confidence: Int,
        isBullish: Bool,
        recentPriceHistory: [Double] = []
    ) async -> PatternAnalysis {
        isProcessing = true
        defer { isProcessing = false }
        
        let prompt = buildPatternAnalysisPrompt(
            patternName: patternName,
            symbol: symbol,
            currentPrice: currentPrice,
            patternPrice: patternPrice,
            confidence: confidence,
            isBullish: isBullish,
            recentPriceHistory: recentPriceHistory
        )
        
        // Try OpenAI first, then Ollama
        if let analysis = await callOpenAI(prompt: prompt) {
            return parsePatternAnalysis(analysis, patternName: patternName, isBullish: isBullish)
        } else if let analysis = await callOllama(prompt: prompt) {
            return parsePatternAnalysis(analysis, patternName: patternName, isBullish: isBullish)
        } else {
            // Fallback to static analysis
            return getStaticPatternAnalysis(patternName: patternName, isBullish: isBullish, confidence: confidence)
        }
    }
    
    // MARK: - Trading Recommendation
    
    /// Generate AI-powered trading recommendation
    func generateTradingRecommendation(
        symbol: String,
        currentPrice: Double,
        patterns: [String],
        technicalIndicators: TechnicalIndicators,
        sentiment: Double
    ) async -> TradingRecommendation {
        isProcessing = true
        defer { isProcessing = false }
        
        let prompt = buildTradingPrompt(
            symbol: symbol,
            currentPrice: currentPrice,
            patterns: patterns,
            technicalIndicators: technicalIndicators,
            sentiment: sentiment
        )
        
        if let response = await callOpenAI(prompt: prompt) {
            return parseTradingRecommendation(response, symbol: symbol, currentPrice: currentPrice)
        } else if let response = await callOllama(prompt: prompt) {
            return parseTradingRecommendation(response, symbol: symbol, currentPrice: currentPrice)
        } else {
            return TradingRecommendation(
                action: .hold,
                confidence: 50,
                reason: "Unable to generate AI analysis. Please check network connection.",
                targetPrice: nil,
                stopLoss: nil,
                positionSize: nil
            )
        }
    }
    
    // MARK: - OpenAI API
    
    private func callOpenAI(prompt: String) async -> String? {
        guard let apiKey = openAIKey, !apiKey.isEmpty else {
            print("⚠️ OpenAI API key not configured")
            return nil
        }
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 500,
            "temperature": 0.7
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ OpenAI API error: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return nil
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let choices = json?["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content
            }
        } catch {
            print("❌ OpenAI API error: \(error)")
            lastError = error.localizedDescription
        }
        
        return nil
    }
    
    // MARK: - Ollama (Local)
    
    private func callOllama(prompt: String) async -> String? {
        let url = URL(string: "\(ollamaBaseURL)/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let body: [String: Any] = [
            "model": "qwen2.5:latest",
            "prompt": "\(systemPrompt)\n\nUser: \(prompt)",
            "stream": false
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("⚠️ Ollama not available")
                return nil
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return json?["response"] as? String
        } catch {
            print("⚠️ Ollama error: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Prompts
    
    private var systemPrompt: String {
        """
        You are an expert stock market analyst and trading advisor, similar to the AI agents in virattt/ai-hedge-fund.
        You combine the wisdom of legendary investors like Warren Buffett, Peter Lynch, and Michael Burry.
        
        Your role:
        - Analyze candlestick patterns and their implications
        - Provide specific, actionable trading advice
        - Consider risk management and position sizing
        - Be concise but thorough
        
        Always include:
        1. What the pattern means in current context
        2. Specific entry/exit levels
        3. Risk assessment
        4. Confidence level
        
        Never use placeholder or dummy data. If you don't have enough information, say so.
        """
    }
    
    private func buildPatternAnalysisPrompt(
        patternName: String,
        symbol: String,
        currentPrice: Double,
        patternPrice: Double,
        confidence: Int,
        isBullish: Bool,
        recentPriceHistory: [Double]
    ) -> String {
        var prompt = """
        Analyze this candlestick pattern for \(symbol):
        
        Pattern: \(patternName)
        Type: \(isBullish ? "Bullish" : "Bearish")
        Detection Confidence: \(confidence)%
        Pattern Price: $\(String(format: "%.2f", patternPrice))
        Current Price: $\(String(format: "%.2f", currentPrice))
        Price Change Since Pattern: \(String(format: "%.2f", ((currentPrice - patternPrice) / patternPrice) * 100))%
        """
        
        if !recentPriceHistory.isEmpty {
            let trend = recentPriceHistory.last! > recentPriceHistory.first! ? "upward" : "downward"
            prompt += "\nRecent Trend: \(trend)"
        }
        
        prompt += """
        
        Please provide:
        1. What this \(patternName) pattern means specifically for \(symbol) right now
        2. Trading recommendation (entry point, target, stop loss)
        3. Key risks to watch
        4. Your confidence in this signal (1-100)
        
        Keep response under 300 words and be specific to this stock.
        """
        
        return prompt
    }
    
    private func buildTradingPrompt(
        symbol: String,
        currentPrice: Double,
        patterns: [String],
        technicalIndicators: TechnicalIndicators,
        sentiment: Double
    ) -> String {
        """
        Generate a trading recommendation for \(symbol):
        
        Current Price: $\(String(format: "%.2f", currentPrice))
        Detected Patterns: \(patterns.joined(separator: ", "))
        
        Technical Indicators:
        - RSI: \(String(format: "%.1f", technicalIndicators.rsi))
        - MACD: \(technicalIndicators.macdSignal)
        - 50 SMA: $\(String(format: "%.2f", technicalIndicators.sma50))
        - 200 SMA: $\(String(format: "%.2f", technicalIndicators.sma200))
        
        Market Sentiment Score: \(String(format: "%.1f", sentiment * 100))%
        
        Provide:
        1. Action: BUY, SELL, or HOLD
        2. If BUY/SELL: Entry price, Target price, Stop loss
        3. Position size recommendation (% of portfolio)
        4. Confidence level (1-100)
        5. Key reasoning (2-3 sentences)
        
        Be specific with numbers. No placeholders.
        """
    }
    
    // MARK: - Response Parsing
    
    private func parsePatternAnalysis(_ response: String, patternName: String, isBullish: Bool) -> PatternAnalysis {
        // Extract confidence from response (look for numbers near "confidence")
        let confidencePattern = try? NSRegularExpression(pattern: "confidence[:\\s]*(\\d+)", options: .caseInsensitive)
        var aiConfidence = 70
        if let match = confidencePattern?.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
           let range = Range(match.range(at: 1), in: response),
           let num = Int(response[range]) {
            aiConfidence = min(100, max(0, num))
        }
        
        return PatternAnalysis(
            patternName: patternName,
            explanation: response,
            tradingImplication: isBullish ? "Potential bullish opportunity" : "Caution: bearish signal",
            riskLevel: aiConfidence > 70 ? .low : (aiConfidence > 50 ? .medium : .high),
            confidence: aiConfidence,
            isAIGenerated: true
        )
    }
    
    private func parseTradingRecommendation(_ response: String, symbol: String, currentPrice: Double) -> TradingRecommendation {
        // Parse action
        var action: TradingAction = .hold
        let responseLower = response.lowercased()
        if responseLower.contains("strong buy") || responseLower.contains("action: buy") {
            action = .strongBuy
        } else if responseLower.contains("buy") {
            action = .buy
        } else if responseLower.contains("strong sell") {
            action = .strongSell
        } else if responseLower.contains("sell") {
            action = .sell
        }
        
        // Extract target price
        var targetPrice: Double?
        let targetPattern = try? NSRegularExpression(pattern: "target[:\\s]*\\$?(\\d+\\.?\\d*)", options: .caseInsensitive)
        if let match = targetPattern?.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
           let range = Range(match.range(at: 1), in: response),
           let num = Double(response[range]) {
            targetPrice = num
        }
        
        // Extract stop loss
        var stopLoss: Double?
        let stopPattern = try? NSRegularExpression(pattern: "stop[\\s-]*loss[:\\s]*\\$?(\\d+\\.?\\d*)", options: .caseInsensitive)
        if let match = stopPattern?.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
           let range = Range(match.range(at: 1), in: response),
           let num = Double(response[range]) {
            stopLoss = num
        }
        
        // Extract confidence
        var confidence = 60
        let confPattern = try? NSRegularExpression(pattern: "confidence[:\\s]*(\\d+)", options: .caseInsensitive)
        if let match = confPattern?.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
           let range = Range(match.range(at: 1), in: response),
           let num = Int(response[range]) {
            confidence = min(100, max(0, num))
        }
        
        return TradingRecommendation(
            action: action,
            confidence: confidence,
            reason: response,
            targetPrice: targetPrice,
            stopLoss: stopLoss,
            positionSize: nil
        )
    }
    
    // MARK: - Static Fallback
    
    private func getStaticPatternAnalysis(patternName: String, isBullish: Bool, confidence: Int) -> PatternAnalysis {
        let definition = PatternLibrary.allPatterns.first { $0.name == patternName }
        
        return PatternAnalysis(
            patternName: patternName,
            explanation: definition?.description ?? "Pattern detected with \(confidence)% confidence.",
            tradingImplication: definition?.entryStrategy ?? (isBullish ? "Consider long entry" : "Consider reducing exposure"),
            riskLevel: confidence > 70 ? .low : (confidence > 50 ? .medium : .high),
            confidence: confidence,
            isAIGenerated: false
        )
    }
}

// MARK: - Models

struct PatternAnalysis {
    let patternName: String
    let explanation: String
    let tradingImplication: String
    let riskLevel: RiskLevel
    let confidence: Int
    let isAIGenerated: Bool
    
    enum RiskLevel: String {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        
        var color: String {
            switch self {
            case .low: return "green"
            case .medium: return "orange"
            case .high: return "red"
            }
        }
    }
}

struct TradingRecommendation {
    let action: TradingAction
    let confidence: Int
    let reason: String
    let targetPrice: Double?
    let stopLoss: Double?
    let positionSize: Double?
}

enum TradingAction: String {
    case strongBuy = "Strong Buy"
    case buy = "Buy"
    case hold = "Hold"
    case sell = "Sell"
    case strongSell = "Strong Sell"
    
    var emoji: String {
        switch self {
        case .strongBuy: return "🚀"
        case .buy: return "📈"
        case .hold: return "⏸️"
        case .sell: return "📉"
        case .strongSell: return "🔴"
        }
    }
    
    var color: String {
        switch self {
        case .strongBuy, .buy: return "green"
        case .hold: return "orange"
        case .sell, .strongSell: return "red"
        }
    }
}

struct TechnicalIndicators {
    var rsi: Double = 50
    var macdSignal: String = "Neutral"
    var sma50: Double = 0
    var sma200: Double = 0
    var bollingerPosition: String = "Middle"
}
