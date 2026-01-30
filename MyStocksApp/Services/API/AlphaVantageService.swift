//
//  AlphaVantageService.swift
//  MyStocksApp
//
//  Alpha Vantage API integration (free tier: 5 calls/min)
//

import Foundation

class AlphaVantageService: MarketDataProvider {
    private let baseURL = "https://www.alphavantage.co/query"
    private let apiKey: String
    private let session: URLSession
    
    // Rate limiting
    private var lastRequestTime: Date?
    private let minRequestInterval: TimeInterval = 12 // 5 calls/min = 12 sec between calls
    
    init() {
        // Get API key from Secrets.plist or environment
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let secrets = NSDictionary(contentsOfFile: path) as? [String: Any],
           let key = secrets["ALPHA_VANTAGE_API_KEY"] as? String {
            self.apiKey = key
        } else {
            self.apiKey = "demo" // Alpha Vantage demo key
        }
        
        self.session = URLSession.shared
    }
    
    // MARK: - Rate Limiting
    
    private func waitForRateLimit() async {
        if let lastTime = lastRequestTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < minRequestInterval {
                try? await Task.sleep(nanoseconds: UInt64((minRequestInterval - elapsed) * 1_000_000_000))
            }
        }
        lastRequestTime = Date()
    }
    
    // MARK: - Quote
    
    func fetchQuote(symbol: String) async throws -> StockQuote {
        await waitForRateLimit()
        
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "function", value: "GLOBAL_QUOTE"),
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "apikey", value: apiKey)
        ]
        
        let (data, response) = try await session.data(from: components.url!)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarketDataError.networkError
        }
        
        return try parseQuote(data: data, symbol: symbol)
    }
    
    private func parseQuote(data: Data, symbol: String) throws -> StockQuote {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // Check for rate limit message
        if let note = json?["Note"] as? String, note.contains("rate limit") {
            throw MarketDataError.rateLimitExceeded
        }
        
        guard let globalQuote = json?["Global Quote"] as? [String: String],
              let priceStr = globalQuote["05. price"],
              let price = Double(priceStr) else {
            throw MarketDataError.parseError
        }
        
        let previousClose = Double(globalQuote["08. previous close"] ?? "0") ?? price
        let open = Double(globalQuote["02. open"] ?? "0") ?? price
        let high = Double(globalQuote["03. high"] ?? "0") ?? price
        let low = Double(globalQuote["04. low"] ?? "0") ?? price
        let volume = Int64(globalQuote["06. volume"] ?? "0") ?? 0
        
        return StockQuote(
            symbol: symbol,
            name: symbol, // Alpha Vantage doesn't return name in quote
            exchange: "UNKNOWN",
            currency: symbol.hasSuffix(".L") ? "GBP" : "USD",
            currentPrice: price,
            previousClose: previousClose,
            open: open,
            high: high,
            low: low,
            volume: volume,
            high52Week: high,
            low52Week: low,
            marketCap: nil,
            peRatio: nil,
            timestamp: Date()
        )
    }
    
    // MARK: - Historical Data
    
    func fetchHistoricalData(symbol: String, period: HistoricalPeriod) async throws -> [OHLCV] {
        await waitForRateLimit()
        
        let function: String
        let outputSize: String
        
        switch period {
        case .oneDay, .fiveDays:
            function = "TIME_SERIES_INTRADAY"
        default:
            function = "TIME_SERIES_DAILY"
        }
        
        outputSize = period.days > 100 ? "full" : "compact"
        
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "function", value: function),
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "outputsize", value: outputSize),
            URLQueryItem(name: "apikey", value: apiKey)
        ]
        
        if function == "TIME_SERIES_INTRADAY" {
            components.queryItems?.append(URLQueryItem(name: "interval", value: "5min"))
        }
        
        let (data, response) = try await session.data(from: components.url!)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarketDataError.networkError
        }
        
        return try parseHistoricalData(data: data, function: function)
    }
    
    private func parseHistoricalData(data: Data, function: String) throws -> [OHLCV] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // Check for rate limit
        if let note = json?["Note"] as? String, note.contains("rate limit") {
            throw MarketDataError.rateLimitExceeded
        }
        
        let timeSeriesKey = function == "TIME_SERIES_INTRADAY" 
            ? "Time Series (5min)" 
            : "Time Series (Daily)"
        
        guard let timeSeries = json?[timeSeriesKey] as? [String: [String: String]] else {
            throw MarketDataError.parseError
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = function == "TIME_SERIES_INTRADAY" 
            ? "yyyy-MM-dd HH:mm:ss" 
            : "yyyy-MM-dd"
        
        var ohlcv: [OHLCV] = []
        
        for (dateString, values) in timeSeries {
            guard let date = dateFormatter.date(from: dateString),
                  let open = Double(values["1. open"] ?? ""),
                  let high = Double(values["2. high"] ?? ""),
                  let low = Double(values["3. low"] ?? ""),
                  let close = Double(values["4. close"] ?? ""),
                  let volume = Int64(values["5. volume"] ?? "") else {
                continue
            }
            
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
        
        // Sort by date ascending
        return ohlcv.sorted { $0.date < $1.date }
    }
    
    // MARK: - Search
    
    func searchSymbols(query: String) async throws -> [SymbolSearchResult] {
        await waitForRateLimit()
        
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "function", value: "SYMBOL_SEARCH"),
            URLQueryItem(name: "keywords", value: query),
            URLQueryItem(name: "apikey", value: apiKey)
        ]
        
        let (data, response) = try await session.data(from: components.url!)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarketDataError.networkError
        }
        
        return try parseSearchResults(data: data)
    }
    
    private func parseSearchResults(data: Data) throws -> [SymbolSearchResult] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let matches = json?["bestMatches"] as? [[String: String]] else {
            return []
        }
        
        return matches.compactMap { match in
            guard let symbol = match["1. symbol"],
                  let name = match["2. name"] else {
                return nil
            }
            
            let type = match["3. type"] ?? "Equity"
            let region = match["4. region"] ?? "Unknown"
            let currency = match["8. currency"] ?? "USD"
            
            return SymbolSearchResult(
                symbol: symbol,
                name: name,
                type: type,
                exchange: region,
                currency: currency
            )
        }
    }
    
    // MARK: - News
    
    func fetchNews(symbol: String, limit: Int) async throws -> [NewsArticle] {
        await waitForRateLimit()
        
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "function", value: "NEWS_SENTIMENT"),
            URLQueryItem(name: "tickers", value: symbol),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "apikey", value: apiKey)
        ]
        
        let (data, response) = try await session.data(from: components.url!)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarketDataError.networkError
        }
        
        return try parseNews(data: data)
    }
    
    private func parseNews(data: Data) throws -> [NewsArticle] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let feed = json?["feed"] as? [[String: Any]] else {
            return []
        }
        
        let dateFormatter = ISO8601DateFormatter()
        
        return feed.compactMap { article in
            guard let title = article["title"] as? String,
                  let urlString = article["url"] as? String,
                  let timePublished = article["time_published"] as? String else {
                return nil
            }
            
            let summary = article["summary"] as? String ?? ""
            let source = article["source"] as? String ?? "Unknown"
            let url = URL(string: urlString)
            let imageURL = (article["banner_image"] as? String).flatMap { URL(string: $0) }
            
            // Parse sentiment
            var sentiment: NewsArticle.NewsSentiment? = nil
            if let overallSentiment = article["overall_sentiment_label"] as? String {
                switch overallSentiment.lowercased() {
                case "bullish", "somewhat-bullish":
                    sentiment = .positive
                case "bearish", "somewhat-bearish":
                    sentiment = .negative
                default:
                    sentiment = .neutral
                }
            }
            
            // Parse date
            let publishedAt = dateFormatter.date(from: timePublished) ?? Date()
            
            return NewsArticle(
                id: UUID(),
                title: title,
                summary: summary,
                source: source,
                url: url,
                imageURL: imageURL,
                publishedAt: publishedAt,
                sentiment: sentiment
            )
        }
    }
}
