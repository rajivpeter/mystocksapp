//
//  StockDetailView.swift
//  MyStocksApp
//
//  Comprehensive stock detail view with charts, patterns, and metrics
//

import SwiftUI
import Charts

struct StockDetailView: View {
    let symbol: String
    
    @State private var stock: Stock?
    @State private var historicalData: [CandlestickData] = []
    @State private var detectedPatterns: [PatternAnnotation] = []
    @State private var selectedPeriod: HistoricalPeriod = .oneMonth
    @State private var chartType: ChartType = .candlestick
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedPattern: PatternAnnotation?
    @State private var showPatternEducation = false
    
    @Environment(\.dismiss) private var dismiss
    
    enum ChartType: String, CaseIterable {
        case candlestick = "Candles"
        case line = "Line"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if isLoading {
                    loadingView
                } else if let error = error {
                    errorView(error)
                } else if let stock = stock {
                    stockContent(stock)
                }
            }
        }
        .background(Color.black)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(symbol)
                        .font(.headline)
                    if let stock = stock {
                        Text(stock.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if let stock = stock {
                        if let url = stock.morningstarURL {
                            Link(destination: url) {
                                Label("Morningstar", systemImage: "star.fill")
                            }
                        }
                        if let url = stock.yahooFinanceURL {
                            Link(destination: url) {
                                Label("Yahoo Finance", systemImage: "chart.line.uptrend.xyaxis")
                            }
                        }
                        if let url = stock.tradingViewURL {
                            Link(destination: url) {
                                Label("TradingView", systemImage: "chart.bar.fill")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await loadStockData()
        }
        .onChange(of: selectedPeriod) { _, _ in
            Task { await loadHistoricalData() }
        }
        .sheet(isPresented: $showPatternEducation) {
            if let pattern = selectedPattern {
                PatternEducationSheet(pattern: pattern)
            }
        }
    }
    
    // MARK: - Stock Content
    @ViewBuilder
    private func stockContent(_ stock: Stock) -> some View {
        // Price Header
        priceHeader(stock)
        
        // Chart Section
        chartSection
        
        // Detected Patterns (Learn by Doing)
        if !detectedPatterns.isEmpty {
            patternsSection
        }
        
        // Key Metrics
        metricsSection(stock)
        
        // Technical Indicators
        technicalSection(stock)
        
        // Fair Value Analysis
        fairValueSection(stock)
        
        // Historical Performance
        performanceSection(stock)
        
        // 52-Week Range
        rangeSection(stock)
        
        // Quick Actions
        actionsSection(stock)
    }
    
    // MARK: - Price Header
    private func priceHeader(_ stock: Stock) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                Text(stock.formattedPrice)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(stock.formattedChange)
                        .font(.title3.bold())
                        .foregroundColor(stock.isPositive ? .green : .red)
                    
                    Text(stock.formattedChangePercent)
                        .font(.subheadline)
                        .foregroundColor(stock.isPositive ? .green : .red)
                }
            }
            
            // Technical Signal Badge
            HStack(spacing: 8) {
                Text(stock.technicalSignal.emoji)
                Text(stock.technicalSignal.rawValue)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(signalColor(stock.technicalSignal).opacity(0.2))
            .foregroundColor(signalColor(stock.technicalSignal))
            .cornerRadius(16)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
    }
    
    // MARK: - Chart Section
    private var chartSection: some View {
        VStack(spacing: 12) {
            // Period Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HistoricalPeriod.allCases, id: \.self) { period in
                        Button(period.rawValue) {
                            selectedPeriod = period
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedPeriod == period ? Color.accentColor : Color.gray.opacity(0.3))
                        .foregroundColor(selectedPeriod == period ? .white : .gray)
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal)
            }
            
            // Chart Type Toggle
            Picker("Chart Type", selection: $chartType) {
                ForEach(ChartType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // Chart
            if historicalData.isEmpty {
                Text("Loading chart data...")
                    .foregroundColor(.secondary)
                    .frame(height: 300)
            } else {
                Group {
                    switch chartType {
                    case .candlestick:
                        CandlestickChart(
                            data: historicalData,
                            patterns: detectedPatterns,
                            showVolume: true,
                            showPatterns: true
                        ) { pattern in
                            selectedPattern = pattern
                            showPatternEducation = true
                        }
                    case .line:
                        StockLineChart(
                            data: historicalData,
                            color: (historicalData.last?.close ?? 0) >= (historicalData.first?.close ?? 0) ? .green : .red
                        )
                    }
                }
                .frame(height: 350)
                .padding(.horizontal, 8)
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - Patterns Section (Learn by Doing)
    private var patternsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("Detected Patterns")
                    .font(.headline)
                Spacer()
                Text("Tap to learn")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(detectedPatterns) { pattern in
                        DetectedPatternCard(pattern: pattern)
                            .onTapGesture {
                                selectedPattern = pattern
                                showPatternEducation = true
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color.gray.opacity(0.1))
    }
    
    // MARK: - Metrics Section
    private func metricsSection(_ stock: Stock) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Metrics")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetricCard(title: "Market Cap", value: formatMarketCap(stock.marketCap), icon: "building.2.fill")
                MetricCard(title: "P/E Ratio", value: formatOptional(stock.peRatio), icon: "percent")
                MetricCard(title: "PEG Ratio", value: formatOptional(stock.pegRatio), icon: "chart.line.uptrend.xyaxis")
                MetricCard(title: "Dividend", value: formatPercent(stock.dividendYield), icon: "dollarsign.circle.fill")
                MetricCard(title: "Volume", value: formatVolume(stock.volume), icon: "chart.bar.fill")
                MetricCard(title: "Avg Volume", value: formatVolume(stock.averageVolume), icon: "chart.bar")
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    // MARK: - Technical Section
    private func technicalSection(_ stock: Stock) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Technical Indicators")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                // RSI
                if let rsi = stock.rsi14 {
                    TechnicalIndicatorRow(
                        name: "RSI (14)",
                        value: String(format: "%.1f", rsi),
                        status: rsi < 30 ? "Oversold" : rsi > 70 ? "Overbought" : "Neutral",
                        color: rsi < 30 ? .green : rsi > 70 ? .red : .gray
                    )
                }
                
                // Moving Averages
                if let sma20 = stock.sma20 {
                    TechnicalIndicatorRow(
                        name: "SMA 20",
                        value: String(format: "%.2f", sma20),
                        status: stock.currentPrice > sma20 ? "Above" : "Below",
                        color: stock.currentPrice > sma20 ? .green : .red
                    )
                }
                
                if let sma50 = stock.sma50 {
                    TechnicalIndicatorRow(
                        name: "SMA 50",
                        value: String(format: "%.2f", sma50),
                        status: stock.currentPrice > sma50 ? "Above" : "Below",
                        color: stock.currentPrice > sma50 ? .green : .red
                    )
                }
                
                if let sma200 = stock.sma200 {
                    TechnicalIndicatorRow(
                        name: "SMA 200",
                        value: String(format: "%.2f", sma200),
                        status: stock.currentPrice > sma200 ? "Above" : "Below",
                        color: stock.currentPrice > sma200 ? .green : .red
                    )
                }
                
                // MACD
                if let macd = stock.macd, let signal = stock.macdSignal {
                    TechnicalIndicatorRow(
                        name: "MACD",
                        value: String(format: "%.2f", macd),
                        status: macd > signal ? "Bullish" : "Bearish",
                        color: macd > signal ? .green : .red
                    )
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    // MARK: - Fair Value Section
    private func fairValueSection(_ stock: Stock) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fair Value Analysis")
                .font(.headline)
                .padding(.horizontal)
            
            if let fairValue = stock.fairValue, let upside = stock.fairValueUpside {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Fair Value")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(stock.currencySymbol)\(fairValue, specifier: "%.2f")")
                                .font(.title2.bold())
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Upside/Downside")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(upside > 0 ? "+" : "")\(upside, specifier: "%.1f")%")
                                .font(.title2.bold())
                                .foregroundColor(upside > 0 ? .green : .red)
                        }
                    }
                    
                    // Fair Value Gauge
                    FairValueGauge(
                        currentPrice: stock.currentPrice,
                        fairValue: fairValue
                    )
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                Text("Fair value data not available")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - Performance Section
    private func performanceSection(_ stock: Stock) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Historical Performance")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                PerformanceRow(period: "1 Day", change: stock.change1D)
                PerformanceRow(period: "1 Week", change: stock.change1W)
                PerformanceRow(period: "1 Month", change: stock.change1M)
                PerformanceRow(period: "3 Months", change: stock.change3M)
                PerformanceRow(period: "1 Year", change: stock.change1Y)
                PerformanceRow(period: "3 Years", change: stock.change3Y)
                PerformanceRow(period: "5 Years", change: stock.change5Y)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    // MARK: - 52-Week Range
    private func rangeSection(_ stock: Stock) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("52-Week Range")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                RangeBar(
                    low: stock.low52Week,
                    high: stock.high52Week,
                    current: stock.currentPrice,
                    currency: stock.currencySymbol
                )
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("From High")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(stock.percentFrom52WeekHigh, specifier: "%.1f")%")
                            .font(.subheadline.bold())
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("From Low")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("+\(stock.percentFrom52WeekLow, specifier: "%.1f")%")
                            .font(.subheadline.bold())
                            .foregroundColor(.green)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    // MARK: - Actions Section
    private func actionsSection(_ stock: Stock) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ActionButton(title: "Add to Portfolio", icon: "plus.circle.fill", color: .green) {
                    // TODO: Add to portfolio
                }
                
                ActionButton(title: "Set Alert", icon: "bell.fill", color: .orange) {
                    // TODO: Set alert
                }
            }
            
            HStack(spacing: 12) {
                ActionButton(title: "AI Prediction", icon: "brain", color: .purple) {
                    // TODO: Get prediction
                }
                
                ActionButton(title: "Add to Watchlist", icon: "star.fill", color: .yellow) {
                    // TODO: Add to watchlist
                }
            }
        }
        .padding()
    }
    
    // MARK: - Loading & Error Views
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading \(symbol)...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text(error)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                Task { await loadStockData() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 400)
    }
    
    // MARK: - Data Loading
    private func loadStockData() async {
        isLoading = true
        error = nil
        
        do {
            // Fetch stock data
            let fetchedStock = try await MarketDataService.shared.fetchStock(symbol: symbol)
            await MainActor.run {
                self.stock = fetchedStock
            }
            
            // Fetch historical data
            await loadHistoricalData()
            
            await MainActor.run {
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func loadHistoricalData() async {
        do {
            let ohlcv = try await MarketDataService.shared.fetchHistoricalData(
                symbol: symbol,
                period: selectedPeriod
            )
            
            let candleData = ohlcv.map { CandlestickData(from: $0) }
            
            // Detect patterns
            let patterns = detectPatterns(in: candleData)
            
            await MainActor.run {
                self.historicalData = candleData
                self.detectedPatterns = patterns
            }
        } catch {
            print("Failed to load historical data: \(error)")
        }
    }
    
    private func detectPatterns(in data: [CandlestickData]) -> [PatternAnnotation] {
        // Use pattern recognizer to detect patterns
        guard data.count >= 5 else { return [] }
        
        var patterns: [PatternAnnotation] = []
        
        // Check last few candles for patterns
        for i in stride(from: data.count - 1, through: max(0, data.count - 20), by: -1) {
            let candle = data[i]
            
            // Check for Hammer
            if isHammer(candle) {
                patterns.append(PatternAnnotation(
                    date: candle.date,
                    price: candle.low * 0.99,
                    patternName: "Hammer",
                    isBullish: true,
                    confidence: 75,
                    description: "Bullish reversal pattern with small body and long lower shadow"
                ))
            }
            
            // Check for Shooting Star
            if isShootingStar(candle) {
                patterns.append(PatternAnnotation(
                    date: candle.date,
                    price: candle.high * 1.01,
                    patternName: "Shooting Star",
                    isBullish: false,
                    confidence: 75,
                    description: "Bearish reversal pattern with small body and long upper shadow"
                ))
            }
            
            // Check for Doji
            if isDoji(candle) {
                patterns.append(PatternAnnotation(
                    date: candle.date,
                    price: candle.high * 1.01,
                    patternName: "Doji",
                    isBullish: false,
                    confidence: 50,
                    description: "Indecision pattern - open and close are nearly equal"
                ))
            }
            
            // Limit to 5 patterns
            if patterns.count >= 5 { break }
        }
        
        return patterns
    }
    
    // MARK: - Pattern Detection Helpers
    private func isHammer(_ candle: CandlestickData) -> Bool {
        let body = candle.bodyHeight
        let lowerShadow = candle.bodyBottom - candle.low
        let upperShadow = candle.high - candle.bodyTop
        
        return lowerShadow >= body * 2 && upperShadow < body * 0.5
    }
    
    private func isShootingStar(_ candle: CandlestickData) -> Bool {
        let body = candle.bodyHeight
        let lowerShadow = candle.bodyBottom - candle.low
        let upperShadow = candle.high - candle.bodyTop
        
        return upperShadow >= body * 2 && lowerShadow < body * 0.5
    }
    
    private func isDoji(_ candle: CandlestickData) -> Bool {
        let range = candle.high - candle.low
        return candle.bodyHeight < range * 0.1 && range > 0
    }
    
    // MARK: - Formatting Helpers
    private func signalColor(_ signal: TechnicalSignal) -> Color {
        switch signal {
        case .strongBuy, .oversold: return .green
        case .bullish: return .green.opacity(0.8)
        case .neutral: return .gray
        case .bearish: return .orange
        case .strongSell, .overbought: return .red
        }
    }
    
    private func formatMarketCap(_ cap: Double?) -> String {
        guard let cap = cap else { return "N/A" }
        if cap >= 1_000_000_000_000 {
            return String(format: "$%.2fT", cap / 1_000_000_000_000)
        } else if cap >= 1_000_000_000 {
            return String(format: "$%.2fB", cap / 1_000_000_000)
        } else if cap >= 1_000_000 {
            return String(format: "$%.2fM", cap / 1_000_000)
        }
        return String(format: "$%.0f", cap)
    }
    
    private func formatOptional(_ value: Double?) -> String {
        guard let value = value else { return "N/A" }
        return String(format: "%.2f", value)
    }
    
    private func formatPercent(_ value: Double?) -> String {
        guard let value = value else { return "N/A" }
        return String(format: "%.2f%%", value * 100)
    }
    
    private func formatVolume(_ volume: Int64) -> String {
        if volume >= 1_000_000_000 {
            return String(format: "%.2fB", Double(volume) / 1_000_000_000)
        } else if volume >= 1_000_000 {
            return String(format: "%.2fM", Double(volume) / 1_000_000)
        } else if volume >= 1_000 {
            return String(format: "%.2fK", Double(volume) / 1_000)
        }
        return "\(volume)"
    }
}

// MARK: - Supporting Components

struct DetectedPatternCard: View {
    let pattern: PatternAnnotation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: pattern.isBullish ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundColor(pattern.isBullish ? .green : .red)
                Text(pattern.patternName)
                    .font(.subheadline.bold())
            }
            
            Text(pattern.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Text("Confidence:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(pattern.confidence)%")
                    .font(.caption.bold())
                    .foregroundColor(pattern.confidence > 70 ? .green : .orange)
            }
        }
        .padding()
        .frame(width: 200)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline.bold())
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct TechnicalIndicatorRow: View {
    let name: String
    let value: String
    let status: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(name)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit())
            Text(status)
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.2))
                .foregroundColor(color)
                .cornerRadius(8)
        }
    }
}

struct PerformanceRow: View {
    let period: String
    let change: Double
    
    var body: some View {
        HStack {
            Text(period)
                .font(.subheadline)
            Spacer()
            Text("\(change >= 0 ? "+" : "")\(change, specifier: "%.2f")%")
                .font(.subheadline.bold())
                .foregroundColor(change >= 0 ? .green : .red)
        }
    }
}

struct FairValueGauge: View {
    let currentPrice: Double
    let fairValue: Double
    
    var body: some View {
        GeometryReader { geometry in
            let ratio = currentPrice / fairValue
            let position = min(max(ratio - 0.5, 0), 1) // 0.5x to 1.5x range
            
            ZStack(alignment: .leading) {
                // Background
                LinearGradient(
                    colors: [.green, .yellow, .red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 8)
                .cornerRadius(4)
                
                // Current position indicator
                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .shadow(radius: 2)
                    .offset(x: geometry.size.width * position - 8)
            }
        }
        .frame(height: 16)
    }
}

struct RangeBar: View {
    let low: Double
    let high: Double
    let current: Double
    let currency: String
    
    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                let range = high - low
                let position = range > 0 ? (current - low) / range : 0.5
                
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                    
                    // Filled portion
                    Capsule()
                        .fill(LinearGradient(colors: [.red, .yellow, .green], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geometry.size.width * position, height: 8)
                    
                    // Current position
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .shadow(radius: 2)
                        .offset(x: geometry.size.width * position - 8)
                }
            }
            .frame(height: 16)
            
            HStack {
                Text("\(currency)\(low, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(currency)\(high, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                    .font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(12)
        }
    }
}

// MARK: - Pattern Education Sheet
struct PatternEducationSheet: View {
    let pattern: PatternAnnotation
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        Image(systemName: pattern.isBullish ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(pattern.isBullish ? .green : .red)
                        
                        VStack(alignment: .leading) {
                            Text(pattern.patternName)
                                .font(.title.bold())
                            Text(pattern.isBullish ? "Bullish Pattern" : "Bearish Pattern")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What is it?")
                            .font(.headline)
                        Text(pattern.description)
                            .foregroundColor(.secondary)
                    }
                    
                    // Find pattern definition
                    if let definition = PatternLibrary.allPatterns.first(where: { $0.name == pattern.patternName }) {
                        // Key Characteristics
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Key Characteristics")
                                .font(.headline)
                            ForEach(definition.keyCharacteristics, id: \.self) { characteristic in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(characteristic)
                                }
                            }
                        }
                        
                        // Trading Strategy
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How to Trade")
                                .font(.headline)
                            
                            StrategyCard(title: "Entry", content: definition.entryStrategy, icon: "arrow.right.circle.fill", color: .blue)
                            StrategyCard(title: "Target", content: definition.targetCalculation, icon: "target", color: .green)
                            StrategyCard(title: "Stop Loss", content: definition.stopLoss, icon: "xmark.octagon.fill", color: .red)
                        }
                        
                        // Reliability
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reliability")
                                .font(.headline)
                            HStack {
                                Text(definition.reliability.rawValue)
                                    .font(.subheadline.bold())
                                Text("(\(definition.reliability.successRate) success rate)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Confidence for this detection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Detection Confidence")
                            .font(.headline)
                        HStack {
                            ProgressView(value: Double(pattern.confidence) / 100)
                                .tint(pattern.confidence > 70 ? .green : .orange)
                            Text("\(pattern.confidence)%")
                                .font(.headline)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Learn: \(pattern.patternName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct StrategyCard: View {
    let title: String
    let content: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                Text(content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        StockDetailView(symbol: "AAPL")
    }
}
