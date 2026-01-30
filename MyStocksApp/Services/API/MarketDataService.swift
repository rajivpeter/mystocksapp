//
//  MarketDataService.swift
//  MyStocksApp
//
//  Unified market data service with intelligent caching and multiple provider fallbacks
//

import Foundation

/// Protocol for market data providers
protocol MarketDataProvider {
    func fetchQuote(symbol: String) async throws -> StockQuote
    func fetchHistoricalData(symbol: String, period: HistoricalPeriod) async throws -> [OHLCV]
    func searchSymbols(query: String) async throws -> [SymbolSearchResult]
    func fetchNews(symbol: String, limit: Int) async throws -> [NewsArticle]
}

/// Main market data service with intelligent caching and provider fallbacks
@Observable
class MarketDataService {
    static let shared = MarketDataService()
    
    private let polygonService: PolygonService
    private let alphaVantageService: AlphaVantageService
    private let yahooFinanceService: YahooFinanceService
    
    /// Centralized cache manager
    private let cacheManager = CacheManager.shared
    
    var isLoading = false
    var lastError: String?
    
    /// Statistics for API calls (for monitoring)
    private(set) var apiCallCount = 0
    private(set) var cacheHitCount = 0
    
    private init() {
        self.polygonService = PolygonService()
        self.alphaVantageService = AlphaVantageService()
        self.yahooFinanceService = YahooFinanceService()
    }
    
    // MARK: - Public API
    
    /// Fetch quote with intelligent caching
    func fetchQuote(symbol: String, forceRefresh: Bool = false) async throws -> StockQuote {
        let upperSymbol = symbol.uppercased()
        
        // Check cache first (unless force refresh)
        if !forceRefresh, let cached = cacheManager.getCachedQuote(symbol: upperSymbol) {
            cacheHitCount += 1
            print("📦 Cache HIT for \(upperSymbol) quote")
            return cached
        }
        
        apiCallCount += 1
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
                let quote = try await provider.fetchQuote(symbol: upperSymbol)
                
                // Cache successful result
                cacheManager.cacheQuote(quote)
                
                print("✅ Fetched \(upperSymbol) quote from \(name) (API call #\(apiCallCount))")
                return quote
            } catch {
                print("⚠️ \(name) failed for \(upperSymbol): \(error.localizedDescription)")
                lastError = error
                continue
            }
        }
        
        self.lastError = lastError?.localizedDescription
        throw lastError ?? MarketDataError.allProvidersFailed
    }
    
    /// Fetch multiple quotes efficiently with batching
    func fetchQuotes(symbols: [String], forceRefresh: Bool = false) async throws -> [StockQuote] {
        var results: [StockQuote] = []
        var symbolsToFetch: [String] = []
        
        // First, check cache for each symbol
        for symbol in symbols {
            let upperSymbol = symbol.uppercased()
            if !forceRefresh, let cached = cacheManager.getCachedQuote(symbol: upperSymbol) {
                results.append(cached)
                cacheHitCount += 1
            } else {
                symbolsToFetch.append(upperSymbol)
            }
        }
        
        if !symbolsToFetch.isEmpty {
            print("📡 Fetching \(symbolsToFetch.count) quotes (cached: \(results.count))")
            
            // Batch fetch remaining symbols with concurrency limit
            let batchSize = 5 // Limit concurrent requests
            for batch in stride(from: 0, to: symbolsToFetch.count, by: batchSize) {
                let batchEnd = min(batch + batchSize, symbolsToFetch.count)
                let batchSymbols = Array(symbolsToFetch[batch..<batchEnd])
                
                let batchResults = try await withThrowingTaskGroup(of: StockQuote?.self) { group in
                    for symbol in batchSymbols {
                        group.addTask {
                            try? await self.fetchQuote(symbol: symbol, forceRefresh: true)
                        }
                    }
                    
                    var batchQuotes: [StockQuote] = []
                    for try await quote in group {
                        if let quote = quote {
                            batchQuotes.append(quote)
                        }
                    }
                    return batchQuotes
                }
                
                results.append(contentsOf: batchResults)
                
                // Small delay between batches to avoid rate limits
                if batchEnd < symbolsToFetch.count {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                }
            }
        }
        
        return results
    }
    
    /// Fetch historical OHLCV data with intelligent caching
    func fetchHistoricalData(symbol: String, period: HistoricalPeriod, forceRefresh: Bool = false) async throws -> [OHLCV] {
        let upperSymbol = symbol.uppercased()
        
        // Check cache first
        if !forceRefresh, let cached = cacheManager.getCachedHistoricalData(symbol: upperSymbol, period: period) {
            cacheHitCount += 1
            return cached
        }
        
        apiCallCount += 1
        isLoading = true
        defer { isLoading = false }
        
        print("📡 Fetching \(upperSymbol) \(period.rawValue) historical data (API call #\(apiCallCount))")
        
        // Try Yahoo first (best historical data)
        do {
            let data = try await yahooFinanceService.fetchHistoricalData(symbol: upperSymbol, period: period)
            
            // Cache the result
            cacheManager.cacheHistoricalData(symbol: upperSymbol, period: period, data: data)
            
            return data
        } catch {
            // Fallback to Alpha Vantage
            let data = try await alphaVantageService.fetchHistoricalData(symbol: upperSymbol, period: period)
            
            // Cache the result
            cacheManager.cacheHistoricalData(symbol: upperSymbol, period: period, data: data)
            
            return data
        }
    }
    
    /// Prefetch historical data for multiple periods (efficient for stock detail view)
    func prefetchHistoricalData(symbol: String, periods: [HistoricalPeriod]) async {
        let upperSymbol = symbol.uppercased()
        
        // Only fetch periods not already cached
        let periodsToFetch = periods.filter { period in
            cacheManager.getCachedHistoricalData(symbol: upperSymbol, period: period) == nil
        }
        
        guard !periodsToFetch.isEmpty else {
            print("📦 All \(periods.count) periods already cached for \(upperSymbol)")
            return
        }
        
        print("📡 Prefetching \(periodsToFetch.count) historical periods for \(upperSymbol)")
        
        // Fetch in sequence to avoid rate limits
        for period in periodsToFetch {
            do {
                _ = try await fetchHistoricalData(symbol: upperSymbol, period: period)
                // Small delay between fetches
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
            } catch {
                print("⚠️ Failed to prefetch \(period.rawValue) for \(upperSymbol)")
            }
        }
    }
    
    /// Search for symbols with caching
    func searchSymbols(query: String, forceRefresh: Bool = false) async throws -> [SymbolSearchResult] {
        guard query.count >= 1 else { return [] }
        
        // Check cache first
        if !forceRefresh, let cached = cacheManager.getCachedSearch(query: query) {
            cacheHitCount += 1
            print("📦 Cache HIT for search: \(query)")
            return cached
        }
        
        apiCallCount += 1
        
        // Try Yahoo first
        do {
            let results = try await yahooFinanceService.searchSymbols(query: query)
            cacheManager.cacheSearch(query: query, results: results)
            return results
        } catch {
            let results = try await alphaVantageService.searchSymbols(query: query)
            cacheManager.cacheSearch(query: query, results: results)
            return results
        }
    }
    
    /// Fetch news for a symbol with caching
    func fetchNews(symbol: String, limit: Int = 10, forceRefresh: Bool = false) async throws -> [NewsArticle] {
        let upperSymbol = symbol.uppercased()
        
        // Check cache first
        if !forceRefresh, let cached = cacheManager.getCachedNews(symbol: upperSymbol) {
            cacheHitCount += 1
            print("📦 Cache HIT for \(upperSymbol) news")
            return Array(cached.prefix(limit))
        }
        
        apiCallCount += 1
        
        // Try multiple sources
        var allNews: [NewsArticle] = []
        
        if let yahooNews = try? await yahooFinanceService.fetchNews(symbol: upperSymbol, limit: limit) {
            allNews.append(contentsOf: yahooNews)
        }
        
        // Sort by date and deduplicate
        let sortedNews = Array(allNews.sorted { $0.publishedAt > $1.publishedAt }.prefix(limit))
        
        // Cache results
        cacheManager.cacheNews(symbol: upperSymbol, articles: sortedNews)
        
        return sortedNews
    }
    
    /// Clear all caches
    func clearCache() {
        cacheManager.clearAllCaches()
        apiCallCount = 0
        cacheHitCount = 0
    }
    
    /// Clear cache for specific symbol
    func clearCache(for symbol: String) {
        cacheManager.clearHistoricalCache(symbol: symbol)
    }
    
    /// Prune expired cache entries
    func pruneExpiredCache() {
        cacheManager.pruneExpiredEntries()
    }
    
    /// Fetch stock (converts quote to Stock model) with caching
    func fetchStock(symbol: String, forceRefresh: Bool = false) async throws -> Stock {
        let quote = try await fetchQuote(symbol: symbol, forceRefresh: forceRefresh)
        let stock = Stock(
            symbol: quote.symbol,
            name: quote.name,
            exchange: quote.exchange,
            currency: Currency(rawValue: quote.currency) ?? .usd,
            currentPrice: quote.currentPrice,
            previousClose: quote.previousClose,
            open: quote.open,
            high: quote.high,
            low: quote.low,
            volume: quote.volume,
            averageVolume: quote.volume,
            high52Week: quote.high52Week,
            low52Week: quote.low52Week
        )
        
        // Add additional data from quote
        stock.marketCap = quote.marketCap
        stock.peRatio = quote.peRatio
        
        return stock
    }
    
    // MARK: - Cache Statistics
    
    var cacheStats: CacheStatistics {
        cacheManager.cacheStats
    }
    
    var cacheEfficiency: Double {
        let total = apiCallCount + cacheHitCount
        guard total > 0 else { return 0 }
        return Double(cacheHitCount) / Double(total) * 100
    }
    
    /// Check if markets are currently open
    var isMarketOpen: Bool {
        cacheManager.isAnyMarketOpen
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
