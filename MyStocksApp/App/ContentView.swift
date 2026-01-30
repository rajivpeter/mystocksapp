//
//  ContentView.swift
//  MyStocksApp
//
//  Main content view with tab navigation
//

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: AppTab = .portfolio
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Portfolio Tab
            PortfolioView()
                .tabItem {
                    Label(AppTab.portfolio.rawValue, systemImage: AppTab.portfolio.icon)
                }
                .tag(AppTab.portfolio)
            
            // Market Tab
            MarketView()
                .tabItem {
                    Label(AppTab.market.rawValue, systemImage: AppTab.market.icon)
                }
                .tag(AppTab.market)
            
            // Alerts Tab
            AlertsView()
                .tabItem {
                    Label(AppTab.alerts.rawValue, systemImage: AppTab.alerts.icon)
                }
                .tag(AppTab.alerts)
                .badge(appState.currentAlert != nil ? 1 : 0)
            
            // Education Tab
            EducationView()
                .tabItem {
                    Label(AppTab.education.rawValue, systemImage: AppTab.education.icon)
                }
                .tag(AppTab.education)
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Label(AppTab.settings.rawValue, systemImage: AppTab.settings.icon)
                }
                .tag(AppTab.settings)
        }
        .tint(.brandPrimary)
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: .navigateToStock)) { notification in
            if let symbol = notification.userInfo?["symbol"] as? String {
                // Handle navigation to stock
                selectedTab = .market
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToAlert)) { _ in
            selectedTab = .alerts
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environment(AppState())
}
