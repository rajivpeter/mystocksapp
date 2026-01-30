//
//  CandlestickChart.swift
//  MyStocksApp
//
//  Interactive candlestick chart with pattern annotations
//

import SwiftUI
import Charts

// MARK: - Candlestick Data Point
struct CandlestickData: Identifiable {
    let id = UUID()
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int64
    
    var isBullish: Bool { close >= open }
    var bodyTop: Double { max(open, close) }
    var bodyBottom: Double { min(open, close) }
    var bodyHeight: Double { abs(close - open) }
    
    init(date: Date, open: Double, high: Double, low: Double, close: Double, volume: Int64 = 0) {
        self.date = date
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
    }
    
    init(from ohlcv: OHLCV) {
        self.date = ohlcv.date
        self.open = ohlcv.open
        self.high = ohlcv.high
        self.low = ohlcv.low
        self.close = ohlcv.close
        self.volume = ohlcv.volume
    }
}

// MARK: - Pattern Annotation
struct PatternAnnotation: Identifiable {
    let id = UUID()
    let date: Date
    let price: Double
    let patternName: String
    let isBullish: Bool
    let confidence: Int
    let description: String
}

// MARK: - Candlestick Chart View
struct CandlestickChart: View {
    let data: [CandlestickData]
    let patterns: [PatternAnnotation]
    let showVolume: Bool
    let showPatterns: Bool
    let onPatternTap: ((PatternAnnotation) -> Void)?
    
    @State private var selectedCandle: CandlestickData?
    @State private var showTooltip = false
    
    init(
        data: [CandlestickData],
        patterns: [PatternAnnotation] = [],
        showVolume: Bool = true,
        showPatterns: Bool = true,
        onPatternTap: ((PatternAnnotation) -> Void)? = nil
    ) {
        self.data = data
        self.patterns = patterns
        self.showVolume = showVolume
        self.showPatterns = showPatterns
        self.onPatternTap = onPatternTap
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Price Chart
            priceChart
                .frame(height: showVolume ? 250 : 300)
            
            // Volume Chart
            if showVolume {
                volumeChart
                    .frame(height: 60)
            }
            
            // Pattern Legend
            if showPatterns && !patterns.isEmpty {
                patternLegend
            }
        }
    }
    
    // MARK: - Price Chart
    private var priceChart: some View {
        Chart {
            ForEach(data) { candle in
                // High-Low wick
                RectangleMark(
                    x: .value("Date", candle.date),
                    yStart: .value("Low", candle.low),
                    yEnd: .value("High", candle.high),
                    width: 1
                )
                .foregroundStyle(candle.isBullish ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
                
                // Body
                RectangleMark(
                    x: .value("Date", candle.date),
                    yStart: .value("Open", candle.bodyBottom),
                    yEnd: .value("Close", candle.bodyTop),
                    width: 8
                )
                .foregroundStyle(candle.isBullish ? Color.green : Color.red)
            }
            
            // Pattern markers
            if showPatterns {
                ForEach(patterns) { pattern in
                    PointMark(
                        x: .value("Date", pattern.date),
                        y: .value("Price", pattern.price)
                    )
                    .symbolSize(200)
                    .foregroundStyle(pattern.isBullish ? Color.green : Color.red)
                    .annotation(position: pattern.isBullish ? .bottom : .top) {
                        patternMarker(pattern)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: max(1, data.count / 5))) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                    }
                }
                AxisGridLine()
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisValueLabel {
                    if let price = value.as(Double.self) {
                        Text(price, format: .currency(code: "USD").precision(.fractionLength(2)))
                            .font(.caption2)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
            }
        }
        .chartYScale(domain: priceRange)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let location = value.location
                                if let date: Date = proxy.value(atX: location.x) {
                                    selectedCandle = data.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
                                    showTooltip = true
                                }
                            }
                            .onEnded { _ in
                                showTooltip = false
                                selectedCandle = nil
                            }
                    )
            }
        }
        .overlay(alignment: .topLeading) {
            if showTooltip, let candle = selectedCandle {
                candleTooltip(candle)
                    .padding(8)
            }
        }
    }
    
    // MARK: - Volume Chart
    private var volumeChart: some View {
        Chart {
            ForEach(data) { candle in
                BarMark(
                    x: .value("Date", candle.date),
                    y: .value("Volume", candle.volume)
                )
                .foregroundStyle(candle.isBullish ? Color.green.opacity(0.5) : Color.red.opacity(0.5))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 2)) { value in
                AxisValueLabel {
                    if let vol = value.as(Int64.self) {
                        Text(formatVolume(vol))
                            .font(.caption2)
                    }
                }
            }
        }
    }
    
    // MARK: - Pattern Marker
    private func patternMarker(_ pattern: PatternAnnotation) -> some View {
        VStack(spacing: 2) {
            Image(systemName: pattern.isBullish ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.caption2)
                .foregroundColor(pattern.isBullish ? .green : .red)
            
            Text(pattern.patternName)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(pattern.isBullish ? Color.green : Color.red)
                .cornerRadius(4)
        }
        .onTapGesture {
            onPatternTap?(pattern)
        }
    }
    
    // MARK: - Pattern Legend
    private var patternLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(patterns) { pattern in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(pattern.isBullish ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(pattern.patternName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(pattern.confidence)%")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .onTapGesture {
                        onPatternTap?(pattern)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Candle Tooltip
    private func candleTooltip(_ candle: CandlestickData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(candle.date, format: .dateTime.month(.abbreviated).day().year())
                .font(.caption.bold())
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    tooltipRow("O", candle.open)
                    tooltipRow("H", candle.high)
                }
                VStack(alignment: .leading, spacing: 2) {
                    tooltipRow("L", candle.low)
                    tooltipRow("C", candle.close)
                }
            }
            
            Text("Vol: \(formatVolume(candle.volume))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color(UIColor.systemBackground).opacity(0.95))
        .cornerRadius(8)
        .shadow(radius: 4)
    }
    
    private func tooltipRow(_ label: String, _ value: Double) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value, format: .number.precision(.fractionLength(2)))
                .font(.caption.monospacedDigit())
        }
    }
    
    // MARK: - Helpers
    private var priceRange: ClosedRange<Double> {
        guard !data.isEmpty else { return 0...100 }
        let lows = data.map { $0.low }
        let highs = data.map { $0.high }
        let minPrice = (lows.min() ?? 0) * 0.99
        let maxPrice = (highs.max() ?? 100) * 1.01
        return minPrice...maxPrice
    }
    
    private func formatVolume(_ volume: Int64) -> String {
        if volume >= 1_000_000_000 {
            return String(format: "%.1fB", Double(volume) / 1_000_000_000)
        } else if volume >= 1_000_000 {
            return String(format: "%.1fM", Double(volume) / 1_000_000)
        } else if volume >= 1_000 {
            return String(format: "%.1fK", Double(volume) / 1_000)
        }
        return "\(volume)"
    }
}

// MARK: - Line Chart Alternative
struct StockLineChart: View {
    let data: [CandlestickData]
    let color: Color
    
    var body: some View {
        Chart {
            ForEach(data) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Price", point.close)
                )
                .foregroundStyle(color.gradient)
                .interpolationMethod(.catmullRom)
            }
            
            ForEach(data) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Price", point.close)
                )
                .foregroundStyle(color.opacity(0.1).gradient)
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: max(1, data.count / 5))) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisValueLabel {
                    if let price = value.as(Double.self) {
                        Text(price, format: .number.precision(.fractionLength(2)))
                            .font(.caption2)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
            }
        }
    }
}

// MARK: - Preview
#Preview {
    let sampleData = (0..<30).map { i in
        let base = 150.0 + Double.random(in: -10...10)
        let open = base + Double.random(in: -2...2)
        let close = base + Double.random(in: -2...2)
        let high = max(open, close) + Double.random(in: 0...3)
        let low = min(open, close) - Double.random(in: 0...3)
        return CandlestickData(
            date: Calendar.current.date(byAdding: .day, value: i, to: Date())!,
            open: open,
            high: high,
            low: low,
            close: close,
            volume: Int64.random(in: 1_000_000...50_000_000)
        )
    }
    
    let samplePatterns = [
        PatternAnnotation(
            date: Calendar.current.date(byAdding: .day, value: 10, to: Date())!,
            price: 145,
            patternName: "Hammer",
            isBullish: true,
            confidence: 85,
            description: "Bullish reversal pattern"
        )
    ]
    
    return CandlestickChart(data: sampleData, patterns: samplePatterns)
        .frame(height: 350)
        .padding()
        .background(Color.black)
}
