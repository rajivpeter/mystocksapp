//
//  PortfolioView.swift
//  MyStocksApp
//
//  Beautiful portfolio view with Robinhood-inspired design
//

import SwiftUI
import SwiftData
import Charts

struct PortfolioView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    
    @State private var viewModel = PortfolioViewModel()
    @State private var selectedTimeframe: HistoricalPeriod = .oneMonth
    @State private var showingAddPosition = false
    @State private var showingImport = false
    @State private var showClearAllConfirmation = false
    @State private var selectedPosition: Position?
    @State private var selectedStockSymbol: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Portfolio Value Header
                    portfolioHeader
                    
                    // Allocation Chart
                    allocationSection
                    
                    // Performance Chart
                    performanceSection
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Positions List
                    positionsSection
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(action: { showingAddPosition = true }) {
                            Label("Add Single", systemImage: "plus")
                        }
                        Button(action: { showingImport = true }) {
                            Label("Bulk Import", systemImage: "square.and.arrow.down")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: { showClearAllConfirmation = true }) {
                            Label("Clear All Positions", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.brandPrimary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task { await viewModel.refreshPrices() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.brandPrimary)
                    }
                }
            }
            .confirmationDialog(
                "Clear All Positions",
                isPresented: $showClearAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    clearAllPositions()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all positions from your portfolio. You can re-import from CSV or screenshot after.")
            }
            .refreshable {
                await viewModel.refreshPrices()
            }
            .task {
                await viewModel.loadPortfolio(modelContext: modelContext)
            }
            .sheet(isPresented: $showingAddPosition) {
                AddPositionSheet(viewModel: viewModel)
            }
            .sheet(item: $selectedPosition) { position in
                PositionDetailSheet(position: position, viewModel: viewModel)
            }
            .sheet(isPresented: $showingImport) {
                PortfolioImportView()
            }
            .navigationDestination(item: $selectedStockSymbol) { symbol in
                StockDetailView(symbol: symbol)
            }
        }
    }
    
    // MARK: - Portfolio Header
    
    private var portfolioHeader: some View {
        VStack(spacing: 8) {
            // Total Value
            Text(formatCurrency(viewModel.totalValue))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            // P&L
            HStack(spacing: 4) {
                Image(systemName: viewModel.totalPnL >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption)
                
                Text(formatCurrency(abs(viewModel.totalPnL)))
                
                Text("(\(formatPercent(viewModel.totalPnLPercent)))")
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(viewModel.totalPnL >= 0 ? .brandPrimary : .loss)
            
            // Last Updated
            if let lastUpdated = viewModel.lastUpdated {
                Text("Updated \(lastUpdated.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    // MARK: - Allocation Section
    
    private var allocationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Allocation")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 20) {
                // UK Allocation
                AllocationItem(
                    title: "UK",
                    emoji: "🇬🇧",
                    percentage: viewModel.ukAllocation,
                    color: .blue
                )
                
                // US Allocation
                AllocationItem(
                    title: "US",
                    emoji: "🇺🇸",
                    percentage: viewModel.usAllocation,
                    color: .red
                )
                
                // Cash
                AllocationItem(
                    title: "Cash",
                    emoji: "💵",
                    percentage: viewModel.cashAllocation,
                    color: .green
                )
            }
            
            // Allocation Bar
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    Rectangle()
                        .fill(Color.brandBlue)
                        .frame(width: geometry.size.width * CGFloat(viewModel.ukAllocation / 100))
                    
                    Rectangle()
                        .fill(Color.brandPrimary)
                        .frame(width: geometry.size.width * CGFloat(viewModel.usAllocation / 100))
                    
                    Rectangle()
                        .fill(Color.brandSoft)
                        .frame(width: geometry.size.width * CGFloat(viewModel.cashAllocation / 100))
                }
                .clipShape(Capsule())
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(16)
    }
    
    // MARK: - Performance Section
    
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Performance")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Timeframe Picker
                Picker("Timeframe", selection: $selectedTimeframe) {
                    Text("1D").tag(HistoricalPeriod.oneDay)
                    Text("1W").tag(HistoricalPeriod.fiveDays)
                    Text("1M").tag(HistoricalPeriod.oneMonth)
                    Text("3M").tag(HistoricalPeriod.threeMonths)
                    Text("1Y").tag(HistoricalPeriod.oneYear)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            
            // Stats Row
            HStack(spacing: 20) {
                StatItem(
                    title: "Win Rate",
                    value: "\(Int(viewModel.winRate))%",
                    icon: "chart.pie.fill",
                    color: .green
                )
                
                StatItem(
                    title: "Positions",
                    value: "\(viewModel.positionCount)",
                    icon: "square.stack.3d.up.fill",
                    color: .blue
                )
                
                StatItem(
                    title: "Cash",
                    value: formatCurrencyShort(viewModel.cashBalance),
                    icon: "banknote.fill",
                    color: .yellow
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(16)
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Buy",
                    icon: "plus.circle.fill",
                    color: .green
                ) {
                    showingAddPosition = true
                }
                
                QuickActionButton(
                    title: "Alerts",
                    icon: "bell.badge.fill",
                    color: .orange
                ) {
                    // Navigate to alerts
                }
                
                QuickActionButton(
                    title: "Predict",
                    icon: "brain.head.profile",
                    color: .purple
                ) {
                    // Show predictions
                }
                
                QuickActionButton(
                    title: "Sync",
                    icon: "arrow.triangle.2.circlepath",
                    color: .blue
                ) {
                    Task { await viewModel.refreshPrices() }
                }
            }
        }
    }
    
    // MARK: - Positions Section
    
    private var positionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Holdings")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(viewModel.positions.count) positions")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            if viewModel.positions.isEmpty {
                emptyPositionsView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.positions.sorted { $0.marketValueGBP > $1.marketValueGBP }) { position in
                        PositionCard(position: position)
                            .onTapGesture {
                                selectedStockSymbol = position.symbol
                            }
                            .contextMenu {
                                Button {
                                    selectedStockSymbol = position.symbol
                                } label: {
                                    Label("View Details", systemImage: "chart.line.uptrend.xyaxis")
                                }
                                
                                Button {
                                    selectedPosition = position
                                } label: {
                                    Label("Edit Position", systemImage: "pencil")
                                }
                                
                                Button(role: .destructive) {
                                    // Delete position
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }
    
    private var emptyPositionsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No positions yet")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Add your first stock to start tracking your portfolio")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button(action: { showingAddPosition = true }) {
                Label("Add Position", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding()
                    .background(Color.brandPrimary)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Helpers
    
    private func formatCurrency(_ value: Double) -> String {
        "£\(value.formatted(.number.precision(.fractionLength(2))))"
    }
    
    private func formatCurrencyShort(_ value: Double) -> String {
        if value >= 1000000 {
            return "£\((value / 1000000).formatted(.number.precision(.fractionLength(1))))M"
        } else if value >= 1000 {
            return "£\((value / 1000).formatted(.number.precision(.fractionLength(1))))K"
        }
        return "£\(value.formatted(.number.precision(.fractionLength(0))))"
    }
    
    private func formatPercent(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(value.formatted(.number.precision(.fractionLength(2))))%"
    }
    
    private func clearAllPositions() {
        do {
            let positions = try modelContext.fetch(FetchDescriptor<Position>())
            for position in positions {
                modelContext.delete(position)
            }
            try modelContext.save()
            Task { await viewModel.loadPortfolio(modelContext: modelContext) }
        } catch {
            print("Error clearing positions: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct AllocationItem: View {
    let title: String
    let emoji: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(emoji)
                .font(.title2)
            
            Text("\(Int(percentage))%")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
        }
    }
}

struct PositionCard: View {
    let position: Position
    
    var body: some View {
        HStack {
            // Stock Info
            VStack(alignment: .leading, spacing: 4) {
                Text(position.symbol)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(Int(position.shares)) shares")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Value & P&L
            VStack(alignment: .trailing, spacing: 4) {
                Text(position.formattedMarketValue)
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 4) {
                    Text(position.formattedPnL)
                    Text("(\(position.formattedPnLPercent))")
                }
                .font(.caption)
                .foregroundColor(position.isProfit ? .brandPrimary : .loss)
            }
            
            // Arrow
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
}

// MARK: - Placeholder Sheets

struct AddPositionSheet: View {
    let viewModel: PortfolioViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var symbol = ""
    @State private var shares = ""
    @State private var averageCost = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Stock") {
                    TextField("Symbol (e.g., AAPL)", text: $symbol)
                        .textInputAutocapitalization(.characters)
                }
                
                Section("Position") {
                    TextField("Number of shares", text: $shares)
                        .keyboardType(.decimalPad)
                    
                    TextField("Average cost per share", text: $averageCost)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Add Position")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        // Add position
                        dismiss()
                    }
                    .disabled(symbol.isEmpty || shares.isEmpty || averageCost.isEmpty)
                }
            }
        }
    }
}

struct PositionDetailSheet: View {
    let position: Position
    let viewModel: PortfolioViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Position Details") {
                    LabeledContent("Symbol", value: position.symbol)
                    LabeledContent("Shares", value: "\(Int(position.shares))")
                    LabeledContent("Average Cost", value: "£\(position.averageCost.formatted())")
                    LabeledContent("Market Value", value: position.formattedMarketValue)
                    LabeledContent("P&L", value: position.formattedPnL)
                }
            }
            .navigationTitle(position.symbol)
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
    PortfolioView()
        .environment(AppState())
        .modelContainer(for: [Portfolio.self, Position.self, Stock.self], inMemory: true)
}
