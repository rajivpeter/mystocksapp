//
//  LiveActivityManager.swift
//  MyStocksApp
//
//  Live Activities for real-time stock prices on Lock Screen & Dynamic Island
//

import Foundation
import ActivityKit

// Note: Live Activities require iOS 16.1+ and proper entitlements

@Observable
class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private var currentActivities: [String: Activity<StockPriceAttributes>] = [:]
    
    private init() {}
    
    // MARK: - Start Activity
    
    /// Start a live activity for a stock
    func startStockPriceActivity(
        symbol: String,
        name: String,
        currentPrice: Double,
        previousClose: Double,
        currency: String = "GBP"
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ Live Activities are not enabled")
            return
        }
        
        let attributes = StockPriceAttributes(
            symbol: symbol,
            name: name,
            currency: currency
        )
        
        let change = currentPrice - previousClose
        let changePercent = previousClose > 0 ? (change / previousClose) * 100 : 0
        
        let initialState = StockPriceAttributes.ContentState(
            currentPrice: currentPrice,
            priceChange: change,
            priceChangePercent: changePercent,
            lastUpdated: Date()
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: .token // Enable server push updates
            )
            
            currentActivities[symbol] = activity
            
            // Get push token for server updates
            Task {
                for await pushToken in activity.pushTokenUpdates {
                    let tokenString = pushToken.map { String(format: "%02x", $0) }.joined()
                    print("📱 Live Activity push token for \(symbol): \(tokenString)")
                    
                    // Send to backend for server-side updates
                    await sendPushTokenToBackend(symbol: symbol, token: tokenString)
                }
            }
            
            print("✅ Started Live Activity for \(symbol)")
        } catch {
            print("❌ Failed to start Live Activity: \(error)")
        }
    }
    
    // MARK: - Update Activity
    
    /// Update an existing live activity
    func updateStockPrice(
        symbol: String,
        currentPrice: Double,
        previousClose: Double
    ) async {
        guard let activity = currentActivities[symbol] else {
            print("⚠️ No Live Activity found for \(symbol)")
            return
        }
        
        let change = currentPrice - previousClose
        let changePercent = previousClose > 0 ? (change / previousClose) * 100 : 0
        
        let updatedState = StockPriceAttributes.ContentState(
            currentPrice: currentPrice,
            priceChange: change,
            priceChangePercent: changePercent,
            lastUpdated: Date()
        )
        
        await activity.update(
            ActivityContent(
                state: updatedState,
                staleDate: Calendar.current.date(byAdding: .minute, value: 5, to: Date())
            )
        )
        
        print("✅ Updated Live Activity for \(symbol): \(currentPrice)")
    }
    
    // MARK: - End Activity
    
    /// End a live activity
    func endStockPriceActivity(symbol: String) async {
        guard let activity = currentActivities[symbol] else { return }
        
        let finalState = activity.content.state
        
        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )
        
        currentActivities.removeValue(forKey: symbol)
        print("✅ Ended Live Activity for \(symbol)")
    }
    
    /// End all activities
    func endAllActivities() async {
        for symbol in currentActivities.keys {
            await endStockPriceActivity(symbol: symbol)
        }
    }
    
    // MARK: - Alert Activity
    
    /// Start an alert live activity
    func startAlertActivity(alert: TradingAlert) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let attributes = AlertActivityAttributes(
            symbol: alert.symbol,
            alertType: alert.alertType.rawValue
        )
        
        let initialState = AlertActivityAttributes.ContentState(
            message: alert.reason,
            confidence: alert.confidence,
            timestamp: Date()
        )
        
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            
            print("✅ Started Alert Live Activity for \(alert.symbol)")
        } catch {
            print("❌ Failed to start Alert Live Activity: \(error)")
        }
    }
    
    // MARK: - Helper
    
    private func sendPushTokenToBackend(symbol: String, token: String) async {
        // Send the push token to your backend server
        // The server will use this to send Live Activity updates
    }
    
    /// Check if activities are supported
    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }
    
    /// Get active symbols
    var activeSymbols: [String] {
        Array(currentActivities.keys)
    }
}

// MARK: - Stock Price Attributes

struct StockPriceAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentPrice: Double
        var priceChange: Double
        var priceChangePercent: Double
        var lastUpdated: Date
        
        var isPositive: Bool { priceChange >= 0 }
        
        var formattedPrice: String {
            String(format: "%.2f", currentPrice)
        }
        
        var formattedChange: String {
            let sign = priceChange >= 0 ? "+" : ""
            return "\(sign)\(String(format: "%.2f", priceChange))"
        }
        
        var formattedChangePercent: String {
            let sign = priceChangePercent >= 0 ? "+" : ""
            return "\(sign)\(String(format: "%.2f", priceChangePercent))%"
        }
    }
    
    var symbol: String
    var name: String
    var currency: String
    
    var currencySymbol: String {
        switch currency {
        case "GBP": return "£"
        case "USD": return "$"
        case "EUR": return "€"
        default: return currency
        }
    }
}

// MARK: - Alert Activity Attributes

struct AlertActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var message: String
        var confidence: Int
        var timestamp: Date
    }
    
    var symbol: String
    var alertType: String
}
