//
//  Portfolio.swift
//  MyStocksApp
//
//  Portfolio and Position models
//

import Foundation
import SwiftData

@Model
final class Portfolio {
    // MARK: - Identifiers
    @Attribute(.unique) var id: UUID
    var name: String
    var accountType: AccountType
    var broker: BrokerType
    
    // MARK: - Cash & Value
    var cashBalance: Double
    var totalInvested: Double
    var currency: Currency
    
    // MARK: - Positions
    @Relationship(deleteRule: .cascade)
    var positions: [Position]
    
    // MARK: - Metadata
    var createdAt: Date
    var lastUpdated: Date
    var isActive: Bool
    
    // MARK: - Computed Properties
    var totalValue: Double {
        let positionsValue = positions.reduce(0) { $0 + $1.marketValue }
        return cashBalance + positionsValue
    }
    
    var totalUnrealizedPnL: Double {
        positions.reduce(0) { $0 + $1.unrealizedPnL }
    }
    
    var totalUnrealizedPnLPercent: Double {
        guard totalInvested > 0 else { return 0 }
        return (totalUnrealizedPnL / totalInvested) * 100
    }
    
    var positionCount: Int {
        positions.count
    }
    
    var winningPositions: [Position] {
        positions.filter { $0.unrealizedPnL > 0 }
    }
    
    var losingPositions: [Position] {
        positions.filter { $0.unrealizedPnL < 0 }
    }
    
    var winRate: Double {
        guard !positions.isEmpty else { return 0 }
        return Double(winningPositions.count) / Double(positions.count) * 100
    }
    
    var topPerformers: [Position] {
        positions.sorted { $0.unrealizedPnLPercent > $1.unrealizedPnLPercent }.prefix(5).map { $0 }
    }
    
    var worstPerformers: [Position] {
        positions.sorted { $0.unrealizedPnLPercent < $1.unrealizedPnLPercent }.prefix(5).map { $0 }
    }
    
    var ukPositions: [Position] {
        positions.filter { $0.stock?.currency == .gbp }
    }
    
    var usPositions: [Position] {
        positions.filter { $0.stock?.currency == .usd }
    }
    
    var ukAllocation: Double {
        guard totalValue > 0 else { return 0 }
        let ukValue = ukPositions.reduce(0) { $0 + $1.marketValueGBP }
        return (ukValue / totalValue) * 100
    }
    
    var usAllocation: Double {
        guard totalValue > 0 else { return 0 }
        let usValue = usPositions.reduce(0) { $0 + $1.marketValueGBP }
        return (usValue / totalValue) * 100
    }
    
    var cashAllocation: Double {
        guard totalValue > 0 else { return 0 }
        return (cashBalance / totalValue) * 100
    }
    
    // MARK: - Initializer
    init(
        name: String = "Main Portfolio",
        accountType: AccountType = .isa,
        broker: BrokerType = .ig,
        cashBalance: Double = 0,
        currency: Currency = .gbp
    ) {
        self.id = UUID()
        self.name = name
        self.accountType = accountType
        self.broker = broker
        self.cashBalance = cashBalance
        self.totalInvested = 0
        self.currency = currency
        self.positions = []
        self.createdAt = Date()
        self.lastUpdated = Date()
        self.isActive = true
    }
}

// MARK: - Position Model
@Model
final class Position {
    // MARK: - Identifiers
    @Attribute(.unique) var id: UUID
    
    // MARK: - Stock Reference
    var stock: Stock?
    var symbol: String
    
    // MARK: - Position Details
    var shares: Double
    var averageCost: Double
    var purchaseDate: Date
    var accountRef: String? // Account reference (e.g., "IG ISA", "ii", "HL")
    
    // MARK: - Computed Properties (non-stored)
    var currentPrice: Double {
        stock?.currentPrice ?? 0
    }
    
    var marketValue: Double {
        shares * currentPrice
    }
    
    var totalCost: Double {
        shares * averageCost
    }
    
    var unrealizedPnL: Double {
        marketValue - totalCost
    }
    
    var unrealizedPnLPercent: Double {
        guard totalCost > 0 else { return 0 }
        return (unrealizedPnL / totalCost) * 100
    }
    
    var currency: Currency {
        stock?.currency ?? .gbp
    }
    
    var marketValueGBP: Double {
        marketValue * currency.exchangeRate
    }
    
    var isProfit: Bool {
        unrealizedPnL >= 0
    }
    
    var holdingPeriodDays: Int {
        Calendar.current.dateComponents([.day], from: purchaseDate, to: Date()).day ?? 0
    }
    
    // MARK: - Formatted Values
    var formattedMarketValue: String {
        let symbol = currency.symbol
        return "\(symbol)\(marketValue.formatted(.number.precision(.fractionLength(2))))"
    }
    
    var formattedPnL: String {
        let sign = unrealizedPnL >= 0 ? "+" : ""
        let symbol = currency.symbol
        return "\(sign)\(symbol)\(unrealizedPnL.formatted(.number.precision(.fractionLength(2))))"
    }
    
    var formattedPnLPercent: String {
        let sign = unrealizedPnLPercent >= 0 ? "+" : ""
        return "\(sign)\(unrealizedPnLPercent.formatted(.number.precision(.fractionLength(2))))%"
    }
    
    // MARK: - Initializer
    init(
        symbol: String,
        shares: Double,
        averageCost: Double,
        purchaseDate: Date = Date(),
        stock: Stock? = nil,
        accountRef: String? = nil
    ) {
        self.id = UUID()
        self.symbol = symbol
        self.accountRef = accountRef
        self.shares = shares
        self.averageCost = averageCost
        self.purchaseDate = purchaseDate
        self.stock = stock
    }
}

// MARK: - Account Type
enum AccountType: String, Codable, CaseIterable {
    case isa = "ISA"
    case sipp = "SIPP"
    case gia = "GIA"
    case trading = "Trading"
    
    var description: String {
        switch self {
        case .isa: return "Stocks & Shares ISA"
        case .sipp: return "Self-Invested Personal Pension"
        case .gia: return "General Investment Account"
        case .trading: return "Trading Account"
        }
    }
}

// MARK: - Broker Type
enum BrokerType: String, Codable, CaseIterable {
    case ig = "IG"
    case interactiveInvestor = "ii"
    case interactiveBrokers = "IBKR"
    case hargreavesLansdown = "HL"
    case freetrade = "Freetrade"
    case trading212 = "Trading212"
    case manual = "Manual"
    
    var displayName: String {
        switch self {
        case .ig: return "IG"
        case .interactiveInvestor: return "Interactive Investor"
        case .interactiveBrokers: return "Interactive Brokers"
        case .hargreavesLansdown: return "Hargreaves Lansdown"
        case .freetrade: return "Freetrade"
        case .trading212: return "Trading 212"
        case .manual: return "Manual Entry"
        }
    }
    
    var hasAPI: Bool {
        switch self {
        case .ig, .interactiveBrokers: return true
        default: return false
        }
    }
}

// MARK: - Watchlist Item
@Model
final class WatchlistItem {
    @Attribute(.unique) var id: UUID
    var symbol: String
    var stock: Stock?
    var addedAt: Date
    var targetPrice: Double?
    var alertThreshold: Double?
    var notes: String?
    
    init(symbol: String, stock: Stock? = nil, targetPrice: Double? = nil) {
        self.id = UUID()
        self.symbol = symbol
        self.stock = stock
        self.addedAt = Date()
        self.targetPrice = targetPrice
    }
}

// MARK: - Trade History
@Model
final class TradeHistory {
    @Attribute(.unique) var id: UUID
    var symbol: String
    var action: TradeAction
    var shares: Double
    var price: Double
    var totalValue: Double
    var executedAt: Date
    var broker: BrokerType
    var notes: String?
    
    var formattedValue: String {
        "£\(totalValue.formatted(.number.precision(.fractionLength(2))))"
    }
    
    init(
        symbol: String,
        action: TradeAction,
        shares: Double,
        price: Double,
        broker: BrokerType = .manual
    ) {
        self.id = UUID()
        self.symbol = symbol
        self.action = action
        self.shares = shares
        self.price = price
        self.totalValue = shares * price
        self.executedAt = Date()
        self.broker = broker
    }
}

enum TradeAction: String, Codable {
    case buy = "BUY"
    case sell = "SELL"
    
    var emoji: String {
        switch self {
        case .buy: return "🟢"
        case .sell: return "🔴"
        }
    }
}
