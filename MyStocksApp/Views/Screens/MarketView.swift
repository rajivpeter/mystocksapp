//
//  MarketView.swift
//  MyStocksApp
//
//  Market overview and stock search
//

import SwiftUI

struct MarketView: View {
    @State private var searchText = ""
    @State private var searchResults: [SymbolSearchResult] = []
    @State private var isSearching = false
    @State private var selectedStock: String?
    
    private let marketDataService = MarketDataService.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Market Overview Cards
                    marketOverviewSection
                    
                    // Watchlist
                    watchlistSection
                    
                    // Market Movers
                    marketMoversSection
                    
                    // Search Results
                    if !searchResults.isEmpty {
                        searchResultsSection
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Market")
            .searchable(text: $searchText, prompt: "Search stocks")
            .onChange(of: searchText) { _, newValue in
                Task {
                    await searchStocks(query: newValue)
                }
            }
            .navigationDestination(item: $selectedStock) { symbol in
                StockDetailView(symbol: symbol)
            }
        }
    }
    
    // MARK: - Market Overview
    
    private var marketOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Market Overview")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MarketIndexCard(
                    name: "S&P 500",
                    value: "5,892.34",
                    change: "+1.23%",
                    isPositive: true
                )
                
                MarketIndexCard(
                    name: "FTSE 100",
                    value: "8,456.78",
                    change: "+0.87%",
                    isPositive: true
                )
                
                MarketIndexCard(
                    name: "NASDAQ",
                    value: "18,234.56",
                    change: "-0.45%",
                    isPositive: false
                )
                
                MarketIndexCard(
                    name: "FTSE 250",
                    value: "21,345.67",
                    change: "+0.32%",
                    isPositive: true
                )
            }
        }
    }
    
    // MARK: - Watchlist
    
    private var watchlistSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Watchlist")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {}) {
                    Text("Edit")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            // Sample watchlist items
            VStack(spacing: 8) {
                WatchlistRow(
                    symbol: "AAPL",
                    name: "Apple Inc.",
                    price: "$189.42",
                    change: "+2.34%",
                    isPositive: true
                )
                
                WatchlistRow(
                    symbol: "MSFT",
                    name: "Microsoft Corp",
                    price: "$415.67",
                    change: "+1.12%",
                    isPositive: true
                )
                
                WatchlistRow(
                    symbol: "BARC.L",
                    name: "Barclays PLC",
                    price: "£2.45",
                    change: "-3.21%",
                    isPositive: false
                )
            }
        }
    }
    
    // MARK: - Market Movers
    
    private var marketMoversSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Market Movers")
                .font(.headline)
                .foregroundColor(.white)
            
            // Segment picker for Gainers/Losers
            HStack(spacing: 12) {
                MoverCategoryButton(title: "Top Gainers", emoji: "🚀", isSelected: true)
                MoverCategoryButton(title: "Top Losers", emoji: "📉", isSelected: false)
                MoverCategoryButton(title: "Most Active", emoji: "📊", isSelected: false)
            }
            
            // Sample movers
            VStack(spacing: 8) {
                MoverRow(
                    symbol: "NVDA",
                    name: "NVIDIA Corp",
                    price: "$892.45",
                    change: "+8.45%",
                    volume: "45.2M"
                )
                
                MoverRow(
                    symbol: "TSLA",
                    name: "Tesla Inc",
                    price: "$248.32",
                    change: "+5.67%",
                    volume: "89.1M"
                )
            }
        }
    }
    
    // MARK: - Search Results
    
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search Results")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(searchResults) { result in
                Button(action: {
                    selectedStock = result.symbol
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(result.symbol)
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(result.name)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Text(result.exchange)
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Search
    
    private func searchStocks(query: String) async {
        guard query.count >= 1 else {
            searchResults = []
            return
        }
        
        isSearching = true
        defer { isSearching = false }
        
        do {
            searchResults = try await marketDataService.searchSymbols(query: query)
        } catch {
            searchResults = []
        }
    }
}

// MARK: - Supporting Views

struct MarketIndexCard: View {
    let name: String
    let value: String
    let change: String
    let isPositive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.white)
            
            Text(change)
                .font(.subheadline.weight(.medium))
                .foregroundColor(isPositive ? .green : .red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
}

struct WatchlistRow: View {
    let symbol: String
    let name: String
    let price: String
    let change: String
    let isPositive: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(symbol)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(name)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(price)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(change)
                    .font(.caption.weight(.medium))
                    .foregroundColor(isPositive ? .green : .red)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
}

struct MoverCategoryButton: View {
    let title: String
    let emoji: String
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Text(emoji)
            Text(title)
                .font(.caption)
        }
        .foregroundColor(isSelected ? .black : .white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.brandPrimary : Color.gray.opacity(0.3))
        .cornerRadius(20)
    }
}

struct MoverRow: View {
    let symbol: String
    let name: String
    let price: String
    let change: String
    let volume: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(symbol)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(name)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(price)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Text(change)
                    .font(.caption.weight(.bold))
                    .foregroundColor(.brandPrimary)
            }
            
            Text(volume)
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 50)
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    MarketView()
}
