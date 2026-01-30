//
//  YahooFinanceService.swift
//  MyStocksApp
//
//  Yahoo Finance API integration (free, reliable)
//

import Foundation

class YahooFinanceService: MarketDataProvider {
    private let baseURL = "https://query1.finance.yahoo.com"
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)"
        ]
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Quote
    
    func fetchQuote(symbol: String) async throws -> StockQuote {
        // Use the quoteSummary endpoint for more comprehensive data
        let summaryURL = URL(string: "\(baseURL)/v10/finance/quoteSummary/\(symbol)?modules=price,summaryDetail,defaultKeyStatistics")!
        
        do {
            let (summaryData, summaryResponse) = try await session.data(from: summaryURL)
            
            if let httpResponse = summaryResponse as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                return try parseQuoteSummary(data: summaryData, symbol: symbol)
            }
        } catch {
            print("Quote summary failed, falling back to chart: \(error)")
        }
        
        // Fallback to chart endpoint
        let chartURL = URL(string: "\(baseURL)/v8/finance/chart/\(symbol)?interval=1d&range=1d")!
        let (data, response) = try await session.data(from: chartURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarketDataError.networkError
        }
        
        return try parseQuote(data: data, symbol: symbol)
    }
    
    private func parseQuoteSummary(data: Data, symbol: String) throws -> StockQuote {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let quoteSummary = json?["quoteSummary"] as? [String: Any],
              let result = (quoteSummary["result"] as? [[String: Any]])?.first else {
            throw MarketDataError.parseError
        }
        
        // Parse price module
        let priceData = result["price"] as? [String: Any] ?? [:]
        let summaryDetail = result["summaryDetail"] as? [String: Any] ?? [:]
        let keyStats = result["defaultKeyStatistics"] as? [String: Any] ?? [:]
        
        let currentPrice = extractNumber(from: priceData["regularMarketPrice"]) ?? 0
        let previousClose = extractNumber(from: priceData["regularMarketPreviousClose"]) ?? currentPrice
        let open = extractNumber(from: priceData["regularMarketOpen"]) ?? currentPrice
        let high = extractNumber(from: priceData["regularMarketDayHigh"]) ?? currentPrice
        let low = extractNumber(from: priceData["regularMarketDayLow"]) ?? currentPrice
        let volume = Int64(extractNumber(from: priceData["regularMarketVolume"]) ?? 0)
        
        let currency = priceData["currency"] as? String ?? "USD"
        let exchange = priceData["exchangeName"] as? String ?? "UNKNOWN"
        let name = priceData["shortName"] as? String ?? priceData["longName"] as? String ?? symbol
        
        let high52Week = extractNumber(from: summaryDetail["fiftyTwoWeekHigh"]) ?? high
        let low52Week = extractNumber(from: summaryDetail["fiftyTwoWeekLow"]) ?? low
        
        // Extract valuation metrics
        let marketCap = extractNumber(from: priceData["marketCap"])
        let peRatio = extractNumber(from: summaryDetail["trailingPE"])
        
        return StockQuote(
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
            marketCap: marketCap,
            peRatio: peRatio,
            timestamp: Date()
        )
    }
    
    /// Extract number from Yahoo's nested format (e.g., {"raw": 123.45, "fmt": "123.45"})
    private func extractNumber(from value: Any?) -> Double? {
        if let dict = value as? [String: Any] {
            return dict["raw"] as? Double
        }
        return value as? Double
    }
    
    private func parseQuote(data: Data, symbol: String) throws -> StockQuote {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let chart = json?["chart"] as? [String: Any],
              let result = (chart["result"] as? [[String: Any]])?.first,
              let meta = result["meta"] as? [String: Any] else {
            throw MarketDataError.parseError
        }
        
        let currentPrice = meta["regularMarketPrice"] as? Double ?? 0
        let previousClose = meta["previousClose"] as? Double ?? meta["chartPreviousClose"] as? Double ?? currentPrice
        let currency = meta["currency"] as? String ?? "USD"
        let exchange = meta["exchangeName"] as? String ?? "UNKNOWN"
        let name = meta["shortName"] as? String ?? meta["longName"] as? String ?? symbol
        
        // Get OHLV from indicators
        var open = currentPrice
        var high = currentPrice
        var low = currentPrice
        var volume: Int64 = 0
        
        if let indicators = result["indicators"] as? [String: Any],
           let quote = (indicators["quote"] as? [[String: Any]])?.first {
            open = (quote["open"] as? [Double])?.last ?? currentPrice
            high = (quote["high"] as? [Double])?.last ?? currentPrice
            low = (quote["low"] as? [Double])?.last ?? currentPrice
            volume = Int64((quote["volume"] as? [Int])?.last ?? 0)
        }
        
        // Get 52-week range
        let high52Week = meta["fiftyTwoWeekHigh"] as? Double ?? high
        let low52Week = meta["fiftyTwoWeekLow"] as? Double ?? low
        
        return StockQuote(
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
            timestamp: Date()
        )
    }
    
    // MARK: - Historical Data
    
    func fetchHistoricalData(symbol: String, period: HistoricalPeriod) async throws -> [OHLCV] {
        let range = periodToRange(period)
        let interval = period.interval
        
        let url = URL(string: "\(baseURL)/v8/finance/chart/\(symbol)?interval=\(interval)&range=\(range)")!
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarketDataError.networkError
        }
        
        return try parseHistoricalData(data: data)
    }
    
    private func periodToRange(_ period: HistoricalPeriod) -> String {
        switch period {
        case .oneDay: return "1d"
        case .fiveDays: return "5d"
        case .oneMonth: return "1mo"
        case .threeMonths: return "3mo"
        case .sixMonths: return "6mo"
        case .oneYear: return "1y"
        case .threeYears: return "3y"
        case .fiveYears: return "5y"
        }
    }
    
    private func parseHistoricalData(data: Data) throws -> [OHLCV] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let chart = json?["chart"] as? [String: Any],
              let result = (chart["result"] as? [[String: Any]])?.first,
              let timestamps = result["timestamp"] as? [Int],
              let indicators = result["indicators"] as? [String: Any],
              let quote = (indicators["quote"] as? [[String: Any]])?.first else {
            throw MarketDataError.parseError
        }
        
        let opens = quote["open"] as? [Double?] ?? []
        let highs = quote["high"] as? [Double?] ?? []
        let lows = quote["low"] as? [Double?] ?? []
        let closes = quote["close"] as? [Double?] ?? []
        let volumes = quote["volume"] as? [Int?] ?? []
        
        var ohlcv: [OHLCV] = []
        
        for i in 0..<timestamps.count {
            guard let open = opens[safe: i] ?? nil,
                  let high = highs[safe: i] ?? nil,
                  let low = lows[safe: i] ?? nil,
                  let close = closes[safe: i] ?? nil else {
                continue
            }
            
            let date = Date(timeIntervalSince1970: TimeInterval(timestamps[i]))
            let volumeValue: Int = (volumes[safe: i]).flatMap { $0 } ?? 0
            let volume = Int64(volumeValue)
            
            ohlcv.append(OHLCV(
                date: date,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume,
                adjustedClose: close
            ))
        }
        
        return ohlcv
    }
    
    // MARK: - Search
    
    func searchSymbols(query: String) async throws -> [SymbolSearchResult] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "https://query2.finance.yahoo.com/v1/finance/search?q=\(encodedQuery)&quotesCount=10&newsCount=0")!
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarketDataError.networkError
        }
        
        return try parseSearchResults(data: data)
    }
    
    private func parseSearchResults(data: Data) throws -> [SymbolSearchResult] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let quotes = json?["quotes"] as? [[String: Any]] else {
            return []
        }
        
        return quotes.compactMap { quote in
            guard let symbol = quote["symbol"] as? String else { return nil }
            
            let name = quote["shortname"] as? String ?? quote["longname"] as? String ?? symbol
            let type = quote["quoteType"] as? String ?? "EQUITY"
            let exchange = quote["exchange"] as? String ?? "UNKNOWN"
            
            return SymbolSearchResult(
                symbol: symbol,
                name: name,
                type: type,
                exchange: exchange,
                currency: "USD" // Yahoo doesn't return currency in search
            )
        }
    }
    
    // MARK: - News
    
    func fetchNews(symbol: String, limit: Int) async throws -> [NewsArticle] {
        // Yahoo Finance doesn't have a public news API
        // In production, you would use a news API like Finnhub or NewsAPI
        return []
    }
}

// MARK: - Array Extension
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
