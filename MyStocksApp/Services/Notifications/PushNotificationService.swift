//
//  PushNotificationService.swift
//  MyStocksApp
//
//  Push notification service for trading alerts
//

import Foundation
import UserNotifications
import UIKit

@Observable
class PushNotificationService: NSObject {
    static let shared = PushNotificationService()
    
    var deviceToken: String?
    var isAuthorized = false
    var pendingAlerts: [TradingAlert] = []
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private override init() {
        super.init()
        notificationCenter.delegate = self
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                
                if granted {
                    self.registerForRemoteNotifications()
                }
                
                if let error = error {
                    print("❌ Notification authorization error: \(error)")
                }
            }
        }
    }
    
    private func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    func handleDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = token
        
        // Send token to backend
        Task {
            await registerTokenWithBackend(token)
        }
        
        print("📱 Device token: \(token)")
    }
    
    private func registerTokenWithBackend(_ token: String) async {
        // Register with your push notification backend
        // This would send the token to your server
    }
    
    // MARK: - Local Notifications
    
    /// Schedule a trading alert notification
    func scheduleAlertNotification(_ alert: TradingAlert) {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.sound = soundForUrgency(alert.urgency)
        content.categoryIdentifier = "TRADING_ALERT"
        content.userInfo = [
            "alertId": alert.id.uuidString,
            "symbol": alert.symbol,
            "alertType": alert.alertType.rawValue
        ]
        
        // Add action buttons
        if alert.alertType.actionRequired {
            content.categoryIdentifier = "URGENT_TRADING_ALERT"
        }
        
        // Immediate notification
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: alert.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule notification: \(error)")
            } else {
                print("✅ Alert notification scheduled: \(alert.symbol)")
            }
        }
    }
    
    /// Schedule a price alert
    func schedulePriceAlert(symbol: String, price: Double, direction: PriceAlertDirection) {
        let content = UNMutableNotificationContent()
        content.title = "\(direction.emoji) Price Alert: \(symbol)"
        content.body = "\(symbol) has \(direction.verb) \(price.formatted(.currency(code: "GBP")))"
        content.sound = .default
        content.categoryIdentifier = "PRICE_ALERT"
        content.userInfo = ["symbol": symbol]
        
        let request = UNNotificationRequest(
            identifier: "\(symbol)-\(direction.rawValue)-\(Int(price))",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request)
    }
    
    /// Schedule a pattern detection notification
    func schedulePatternNotification(symbol: String, patternName: String, confidence: Int) {
        let content = UNMutableNotificationContent()
        content.title = "📊 Pattern Detected: \(patternName)"
        content.body = "\(patternName) pattern found on \(symbol) with \(confidence)% confidence"
        content.sound = .default
        content.categoryIdentifier = "PATTERN_ALERT"
        content.userInfo = ["symbol": symbol, "pattern": patternName]
        
        let request = UNNotificationRequest(
            identifier: "\(symbol)-pattern-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request)
    }
    
    // MARK: - Categories
    
    func setupNotificationCategories() {
        // Urgent trading alert actions
        let viewAction = UNNotificationAction(
            identifier: "VIEW_ACTION",
            title: "View Details",
            options: .foreground
        )
        
        let tradeAction = UNNotificationAction(
            identifier: "TRADE_ACTION",
            title: "Open Broker",
            options: .foreground
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_ACTION",
            title: "Dismiss",
            options: .destructive
        )
        
        let urgentCategory = UNNotificationCategory(
            identifier: "URGENT_TRADING_ALERT",
            actions: [viewAction, tradeAction, dismissAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        let tradingCategory = UNNotificationCategory(
            identifier: "TRADING_ALERT",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        let priceCategory = UNNotificationCategory(
            identifier: "PRICE_ALERT",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        let patternCategory = UNNotificationCategory(
            identifier: "PATTERN_ALERT",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([
            urgentCategory,
            tradingCategory,
            priceCategory,
            patternCategory
        ])
    }
    
    // MARK: - Helpers
    
    private func soundForUrgency(_ urgency: AlertUrgency) -> UNNotificationSound {
        switch urgency {
        case .critical:
            // Use critical alert sound (requires entitlement)
            return UNNotificationSound.defaultCritical
        case .high:
            return UNNotificationSound(named: UNNotificationSoundName("alert_high.wav"))
        case .medium:
            return .default
        case .low:
            return UNNotificationSound(named: UNNotificationSoundName("subtle.wav"))
        }
    }
    
    /// Clear all pending notifications
    func clearAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }
    
    /// Get pending notifications count
    func getPendingCount() async -> Int {
        let requests = await notificationCenter.pendingNotificationRequests()
        return requests.count
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "VIEW_ACTION":
            if let symbol = userInfo["symbol"] as? String {
                NotificationCenter.default.post(
                    name: .navigateToStock,
                    object: nil,
                    userInfo: ["symbol": symbol]
                )
            }
        case "TRADE_ACTION":
            if let symbol = userInfo["symbol"] as? String {
                // Open broker app or trading view
                openBrokerForSymbol(symbol)
            }
        case UNNotificationDefaultActionIdentifier:
            // User tapped notification
            if let alertId = userInfo["alertId"] as? String {
                NotificationCenter.default.post(
                    name: .navigateToAlert,
                    object: nil,
                    userInfo: ["alertId": alertId]
                )
            }
        default:
            break
        }
        
        completionHandler()
    }
    
    private func openBrokerForSymbol(_ symbol: String) {
        // Try to open IG app
        if let igURL = URL(string: "ig://"),
           UIApplication.shared.canOpenURL(igURL) {
            UIApplication.shared.open(igURL)
        }
        // Or open ii app
        else if let iiURL = URL(string: "interactiveinvestor://"),
                UIApplication.shared.canOpenURL(iiURL) {
            UIApplication.shared.open(iiURL)
        }
    }
}

// MARK: - Price Alert Direction

enum PriceAlertDirection: String {
    case above = "ABOVE"
    case below = "BELOW"
    
    var emoji: String {
        switch self {
        case .above: return "📈"
        case .below: return "📉"
        }
    }
    
    var verb: String {
        switch self {
        case .above: return "risen above"
        case .below: return "dropped below"
        }
    }
}
