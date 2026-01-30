//
//  SettingsView.swift
//  MyStocksApp
//
//  App settings and broker configuration
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    
    @State private var notificationsEnabled = true
    @State private var urgentAlertsEnabled = true
    @State private var priceAlertsEnabled = true
    @State private var patternAlertsEnabled = true
    @State private var hapticFeedbackEnabled = true
    @State private var liveActivitiesEnabled = true
    
    @State private var showingIGLogin = false
    @State private var showingAPIKeys = false
    @State private var showingAbout = false
    
    private let igService = IGTradingService.shared
    
    var body: some View {
        NavigationStack {
            List {
                // Account Section
                Section("Account") {
                    NavigationLink {
                        BrokerSettingsView()
                    } label: {
                        SettingsRow(
                            icon: "building.columns.fill",
                            title: "Broker Connections",
                            subtitle: igService.isAuthenticated ? "IG Connected" : "Not connected",
                            color: .blue
                        )
                    }
                    
                    NavigationLink {
                        PortfolioSettingsView()
                    } label: {
                        SettingsRow(
                            icon: "chart.pie.fill",
                            title: "Portfolio Settings",
                            subtitle: "Manage accounts & positions",
                            color: .green
                        )
                    }
                }
                
                // Notifications Section
                Section("Notifications") {
                    Toggle(isOn: $notificationsEnabled) {
                        SettingsRow(
                            icon: "bell.fill",
                            title: "Push Notifications",
                            color: .orange
                        )
                    }
                    
                    if notificationsEnabled {
                        Toggle(isOn: $urgentAlertsEnabled) {
                            SettingsRow(
                                icon: "exclamationmark.triangle.fill",
                                title: "Urgent Alerts",
                                subtitle: "No-brainer opportunities",
                                color: .red
                            )
                        }
                        
                        Toggle(isOn: $priceAlertsEnabled) {
                            SettingsRow(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "Price Alerts",
                                subtitle: "Target & stop loss triggers",
                                color: .green
                            )
                        }
                        
                        Toggle(isOn: $patternAlertsEnabled) {
                            SettingsRow(
                                icon: "chart.bar.doc.horizontal",
                                title: "Pattern Alerts",
                                subtitle: "Chart pattern detection",
                                color: .purple
                            )
                        }
                    }
                }
                
                // iOS Features Section
                Section("iOS Features") {
                    Toggle(isOn: $liveActivitiesEnabled) {
                        SettingsRow(
                            icon: "iphone.radiowaves.left.and.right",
                            title: "Live Activities",
                            subtitle: "Real-time prices on Lock Screen",
                            color: .blue
                        )
                    }
                    
                    Toggle(isOn: $hapticFeedbackEnabled) {
                        SettingsRow(
                            icon: "hand.tap.fill",
                            title: "Haptic Feedback",
                            subtitle: "Vibration for alerts",
                            color: .gray
                        )
                    }
                    
                    NavigationLink {
                        WidgetSettingsView()
                    } label: {
                        SettingsRow(
                            icon: "square.grid.2x2.fill",
                            title: "Widget Settings",
                            subtitle: "Home screen widgets",
                            color: .cyan
                        )
                    }
                }
                
                // Data Section
                Section("Data & API") {
                    NavigationLink {
                        APIKeysView()
                    } label: {
                        SettingsRow(
                            icon: "key.fill",
                            title: "API Keys",
                            subtitle: "Market data providers",
                            color: .yellow
                        )
                    }
                    
                    NavigationLink {
                        DataExportView()
                    } label: {
                        SettingsRow(
                            icon: "square.and.arrow.up.fill",
                            title: "Export Data",
                            subtitle: "Portfolio & trade history",
                            color: .mint
                        )
                    }
                    
                    Button(action: clearCache) {
                        SettingsRow(
                            icon: "trash.fill",
                            title: "Clear Cache",
                            subtitle: "Remove cached data",
                            color: .red
                        )
                    }
                }
                
                // ML Section
                Section("AI & Predictions") {
                    NavigationLink {
                        MLSettingsView()
                    } label: {
                        SettingsRow(
                            icon: "brain.head.profile",
                            title: "ML Models",
                            subtitle: "Prediction settings",
                            color: .purple
                        )
                    }
                    
                    NavigationLink {
                        AlertPreferencesView()
                    } label: {
                        SettingsRow(
                            icon: "slider.horizontal.3",
                            title: "Alert Preferences",
                            subtitle: "Confidence thresholds",
                            color: .indigo
                        )
                    }
                }
                
                // About Section
                Section("About") {
                    NavigationLink {
                        AboutView()
                    } label: {
                        SettingsRow(
                            icon: "info.circle.fill",
                            title: "About",
                            subtitle: "Version 1.0.0",
                            color: .gray
                        )
                    }
                    
                    Link(destination: URL(string: "https://github.com/rajivpeter/mystocksapp")!) {
                        SettingsRow(
                            icon: "link",
                            title: "GitHub Repository",
                            color: .black
                        )
                    }
                    
                    Link(destination: URL(string: "https://twitter.com/mystocksapp")!) {
                        SettingsRow(
                            icon: "bubble.left.fill",
                            title: "Send Feedback",
                            color: .blue
                        )
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
    
    private func clearCache() {
        MarketDataService.shared.clearCache()
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(color)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

// MARK: - Placeholder Views

struct BrokerSettingsView: View {
    @State private var igUsername = ""
    @State private var igPassword = ""
    @State private var isLoading = false
    
    private let igService = IGTradingService.shared
    
    var body: some View {
        Form {
            Section("IG Trading") {
                if igService.isAuthenticated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Connected")
                    }
                    
                    Button("Disconnect", role: .destructive) {
                        Task {
                            try? await igService.logout()
                        }
                    }
                } else {
                    TextField("Username", text: $igUsername)
                    SecureField("Password", text: $igPassword)
                    
                    Button("Connect") {
                        Task {
                            isLoading = true
                            defer { isLoading = false }
                            _ = try? await igService.login(identifier: igUsername, password: igPassword)
                        }
                    }
                    .disabled(igUsername.isEmpty || igPassword.isEmpty)
                }
            }
            
            Section("Interactive Investor") {
                Text("API not available")
                    .foregroundColor(.gray)
                
                Text("Interactive Investor doesn't provide a public API. Use manual portfolio entry instead.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Section("Interactive Brokers") {
                Text("Coming Soon")
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle("Broker Connections")
    }
}

struct PortfolioSettingsView: View {
    var body: some View {
        List {
            Section("Portfolios") {
                Text("Main Portfolio (ISA)")
                Text("Trading Account")
            }
            
            Section("Import") {
                Button("Import from CSV") {}
                Button("Import from Broker") {}
            }
        }
        .navigationTitle("Portfolio Settings")
    }
}

struct WidgetSettingsView: View {
    var body: some View {
        List {
            Section("Available Widgets") {
                Text("Portfolio Summary")
                Text("Stock Ticker")
                Text("Alerts Widget")
            }
        }
        .navigationTitle("Widget Settings")
    }
}

struct APIKeysView: View {
    @State private var polygonKey = ""
    @State private var alphaVantageKey = ""
    
    var body: some View {
        Form {
            Section("Polygon.io") {
                SecureField("API Key", text: $polygonKey)
                Link("Get API Key", destination: URL(string: "https://polygon.io/")!)
            }
            
            Section("Alpha Vantage") {
                SecureField("API Key", text: $alphaVantageKey)
                Link("Get Free Key", destination: URL(string: "https://www.alphavantage.co/support/#api-key")!)
            }
            
            Section {
                Button("Save Keys") {
                    // Save to keychain
                }
            }
        }
        .navigationTitle("API Keys")
    }
}

struct DataExportView: View {
    var body: some View {
        List {
            Section("Export Options") {
                Button("Export Portfolio (CSV)") {}
                Button("Export Trade History (CSV)") {}
                Button("Export All Data (JSON)") {}
            }
        }
        .navigationTitle("Export Data")
    }
}

struct MLSettingsView: View {
    @State private var confidenceThreshold = 60.0
    
    var body: some View {
        Form {
            Section("Prediction Model") {
                LabeledContent("Model Version", value: "1.0")
                LabeledContent("Last Updated", value: "Jan 2026")
                
                Button("Update Model") {}
            }
            
            Section("Settings") {
                VStack(alignment: .leading) {
                    Text("Minimum Confidence: \(Int(confidenceThreshold))%")
                    Slider(value: $confidenceThreshold, in: 30...90, step: 5)
                }
            }
        }
        .navigationTitle("ML Settings")
    }
}

struct AlertPreferencesView: View {
    @State private var buyThreshold = 60.0
    @State private var sellThreshold = 70.0
    @State private var noBrainerThreshold = 90.0
    
    var body: some View {
        Form {
            Section("Alert Thresholds") {
                VStack(alignment: .leading) {
                    Text("Buy Alert: \(Int(buyThreshold))% confidence")
                    Slider(value: $buyThreshold, in: 40...80, step: 5)
                }
                
                VStack(alignment: .leading) {
                    Text("Sell Alert: \(Int(sellThreshold))% confidence")
                    Slider(value: $sellThreshold, in: 50...90, step: 5)
                }
                
                VStack(alignment: .leading) {
                    Text("No-Brainer Alert: \(Int(noBrainerThreshold))% confidence")
                    Slider(value: $noBrainerThreshold, in: 80...99, step: 1)
                }
            }
        }
        .navigationTitle("Alert Preferences")
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.brandPrimary)
                    
                    Text("MyStocksApp")
                        .font(.title.weight(.bold))
                    
                    Text("AI-Powered iOS Investment Advisor")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("Version 1.0.0")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            
            Section("Legal") {
                NavigationLink("Privacy Policy") {
                    Text("Privacy Policy")
                }
                NavigationLink("Terms of Service") {
                    Text("Terms of Service")
                }
            }
            
            Section {
                Text("This app is for educational purposes only. Not financial advice.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle("About")
    }
}

struct StockDetailView: View {
    let symbol: String
    
    var body: some View {
        Text("Stock Detail: \(symbol)")
            .navigationTitle(symbol)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(AppState())
}
