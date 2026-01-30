//
//  StockDetailView.swift
//  MyStocksApp
//
//  Comprehensive stock detail view with charts, patterns, and metrics
//

import SwiftUI
import SwiftData
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
    @State private var showAlertSetup = false
    @State private var showAIPrediction = false
    @State private var showAddToPortfolio = false
    @State private var showAddToWatchlist = false
    @State private var alertMessage: String?
    @State private var showAlertToast = false
    @State private var cachedFiveYearData: [OHLCV] = []
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
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
        // Deduplicate patterns - only show each pattern type once
        let uniquePatterns = deduplicatePatterns(detectedPatterns)
        
        return VStack(alignment: .leading, spacing: 12) {
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
                    ForEach(uniquePatterns) { pattern in
                        DetectedPatternCard(pattern: pattern, count: countPatternOccurrences(pattern.patternName))
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
    
    /// Deduplicate patterns - keep only first occurrence of each pattern type
    private func deduplicatePatterns(_ patterns: [PatternAnnotation]) -> [PatternAnnotation] {
        var seen = Set<String>()
        return patterns.filter { pattern in
            if seen.contains(pattern.patternName) {
                return false
            }
            seen.insert(pattern.patternName)
            return true
        }
    }
    
    /// Count how many times a pattern type appears
    private func countPatternOccurrences(_ patternName: String) -> Int {
        detectedPatterns.filter { $0.patternName == patternName }.count
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
                    showAddToPortfolio = true
                }
                
                ActionButton(title: "Set Alert", icon: "bell.fill", color: .orange) {
                    showAlertSetup = true
                }
            }
            
            HStack(spacing: 12) {
                ActionButton(title: "AI Prediction", icon: "brain", color: .purple) {
                    showAIPrediction = true
                }
                
                ActionButton(title: "Add to Watchlist", icon: "star.fill", color: .yellow) {
                    addToWatchlist(stock)
                }
            }
            
            // Toast message
            if showAlertToast, let message = alertMessage {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.green.opacity(0.9))
                    .cornerRadius(12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding()
        .sheet(isPresented: $showAlertSetup) {
            SetAlertSheet(stock: stock) { alertType, targetPrice in
                createAlert(for: stock, type: alertType, target: targetPrice)
            }
        }
        .sheet(isPresented: $showAIPrediction) {
            AIPredictionSheet(stock: stock, historicalData: historicalData)
        }
        .sheet(isPresented: $showAddToPortfolio) {
            AddToPortfolioSheet(stock: stock) { shares, avgCost in
                addToPortfolio(stock: stock, shares: shares, avgCost: avgCost)
            }
        }
    }
    
    // MARK: - Action Implementations
    
    private func addToWatchlist(_ stock: Stock) {
        // Save to UserDefaults for now (could be SwiftData)
        var watchlist = UserDefaults.standard.stringArray(forKey: "watchlist") ?? []
        if !watchlist.contains(stock.symbol) {
            watchlist.append(stock.symbol)
            UserDefaults.standard.set(watchlist, forKey: "watchlist")
            showToast("Added \(stock.symbol) to watchlist")
        } else {
            showToast("\(stock.symbol) is already in watchlist")
        }
    }
    
    private func createAlert(for stock: Stock, type: AlertType, target: Double?) {
        let alert = Alert(
            symbol: stock.symbol,
            alertType: type,
            confidence: 75, // Default user confidence
            urgency: .medium,
            triggerPrice: target ?? stock.currentPrice,
            currentPrice: stock.currentPrice,
            reason: "User-created price alert",
            stock: stock
        )
        // Set target price after creation
        alert.targetPrice = target
        modelContext.insert(alert)
        try? modelContext.save()
        showToast("Alert created for \(stock.symbol)")
    }
    
    private func addToPortfolio(stock: Stock, shares: Double, avgCost: Double) {
        let position = Position(
            symbol: stock.symbol,
            shares: shares,
            averageCost: avgCost,
            purchaseDate: Date(),
            stock: stock
        )
        modelContext.insert(stock)
        modelContext.insert(position)
        try? modelContext.save()
        showToast("Added \(shares) shares of \(stock.symbol)")
    }
    
    private func showToast(_ message: String) {
        alertMessage = message
        withAnimation {
            showAlertToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showAlertToast = false
            }
        }
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
            // Fetch stock data (uses cache if available)
            let fetchedStock = try await MarketDataService.shared.fetchStock(symbol: symbol)
            
            // Fetch 5-year data ONCE for both performance calculation and technical indicators
            // This data is cached by CacheManager for up to 1 week
            let fiveYearData = try await MarketDataService.shared.fetchHistoricalData(
                symbol: symbol,
                period: .fiveYears
            )
            
            await MainActor.run {
                self.cachedFiveYearData = fiveYearData
            }
            
            // Calculate historical performance from the 5-year data
            await calculateHistoricalPerformance(for: fetchedStock, using: fiveYearData)
            
            // Enrich with technical indicators using 5-year data (has enough points for SMA200)
            await enrichStockData(fetchedStock, using: fiveYearData)
            
            // Now load the current period's historical data for chart display
            await loadHistoricalData()
            
            await MainActor.run {
                self.stock = fetchedStock
                isLoading = false
            }
            
            // Prefetch other commonly used periods in background (uses cache, won't duplicate)
            let symbolToPrefetch = symbol
            Task.detached(priority: .background) {
                await MarketDataService.shared.prefetchHistoricalData(
                    symbol: symbolToPrefetch,
                    periods: [.oneMonth, .threeMonths, .oneYear]
                )
            }
            
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    /// Calculate historical performance from cached price data (no API call if data is provided)
    private func calculateHistoricalPerformance(for stock: Stock, using fiveYearData: [OHLCV]) async {
        guard !fiveYearData.isEmpty else {
            print("⚠️ No historical data available for performance calculation")
            return
        }
        
        let currentPrice = fiveYearData.last?.close ?? stock.currentPrice
        
        // Calculate changes for different periods (all from the same cached dataset)
        if let dayAgo = findPriceFromDaysAgo(fiveYearData, days: 1) {
            stock.change1D = calculateChange(from: dayAgo, to: currentPrice)
        }
        if let weekAgo = findPriceFromDaysAgo(fiveYearData, days: 7) {
            stock.change1W = calculateChange(from: weekAgo, to: currentPrice)
        }
        if let monthAgo = findPriceFromDaysAgo(fiveYearData, days: 30) {
            stock.change1M = calculateChange(from: monthAgo, to: currentPrice)
        }
        if let threeMonthsAgo = findPriceFromDaysAgo(fiveYearData, days: 90) {
            stock.change3M = calculateChange(from: threeMonthsAgo, to: currentPrice)
        }
        if let yearAgo = findPriceFromDaysAgo(fiveYearData, days: 365) {
            stock.change1Y = calculateChange(from: yearAgo, to: currentPrice)
        }
        if let threeYearsAgo = findPriceFromDaysAgo(fiveYearData, days: 1095) {
            stock.change3Y = calculateChange(from: threeYearsAgo, to: currentPrice)
        }
        if let fiveYearsAgo = findPriceFromDaysAgo(fiveYearData, days: 1825) {
            stock.change5Y = calculateChange(from: fiveYearsAgo, to: currentPrice)
        }
        
        print("📊 Calculated performance for \(symbol) using cached 5-year data")
    }
    
    private func findPriceFromDaysAgo(_ data: [OHLCV], days: Int) -> Double? {
        let targetDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        // Find closest data point to target date
        let sorted = data.sorted { abs($0.date.timeIntervalSince(targetDate)) < abs($1.date.timeIntervalSince(targetDate)) }
        return sorted.first?.close
    }
    
    private func calculateChange(from oldPrice: Double, to newPrice: Double) -> Double {
        guard oldPrice > 0 else { return 0 }
        return ((newPrice - oldPrice) / oldPrice) * 100
    }
    
    /// Enrich stock with additional metrics (technical indicators, estimates)
    /// Uses 5-year data to ensure enough data points for all indicators (especially SMA200)
    private func enrichStockData(_ stock: Stock, using fiveYearData: [OHLCV]) async {
        // Use 5-year data for technical calculations to ensure we have enough data points
        let closes = fiveYearData.map { $0.close }
        
        guard !closes.isEmpty else {
            print("⚠️ No price data available for technical calculations")
            return
        }
        
        // Calculate RSI (14-period)
        if closes.count >= 14 {
            stock.rsi14 = calculateRSI(closes: closes, period: 14)
        }
        
        // Calculate Moving Averages (using 5-year data ensures we have enough points)
        if closes.count >= 20 {
            stock.sma20 = calculateSMA(closes: closes, period: 20)
        }
        if closes.count >= 50 {
            stock.sma50 = calculateSMA(closes: closes, period: 50)
        }
        if closes.count >= 200 {
            stock.sma200 = calculateSMA(closes: closes, period: 200)
        }
        
        // Calculate MACD
        if closes.count >= 26 {
            let (macd, signal) = calculateMACD(closes: closes)
            stock.macd = macd
            stock.macdSignal = signal
        }
        
        // Estimate fair value using simple DCF-like model (simplified for demo)
        stock.fairValue = estimateFairValue(stock: stock)
        
        // Cache technical indicators for reuse
        let technicals = CachedTechnicals(
            symbol: symbol,
            rsi14: stock.rsi14,
            sma20: stock.sma20,
            sma50: stock.sma50,
            sma200: stock.sma200,
            macd: stock.macd,
            macdSignal: stock.macdSignal,
            fetchedAt: Date()
        )
        CacheManager.shared.cacheTechnicals(technicals)
        
        print("📊 Calculated technical indicators for \(symbol) using \(closes.count) data points")
    }
    
    // MARK: - Technical Indicator Calculations
    
    private func calculateRSI(closes: [Double], period: Int) -> Double {
        guard closes.count > period else { return 50 }
        
        var gains: [Double] = []
        var losses: [Double] = []
        
        for i in 1..<closes.count {
            let change = closes[i] - closes[i-1]
            if change >= 0 {
                gains.append(change)
                losses.append(0)
            } else {
                gains.append(0)
                losses.append(abs(change))
            }
        }
        
        guard gains.count >= period else { return 50 }
        
        let avgGain = gains.suffix(period).reduce(0, +) / Double(period)
        let avgLoss = losses.suffix(period).reduce(0, +) / Double(period)
        
        if avgLoss == 0 { return 100 }
        
        let rs = avgGain / avgLoss
        return 100 - (100 / (1 + rs))
    }
    
    private func calculateSMA(closes: [Double], period: Int) -> Double {
        guard closes.count >= period else { return closes.last ?? 0 }
        return closes.suffix(period).reduce(0, +) / Double(period)
    }
    
    private func calculateMACD(closes: [Double]) -> (Double, Double) {
        let ema12 = calculateEMA(closes: closes, period: 12)
        let ema26 = calculateEMA(closes: closes, period: 26)
        let macd = ema12 - ema26
        
        // Signal line is 9-period EMA of MACD (simplified)
        let signal = macd * 0.9 // Simplified for demo
        
        return (macd, signal)
    }
    
    private func calculateEMA(closes: [Double], period: Int) -> Double {
        guard closes.count >= period else { return closes.last ?? 0 }
        
        let multiplier = 2.0 / Double(period + 1)
        var ema = closes.prefix(period).reduce(0, +) / Double(period)
        
        for i in period..<closes.count {
            ema = (closes[i] - ema) * multiplier + ema
        }
        
        return ema
    }
    
    private func estimateFairValue(stock: Stock) -> Double {
        // Simple fair value estimate based on historical average P/E and current earnings
        // This is a simplified model - real fair value calculation would be more sophisticated
        let currentPrice = stock.currentPrice
        
        if let pe = stock.peRatio, pe > 0 {
            // Assume historical average P/E is around 15-20 for most stocks
            let targetPE = 17.5
            return currentPrice * (targetPE / pe)
        }
        
        // Fallback: estimate based on 52-week range midpoint with some adjustment
        let midpoint = (stock.high52Week + stock.low52Week) / 2
        return midpoint * 1.05 // Slight premium for growth assumption
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
    var count: Int = 1
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: pattern.isBullish ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundColor(pattern.isBullish ? .green : .red)
                Text(pattern.patternName)
                    .font(.subheadline.bold())
                
                Spacer()
                
                if count > 1 {
                    Text("×\(count)")
                        .font(.caption.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.3))
                        .cornerRadius(8)
                }
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
                
                Spacer()
                
                Image(systemName: "chevron.right.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.caption)
            }
        }
        .padding()
        .frame(width: 220)
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

// MARK: - Set Alert Sheet
struct SetAlertSheet: View {
    let stock: Stock
    let onSave: (AlertType, Double?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var alertType: AlertType = .buy
    @State private var targetPrice: String = ""
    @State private var usePercentage = false
    @State private var percentageChange: String = "5"
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Alert Type") {
                    Picker("Type", selection: $alertType) {
                        Text("Price Above").tag(AlertType.targetReached)
                        Text("Price Below").tag(AlertType.stopLossTriggered)
                        Text("Buy Signal").tag(AlertType.buy)
                        Text("Sell Signal").tag(AlertType.sell)
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Target Price") {
                    Toggle("Use Percentage", isOn: $usePercentage)
                    
                    if usePercentage {
                        HStack {
                            TextField("Percentage", text: $percentageChange)
                                .keyboardType(.decimalPad)
                            Text("%")
                        }
                        
                        if let pct = Double(percentageChange) {
                            let target = alertType == .stopLossTriggered 
                                ? stock.currentPrice * (1 - pct/100)
                                : stock.currentPrice * (1 + pct/100)
                            Text("Target: \(stock.currencySymbol)\(target, specifier: "%.2f")")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Text(stock.currencySymbol)
                            TextField("Target Price", text: $targetPrice)
                                .keyboardType(.decimalPad)
                        }
                    }
                }
                
                Section("Current Price") {
                    LabeledContent("Current", value: stock.formattedPrice)
                    LabeledContent("52W High", value: "\(stock.currencySymbol)\(String(format: "%.2f", stock.high52Week))")
                    LabeledContent("52W Low", value: "\(stock.currencySymbol)\(String(format: "%.2f", stock.low52Week))")
                }
            }
            .navigationTitle("Set Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let target: Double?
                        if usePercentage, let pct = Double(percentageChange) {
                            target = alertType == .stopLossTriggered 
                                ? stock.currentPrice * (1 - pct/100)
                                : stock.currentPrice * (1 + pct/100)
                        } else {
                            target = Double(targetPrice)
                        }
                        onSave(alertType, target)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - AI Prediction Sheet
struct AIPredictionSheet: View {
    let stock: Stock
    let historicalData: [CandlestickData]
    
    @Environment(\.dismiss) private var dismiss
    @State private var prediction: AIPredictionResult?
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView("Analyzing \(stock.symbol)...")
                            .padding(.vertical, 40)
                    } else if let pred = prediction {
                        // Prediction Header
                        VStack(spacing: 8) {
                            Text(pred.signalEmoji)
                                .font(.system(size: 64))
                            
                            Text(pred.signal)
                                .font(.title.bold())
                                .foregroundColor(pred.signalColor)
                            
                            Text("Confidence: \(pred.confidence)%")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(pred.signalColor.opacity(0.1))
                        .cornerRadius(16)
                        
                        // Price Predictions
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Price Predictions")
                                .font(.headline)
                            
                            PredictionRow(period: "1 Day", price: pred.predicted1D, change: pred.change1D)
                            PredictionRow(period: "5 Days", price: pred.predicted5D, change: pred.change5D)
                            PredictionRow(period: "30 Days", price: pred.predicted30D, change: pred.change30D)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        
                        // Analysis
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Analysis")
                                .font(.headline)
                            
                            ForEach(pred.factors, id: \.self) { factor in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(factor)
                                        .font(.subheadline)
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        
                        // Disclaimer
                        Text("AI predictions are for educational purposes only. Always do your own research before making investment decisions.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("AI Prediction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await generatePrediction()
            }
        }
    }
    
    private func generatePrediction() async {
        // Simulate AI prediction based on technical indicators
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s delay for effect
        
        let closes = historicalData.map { $0.close }
        guard !closes.isEmpty else {
            await MainActor.run { isLoading = false }
            return
        }
        
        // Calculate simple momentum indicators
        let sma20 = closes.count >= 20 ? closes.suffix(20).reduce(0, +) / 20 : closes.last ?? 0
        let sma50 = closes.count >= 50 ? closes.suffix(50).reduce(0, +) / 50 : closes.last ?? 0
        let currentPrice = closes.last ?? stock.currentPrice
        
        // Simple scoring
        var bullishScore = 50
        
        if currentPrice > sma20 { bullishScore += 15 }
        if currentPrice > sma50 { bullishScore += 15 }
        if let rsi = stock.rsi14 {
            if rsi < 30 { bullishScore += 20 } // Oversold
            else if rsi > 70 { bullishScore -= 20 } // Overbought
        }
        
        let signal: String
        let emoji: String
        let color: Color
        
        if bullishScore >= 70 {
            signal = "STRONG BUY"
            emoji = "🚀"
            color = .green
        } else if bullishScore >= 55 {
            signal = "BUY"
            emoji = "🟢"
            color = .green.opacity(0.8)
        } else if bullishScore <= 30 {
            signal = "STRONG SELL"
            emoji = "🔴"
            color = .red
        } else if bullishScore <= 45 {
            signal = "SELL"
            emoji = "🟠"
            color = .orange
        } else {
            signal = "HOLD"
            emoji = "⚪"
            color = .gray
        }
        
        // Generate price predictions
        let momentum = (currentPrice - sma20) / sma20
        let pred1D = currentPrice * (1 + momentum * 0.1)
        let pred5D = currentPrice * (1 + momentum * 0.3)
        let pred30D = currentPrice * (1 + momentum * 0.8)
        
        var factors: [String] = []
        if currentPrice > sma20 { factors.append("Price above 20-day moving average") }
        if currentPrice > sma50 { factors.append("Price above 50-day moving average") }
        if let rsi = stock.rsi14 {
            if rsi < 30 { factors.append("RSI indicates oversold conditions") }
            else if rsi > 70 { factors.append("RSI indicates overbought conditions") }
            else { factors.append("RSI at neutral level (\(Int(rsi)))") }
        }
        factors.append("Based on \(historicalData.count) days of price history")
        
        await MainActor.run {
            prediction = AIPredictionResult(
                signal: signal,
                signalEmoji: emoji,
                signalColor: color,
                confidence: bullishScore,
                predicted1D: pred1D,
                predicted5D: pred5D,
                predicted30D: pred30D,
                currentPrice: currentPrice,
                factors: factors
            )
            isLoading = false
        }
    }
}

struct AIPredictionResult {
    let signal: String
    let signalEmoji: String
    let signalColor: Color
    let confidence: Int
    let predicted1D: Double
    let predicted5D: Double
    let predicted30D: Double
    let currentPrice: Double
    let factors: [String]
    
    var change1D: Double { ((predicted1D - currentPrice) / currentPrice) * 100 }
    var change5D: Double { ((predicted5D - currentPrice) / currentPrice) * 100 }
    var change30D: Double { ((predicted30D - currentPrice) / currentPrice) * 100 }
}

struct PredictionRow: View {
    let period: String
    let price: Double
    let change: Double
    
    var body: some View {
        HStack {
            Text(period)
                .font(.subheadline)
            Spacer()
            VStack(alignment: .trailing) {
                Text("$\(price, specifier: "%.2f")")
                    .font(.subheadline.bold())
                Text("\(change >= 0 ? "+" : "")\(change, specifier: "%.1f")%")
                    .font(.caption)
                    .foregroundColor(change >= 0 ? .green : .red)
            }
        }
    }
}

// MARK: - Add to Portfolio Sheet
struct AddToPortfolioSheet: View {
    let stock: Stock
    let onSave: (Double, Double) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var shares: String = ""
    @State private var avgCost: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Stock") {
                    LabeledContent("Symbol", value: stock.symbol)
                    LabeledContent("Current Price", value: stock.formattedPrice)
                }
                
                Section("Position Details") {
                    TextField("Number of Shares", text: $shares)
                        .keyboardType(.decimalPad)
                    
                    HStack {
                        Text(stock.currencySymbol)
                        TextField("Average Cost", text: $avgCost)
                            .keyboardType(.decimalPad)
                    }
                }
                
                if let sharesNum = Double(shares), let costNum = Double(avgCost) {
                    Section("Summary") {
                        LabeledContent("Total Value", value: "\(stock.currencySymbol)\((sharesNum * costNum).formatted())")
                        
                        let currentValue = sharesNum * stock.currentPrice
                        let costBasis = sharesNum * costNum
                        let pnl = currentValue - costBasis
                        let pnlPercent = (pnl / costBasis) * 100
                        
                        LabeledContent("Current Value", value: "\(stock.currencySymbol)\(currentValue.formatted())")
                        LabeledContent("P&L") {
                            Text("\(pnl >= 0 ? "+" : "")\(stock.currencySymbol)\(pnl.formatted()) (\(pnlPercent >= 0 ? "+" : "")\(pnlPercent, specifier: "%.1f")%)")
                                .foregroundColor(pnl >= 0 ? .green : .red)
                        }
                    }
                }
            }
            .navigationTitle("Add to Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let sharesNum = Double(shares), let costNum = Double(avgCost) {
                            onSave(sharesNum, costNum)
                            dismiss()
                        }
                    }
                    .disabled(shares.isEmpty || avgCost.isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        StockDetailView(symbol: "AAPL")
    }
}
