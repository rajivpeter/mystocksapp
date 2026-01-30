//
//  IGTradingService.swift
//  MyStocksApp
//
//  IG Trading API integration for UK/EU broker
//  Documentation: https://labs.ig.com/rest-trading-api-guide.html
//

import Foundation

@Observable
class IGTradingService {
    static let shared = IGTradingService()
    
    // MARK: - Configuration
    private let baseURL: String
    private let apiKey: String
    private var cst: String? // Client session token
    private var xSecurityToken: String? // Security token
    private var accountId: String?
    
    private let session: URLSession
    
    var isAuthenticated: Bool {
        cst != nil && xSecurityToken != nil
    }
    
    var isDemo: Bool = true // Toggle for demo/live
    
    private init() {
        // Initialize session first
        self.session = URLSession.shared
        
        // Get credentials from Secrets.plist
        var apiKeyValue = ""
        var isDemoValue = true
        
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let secrets = NSDictionary(contentsOfFile: path) as? [String: Any] {
            apiKeyValue = secrets["IG_API_KEY"] as? String ?? ""
            isDemoValue = secrets["IG_IS_DEMO"] as? Bool ?? true
        }
        
        self.apiKey = apiKeyValue
        self.isDemo = isDemoValue
        self.baseURL = isDemoValue 
            ? "https://demo-api.ig.com/gateway/deal"
            : "https://api.ig.com/gateway/deal"
    }
    
    // MARK: - Authentication
    
    /// Login to IG Trading API
    func login(identifier: String, password: String) async throws -> IGSession {
        let url = URL(string: "\(baseURL)/session")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "X-IG-API-KEY")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("2", forHTTPHeaderField: "VERSION")
        
        let body: [String: Any] = [
            "identifier": identifier,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IGError.networkError
        }
        
        // Extract tokens from headers
        if let cst = httpResponse.value(forHTTPHeaderField: "CST"),
           let xst = httpResponse.value(forHTTPHeaderField: "X-SECURITY-TOKEN") {
            self.cst = cst
            self.xSecurityToken = xst
        } else {
            throw IGError.authenticationFailed
        }
        
        // Parse session info
        let sessionInfo = try JSONDecoder().decode(IGSession.self, from: data)
        self.accountId = sessionInfo.currentAccountId
        
        return sessionInfo
    }
    
    /// Logout
    func logout() async throws {
        guard isAuthenticated else { return }
        
        let url = URL(string: "\(baseURL)/session")!
        var request = authenticatedRequest(url: url)
        request.httpMethod = "DELETE"
        
        _ = try await session.data(for: request)
        
        cst = nil
        xSecurityToken = nil
        accountId = nil
    }
    
    // MARK: - Account
    
    /// Get account details
    func getAccounts() async throws -> [IGAccount] {
        let url = URL(string: "\(baseURL)/accounts")!
        let request = authenticatedRequest(url: url)
        
        let (data, _) = try await session.data(for: request)
        
        let response = try JSONDecoder().decode(IGAccountsResponse.self, from: data)
        return response.accounts
    }
    
    // MARK: - Positions
    
    /// Get all open positions
    func getPositions() async throws -> [IGPosition] {
        let url = URL(string: "\(baseURL)/positions")!
        var request = authenticatedRequest(url: url)
        request.setValue("2", forHTTPHeaderField: "VERSION")
        
        let (data, _) = try await session.data(for: request)
        
        let response = try JSONDecoder().decode(IGPositionsResponse.self, from: data)
        return response.positions
    }
    
    /// Open a position (buy/sell)
    func openPosition(
        epic: String,
        direction: IGDirection,
        size: Double,
        orderType: IGOrderType = .market,
        limitLevel: Double? = nil,
        stopLevel: Double? = nil
    ) async throws -> IGDealReference {
        let url = URL(string: "\(baseURL)/positions/otc")!
        var request = authenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("2", forHTTPHeaderField: "VERSION")
        
        var body: [String: Any] = [
            "epic": epic,
            "direction": direction.rawValue,
            "size": size,
            "orderType": orderType.rawValue,
            "currencyCode": "GBP",
            "forceOpen": true,
            "guaranteedStop": false
        ]
        
        if let limit = limitLevel {
            body["limitLevel"] = limit
        }
        if let stop = stopLevel {
            body["stopLevel"] = stop
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await session.data(for: request)
        
        return try JSONDecoder().decode(IGDealReference.self, from: data)
    }
    
    /// Close a position
    func closePosition(dealId: String, size: Double, direction: IGDirection) async throws -> IGDealReference {
        let url = URL(string: "\(baseURL)/positions/otc")!
        var request = authenticatedRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("1", forHTTPHeaderField: "VERSION")
        request.setValue("application/json", forHTTPHeaderField: "_method")
        
        let body: [String: Any] = [
            "dealId": dealId,
            "size": size,
            "direction": direction.opposite.rawValue,
            "orderType": "MARKET"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await session.data(for: request)
        
        return try JSONDecoder().decode(IGDealReference.self, from: data)
    }
    
    // MARK: - Market Data
    
    /// Get market details
    func getMarket(epic: String) async throws -> IGMarket {
        let url = URL(string: "\(baseURL)/markets/\(epic)")!
        var request = authenticatedRequest(url: url)
        request.setValue("3", forHTTPHeaderField: "VERSION")
        
        let (data, _) = try await session.data(for: request)
        
        return try JSONDecoder().decode(IGMarket.self, from: data)
    }
    
    /// Search for markets
    func searchMarkets(query: String) async throws -> [IGMarketSearchResult] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "\(baseURL)/markets?searchTerm=\(encodedQuery)")!
        let request = authenticatedRequest(url: url)
        
        let (data, _) = try await session.data(for: request)
        
        let response = try JSONDecoder().decode(IGMarketSearchResponse.self, from: data)
        return response.markets
    }
    
    // MARK: - Watchlist
    
    /// Get watchlists
    func getWatchlists() async throws -> [IGWatchlist] {
        let url = URL(string: "\(baseURL)/watchlists")!
        let request = authenticatedRequest(url: url)
        
        let (data, _) = try await session.data(for: request)
        
        let response = try JSONDecoder().decode(IGWatchlistsResponse.self, from: data)
        return response.watchlists
    }
    
    // MARK: - Helper
    
    private func authenticatedRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.addValue(apiKey, forHTTPHeaderField: "X-IG-API-KEY")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        if let cst = cst {
            request.addValue(cst, forHTTPHeaderField: "CST")
        }
        if let xst = xSecurityToken {
            request.addValue(xst, forHTTPHeaderField: "X-SECURITY-TOKEN")
        }
        
        return request
    }
    
    /// Convert stock symbol to IG epic
    func symbolToEpic(_ symbol: String) -> String {
        // IG uses specific epic formats
        // UK stocks: CS.D.{SYMBOL}.CFD.IP
        // US stocks: CS.D.{SYMBOL}.CFD.IP
        
        if symbol.hasSuffix(".L") {
            let cleanSymbol = symbol.replacingOccurrences(of: ".L", with: "")
            return "CS.D.\(cleanSymbol).CFD.IP"
        } else {
            return "CS.D.\(symbol).CFD.IP"
        }
    }
}

// MARK: - IG Data Types

struct IGSession: Codable {
    let currentAccountId: String
    let clientId: String
    let timezoneOffset: Int
    let lightstreamerEndpoint: String
    let accountType: String?
}

struct IGAccount: Codable, Identifiable {
    var id: String { accountId }
    
    let accountId: String
    let accountName: String
    let accountType: String
    let balance: IGBalance
    let currency: String
    let status: String
    let preferred: Bool
}

struct IGBalance: Codable {
    let balance: Double
    let deposit: Double
    let profitLoss: Double
    let available: Double
}

struct IGAccountsResponse: Codable {
    let accounts: [IGAccount]
}

struct IGPosition: Codable, Identifiable {
    var id: String { position.dealId }
    
    let position: IGPositionDetail
    let market: IGMarketInfo
}

struct IGPositionDetail: Codable {
    let dealId: String
    let direction: String
    let size: Double
    let openLevel: Double
    let currency: String
    let createdDateUTC: String
    let stopLevel: Double?
    let limitLevel: Double?
}

struct IGMarketInfo: Codable {
    let instrumentName: String
    let epic: String
    let bid: Double?
    let offer: Double?
    let percentageChange: Double?
    let netChange: Double?
}

struct IGPositionsResponse: Codable {
    let positions: [IGPosition]
}

struct IGMarket: Codable {
    let instrument: IGInstrument
    let dealingRules: IGDealingRules
    let snapshot: IGSnapshot
}

struct IGInstrument: Codable {
    let epic: String
    let name: String
    let type: String
    let currency: String
}

struct IGDealingRules: Codable {
    let minStopOrLimitDistance: IGDistance?
    let maxStopOrLimitDistance: IGDistance?
}

struct IGDistance: Codable {
    let value: Double
    let unit: String
}

struct IGSnapshot: Codable {
    let bid: Double
    let offer: Double
    let high: Double
    let low: Double
    let netChange: Double
    let percentageChange: Double
    let marketStatus: String
}

struct IGMarketSearchResult: Codable, Identifiable {
    var id: String { epic }
    
    let epic: String
    let instrumentName: String
    let instrumentType: String
    let expiry: String?
    let bid: Double?
    let offer: Double?
    let netChange: Double?
    let percentageChange: Double?
}

struct IGMarketSearchResponse: Codable {
    let markets: [IGMarketSearchResult]
}

struct IGWatchlist: Codable, Identifiable {
    let watchlistId: String
    let name: String
    let editable: Bool
    let deleteable: Bool
    let defaultSystemWatchlist: Bool
    
    var id: String { watchlistId }
    
    enum CodingKeys: String, CodingKey {
        case watchlistId = "id"
        case name, editable, deleteable, defaultSystemWatchlist
    }
}

struct IGWatchlistsResponse: Codable {
    let watchlists: [IGWatchlist]
}

struct IGDealReference: Codable {
    let dealReference: String
}

enum IGDirection: String, Codable {
    case buy = "BUY"
    case sell = "SELL"
    
    var opposite: IGDirection {
        self == .buy ? .sell : .buy
    }
}

enum IGOrderType: String, Codable {
    case market = "MARKET"
    case limit = "LIMIT"
    case quote = "QUOTE"
}

enum IGError: Error, LocalizedError {
    case notAuthenticated
    case authenticationFailed
    case networkError
    case insufficientFunds
    case marketClosed
    case invalidPosition
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not logged in to IG"
        case .authenticationFailed: return "IG login failed"
        case .networkError: return "Network error connecting to IG"
        case .insufficientFunds: return "Insufficient funds in account"
        case .marketClosed: return "Market is currently closed"
        case .invalidPosition: return "Invalid position"
        }
    }
}
