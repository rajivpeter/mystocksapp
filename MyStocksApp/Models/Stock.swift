//
//  Stock.swift
//  MyStocksApp
//
//  Stock data model with real-time price data
//

import Foundation
import SwiftData

@Model
final class Stock {
    // MARK: - Identifiers
    @Attribute(.unique) var symbol: String
    var name: String
    var exchange: String
    var currency: Currency
    var sector: String?
    var industry: String?
    
    // MARK: - Price Data
    var currentPrice: Double
    var previousClose: Double
    var open: Double
    var high: Double
    var low: Double
    var volume: Int64
    var averageVolume: Int64
    
    // MARK: - Historical Performance
    var change1D: Double
    var change1W: Double
    var change1M: Double
    var change3M: Double
    var change1Y: Double
    var change3Y: Double
    var change5Y: Double
    
    // MARK: - Valuation Metrics
    var marketCap: Double?
    var peRatio: Double?
    var pegRatio: Double?
    var priceToBook: Double?
    var dividendYield: Double?
    var fairValue: Double?
    
    // MARK: - Technical Indicators
    var rsi14: Double?
    var macd: Double?
    var macdSignal: Double?
    var sma20: Double?
    var sma50: Double?
    var sma200: Double?
    var bollingerUpper: Double?
    var bollingerLower: Double?
    
    // MARK: - 52-Week Range
    var high52Week: Double
    var low52Week: Double
    
    // MARK: - Metadata
    var lastUpdated: Date
    var logoURL: String?
    var websiteURL: String?
    
    // MARK: - Relationships
    @Relationship(deleteRule: .cascade, inverse: \Position.stock)
    var positions: [Position]?
    
    @Relationship(deleteRule: .cascade, inverse: \Alert.stock)
    var alerts: [Alert]?
    
    @Relationship(deleteRule: .cascade, inverse: \Prediction.stock)
    var predictions: [Prediction]?
    
    // MARK: - Computed Properties
    var changePercent: Double {
        guard previousClose > 0 else { return 0 }
        return ((currentPrice - previousClose) / previousClose) * 100
    }
    
    var changeAmount: Double {
        currentPrice - previousClose
    }
    
    var isPositive: Bool {
        changeAmount >= 0
    }
    
    var currencySymbol: String {
        currency.symbol
    }
    
    var formattedPrice: String {
        "\(currencySymbol)\(currentPrice.formatted(.number.precision(.fractionLength(2))))"
    }
    
    var formattedChange: String {
        let sign = changeAmount >= 0 ? "+" : ""
        return "\(sign)\(currencySymbol)\(changeAmount.formatted(.number.precision(.fractionLength(2))))"
    }
    
    var formattedChangePercent: String {
        let sign = changePercent >= 0 ? "+" : ""
        return "\(sign)\(changePercent.formatted(.number.precision(.fractionLength(2))))%"
    }
    
    var percentFrom52WeekHigh: Double {
        guard high52Week > 0 else { return 0 }
        return ((currentPrice - high52Week) / high52Week) * 100
    }
    
    var percentFrom52WeekLow: Double {
        guard low52Week > 0 else { return 0 }
        return ((currentPrice - low52Week) / low52Week) * 100
    }
    
    var fairValueUpside: Double? {
        guard let fv = fairValue, fv > 0 else { return nil }
        return ((fv - currentPrice) / currentPrice) * 100
    }
    
    var technicalSignal: TechnicalSignal {
        // Simple technical signal based on RSI and moving averages
        guard let rsi = rsi14 else { return .neutral }
        
        if rsi < 30 {
            return .oversold
        } else if rsi > 70 {
            return .overbought
        } else if let sma50 = sma50, currentPrice > sma50 {
            return .bullish
        } else if let sma50 = sma50, currentPrice < sma50 {
            return .bearish
        }
        return .neutral
    }
    
    // MARK: - Initializer
    init(
        symbol: String,
        name: String,
        exchange: String = "UNKNOWN",
        currency: Currency = .gbp,
        currentPrice: Double = 0,
        previousClose: Double = 0,
        open: Double = 0,
        high: Double = 0,
        low: Double = 0,
        volume: Int64 = 0,
        averageVolume: Int64 = 0,
        high52Week: Double = 0,
        low52Week: Double = 0
    ) {
        self.symbol = symbol
        self.name = name
        self.exchange = exchange
        self.currency = currency
        self.currentPrice = currentPrice
        self.previousClose = previousClose
        self.open = open
        self.high = high
        self.low = low
        self.volume = volume
        self.averageVolume = averageVolume
        self.high52Week = high52Week
        self.low52Week = low52Week
        self.change1D = 0
        self.change1W = 0
        self.change1M = 0
        self.change3M = 0
        self.change1Y = 0
        self.change3Y = 0
        self.change5Y = 0
        self.lastUpdated = Date()
    }
}

// MARK: - Currency
enum Currency: String, Codable, CaseIterable {
    case gbp = "GBP"
    case usd = "USD"
    case eur = "EUR"
    
    var symbol: String {
        switch self {
        case .gbp: return "£"
        case .usd: return "$"
        case .eur: return "€"
        }
    }
    
    var exchangeRate: Double {
        // Exchange rate to GBP (base currency)
        switch self {
        case .gbp: return 1.0
        case .usd: return 0.79
        case .eur: return 0.86
        }
    }
}

// MARK: - Technical Signal
enum TechnicalSignal: String, Codable {
    case strongBuy = "STRONG BUY"
    case bullish = "BULLISH"
    case neutral = "NEUTRAL"
    case bearish = "BEARISH"
    case strongSell = "STRONG SELL"
    case oversold = "OVERSOLD"
    case overbought = "OVERBOUGHT"
    
    var color: String {
        switch self {
        case .strongBuy, .oversold: return "green"
        case .bullish: return "lightGreen"
        case .neutral: return "gray"
        case .bearish: return "orange"
        case .strongSell, .overbought: return "red"
        }
    }
    
    var emoji: String {
        switch self {
        case .strongBuy: return "🚀"
        case .bullish: return "🟢"
        case .neutral: return "⚪"
        case .bearish: return "🟠"
        case .strongSell: return "🔴"
        case .oversold: return "💰"
        case .overbought: return "⚠️"
        }
    }
}

// MARK: - Stock Extensions for Morningstar Links
extension Stock {
    var morningstarURL: URL? {
        switch currency {
        case .gbp:
            return URL(string: "https://www.morningstar.co.uk/uk/stocks/\(symbol)")
        case .usd:
            return URL(string: "https://www.morningstar.com/stocks/xnas/\(symbol)/quote")
        case .eur:
            return URL(string: "https://www.morningstar.co.uk/uk/stocks/\(symbol)")
        }
    }
    
    var yahooFinanceURL: URL? {
        URL(string: "https://finance.yahoo.com/quote/\(symbol)")
    }
    
    var tradingViewURL: URL? {
        URL(string: "https://www.tradingview.com/symbols/\(exchange)-\(symbol)/")
    }
}
