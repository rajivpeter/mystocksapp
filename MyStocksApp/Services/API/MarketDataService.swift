//
//  MarketDataService.swift
//  MyStocksApp
//
//  Unified market data service with multiple provider fallbacks
//

import Foundation

/// Protocol for market data providers
protocol MarketDataProvider {
    func fetchQuote(symbol: String) async throws -> StockQuote
    func fetchHistoricalData(symbol: String, period: HistoricalPeriod) async throws -> [OHLCV]
    func searchSymbols(query: String) async throws -> [SymbolSearchResult]
    func fetchNews(symbol: String, limit: Int) async throws -> [NewsArticle]
}

/// Main market data service with provider fallbacks
@Observable
class MarketDataService {
    static let shared = MarketDataService()
    
    private let polygonService: PolygonService
    private let alphaVantageService: AlphaVantageService
    private let yahooFinanceService: YahooFinanceService
    
    private var cache: [String: CachedQuote] = [:]
    private let cacheValiditySeconds: TimeInterval = 60 // 1 minute cache
    
    var isLoading = false
    var lastError: String?
    
    private init() {
        self.polygonService = PolygonService()
        self.alphaVantageService = AlphaVantageService()
        self.yahooFinanceService = YahooFinanceService()
    }
    
    // MARK: - Public API
    
    /// Fetch quote with automatic fallback
    func fetchQuote(symbol: String, forceRefresh: Bool = false) async throws -> StockQuote {
        // Check cache first
        if !forceRefresh, let cached = cache[symbol], cached.isValid {
            return cached.quote
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // Try providers in order of preference
        let providers: [(String, MarketDataProvider)] = [
            ("Yahoo", yahooFinanceService),  // Free, reliable
            ("Alpha Vantage", alphaVantageService),  // Free tier available
            ("Polygon", polygonService)  // Institutional grade, requires subscription
        ]
        
        var lastError: Error?
        
        for (name, provider) in providers {
            do {
                let quote = try await provider.fetchQuote(symbol: symbol)
                
                // Cache successful result
                cache[symbol] = CachedQuote(quote: quote, fetchedAt: Date())
                
                print("✅ Fetched \(symbol) quote from \(name)")
                return quote
            } catch {
                print("⚠️ \(name) failed for \(symbol): \(error.localizedDescription)")
                lastError = error
                continue
            }
        }
        
        self.lastError = lastError?.localizedDescription
        throw lastError ?? MarketDataError.allProvidersFailed
    }
    
    /// Fetch multiple quotes
    func fetchQuotes(symbols: [String]) async throws -> [StockQuote] {
        try await withThrowingTaskGroup(of: StockQuote?.self) { group in
            for symbol in symbols {
                group.addTask {
                    try? await self.fetchQuote(symbol: symbol)
                }
            }
            
            var results: [StockQuote] = []
            for try await quote in group {
                if let quote = quote {
                    results.append(quote)
                }
            }
            return results
        }
    }
    
    /// Fetch historical OHLCV data
    func fetchHistoricalData(symbol: String, period: HistoricalPeriod) async throws -> [OHLCV] {
        isLoading = true
        defer { isLoading = false }
        
        // Try Yahoo first (best historical data)
        do {
            return try await yahooFinanceService.fetchHistoricalData(symbol: symbol, period: period)
        } catch {
            // Fallback to Alpha Vantage
            return try await alphaVantageService.fetchHistoricalData(symbol: symbol, period: period)
        }
    }
    
    /// Search for symbols
    func searchSymbols(query: String) async throws -> [SymbolSearchResult] {
        guard query.count >= 1 else { return [] }
        
        // Try Yahoo first
        do {
            return try await yahooFinanceService.searchSymbols(query: query)
        } catch {
            return try await alphaVantageService.searchSymbols(query: query)
        }
    }
    
    /// Fetch news for a symbol
    func fetchNews(symbol: String, limit: Int = 10) async throws -> [NewsArticle] {
        // Try multiple sources
        var allNews: [NewsArticle] = []
        
        if let yahooNews = try? await yahooFinanceService.fetchNews(symbol: symbol, limit: limit) {
            allNews.append(contentsOf: yahooNews)
        }
        
        // Sort by date and deduplicate
        return Array(allNews.sorted { $0.publishedAt > $1.publishedAt }.prefix(limit))
    }
    
    /// Clear cache
    func clearCache() {
        cache.removeAll()
    }
}

// MARK: - Data Types

struct StockQuote: Codable, Identifiable {
    var id: String { symbol }
    
    let symbol: String
    let name: String
    let exchange: String
    let currency: String
    
    let currentPrice: Double
    let previousClose: Double
    let open: Double
    let high: Double
    let low: Double
    let volume: Int64
    
    let high52Week: Double
    let low52Week: Double
    let marketCap: Double?
    let peRatio: Double?
    
    let timestamp: Date
    
    var change: Double {
        currentPrice - previousClose
    }
    
    var changePercent: Double {
        guard previousClose > 0 else { return 0 }
        return (change / previousClose) * 100
    }
    
    var isPositive: Bool {
        change >= 0
    }
}

struct OHLCV: Codable, Identifiable {
    var id: Date { date }
    
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int64
    let adjustedClose: Double?
    
    var isBullish: Bool {
        close > open
    }
    
    var bodySize: Double {
        abs(close - open)
    }
    
    var upperShadow: Double {
        high - max(open, close)
    }
    
    var lowerShadow: Double {
        min(open, close) - low
    }
}

struct SymbolSearchResult: Codable, Identifiable {
    var id: String { symbol }
    
    let symbol: String
    let name: String
    let type: String
    let exchange: String
    let currency: String
}

struct NewsArticle: Codable, Identifiable {
    let id: UUID
    let title: String
    let summary: String
    let source: String
    let url: URL?
    let imageURL: URL?
    let publishedAt: Date
    let sentiment: NewsSentiment?
    
    enum NewsSentiment: String, Codable {
        case positive = "POSITIVE"
        case negative = "NEGATIVE"
        case neutral = "NEUTRAL"
    }
}

enum HistoricalPeriod: String, CaseIterable {
    case oneDay = "1D"
    case fiveDays = "5D"
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"
    case threeYears = "3Y"
    case fiveYears = "5Y"
    
    var days: Int {
        switch self {
        case .oneDay: return 1
        case .fiveDays: return 5
        case .oneMonth: return 30
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .oneYear: return 365
        case .threeYears: return 1095
        case .fiveYears: return 1825
        }
    }
    
    var interval: String {
        switch self {
        case .oneDay, .fiveDays: return "5m"
        case .oneMonth: return "1h"
        default: return "1d"
        }
    }
}

// MARK: - Cache

struct CachedQuote {
    let quote: StockQuote
    let fetchedAt: Date
    
    var isValid: Bool {
        Date().timeIntervalSince(fetchedAt) < 60 // 1 minute cache
    }
}

// MARK: - Errors

enum MarketDataError: Error, LocalizedError {
    case invalidSymbol
    case networkError
    case rateLimitExceeded
    case parseError
    case allProvidersFailed
    case noData
    
    var errorDescription: String? {
        switch self {
        case .invalidSymbol: return "Invalid stock symbol"
        case .networkError: return "Network connection error"
        case .rateLimitExceeded: return "API rate limit exceeded"
        case .parseError: return "Failed to parse response"
        case .allProvidersFailed: return "All data providers failed"
        case .noData: return "No data available"
        }
    }
}
