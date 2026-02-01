//
//  MyStocksAppApp.swift
//  MyStocksApp
//
//  Created by Rajiv Peter
//  AI-Powered iOS Investment Advisor
//

import SwiftUI
import SwiftData

@main
struct MyStocksAppApp: App {
    // MARK: - State
    @State private var appState = AppState()
    
    // MARK: - Services
    private let notificationService = PushNotificationService.shared
    
    // MARK: - SwiftData Configuration
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Stock.self,
            Portfolio.self,
            Position.self,
            Alert.self,
            ChartPattern.self,
            Prediction.self,
            WatchlistItem.self,
            TradeHistory.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .onAppear {
                    setupApp()
                }
                .onOpenURL { url in
                    handleOpenURL(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    // MARK: - Handle File Open
    private func handleOpenURL(_ url: URL) {
        print("📁 Received file: \(url.lastPathComponent)")
        
        // Check if it's a CSV or text file
        let fileExtension = url.pathExtension.lowercased()
        guard ["csv", "txt"].contains(fileExtension) else {
            print("⚠️ Unsupported file type: \(fileExtension)")
            return
        }
        
        // Read the file and post notification for import
        do {
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess { url.stopAccessingSecurityScopedResource() }
            }
            
            let contents = try String(contentsOf: url, encoding: .utf8)
            
            // Post notification with file contents for import view
            NotificationCenter.default.post(
                name: .importCSVFile,
                object: nil,
                userInfo: ["contents": contents, "filename": url.lastPathComponent]
            )
            
            // Navigate to portfolio import
            appState.pendingImportData = contents
            appState.showImportSheet = true
            
            print("✅ File contents ready for import (\(contents.count) characters)")
        } catch {
            print("❌ Failed to read file: \(error)")
        }
    }
    
    // MARK: - Setup
    private func setupApp() {
        // Request notification permissions
        notificationService.requestAuthorization()
        
        // Setup background refresh
        setupBackgroundTasks()
        
        // Initialize ML models
        Task {
            await MLModelManager.shared.loadModels()
        }
    }
    
    private func setupBackgroundTasks() {
        // Register for background app refresh
        // This enables price monitoring even when app is in background
    }
}

// MARK: - App State
@Observable
class AppState {
    var isAuthenticated = false
    var selectedTab: AppTab = .portfolio
    var showingAlert = false
    var currentAlert: TradingAlert?
    var isLoading = false
    var errorMessage: String?
    
    // Theme
    var isDarkMode = true
    var accentColor = Color.green
    
    // User preferences
    var showPriceChangesAsPercentage = true
    var enableHapticFeedback = true
    var notificationsEnabled = true
    
    // Currency settings
    var displayCurrency: Currency = .gbp  // Main display currency for totals
    var showNativeCurrency = true         // Show stocks in their native currency on detail pages
    
    // Import from file
    var pendingImportData: String?
    var showImportSheet = false
    
    func handleDeepLink(_ url: URL) {
        // Handle deep links from notifications or widgets
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }
        
        switch components.host {
        case "stock":
            if let symbol = components.queryItems?.first(where: { $0.name == "symbol" })?.value {
                // Navigate to stock detail
                NotificationCenter.default.post(
                    name: .navigateToStock,
                    object: nil,
                    userInfo: ["symbol": symbol]
                )
            }
        case "alert":
            if let alertId = components.queryItems?.first(where: { $0.name == "id" })?.value {
                // Navigate to alert detail
                NotificationCenter.default.post(
                    name: .navigateToAlert,
                    object: nil,
                    userInfo: ["alertId": alertId]
                )
            }
        case "portfolio":
            selectedTab = .portfolio
        default:
            break
        }
    }
}

// MARK: - App Tab
enum AppTab: String, CaseIterable {
    case portfolio = "Portfolio"
    case market = "Market"
    case alerts = "Alerts"
    case education = "Learn"
    case settings = "Settings"
    
    var icon: String {
        switch self {
        case .portfolio: return "chart.pie.fill"
        case .market: return "chart.line.uptrend.xyaxis"
        case .alerts: return "bell.badge.fill"
        case .education: return "graduationcap.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let navigateToStock = Notification.Name("navigateToStock")
    static let navigateToAlert = Notification.Name("navigateToAlert")
    static let priceAlert = Notification.Name("priceAlert")
    static let patternDetected = Notification.Name("patternDetected")
    static let importCSVFile = Notification.Name("importCSVFile")
}
