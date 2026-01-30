//
//  Alert.swift
//  MyStocksApp
//
//  Trading alerts and recommendations
//

import Foundation
import SwiftData

@Model
final class Alert {
    // MARK: - Identifiers
    @Attribute(.unique) var id: UUID
    
    // MARK: - Alert Details
    var stock: Stock?
    var symbol: String
    var alertType: AlertType
    var confidence: Int // 0-100
    var urgency: AlertUrgency
    
    // MARK: - Price Context
    var triggerPrice: Double
    var currentPrice: Double
    var targetPrice: Double?
    var stopLossPrice: Double?
    
    // MARK: - Analysis
    var reason: String
    var technicalSignals: [String]
    var fundamentalFactors: [String]
    var newsContext: String?
    
    // MARK: - Suggested Action
    var suggestedShares: Int?
    var suggestedAmount: Double?
    var positionSizePercent: Double?
    
    // MARK: - Timing
    var createdAt: Date
    var expiresAt: Date?
    var acknowledgedAt: Date?
    var executedAt: Date?
    
    // MARK: - Status
    var status: AlertStatus
    var userFeedback: AlertFeedback?
    
    // MARK: - Pattern (if pattern-based alert)
    var patternName: String?
    var patternConfidence: Int?
    
    // MARK: - Computed Properties
    var isActive: Bool {
        status == .active && (expiresAt == nil || expiresAt! > Date())
    }
    
    var isExpired: Bool {
        if let expiresAt = expiresAt {
            return expiresAt < Date()
        }
        return false
    }
    
    var confidenceStars: String {
        let stars = confidence / 20 // 0-5 stars
        return String(repeating: "⭐", count: min(5, max(1, stars)))
    }
    
    var potentialUpside: Double? {
        guard let target = targetPrice, currentPrice > 0 else { return nil }
        return ((target - currentPrice) / currentPrice) * 100
    }
    
    var potentialDownside: Double? {
        guard let stopLoss = stopLossPrice, currentPrice > 0 else { return nil }
        return ((currentPrice - stopLoss) / currentPrice) * 100
    }
    
    var riskRewardRatio: Double? {
        guard let upside = potentialUpside, let downside = potentialDownside, downside > 0 else { return nil }
        return upside / downside
    }
    
    var formattedTitle: String {
        "\(alertType.emoji) \(alertType.rawValue): \(symbol)"
    }
    
    var shortDescription: String {
        switch alertType {
        case .noBrainerBuy:
            return "Exceptional opportunity - \(confidence)% confidence"
        case .strongBuy:
            return "High conviction entry point"
        case .buy:
            return "Good buying opportunity"
        case .hold:
            return "Maintain current position"
        case .reduce:
            return "Consider taking partial profits"
        case .sell:
            return "Exit position recommended"
        case .stopLossTriggered:
            return "Stop loss level breached"
        case .targetReached:
            return "Price target achieved"
        case .patternDetected:
            return "Chart pattern: \(patternName ?? "Unknown")"
        case .earningsAlert:
            return "Upcoming earnings announcement"
        case .newsAlert:
            return "Breaking news affecting stock"
        }
    }
    
    // MARK: - Initializer
    init(
        symbol: String,
        alertType: AlertType,
        confidence: Int,
        urgency: AlertUrgency = .medium,
        triggerPrice: Double,
        currentPrice: Double,
        reason: String,
        stock: Stock? = nil
    ) {
        self.id = UUID()
        self.symbol = symbol
        self.alertType = alertType
        self.confidence = min(100, max(0, confidence))
        self.urgency = urgency
        self.triggerPrice = triggerPrice
        self.currentPrice = currentPrice
        self.reason = reason
        self.stock = stock
        self.technicalSignals = []
        self.fundamentalFactors = []
        self.createdAt = Date()
        self.status = .active
        
        // Set expiration based on urgency
        switch urgency {
        case .critical:
            self.expiresAt = Calendar.current.date(byAdding: .hour, value: 4, to: Date())
        case .high:
            self.expiresAt = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        case .medium:
            self.expiresAt = Calendar.current.date(byAdding: .day, value: 3, to: Date())
        case .low:
            self.expiresAt = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        }
    }
}

// MARK: - Alert Type
enum AlertType: String, Codable, CaseIterable {
    case noBrainerBuy = "NO-BRAINER BUY"
    case strongBuy = "STRONG BUY"
    case buy = "BUY"
    case hold = "HOLD"
    case reduce = "REDUCE"
    case sell = "SELL"
    case stopLossTriggered = "STOP LOSS"
    case targetReached = "TARGET REACHED"
    case patternDetected = "PATTERN"
    case earningsAlert = "EARNINGS"
    case newsAlert = "NEWS"
    
    var emoji: String {
        switch self {
        case .noBrainerBuy: return "🚨"
        case .strongBuy: return "🟢"
        case .buy: return "🟡"
        case .hold: return "⚪"
        case .reduce: return "🟠"
        case .sell: return "🔴"
        case .stopLossTriggered: return "🛑"
        case .targetReached: return "🎯"
        case .patternDetected: return "📊"
        case .earningsAlert: return "📅"
        case .newsAlert: return "📰"
        }
    }
    
    var priority: Int {
        switch self {
        case .noBrainerBuy: return 10
        case .strongBuy: return 9
        case .stopLossTriggered: return 8
        case .sell: return 7
        case .buy: return 6
        case .reduce: return 5
        case .targetReached: return 4
        case .patternDetected: return 3
        case .earningsAlert: return 2
        case .newsAlert: return 2
        case .hold: return 1
        }
    }
    
    var actionRequired: Bool {
        switch self {
        case .noBrainerBuy, .strongBuy, .sell, .stopLossTriggered:
            return true
        default:
            return false
        }
    }
}

// MARK: - Alert Urgency
enum AlertUrgency: String, Codable, CaseIterable {
    case critical = "CRITICAL"
    case high = "HIGH"
    case medium = "MEDIUM"
    case low = "LOW"
    
    var color: String {
        switch self {
        case .critical: return "red"
        case .high: return "orange"
        case .medium: return "yellow"
        case .low: return "gray"
        }
    }
    
    var notificationSound: String {
        switch self {
        case .critical: return "alarm.wav"
        case .high: return "alert_high.wav"
        case .medium: return "notification.wav"
        case .low: return "subtle.wav"
        }
    }
}

// MARK: - Alert Status
enum AlertStatus: String, Codable {
    case active = "ACTIVE"
    case acknowledged = "ACKNOWLEDGED"
    case executed = "EXECUTED"
    case expired = "EXPIRED"
    case dismissed = "DISMISSED"
}

// MARK: - Alert Feedback
enum AlertFeedback: String, Codable {
    case agreed = "AGREED"
    case disagreed = "DISAGREED"
    case executed = "EXECUTED"
    case tooLate = "TOO_LATE"
    case wrongTiming = "WRONG_TIMING"
}

// MARK: - Trading Alert (for push notifications)
struct TradingAlert: Codable, Identifiable {
    let id: UUID
    let symbol: String
    let alertType: AlertType
    let confidence: Int
    let urgency: AlertUrgency
    let currentPrice: Double
    let reason: String
    let timestamp: Date
    
    var title: String {
        "\(alertType.emoji) \(alertType.rawValue): \(symbol)"
    }
    
    var body: String {
        "\(reason) (Confidence: \(confidence)%)"
    }
}
