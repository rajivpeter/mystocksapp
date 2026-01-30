//
//  CacheManager.swift
//  MyStocksApp
//
//  Centralized cache management with intelligent expiry based on trading hours
//

import Foundation

/// Centralized cache manager for all market data
@Observable
final class CacheManager {
    static let shared = CacheManager()
    
    // MARK: - In-Memory Caches
    
    /// Quote cache with 1-minute expiry for real-time prices
    private var quoteCache: [String: CachedQuote] = [:]
    
    /// Historical data cache with period-aware expiry
    private var historicalCache: [String: CachedHistorical] = [:]
    
    /// Search results cache with 5-minute expiry
    private var searchCache: [String: CachedSearch] = [:]
    
    /// News cache with 30-minute expiry
    private var newsCache: [String: CachedNews] = [:]
    
    /// Technical indicators cache (calculated values)
    private var technicalCache: [String: CachedTechnicals] = [:]
    
    // MARK: - Configuration
    
    private let maxCacheSize = 100 // Maximum symbols in each cache
    
    // MARK: - Cache Expiry Configuration (in seconds)
    
    private struct CacheExpiry {
        // Real-time quote expiry varies by trading hours
        static let quoteDuringTrading: TimeInterval = 60 // 1 minute during trading
        static let quoteAfterHours: TimeInterval = 300 // 5 minutes after hours
        static let quoteWeekend: TimeInterval = 3600 // 1 hour on weekends
        
        // Historical data expiry varies by period
        static let historical1D: TimeInterval = 300 // 5 minutes (intraday updates)
        static let historical5D: TimeInterval = 900 // 15 minutes
        static let historical1M: TimeInterval = 3600 // 1 hour
        static let historical3M: TimeInterval = 7200 // 2 hours
        static let historical6M: TimeInterval = 14400 // 4 hours
        static let historical1Y: TimeInterval = 86400 // 24 hours
        static let historical3Y: TimeInterval = 86400 * 7 // 1 week
        static let historical5Y: TimeInterval = 86400 * 7 // 1 week
        
        // Other cache expiries
        static let search: TimeInterval = 300 // 5 minutes
        static let news: TimeInterval = 1800 // 30 minutes
        static let technicals: TimeInterval = 900 // 15 minutes
    }
    
    private init() {}
    
    // MARK: - Trading Hours Detection
    
    /// Check if US markets are currently trading
    var isUSMarketOpen: Bool {
        let calendar = Calendar.current
        let now = Date()
        
        // US Eastern Time
        guard let eastern = TimeZone(identifier: "America/New_York") else { return false }
        var easternCalendar = calendar
        easternCalendar.timeZone = eastern
        
        let components = easternCalendar.dateComponents([.weekday, .hour, .minute], from: now)
        
        guard let weekday = components.weekday,
              let hour = components.hour,
              let minute = components.minute else { return false }
        
        // Check if weekend (1 = Sunday, 7 = Saturday)
        if weekday == 1 || weekday == 7 { return false }
        
        // NYSE/NASDAQ: 9:30 AM - 4:00 PM Eastern
        let currentMinutes = hour * 60 + minute
        let marketOpen = 9 * 60 + 30 // 9:30 AM
        let marketClose = 16 * 60 // 4:00 PM
        
        return currentMinutes >= marketOpen && currentMinutes < marketClose
    }
    
    /// Check if UK markets are currently trading
    var isUKMarketOpen: Bool {
        let calendar = Calendar.current
        let now = Date()
        
        // UK London Time
        guard let london = TimeZone(identifier: "Europe/London") else { return false }
        var londonCalendar = calendar
        londonCalendar.timeZone = london
        
        let components = londonCalendar.dateComponents([.weekday, .hour, .minute], from: now)
        
        guard let weekday = components.weekday,
              let hour = components.hour,
              let minute = components.minute else { return false }
        
        // Check if weekend
        if weekday == 1 || weekday == 7 { return false }
        
        // LSE: 8:00 AM - 4:30 PM London time
        let currentMinutes = hour * 60 + minute
        let marketOpen = 8 * 60 // 8:00 AM
        let marketClose = 16 * 60 + 30 // 4:30 PM
        
        return currentMinutes >= marketOpen && currentMinutes < marketClose
    }
    
    /// Check if any market is open
    var isAnyMarketOpen: Bool {
        isUSMarketOpen || isUKMarketOpen
    }
    
    /// Check if it's a weekend
    var isWeekend: Bool {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 || weekday == 7
    }
    
    // MARK: - Quote Cache
    
    /// Get quote cache expiry based on current market status
    private var quoteExpiry: TimeInterval {
        if isWeekend {
            return CacheExpiry.quoteWeekend
        } else if isAnyMarketOpen {
            return CacheExpiry.quoteDuringTrading
        } else {
            return CacheExpiry.quoteAfterHours
        }
    }
    
    /// Get cached quote if valid
    func getCachedQuote(symbol: String) -> StockQuote? {
        guard let cached = quoteCache[symbol.uppercased()],
              cached.isValid(expiry: quoteExpiry) else {
            return nil
        }
        return cached.quote
    }
    
    /// Cache a quote
    func cacheQuote(_ quote: StockQuote) {
        enforceQuoteCacheLimit()
        quoteCache[quote.symbol.uppercased()] = CachedQuote(quote: quote, fetchedAt: Date())
    }
    
    /// Cache multiple quotes at once
    func cacheQuotes(_ quotes: [StockQuote]) {
        for quote in quotes {
            cacheQuote(quote)
        }
    }
    
    private func enforceQuoteCacheLimit() {
        if quoteCache.count >= maxCacheSize {
            // Remove oldest entries (LRU)
            let sortedKeys = quoteCache.sorted { $0.value.fetchedAt < $1.value.fetchedAt }
            let keysToRemove = sortedKeys.prefix(maxCacheSize / 4).map { $0.key }
            keysToRemove.forEach { quoteCache.removeValue(forKey: $0) }
        }
    }
    
    // MARK: - Historical Data Cache
    
    /// Get cache expiry for historical period
    private func historicalExpiry(for period: HistoricalPeriod) -> TimeInterval {
        switch period {
        case .oneDay: return CacheExpiry.historical1D
        case .fiveDays: return CacheExpiry.historical5D
        case .oneMonth: return CacheExpiry.historical1M
        case .threeMonths: return CacheExpiry.historical3M
        case .sixMonths: return CacheExpiry.historical6M
        case .oneYear: return CacheExpiry.historical1Y
        case .threeYears: return CacheExpiry.historical3Y
        case .fiveYears: return CacheExpiry.historical5Y
        }
    }
    
    /// Cache key for historical data
    private func historicalCacheKey(symbol: String, period: HistoricalPeriod) -> String {
        "\(symbol.uppercased())_\(period.rawValue)"
    }
    
    /// Get cached historical data if valid
    func getCachedHistoricalData(symbol: String, period: HistoricalPeriod) -> [OHLCV]? {
        let key = historicalCacheKey(symbol: symbol, period: period)
        guard let cached = historicalCache[key],
              cached.isValid(expiry: historicalExpiry(for: period)) else {
            return nil
        }
        print("📦 Cache HIT for \(symbol) \(period.rawValue) historical data")
        return cached.data
    }
    
    /// Cache historical data
    func cacheHistoricalData(symbol: String, period: HistoricalPeriod, data: [OHLCV]) {
        let key = historicalCacheKey(symbol: symbol, period: period)
        historicalCache[key] = CachedHistorical(data: data, period: period, fetchedAt: Date())
        print("📦 Cached \(symbol) \(period.rawValue) historical data (\(data.count) points)")
    }
    
    /// Get all cached historical periods for a symbol
    func getCachedHistoricalPeriods(symbol: String) -> [HistoricalPeriod] {
        let prefix = symbol.uppercased() + "_"
        return historicalCache.keys
            .filter { $0.hasPrefix(prefix) }
            .compactMap { key -> HistoricalPeriod? in
                let periodStr = String(key.dropFirst(prefix.count))
                return HistoricalPeriod(rawValue: periodStr)
            }
    }
    
    // MARK: - Search Cache
    
    /// Get cached search results
    func getCachedSearch(query: String) -> [SymbolSearchResult]? {
        let key = query.lowercased()
        guard let cached = searchCache[key],
              cached.isValid(expiry: CacheExpiry.search) else {
            return nil
        }
        return cached.results
    }
    
    /// Cache search results
    func cacheSearch(query: String, results: [SymbolSearchResult]) {
        searchCache[query.lowercased()] = CachedSearch(results: results, fetchedAt: Date())
    }
    
    // MARK: - News Cache
    
    /// Get cached news
    func getCachedNews(symbol: String) -> [NewsArticle]? {
        guard let cached = newsCache[symbol.uppercased()],
              cached.isValid(expiry: CacheExpiry.news) else {
            return nil
        }
        return cached.articles
    }
    
    /// Cache news articles
    func cacheNews(symbol: String, articles: [NewsArticle]) {
        newsCache[symbol.uppercased()] = CachedNews(articles: articles, fetchedAt: Date())
    }
    
    // MARK: - Technical Indicators Cache
    
    /// Get cached technical indicators
    func getCachedTechnicals(symbol: String) -> CachedTechnicals? {
        guard let cached = technicalCache[symbol.uppercased()],
              cached.isValid(expiry: CacheExpiry.technicals) else {
            return nil
        }
        return cached
    }
    
    /// Cache technical indicators
    func cacheTechnicals(_ technicals: CachedTechnicals) {
        technicalCache[technicals.symbol.uppercased()] = technicals
    }
    
    // MARK: - Cache Clearing
    
    /// Clear all caches
    func clearAllCaches() {
        quoteCache.removeAll()
        historicalCache.removeAll()
        searchCache.removeAll()
        newsCache.removeAll()
        technicalCache.removeAll()
        print("🗑️ All caches cleared")
    }
    
    /// Clear quotes cache
    func clearQuoteCache() {
        quoteCache.removeAll()
    }
    
    /// Clear historical cache for a symbol
    func clearHistoricalCache(symbol: String) {
        let prefix = symbol.uppercased() + "_"
        historicalCache = historicalCache.filter { !$0.key.hasPrefix(prefix) }
    }
    
    /// Clear expired entries from all caches
    func pruneExpiredEntries() {
        let quoteExp = quoteExpiry
        quoteCache = quoteCache.filter { $0.value.isValid(expiry: quoteExp) }
        
        historicalCache = historicalCache.filter { key, value in
            if let period = HistoricalPeriod(rawValue: String(key.split(separator: "_").last ?? "")) {
                return value.isValid(expiry: historicalExpiry(for: period))
            }
            return false
        }
        
        searchCache = searchCache.filter { $0.value.isValid(expiry: CacheExpiry.search) }
        newsCache = newsCache.filter { $0.value.isValid(expiry: CacheExpiry.news) }
        technicalCache = technicalCache.filter { $0.value.isValid(expiry: CacheExpiry.technicals) }
    }
    
    // MARK: - Cache Statistics
    
    var cacheStats: CacheStatistics {
        CacheStatistics(
            quoteCount: quoteCache.count,
            historicalCount: historicalCache.count,
            searchCount: searchCache.count,
            newsCount: newsCache.count,
            technicalCount: technicalCache.count,
            isUSMarketOpen: isUSMarketOpen,
            isUKMarketOpen: isUKMarketOpen
        )
    }
}

// MARK: - Cache Data Structures

struct CachedQuote {
    let quote: StockQuote
    let fetchedAt: Date
    
    func isValid(expiry: TimeInterval) -> Bool {
        Date().timeIntervalSince(fetchedAt) < expiry
    }
}

struct CachedHistorical {
    let data: [OHLCV]
    let period: HistoricalPeriod
    let fetchedAt: Date
    
    func isValid(expiry: TimeInterval) -> Bool {
        Date().timeIntervalSince(fetchedAt) < expiry
    }
}

struct CachedSearch {
    let results: [SymbolSearchResult]
    let fetchedAt: Date
    
    func isValid(expiry: TimeInterval) -> Bool {
        Date().timeIntervalSince(fetchedAt) < expiry
    }
}

struct CachedNews {
    let articles: [NewsArticle]
    let fetchedAt: Date
    
    func isValid(expiry: TimeInterval) -> Bool {
        Date().timeIntervalSince(fetchedAt) < expiry
    }
}

struct CachedTechnicals {
    let symbol: String
    let rsi14: Double?
    let sma20: Double?
    let sma50: Double?
    let sma200: Double?
    let macd: Double?
    let macdSignal: Double?
    let fetchedAt: Date
    
    func isValid(expiry: TimeInterval) -> Bool {
        Date().timeIntervalSince(fetchedAt) < expiry
    }
}

struct CacheStatistics {
    let quoteCount: Int
    let historicalCount: Int
    let searchCount: Int
    let newsCount: Int
    let technicalCount: Int
    let isUSMarketOpen: Bool
    let isUKMarketOpen: Bool
    
    var totalEntries: Int {
        quoteCount + historicalCount + searchCount + newsCount + technicalCount
    }
    
    var description: String {
        """
        Cache Statistics:
        - Quotes: \(quoteCount)
        - Historical: \(historicalCount)
        - Search: \(searchCount)
        - News: \(newsCount)
        - Technical: \(technicalCount)
        - US Market: \(isUSMarketOpen ? "OPEN" : "CLOSED")
        - UK Market: \(isUKMarketOpen ? "OPEN" : "CLOSED")
        """
    }
}
