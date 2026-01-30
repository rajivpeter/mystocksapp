//
//  AlertsView.swift
//  MyStocksApp
//
//  Trading alerts view with intelligent recommendations
//

import SwiftUI
import SwiftData

struct AlertsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Alert.createdAt, order: .reverse) private var alerts: [Alert]
    
    @State private var selectedFilter: AlertFilter = .all
    @State private var selectedAlert: Alert?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Pills
                filterSection
                
                // Alerts List
                if filteredAlerts.isEmpty {
                    emptyAlertsView
                } else {
                    alertsList
                }
            }
            .background(Color.black)
            .navigationTitle("Alerts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Mark All as Read") {
                            markAllAsRead()
                        }
                        
                        Button("Clear Expired", role: .destructive) {
                            clearExpiredAlerts()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.green)
                    }
                }
            }
            .sheet(item: $selectedAlert) { alert in
                AlertDetailSheet(alert: alert)
            }
        }
    }
    
    // MARK: - Filter Section
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(AlertFilter.allCases, id: \.self) { filter in
                    FilterPill(
                        title: filter.title,
                        emoji: filter.emoji,
                        count: countForFilter(filter),
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                    }
                }
            }
            .padding()
        }
        .background(Color.gray.opacity(0.1))
    }
    
    // MARK: - Alerts List
    
    private var alertsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredAlerts) { alert in
                    AlertCard(alert: alert)
                        .onTapGesture {
                            selectedAlert = alert
                        }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Empty View
    
    private var emptyAlertsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No alerts")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("You'll receive notifications when trading opportunities are detected")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Computed Properties
    
    private var filteredAlerts: [Alert] {
        switch selectedFilter {
        case .all:
            return alerts
        case .urgent:
            return alerts.filter { $0.alertType.actionRequired }
        case .buy:
            return alerts.filter { $0.alertType == .buy || $0.alertType == .strongBuy || $0.alertType == .noBrainerBuy }
        case .sell:
            return alerts.filter { $0.alertType == .sell || $0.alertType == .reduce }
        case .patterns:
            return alerts.filter { $0.alertType == .patternDetected }
        }
    }
    
    private func countForFilter(_ filter: AlertFilter) -> Int {
        switch filter {
        case .all:
            return alerts.count
        case .urgent:
            return alerts.filter { $0.alertType.actionRequired }.count
        case .buy:
            return alerts.filter { $0.alertType == .buy || $0.alertType == .strongBuy || $0.alertType == .noBrainerBuy }.count
        case .sell:
            return alerts.filter { $0.alertType == .sell || $0.alertType == .reduce }.count
        case .patterns:
            return alerts.filter { $0.alertType == .patternDetected }.count
        }
    }
    
    // MARK: - Actions
    
    private func markAllAsRead() {
        for alert in alerts where alert.status == .active {
            alert.status = .acknowledged
            alert.acknowledgedAt = Date()
        }
    }
    
    private func clearExpiredAlerts() {
        for alert in alerts where alert.isExpired {
            modelContext.delete(alert)
        }
    }
}

// MARK: - Alert Filter

enum AlertFilter: CaseIterable {
    case all, urgent, buy, sell, patterns
    
    var title: String {
        switch self {
        case .all: return "All"
        case .urgent: return "Urgent"
        case .buy: return "Buy"
        case .sell: return "Sell"
        case .patterns: return "Patterns"
        }
    }
    
    var emoji: String {
        switch self {
        case .all: return "📋"
        case .urgent: return "🚨"
        case .buy: return "🟢"
        case .sell: return "🔴"
        case .patterns: return "📊"
        }
    }
}

// MARK: - Filter Pill

struct FilterPill: View {
    let title: String
    let emoji: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(emoji)
                Text(title)
                    .font(.subheadline.weight(.medium))
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.black.opacity(0.3) : Color.gray.opacity(0.3))
                        .cornerRadius(8)
                }
            }
            .foregroundColor(isSelected ? .black : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color.green : Color.gray.opacity(0.3))
            .cornerRadius(20)
        }
    }
}

// MARK: - Alert Card

struct AlertCard: View {
    let alert: Alert
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Alert Type Badge
                HStack(spacing: 4) {
                    Text(alert.alertType.emoji)
                    Text(alert.alertType.rawValue)
                        .font(.caption.weight(.bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(colorForAlertType(alert.alertType))
                .cornerRadius(8)
                
                Spacer()
                
                // Confidence
                Text(alert.confidenceStars)
                    .font(.caption)
                
                // Time
                Text(alert.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Stock Info
            HStack {
                Text(alert.symbol)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("£\(alert.currentPrice.formatted(.number.precision(.fractionLength(2))))")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let target = alert.targetPrice {
                        Text("Target: £\(target.formatted(.number.precision(.fractionLength(2))))")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            // Reason
            Text(alert.reason)
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(2)
            
            // Technical Signals
            if !alert.technicalSignals.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(alert.technicalSignals, id: \.self) { signal in
                            Text(signal)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.3))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            // Suggested Action
            if let amount = alert.suggestedAmount, let shares = alert.suggestedShares {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    
                    Text("Suggested: \(shares) shares (£\(amount.formatted(.number.precision(.fractionLength(0)))))")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.yellow)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(borderColor, lineWidth: alert.alertType.actionRequired ? 2 : 0)
                )
        )
    }
    
    private var borderColor: Color {
        switch alert.alertType {
        case .noBrainerBuy:
            return .green
        case .strongBuy, .buy:
            return .green.opacity(0.5)
        case .sell, .reduce:
            return .red.opacity(0.5)
        case .stopLossTriggered:
            return .red
        default:
            return .clear
        }
    }
    
    private func colorForAlertType(_ type: AlertType) -> Color {
        switch type {
        case .noBrainerBuy:
            return .green
        case .strongBuy:
            return .green.opacity(0.8)
        case .buy:
            return .green.opacity(0.6)
        case .hold:
            return .gray
        case .reduce:
            return .orange
        case .sell:
            return .red
        case .stopLossTriggered:
            return .red
        case .targetReached:
            return .blue
        case .patternDetected:
            return .purple
        case .earningsAlert:
            return .yellow
        case .newsAlert:
            return .cyan
        }
    }
}

// MARK: - Alert Detail Sheet

struct AlertDetailSheet: View {
    let alert: Alert
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .center, spacing: 8) {
                        Text(alert.alertType.emoji)
                            .font(.system(size: 48))
                        
                        Text(alert.alertType.rawValue)
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                        
                        Text(alert.symbol)
                            .font(.title.weight(.bold))
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    
                    // Price Info
                    GroupBox("Price Information") {
                        LabeledContent("Current Price", value: "£\(alert.currentPrice.formatted())")
                        
                        if let target = alert.targetPrice {
                            LabeledContent("Target Price", value: "£\(target.formatted())")
                        }
                        
                        if let stopLoss = alert.stopLossPrice {
                            LabeledContent("Stop Loss", value: "£\(stopLoss.formatted())")
                        }
                        
                        if let upside = alert.potentialUpside {
                            LabeledContent("Potential Upside", value: "\(upside.formatted())%")
                        }
                    }
                    
                    // Reason
                    GroupBox("Analysis") {
                        Text(alert.reason)
                            .foregroundColor(.gray)
                    }
                    
                    // Technical Signals
                    if !alert.technicalSignals.isEmpty {
                        GroupBox("Technical Signals") {
                            ForEach(alert.technicalSignals, id: \.self) { signal in
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(signal)
                                }
                            }
                        }
                    }
                    
                    // Suggested Trade
                    if let shares = alert.suggestedShares, let amount = alert.suggestedAmount {
                        GroupBox("Suggested Trade") {
                            LabeledContent("Shares", value: "\(shares)")
                            LabeledContent("Amount", value: "£\(amount.formatted())")
                        }
                    }
                    
                    // Action Buttons
                    HStack(spacing: 16) {
                        Button(action: {}) {
                            Label("Execute Trade", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(12)
                        }
                        
                        Button(action: { dismiss() }) {
                            Label("Dismiss", systemImage: "xmark.circle.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AlertsView()
        .modelContainer(for: Alert.self, inMemory: true)
}
