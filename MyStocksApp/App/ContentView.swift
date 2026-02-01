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
    @State private var showImportSheet = false
    @State private var importCSVData: String = ""
    
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
            // Navigate to market tab when stock notification received
            if notification.userInfo?["symbol"] is String {
                selectedTab = .market
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToAlert)) { _ in
            selectedTab = .alerts
        }
        .onReceive(NotificationCenter.default.publisher(for: .importCSVFile)) { notification in
            // Handle file import from share sheet
            if let contents = notification.userInfo?["contents"] as? String {
                importCSVData = contents
                selectedTab = .portfolio
                showImportSheet = true
            }
        }
        .onChange(of: appState.showImportSheet) { _, newValue in
            if newValue {
                importCSVData = appState.pendingImportData ?? ""
                selectedTab = .portfolio
                showImportSheet = true
                appState.showImportSheet = false
                appState.pendingImportData = nil
            }
        }
        .sheet(isPresented: $showImportSheet) {
            PortfolioImportView(prefilledCSV: importCSVData)
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environment(AppState())
}
