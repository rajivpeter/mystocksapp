//
//  CachedData.swift
//  MyStocksApp
//
//  SwiftData models for persistent caching of historical and enriched stock data
//

import Foundation
import SwiftData

// MARK: - Cached Historical Data

/// Persistent cache for historical OHLCV data
@Model
final class CachedHistoricalData {
    @Attribute(.unique) var cacheKey: String // symbol_period
    var symbol: String
    var periodRaw: String
    var dataJSON: Data // Serialized [OHLCV]
    var fetchedAt: Date
    var expiresAt: Date
    
    var period: HistoricalPeriod? {
        HistoricalPeriod(rawValue: periodRaw)
    }
    
    var isExpired: Bool {
        Date() > expiresAt
    }
    
    init(symbol: String, period: HistoricalPeriod, data: [OHLCV], expiresIn: TimeInterval) {
        self.cacheKey = "\(symbol.uppercased())_\(period.rawValue)"
        self.symbol = symbol.uppercased()
        self.periodRaw = period.rawValue
        self.fetchedAt = Date()
        self.expiresAt = Date().addingTimeInterval(expiresIn)
        
        // Serialize OHLCV data
        let encoder = JSONEncoder()
        self.dataJSON = (try? encoder.encode(data)) ?? Data()
    }
    
    /// Decode the cached historical data
    func decodedData() -> [OHLCV]? {
        let decoder = JSONDecoder()
        return try? decoder.decode([OHLCV].self, from: dataJSON)
    }
    
    /// Update the cached data
    func update(with data: [OHLCV], expiresIn: TimeInterval) {
        let encoder = JSONEncoder()
        self.dataJSON = (try? encoder.encode(data)) ?? Data()
        self.fetchedAt = Date()
        self.expiresAt = Date().addingTimeInterval(expiresIn)
    }
}

// MARK: - Cached Stock Metrics

/// Persistent cache for enriched stock metrics (calculated indicators, fair value, etc.)
@Model
final class CachedStockMetrics {
    @Attribute(.unique) var symbol: String
    
    // Valuation metrics
    var marketCap: Double?
    var peRatio: Double?
    var pegRatio: Double?
    var priceToBook: Double?
    var dividendYield: Double?
    var fairValue: Double?
    
    // Technical indicators
    var rsi14: Double?
    var sma20: Double?
    var sma50: Double?
    var sma200: Double?
    var macd: Double?
    var macdSignal: Double?
    
    // Historical performance
    var change1D: Double
    var change1W: Double
    var change1M: Double
    var change3M: Double
    var change1Y: Double
    var change3Y: Double
    var change5Y: Double
    
    // Cache metadata
    var fetchedAt: Date
    var metricsExpiresAt: Date // Valuation metrics expire
    var technicalExpiresAt: Date // Technical indicators expire sooner
    var performanceExpiresAt: Date // Historical performance
    
    var areMetricsExpired: Bool {
        Date() > metricsExpiresAt
    }
    
    var areTechnicalsExpired: Bool {
        Date() > technicalExpiresAt
    }
    
    var isPerformanceExpired: Bool {
        Date() > performanceExpiresAt
    }
    
    init(symbol: String) {
        self.symbol = symbol.uppercased()
        self.change1D = 0
        self.change1W = 0
        self.change1M = 0
        self.change3M = 0
        self.change1Y = 0
        self.change3Y = 0
        self.change5Y = 0
        self.fetchedAt = Date()
        
        // Default expiry times
        self.metricsExpiresAt = Date().addingTimeInterval(3600) // 1 hour
        self.technicalExpiresAt = Date().addingTimeInterval(900) // 15 minutes
        self.performanceExpiresAt = Date().addingTimeInterval(86400) // 24 hours
    }
    
    func updateMetrics(
        marketCap: Double? = nil,
        peRatio: Double? = nil,
        pegRatio: Double? = nil,
        priceToBook: Double? = nil,
        dividendYield: Double? = nil,
        fairValue: Double? = nil,
        expiresIn: TimeInterval = 3600
    ) {
        if let v = marketCap { self.marketCap = v }
        if let v = peRatio { self.peRatio = v }
        if let v = pegRatio { self.pegRatio = v }
        if let v = priceToBook { self.priceToBook = v }
        if let v = dividendYield { self.dividendYield = v }
        if let v = fairValue { self.fairValue = v }
        self.metricsExpiresAt = Date().addingTimeInterval(expiresIn)
    }
    
    func updateTechnicals(
        rsi14: Double? = nil,
        sma20: Double? = nil,
        sma50: Double? = nil,
        sma200: Double? = nil,
        macd: Double? = nil,
        macdSignal: Double? = nil,
        expiresIn: TimeInterval = 900
    ) {
        if let v = rsi14 { self.rsi14 = v }
        if let v = sma20 { self.sma20 = v }
        if let v = sma50 { self.sma50 = v }
        if let v = sma200 { self.sma200 = v }
        if let v = macd { self.macd = v }
        if let v = macdSignal { self.macdSignal = v }
        self.technicalExpiresAt = Date().addingTimeInterval(expiresIn)
    }
    
    func updatePerformance(
        change1D: Double,
        change1W: Double,
        change1M: Double,
        change3M: Double,
        change1Y: Double,
        change3Y: Double,
        change5Y: Double,
        expiresIn: TimeInterval = 86400
    ) {
        self.change1D = change1D
        self.change1W = change1W
        self.change1M = change1M
        self.change3M = change3M
        self.change1Y = change1Y
        self.change3Y = change3Y
        self.change5Y = change5Y
        self.performanceExpiresAt = Date().addingTimeInterval(expiresIn)
    }
}

// MARK: - Last Refresh Tracker

/// Tracks the last refresh time for different data types to enable intelligent batch refreshing
@Model
final class RefreshTracker {
    @Attribute(.unique) var trackerType: String
    var lastRefreshAt: Date
    var nextRefreshAt: Date
    
    enum TrackerType: String {
        case portfolioPrices = "portfolio_prices"
        case watchlistPrices = "watchlist_prices"
        case marketMovers = "market_movers"
        case news = "news"
        
        var refreshInterval: TimeInterval {
            switch self {
            case .portfolioPrices: return 60 // 1 minute during trading
            case .watchlistPrices: return 300 // 5 minutes
            case .marketMovers: return 900 // 15 minutes
            case .news: return 1800 // 30 minutes
            }
        }
    }
    
    init(type: TrackerType) {
        self.trackerType = type.rawValue
        self.lastRefreshAt = Date()
        self.nextRefreshAt = Date().addingTimeInterval(type.refreshInterval)
    }
    
    var needsRefresh: Bool {
        Date() > nextRefreshAt
    }
    
    func markRefreshed(interval: TimeInterval? = nil) {
        self.lastRefreshAt = Date()
        if let interval = interval {
            self.nextRefreshAt = Date().addingTimeInterval(interval)
        } else if let type = TrackerType(rawValue: trackerType) {
            self.nextRefreshAt = Date().addingTimeInterval(type.refreshInterval)
        }
    }
}

// MARK: - Batch Quote Cache

/// Cache for batch-fetched quotes (for portfolio/watchlist efficiency)
@Model
final class BatchQuoteCache {
    @Attribute(.unique) var symbol: String
    
    // Current price data
    var currentPrice: Double
    var previousClose: Double
    var open: Double
    var high: Double
    var low: Double
    var volume: Int64
    var high52Week: Double
    var low52Week: Double
    
    // Metadata
    var name: String
    var exchange: String
    var currency: String
    
    // Cache timing
    var fetchedAt: Date
    var expiresAt: Date
    
    var isExpired: Bool {
        Date() > expiresAt
    }
    
    var change: Double {
        currentPrice - previousClose
    }
    
    var changePercent: Double {
        guard previousClose > 0 else { return 0 }
        return (change / previousClose) * 100
    }
    
    init(from quote: StockQuote, expiresIn: TimeInterval = 60) {
        self.symbol = quote.symbol.uppercased()
        self.name = quote.name
        self.exchange = quote.exchange
        self.currency = quote.currency
        self.currentPrice = quote.currentPrice
        self.previousClose = quote.previousClose
        self.open = quote.open
        self.high = quote.high
        self.low = quote.low
        self.volume = quote.volume
        self.high52Week = quote.high52Week
        self.low52Week = quote.low52Week
        self.fetchedAt = Date()
        self.expiresAt = Date().addingTimeInterval(expiresIn)
    }
    
    func update(from quote: StockQuote, expiresIn: TimeInterval = 60) {
        self.currentPrice = quote.currentPrice
        self.previousClose = quote.previousClose
        self.open = quote.open
        self.high = quote.high
        self.low = quote.low
        self.volume = quote.volume
        self.high52Week = quote.high52Week
        self.low52Week = quote.low52Week
        self.fetchedAt = Date()
        self.expiresAt = Date().addingTimeInterval(expiresIn)
    }
    
    /// Convert back to StockQuote
    func toStockQuote() -> StockQuote {
        StockQuote(
            symbol: symbol,
            name: name,
            exchange: exchange,
            currency: currency,
            currentPrice: currentPrice,
            previousClose: previousClose,
            open: open,
            high: high,
            low: low,
            volume: volume,
            high52Week: high52Week,
            low52Week: low52Week,
            marketCap: nil,
            peRatio: nil,
            timestamp: fetchedAt
        )
    }
}
