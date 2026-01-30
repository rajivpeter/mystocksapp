//
//  PortfolioViewModel.swift
//  MyStocksApp
//
//  ViewModel for portfolio management
//

import Foundation
import SwiftData

@Observable
class PortfolioViewModel {
    // MARK: - State
    var portfolio: Portfolio?
    var positions: [Position] = []
    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?
    
    // MARK: - Computed Properties
    var totalValue: Double {
        portfolio?.totalValue ?? 0
    }
    
    var totalPnL: Double {
        portfolio?.totalUnrealizedPnL ?? 0
    }
    
    var totalPnLPercent: Double {
        portfolio?.totalUnrealizedPnLPercent ?? 0
    }
    
    var cashBalance: Double {
        portfolio?.cashBalance ?? 0
    }
    
    var winRate: Double {
        portfolio?.winRate ?? 0
    }
    
    var positionCount: Int {
        positions.count
    }
    
    var topPerformers: [Position] {
        positions.sorted { $0.unrealizedPnLPercent > $1.unrealizedPnLPercent }.prefix(3).map { $0 }
    }
    
    var worstPerformers: [Position] {
        positions.sorted { $0.unrealizedPnLPercent < $1.unrealizedPnLPercent }.prefix(3).map { $0 }
    }
    
    var ukAllocation: Double {
        portfolio?.ukAllocation ?? 0
    }
    
    var usAllocation: Double {
        portfolio?.usAllocation ?? 0
    }
    
    var cashAllocation: Double {
        portfolio?.cashAllocation ?? 0
    }
    
    // MARK: - Services
    private let marketDataService = MarketDataService.shared
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Data Loading
    
    func loadPortfolio(modelContext: ModelContext) async {
        isLoading = true
        defer { isLoading = false }
        
        // Fetch portfolio from SwiftData
        let descriptor = FetchDescriptor<Portfolio>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            let portfolios = try modelContext.fetch(descriptor)
            
            if let existingPortfolio = portfolios.first {
                self.portfolio = existingPortfolio
                self.positions = existingPortfolio.positions
            } else {
                // Create default portfolio if none exists
                let newPortfolio = Portfolio(
                    name: "Main Portfolio",
                    accountType: .isa,
                    broker: .ig,
                    cashBalance: 42238.05
                )
                modelContext.insert(newPortfolio)
                try modelContext.save()
                
                self.portfolio = newPortfolio
                self.positions = []
            }
            
            // Refresh prices
            await refreshPrices()
            lastUpdated = Date()
            
        } catch {
            errorMessage = "Failed to load portfolio: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Price Refresh
    
    func refreshPrices() async {
        guard !positions.isEmpty else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        let symbols = positions.compactMap { $0.stock?.symbol ?? $0.symbol }
        
        do {
            let quotes = try await marketDataService.fetchQuotes(symbols: symbols)
            
            // Update stock prices
            for quote in quotes {
                if let position = positions.first(where: { $0.symbol == quote.symbol }),
                   let stock = position.stock {
                    stock.currentPrice = quote.currentPrice
                    stock.previousClose = quote.previousClose
                    stock.high = quote.high
                    stock.low = quote.low
                    stock.volume = quote.volume
                    stock.lastUpdated = Date()
                }
            }
            
            lastUpdated = Date()
            
        } catch {
            errorMessage = "Failed to refresh prices: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Position Management
    
    func addPosition(
        symbol: String,
        shares: Double,
        averageCost: Double,
        modelContext: ModelContext
    ) async {
        guard let portfolio = portfolio else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Fetch current stock data
            let quote = try await marketDataService.fetchQuote(symbol: symbol)
            
            // Create stock if needed
            let stock = Stock(
                symbol: quote.symbol,
                name: quote.name,
                exchange: quote.exchange,
                currency: quote.currency == "GBP" ? .gbp : .usd,
                currentPrice: quote.currentPrice,
                previousClose: quote.previousClose,
                open: quote.open,
                high: quote.high,
                low: quote.low,
                volume: quote.volume,
                high52Week: quote.high52Week,
                low52Week: quote.low52Week
            )
            
            modelContext.insert(stock)
            
            // Create position
            let position = Position(
                symbol: symbol,
                shares: shares,
                averageCost: averageCost,
                stock: stock
            )
            
            portfolio.positions.append(position)
            portfolio.totalInvested += shares * averageCost
            portfolio.lastUpdated = Date()
            
            try modelContext.save()
            
            // Reload positions
            positions = portfolio.positions
            
        } catch {
            errorMessage = "Failed to add position: \(error.localizedDescription)"
        }
    }
    
    func updatePosition(
        position: Position,
        shares: Double? = nil,
        averageCost: Double? = nil,
        modelContext: ModelContext
    ) {
        if let newShares = shares {
            position.shares = newShares
        }
        if let newCost = averageCost {
            position.averageCost = newCost
        }
        
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to update position: \(error.localizedDescription)"
        }
    }
    
    func removePosition(_ position: Position, modelContext: ModelContext) {
        guard let portfolio = portfolio,
              let index = portfolio.positions.firstIndex(where: { $0.id == position.id }) else {
            return
        }
        
        portfolio.positions.remove(at: index)
        modelContext.delete(position)
        
        do {
            try modelContext.save()
            positions = portfolio.positions
        } catch {
            errorMessage = "Failed to remove position: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Trading
    
    func executeBuy(
        symbol: String,
        shares: Double,
        price: Double,
        modelContext: ModelContext
    ) async {
        guard let portfolio = portfolio else { return }
        
        let totalCost = shares * price
        
        guard portfolio.cashBalance >= totalCost else {
            errorMessage = "Insufficient cash balance"
            return
        }
        
        // Check if we already have a position
        if let existingPosition = positions.first(where: { $0.symbol == symbol }) {
            // Average in
            let totalShares = existingPosition.shares + shares
            let totalValue = (existingPosition.shares * existingPosition.averageCost) + (shares * price)
            let newAverageCost = totalValue / totalShares
            
            existingPosition.shares = totalShares
            existingPosition.averageCost = newAverageCost
        } else {
            // New position
            await addPosition(
                symbol: symbol,
                shares: shares,
                averageCost: price,
                modelContext: modelContext
            )
        }
        
        // Update cash
        portfolio.cashBalance -= totalCost
        portfolio.totalInvested += totalCost
        
        // Record trade
        let trade = TradeHistory(
            symbol: symbol,
            action: .buy,
            shares: shares,
            price: price,
            broker: portfolio.broker
        )
        modelContext.insert(trade)
        
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to record trade: \(error.localizedDescription)"
        }
    }
    
    func executeSell(
        position: Position,
        shares: Double,
        price: Double,
        modelContext: ModelContext
    ) {
        guard let portfolio = portfolio else { return }
        
        guard position.shares >= shares else {
            errorMessage = "Cannot sell more shares than owned"
            return
        }
        
        let proceeds = shares * price
        
        if position.shares == shares {
            // Full sale
            removePosition(position, modelContext: modelContext)
        } else {
            // Partial sale
            position.shares -= shares
        }
        
        // Update cash
        portfolio.cashBalance += proceeds
        
        // Record trade
        let trade = TradeHistory(
            symbol: position.symbol,
            action: .sell,
            shares: shares,
            price: price,
            broker: portfolio.broker
        )
        modelContext.insert(trade)
        
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to record trade: \(error.localizedDescription)"
        }
    }
}
