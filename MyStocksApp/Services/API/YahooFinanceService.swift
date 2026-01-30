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
        let url = URL(string: "\(baseURL)/v8/finance/chart/\(symbol)?interval=1d&range=1d")!
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarketDataError.networkError
        }
        
        return try parseQuote(data: data, symbol: symbol)
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
            let volume = Int64(volumes[safe: i] ?? nil ?? 0)
            
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
