//
//  PolygonService.swift
//  MyStocksApp
//
//  Polygon.io API integration (institutional-grade, requires subscription)
//

import Foundation

class PolygonService: MarketDataProvider {
    private let baseURL = "https://api.polygon.io"
    private let apiKey: String
    private let session: URLSession
    
    init() {
        // Get API key from Secrets.plist
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let secrets = NSDictionary(contentsOfFile: path) as? [String: Any],
           let key = secrets["POLYGON_API_KEY"] as? String {
            self.apiKey = key
        } else {
            self.apiKey = ""
        }
        
        self.session = URLSession.shared
    }
    
    // MARK: - Quote
    
    func fetchQuote(symbol: String) async throws -> StockQuote {
        guard !apiKey.isEmpty else {
            throw MarketDataError.networkError
        }
        
        // Previous day's close
        let prevCloseURL = URL(string: "\(baseURL)/v2/aggs/ticker/\(symbol)/prev?apiKey=\(apiKey)")!
        
        let (data, response) = try await session.data(from: prevCloseURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarketDataError.networkError
        }
        
        return try parseQuote(data: data, symbol: symbol)
    }
    
    private func parseQuote(data: Data, symbol: String) throws -> StockQuote {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let results = json?["results"] as? [[String: Any]],
              let result = results.first else {
            throw MarketDataError.parseError
        }
        
        let close = result["c"] as? Double ?? 0
        let open = result["o"] as? Double ?? close
        let high = result["h"] as? Double ?? close
        let low = result["l"] as? Double ?? close
        let volume = Int64(result["v"] as? Double ?? 0)
        
        return StockQuote(
            symbol: symbol,
            name: symbol,
            exchange: "UNKNOWN",
            currency: "USD",
            currentPrice: close,
            previousClose: close,
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
        guard !apiKey.isEmpty else {
            throw MarketDataError.networkError
        }
        
        let to = Date()
        let from = Calendar.current.date(byAdding: .day, value: -period.days, to: to)!
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let fromStr = dateFormatter.string(from: from)
        let toStr = dateFormatter.string(from: to)
        
        let timespan = period.days <= 5 ? "minute" : "day"
        let multiplier = period.days <= 5 ? 5 : 1
        
        let url = URL(string: "\(baseURL)/v2/aggs/ticker/\(symbol)/range/\(multiplier)/\(timespan)/\(fromStr)/\(toStr)?apiKey=\(apiKey)")!
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarketDataError.networkError
        }
        
        return try parseHistoricalData(data: data)
    }
    
    private func parseHistoricalData(data: Data) throws -> [OHLCV] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let results = json?["results"] as? [[String: Any]] else {
            throw MarketDataError.parseError
        }
        
        return results.compactMap { bar in
            guard let timestamp = bar["t"] as? Double,
                  let open = bar["o"] as? Double,
                  let high = bar["h"] as? Double,
                  let low = bar["l"] as? Double,
                  let close = bar["c"] as? Double,
                  let volume = bar["v"] as? Double else {
                return nil
            }
            
            return OHLCV(
                date: Date(timeIntervalSince1970: timestamp / 1000),
                open: open,
                high: high,
                low: low,
                close: close,
                volume: Int64(volume),
                adjustedClose: close
            )
        }
    }
    
    // MARK: - Search
    
    func searchSymbols(query: String) async throws -> [SymbolSearchResult] {
        guard !apiKey.isEmpty else {
            throw MarketDataError.networkError
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "\(baseURL)/v3/reference/tickers?search=\(encodedQuery)&active=true&limit=10&apiKey=\(apiKey)")!
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarketDataError.networkError
        }
        
        return try parseSearchResults(data: data)
    }
    
    private func parseSearchResults(data: Data) throws -> [SymbolSearchResult] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let results = json?["results"] as? [[String: Any]] else {
            return []
        }
        
        return results.compactMap { ticker in
            guard let symbol = ticker["ticker"] as? String,
                  let name = ticker["name"] as? String else {
                return nil
            }
            
            let type = ticker["type"] as? String ?? "EQUITY"
            let exchange = ticker["primary_exchange"] as? String ?? "UNKNOWN"
            let currency = ticker["currency_name"] as? String ?? "USD"
            
            return SymbolSearchResult(
                symbol: symbol,
                name: name,
                type: type,
                exchange: exchange,
                currency: currency
            )
        }
    }
    
    // MARK: - News
    
    func fetchNews(symbol: String, limit: Int) async throws -> [NewsArticle] {
        guard !apiKey.isEmpty else {
            throw MarketDataError.networkError
        }
        
        let url = URL(string: "\(baseURL)/v2/reference/news?ticker=\(symbol)&limit=\(limit)&apiKey=\(apiKey)")!
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarketDataError.networkError
        }
        
        return try parseNews(data: data)
    }
    
    private func parseNews(data: Data) throws -> [NewsArticle] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let results = json?["results"] as? [[String: Any]] else {
            return []
        }
        
        let dateFormatter = ISO8601DateFormatter()
        
        return results.compactMap { article in
            guard let title = article["title"] as? String,
                  let urlString = article["article_url"] as? String else {
                return nil
            }
            
            let description = article["description"] as? String ?? ""
            let source = (article["publisher"] as? [String: Any])?["name"] as? String ?? "Unknown"
            let url = URL(string: urlString)
            let imageURL = (article["image_url"] as? String).flatMap { URL(string: $0) }
            let publishedAt = (article["published_utc"] as? String).flatMap { dateFormatter.date(from: $0) } ?? Date()
            
            return NewsArticle(
                id: UUID(),
                title: title,
                summary: description,
                source: source,
                url: url,
                imageURL: imageURL,
                publishedAt: publishedAt,
                sentiment: nil
            )
        }
    }
}
