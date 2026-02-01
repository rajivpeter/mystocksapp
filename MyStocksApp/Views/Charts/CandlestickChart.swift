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
    
    // Unique color for each pattern type
    var patternColor: Color {
        switch patternName.lowercased() {
        case "hammer":
            return .green
        case "shooting star":
            return .red
        case "doji":
            return .purple
        case "dragonfly doji":
            return .teal
        case "gravestone doji":
            return .orange
        case "bullish engulfing":
            return .mint
        case "bearish engulfing":
            return .pink
        case "piercing line":
            return .cyan
        case "dark cloud cover":
            return .indigo
        case "morning star":
            return Color(red: 0.2, green: 0.8, blue: 0.4) // Bright green
        case "evening star":
            return Color(red: 0.8, green: 0.2, blue: 0.3) // Dark red
        case "three white soldiers":
            return Color(red: 0.1, green: 0.7, blue: 0.5) // Teal green
        case "three black crows":
            return Color(red: 0.6, green: 0.1, blue: 0.2) // Maroon
        case "spinning top":
            return .yellow
        default:
            return isBullish ? .green : .red
        }
    }
    
    // Icon for each pattern
    var patternIcon: String {
        switch patternName.lowercased() {
        case "hammer":
            return "hammer.fill"
        case "shooting star":
            return "star.fill"
        case "doji", "dragonfly doji", "gravestone doji":
            return "plus"
        case "bullish engulfing", "bearish engulfing":
            return "square.on.square"
        case "morning star", "evening star":
            return "star.circle.fill"
        case "three white soldiers":
            return "person.3.fill"
        case "three black crows":
            return "bird.fill"
        default:
            return "chart.bar.fill"
        }
    }
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
    
    // Zoom and pan state
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var offset: CGFloat = 0
    @State private var lastOffset: CGFloat = 0
    @GestureState private var magnifyBy: CGFloat = 1.0
    
    // Computed visible data based on zoom
    private var visibleData: [CandlestickData] {
        guard !data.isEmpty else { return [] }
        
        let totalCount = data.count
        let visibleCount = max(5, Int(Double(totalCount) / Double(zoomScale)))
        
        // Calculate start index based on offset
        let maxOffset = max(0, totalCount - visibleCount)
        let normalizedOffset = min(maxOffset, max(0, Int(offset)))
        
        let startIndex = normalizedOffset
        let endIndex = min(totalCount, startIndex + visibleCount)
        
        return Array(data[startIndex..<endIndex])
    }
    
    // Visible patterns based on zoom
    private var visiblePatterns: [PatternAnnotation] {
        guard !visibleData.isEmpty else { return patterns }
        guard let firstDate = visibleData.first?.date,
              let lastDate = visibleData.last?.date else { return patterns }
        
        return patterns.filter { pattern in
            pattern.date >= firstDate && pattern.date <= lastDate
        }
    }
    
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
            // Zoom controls
            zoomControls
            
            // Price Chart with gestures
            priceChart
                .frame(height: showVolume ? 250 : 300)
                .gesture(zoomGesture)
                .gesture(panGesture)
            
            // Volume Chart
            if showVolume {
                volumeChart
                    .frame(height: 60)
            }
            
            // Pattern Legend with colors
            if showPatterns && !visiblePatterns.isEmpty {
                patternLegend
            }
        }
    }
    
    // MARK: - Zoom Controls
    private var zoomControls: some View {
        HStack {
            // Zoom out
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    zoomScale = max(1.0, zoomScale - 0.5)
                }
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.caption)
                    .padding(6)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(6)
            }
            
            Text("\(Int(zoomScale * 100))%")
                .font(.caption.monospacedDigit())
                .frame(width: 50)
            
            // Zoom in
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    zoomScale = min(5.0, zoomScale + 0.5)
                }
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.caption)
                    .padding(6)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(6)
            }
            
            Spacer()
            
            // Reset
            if zoomScale != 1.0 || offset != 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        zoomScale = 1.0
                        offset = 0
                    }
                } label: {
                    Text("Reset")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.brandPrimary.opacity(0.2))
                        .cornerRadius(6)
                }
            }
            
            // Pinch hint
            HStack(spacing: 4) {
                Image(systemName: "hand.pinch")
                    .font(.caption2)
                Text("Pinch to zoom")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    // MARK: - Gestures
    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .updating($magnifyBy) { currentState, gestureState, _ in
                gestureState = currentState
            }
            .onEnded { value in
                let newScale = lastZoomScale * value
                withAnimation(.easeInOut(duration: 0.1)) {
                    zoomScale = min(5.0, max(1.0, newScale))
                }
                lastZoomScale = zoomScale
            }
    }
    
    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only pan when zoomed in
                if zoomScale > 1.0 {
                    let delta = value.translation.width / 10 // Sensitivity
                    offset = lastOffset - delta
                    
                    // Clamp to valid range
                    let maxOffset = CGFloat(max(0, data.count - Int(Double(data.count) / Double(zoomScale))))
                    offset = max(0, min(maxOffset, offset))
                }
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }
    
    // MARK: - Price Chart
    private var priceChart: some View {
        Chart {
            ForEach(visibleData) { candle in
                // High-Low wick
                RectangleMark(
                    x: .value("Date", candle.date),
                    yStart: .value("Low", candle.low),
                    yEnd: .value("High", candle.high),
                    width: 1
                )
                .foregroundStyle(candle.isBullish ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
                
                // Body - width increases with zoom
                let bodyWidth: MarkDimension = zoomScale > 2 ? 12 : (zoomScale > 1.5 ? 10 : 8)
                RectangleMark(
                    x: .value("Date", candle.date),
                    yStart: .value("Open", candle.bodyBottom),
                    yEnd: .value("Close", candle.bodyTop),
                    width: bodyWidth
                )
                .foregroundStyle(candle.isBullish ? Color.green : Color.red)
            }
            
            // Pattern markers with unique colors
            if showPatterns {
                ForEach(visiblePatterns) { pattern in
                    PointMark(
                        x: .value("Date", pattern.date),
                        y: .value("Price", pattern.price)
                    )
                    .symbolSize(zoomScale > 1.5 ? 300 : 200)
                    .foregroundStyle(pattern.patternColor) // Use unique color!
                    .annotation(position: pattern.isBullish ? .bottom : .top) {
                        patternMarker(pattern)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: max(1, visibleData.count / 5))) { value in
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
        .chartYScale(domain: visiblePriceRange)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        TapGesture()
                            .onEnded { _ in
                                // Handle tap for selecting candle
                            }
                    )
                    .gesture(
                        LongPressGesture(minimumDuration: 0.2)
                            .sequenced(before: DragGesture(minimumDistance: 0))
                            .onChanged { value in
                                switch value {
                                case .second(true, let drag):
                                    if let location = drag?.location,
                                       let date: Date = proxy.value(atX: location.x) {
                                        selectedCandle = visibleData.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
                                        showTooltip = true
                                    }
                                default:
                                    break
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
    
    // Visible price range (recalculated for zoom)
    private var visiblePriceRange: ClosedRange<Double> {
        guard !visibleData.isEmpty else { return 0...100 }
        let lows = visibleData.map { $0.low }
        let highs = visibleData.map { $0.high }
        let minPrice = (lows.min() ?? 0) * 0.995
        let maxPrice = (highs.max() ?? 100) * 1.005
        return minPrice...maxPrice
    }
    
    // MARK: - Volume Chart
    private var volumeChart: some View {
        Chart {
            ForEach(visibleData) { candle in
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
            Image(systemName: pattern.patternIcon)
                .font(.caption2)
                .foregroundColor(pattern.patternColor)
            
            Text(pattern.patternName)
                .font(.system(size: zoomScale > 1.5 ? 10 : 8, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(pattern.patternColor)
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
                ForEach(visiblePatterns) { pattern in
                    HStack(spacing: 6) {
                        // Pattern-specific icon and color
                        Image(systemName: pattern.patternIcon)
                            .font(.caption)
                            .foregroundColor(pattern.patternColor)
                        
                        Text(pattern.patternName)
                            .font(.caption)
                            .foregroundColor(.primary)
                        
                        // Confidence badge
                        Text("\(pattern.confidence)%")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(pattern.patternColor)
                            .cornerRadius(6)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(pattern.patternColor.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(pattern.patternColor, lineWidth: 1)
                    )
                    .cornerRadius(10)
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
