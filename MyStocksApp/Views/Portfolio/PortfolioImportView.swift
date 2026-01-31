//
//  PortfolioImportView.swift
//  MyStocksApp
//
//  CSV, PDF, and Screenshot import for bulk portfolio upload
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PhotosUI
import Vision
import PDFKit

struct PortfolioImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var importMethod: ImportMethod = .file
    @State private var importMode: ImportMode = .merge
    @State private var showFilePicker = false
    @State private var showPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var parsedPositions: [ParsedPosition] = []
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showPreview = false
    @State private var csvText = ""
    @State private var showClearConfirmation = false
    @State private var aggregateDuplicates = true
    @State private var rawOCRText: [String] = [] // For debugging OCR
    @State private var showRawText = false
    
    enum ImportMethod: String, CaseIterable {
        case file = "File Import"
        case manual = "Manual Entry"
    }
    
    enum ImportMode: String, CaseIterable {
        case merge = "Merge"
        case replace = "Replace All"
        
        var description: String {
            switch self {
            case .merge: return "Add to existing positions (duplicates will be combined)"
            case .replace: return "Clear all existing positions first"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Import Method Selector
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Import Method")
                            .font(.headline)
                        
                        Picker("Method", selection: $importMethod) {
                            ForEach(ImportMethod.allCases, id: \.self) { method in
                                Text(method.rawValue).tag(method)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Import Mode & Options
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Import Options")
                            .font(.headline)
                        
                        // Merge vs Replace
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("Mode", selection: $importMode) {
                                ForEach(ImportMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            Text(importMode.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Aggregate duplicates toggle
                        Toggle(isOn: $aggregateDuplicates) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Combine duplicate symbols")
                                    .font(.subheadline)
                                Text("Sum shares if same stock appears multiple times (e.g., BARC in IG + ii)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(.brandPrimary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Content based on method
                    switch importMethod {
                    case .file:
                        fileImportSection
                    case .manual:
                        manualEntrySection
                    }
                    
                    // Preview Section
                    if !parsedPositions.isEmpty {
                        previewSection
                    }
                    
                    // Error Message
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("Import Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !parsedPositions.isEmpty {
                        Button("Import \(parsedPositions.count)") {
                            importPositions()
                        }
                        .fontWeight(.bold)
                    }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.pdf, .commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleUnifiedFileImport(result)
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $selectedPhoto,
                matching: .images
            )
            .onChange(of: selectedPhoto) { _, newValue in
                if let item = newValue {
                    processScreenshot(item)
                }
            }
            .sheet(isPresented: $showRawText) {
                rawTextDebugSheet
            }
        }
    }
    
    // MARK: - Unified File Import Section
    private var fileImportSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Main Import Button
            VStack(alignment: .leading, spacing: 12) {
                Text("Import from File or Photo")
                    .font(.headline)
                
                Text("Upload a PDF statement, CSV file, or screenshot from your broker app.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Two main buttons
                HStack(spacing: 12) {
                    Button {
                        showFilePicker = true
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.fill")
                                .font(.title2)
                            Text("PDF / CSV")
                                .font(.subheadline.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brandPrimary)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button {
                        showPhotoPicker = true
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.fill")
                                .font(.title2)
                            Text("Screenshot")
                                .font(.subheadline.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brandBlue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
            
            // Supported platforms
            VStack(alignment: .leading, spacing: 8) {
                Text("Works with:")
                    .font(.caption.bold())
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["IG", "Interactive Investor", "Hargreaves Lansdown", "Freetrade", "Trading 212"], id: \.self) { broker in
                            Text(broker)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.brandPrimary.opacity(0.15))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            // Tips
            VStack(alignment: .leading, spacing: 6) {
                Text("Tips for best results:")
                    .font(.caption.bold())
                Label("PDF statements work best (portfolio/holdings page)", systemImage: "checkmark.circle.fill")
                Label("For screenshots, crop to just the positions table", systemImage: "checkmark.circle.fill")
                Label("Ensure stock symbols and quantities are visible", systemImage: "checkmark.circle.fill")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            // CSV Format Help
            DisclosureGroup("CSV Format") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("symbol,shares,average_cost,currency")
                        .font(.system(.caption, design: .monospaced))
                    Text("AAPL,100,150.50,USD")
                        .font(.system(.caption, design: .monospaced))
                    Text("BARC.L,500,1.50,GBP")
                        .font(.system(.caption, design: .monospaced))
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.2))
                .cornerRadius(8)
            }
            .font(.caption)
            
            // Or paste CSV
            DisclosureGroup("Paste CSV Data") {
                VStack(spacing: 12) {
                    TextEditor(text: $csvText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(height: 120)
                        .padding(8)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(8)
                    
                    if !csvText.isEmpty {
                        Button {
                            parseCSVText(csvText)
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                Text("Parse CSV")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .font(.caption)
            
            // Processing indicator
            if isProcessing {
                HStack {
                    ProgressView()
                    Text("Processing...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            
            // Debug option
            if !rawOCRText.isEmpty {
                Button {
                    showRawText = true
                } label: {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("View Extracted Text (Debug)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Raw Text Debug Sheet
    private var rawTextDebugSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Raw Extracted Text")
                        .font(.headline)
                        .padding(.bottom)
                    
                    Text("This is what we extracted from your image/PDF. If positions are missing, check if the text contains recognizable stock symbols and numbers.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom)
                    
                    ForEach(Array(rawOCRText.enumerated()), id: \.offset) { index, line in
                        Text("\(index + 1): \(line)")
                            .font(.system(.caption, design: .monospaced))
                            .padding(.vertical, 2)
                    }
                }
                .padding()
            }
            .navigationTitle("Extracted Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showRawText = false }
                }
            }
        }
    }
    
    // MARK: - Manual Entry Section
    private var manualEntrySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Manual Entry")
                .font(.headline)
            
            Text("Add positions one at a time or in bulk format.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ManualPositionEntry { position in
                parsedPositions.append(position)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Preview Section
    private var previewSection: some View {
        let displayPositions = aggregateDuplicates ? aggregatePositions(parsedPositions) : parsedPositions
        let hasDuplicates = parsedPositions.count != displayPositions.count
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Preview (\(displayPositions.count) positions)")
                        .font(.headline)
                    if hasDuplicates {
                        Text("\(parsedPositions.count - displayPositions.count) duplicates will be combined")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                Spacer()
                Button("Clear All") {
                    parsedPositions.removeAll()
                }
                .foregroundColor(.red)
            }
            
            // Show aggregated or raw positions
            ForEach(displayPositions) { position in
                ParsedPositionRow(position: position) {
                    // Remove all matching symbols from original list
                    parsedPositions.removeAll { $0.symbol == position.symbol }
                }
            }
            
            // Summary
            if !displayPositions.isEmpty {
                HStack {
                    Text("Total Value:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("~\(formatTotalValue(displayPositions))")
                        .font(.subheadline.bold())
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func formatTotalValue(_ positions: [ParsedPosition]) -> String {
        let total = positions.reduce(0) { $0 + $1.estimatedValue }
        let hasGBP = positions.contains { $0.currency == "GBP" }
        let hasUSD = positions.contains { $0.currency == "USD" }
        
        if hasGBP && hasUSD {
            return "Mixed currencies"
        } else if hasGBP {
            return "£\(total.formatted(.number.precision(.fractionLength(2))))"
        } else {
            return "$\(total.formatted(.number.precision(.fractionLength(2))))"
        }
    }
    
    // MARK: - Unified File Import Handler (PDF + CSV)
    private func handleUnifiedFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Start accessing security-scoped resource
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { 
                if hasAccess { url.stopAccessingSecurityScopedResource() }
            }
            
            let fileExtension = url.pathExtension.lowercased()
            
            if fileExtension == "pdf" {
                // Handle PDF
                isProcessing = true
                errorMessage = nil
                
                // Copy PDF data to temp location (fixes security-scoped resource issues)
                do {
                    let fileData = try Data(contentsOf: url)
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("import_\(UUID().uuidString).pdf")
                    try fileData.write(to: tempURL)
                    
                    Task {
                        await extractTextFromPDF(url: tempURL)
                        // Clean up temp file
                        try? FileManager.default.removeItem(at: tempURL)
                    }
                } catch {
                    errorMessage = "Failed to read PDF: \(error.localizedDescription)"
                    isProcessing = false
                }
            } else {
                // Handle CSV/Text
                do {
                    let contents = try String(contentsOf: url, encoding: .utf8)
                    parseCSVText(contents)
                } catch {
                    errorMessage = "Failed to read file: \(error.localizedDescription)"
                }
            }
            
        case .failure(let error):
            errorMessage = "File import failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - CSV Parser
    private func parseCSVText(_ text: String) {
        parsedPositions.removeAll()
        errorMessage = nil
        
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard lines.count > 1 else {
            errorMessage = "CSV file appears to be empty"
            return
        }
        
        // Skip header row
        for (index, line) in lines.dropFirst().enumerated() {
            let columns = line.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            
            guard columns.count >= 3 else {
                print("Skipping line \(index + 2): insufficient columns")
                continue
            }
            
            let symbol = columns[0].uppercased()
            guard let shares = Double(columns[1]),
                  let avgCost = Double(columns[2]) else {
                print("Skipping line \(index + 2): invalid numbers")
                continue
            }
            
            let currency = columns.count > 3 ? columns[3].uppercased() : "USD"
            
            let position = ParsedPosition(
                symbol: symbol,
                shares: shares,
                averageCost: avgCost,
                currency: currency
            )
            parsedPositions.append(position)
        }
        
        if parsedPositions.isEmpty {
            errorMessage = "No valid positions found in CSV"
        }
    }
    
    // MARK: - Screenshot OCR
    private func processScreenshot(_ item: PhotosPickerItem) {
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let cgImage = image.cgImage else {
                    await MainActor.run {
                        errorMessage = "Failed to load image"
                        isProcessing = false
                    }
                    return
                }
                
                // Perform OCR
                let request = VNRecognizeTextRequest { request, error in
                    if let error = error {
                        Task { @MainActor in
                            self.errorMessage = "OCR failed: \(error.localizedDescription)"
                            self.isProcessing = false
                        }
                        return
                    }
                    
                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        Task { @MainActor in
                            self.errorMessage = "No text found in image"
                            self.isProcessing = false
                        }
                        return
                    }
                    
                    let recognizedText = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }
                    
                    Task { @MainActor in
                        self.parseOCRText(recognizedText)
                        self.isProcessing = false
                    }
                }
                
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try handler.perform([request])
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to process image: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }
    
    // MARK: - PDF Text Extraction
    private func extractTextFromPDF(url: URL) async {
        guard let pdfDocument = PDFDocument(url: url) else {
            await MainActor.run {
                errorMessage = "Could not open PDF document"
                isProcessing = false
            }
            return
        }
        
        var allText: [String] = []
        
        // Extract text from all pages
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            
            if let pageText = page.string {
                let lines = pageText.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                allText.append(contentsOf: lines)
            }
        }
        
        await MainActor.run {
            rawOCRText = allText
            parseExtractedText(allText, source: "PDF")
            isProcessing = false
        }
    }
    
    // MARK: - OCR Text Parser (Enhanced)
    private func parseOCRText(_ lines: [String]) {
        rawOCRText = lines
        parseExtractedText(lines, source: "screenshot")
    }
    
    // MARK: - Unified Text Parser (for both OCR and PDF)
    private func parseExtractedText(_ lines: [String], source: String) {
        parsedPositions.removeAll()
        
        // Detect if this is an IG statement
        let fullText = lines.joined(separator: " ")
        let isIGStatement = fullText.contains("IG") || fullText.contains("ig.com") || 
                            fullText.contains("Share Dealing") || fullText.contains("EPIC")
        let isUKDocument = fullText.contains("£") || fullText.contains("GBP") || 
                           fullText.contains("London") || fullText.contains("LSE") ||
                           fullText.contains("plc") || fullText.contains("PLC")
        
        // Default currency based on document type
        let defaultCurrency = isUKDocument ? "GBP" : "USD"
        
        print("📄 Parsing \(source): isIG=\(isIGStatement), isUK=\(isUKDocument), defaultCurrency=\(defaultCurrency)")
        print("📄 Total lines: \(lines.count)")
        
        var foundPositions: [String: (shares: Double, avgCost: Double, marketValue: Double, currency: String)] = [:]
        
        // Extended list of UK stock symbols (IG uses EPIC codes)
        let ukSymbols = Set([
            // FTSE 100
            "BARC", "LLOY", "HSBA", "BP", "SHEL", "VOD", "AZN", "GSK", "ULVR", "RIO",
            "GLEN", "AAL", "BHP", "RR", "IAG", "BA", "BATS", "DGE", "REL", "NG",
            "SSE", "CNA", "LGEN", "STAN", "PRU", "EXPN", "SMT", "CPG", "SBRY", "TSCO",
            "ABF", "ANTO", "PSON", "WPP", "IHG", "INF", "SGE", "IMB", "MNG", "JD",
            "SMIN", "RMV", "AUTO", "FRAS", "BDEV", "TW", "PSN", "NWG", "LAND", "WTB",
            // FTSE 250
            "III", "PDG", "HIK", "DARK", "RTO", "SHED", "MGGT", "JMAT", "MNDI", "SMDS",
            "GFTU", "CCH", "SDR", "WEIR", "RWS", "QQ", "OCDO", "AGK", "KGF", "PHNX",
            // LSE Small Cap
            "LSE", "ITV", "FOUR", "VNET"
        ])
        
        // US symbols
        let usSymbols = Set([
            "AAPL", "MSFT", "GOOGL", "GOOG", "AMZN", "TSLA", "META", "NVDA", "JPM", "V",
            "JNJ", "WMT", "PG", "MA", "HD", "DIS", "NFLX", "PYPL", "INTC", "AMD",
            "CRM", "ADBE", "CSCO", "PFE", "KO", "PEP", "MRK", "ABT", "TMO", "COST",
            "ORCL", "ACN", "AVGO", "TXN", "QCOM", "UNH", "CVX", "XOM", "BAC", "WFC"
        ])
        
        // Words to exclude from symbol detection
        let excludeWords = Set([
            "THE", "AND", "FOR", "PLC", "LTD", "INC", "USD", "GBP", "EUR", "BUY", "SELL",
            "OPEN", "CLOSE", "HIGH", "LOW", "TOTAL", "NET", "FEE", "TAX", "CASH", "DIV",
            "DIVIDEND", "VALUE", "PRICE", "COST", "PROFIT", "LOSS", "SHARE", "SHARES",
            "STOCK", "EPIC", "NAME", "QTY", "AVG", "MKT", "PAGE", "DATE", "REF"
        ])
        
        // Pattern for extracting numbers with optional currency symbols
        let numberPattern = try! NSRegularExpression(
            pattern: "[£$]?([0-9]{1,3}(?:,?[0-9]{3})*(?:\\.[0-9]{1,4})?)",
            options: []
        )
        
        // Pattern for stock symbols (2-5 uppercase letters, optionally with .L suffix)
        let symbolPattern = try! NSRegularExpression(
            pattern: "\\b([A-Z]{2,5})(?:\\.L)?\\b",
            options: []
        )
        
        // Process line by line looking for positions
        var i = 0
        while i < lines.count {
            let line = lines[i]
            let range = NSRange(line.startIndex..., in: line)
            
            // Find potential symbols in this line
            let symbolMatches = symbolPattern.matches(in: line, options: [], range: range)
            
            for match in symbolMatches {
                guard let symbolRange = Range(match.range(at: 1), in: line) else { continue }
                let symbol = String(line[symbolRange])
                
                // Skip excluded words
                if excludeWords.contains(symbol) { continue }
                
                // Check if this looks like a valid stock symbol
                let isKnownUK = ukSymbols.contains(symbol)
                let isKnownUS = usSymbols.contains(symbol)
                let looksLikeSymbol = symbol.count >= 2 && symbol.count <= 5
                
                if isKnownUK || isKnownUS || (looksLikeSymbol && !excludeWords.contains(symbol)) {
                    // Determine currency
                    let currency: String
                    if isKnownUK || line.contains("£") || line.contains("GBP") {
                        currency = "GBP"
                    } else if isKnownUS || line.contains("$") || line.contains("USD") {
                        currency = "USD"
                    } else {
                        currency = defaultCurrency
                    }
                    
                    // Look for numbers in this line and nearby lines
                    var numbersFound: [Double] = []
                    
                    // Check current line and next 2 lines for numbers
                    for j in i..<min(i + 3, lines.count) {
                        let searchLine = lines[j]
                        let searchRange = NSRange(searchLine.startIndex..., in: searchLine)
                        let numMatches = numberPattern.matches(in: searchLine, options: [], range: searchRange)
                        
                        for numMatch in numMatches {
                            if let numRange = Range(numMatch.range(at: 1), in: searchLine) {
                                let numStr = String(searchLine[numRange]).replacingOccurrences(of: ",", with: "")
                                if let num = Double(numStr), num > 0 {
                                    numbersFound.append(num)
                                }
                            }
                        }
                    }
                    
                    // IG format typically has: Quantity, Avg Open, Current Price, Market Value, P/L
                    // We want: shares (quantity), avgCost (avg open), marketValue
                    if numbersFound.count >= 2 {
                        // Heuristics to identify which number is which:
                        // - Shares are usually whole numbers or small decimals < 10000
                        // - Prices are usually < 10000 with decimals
                        // - Market value is usually the largest number
                        
                        let sortedNums = numbersFound.sorted()
                        let maxNum = sortedNums.last ?? 0
                        
                        var shares: Double = 0
                        var avgCost: Double = 0
                        var marketValue: Double = maxNum
                        
                        // Find shares - usually the first reasonable quantity
                        for num in numbersFound {
                            if num < 100000 && num != maxNum {
                                if shares == 0 {
                                    shares = num
                                } else if avgCost == 0 && num < shares {
                                    // This might be the price, swap
                                    avgCost = shares
                                    shares = num
                                } else if avgCost == 0 {
                                    avgCost = num
                                }
                            }
                        }
                        
                        // If we have market value but no avgCost, calculate it
                        if avgCost == 0 && shares > 0 && marketValue > 0 {
                            avgCost = marketValue / shares
                        }
                        
                        // Only add if we have valid data
                        if shares > 0 && (avgCost > 0 || marketValue > 0) {
                            // Check if this position already exists (aggregate)
                            if let existing = foundPositions[symbol] {
                                let totalShares = existing.shares + shares
                                let totalValue = existing.marketValue + marketValue
                                let newAvgCost = totalValue / totalShares
                                foundPositions[symbol] = (totalShares, newAvgCost, totalValue, currency)
                            } else {
                                foundPositions[symbol] = (shares, avgCost, marketValue, currency)
                            }
                            print("✅ Found: \(symbol) - \(shares) shares @ \(currency)\(avgCost) = \(currency)\(marketValue)")
                        }
                    }
                }
            }
            i += 1
        }
        
        // Convert to ParsedPosition array
        for (symbol, data) in foundPositions {
            let position = ParsedPosition(
                symbol: symbol,
                shares: data.shares,
                averageCost: data.avgCost,
                currency: data.currency
            )
            parsedPositions.append(position)
        }
        
        // Sort by market value descending
        parsedPositions.sort { $0.estimatedValue > $1.estimatedValue }
        
        print("📊 Total positions found: \(parsedPositions.count)")
        
        if parsedPositions.isEmpty {
            errorMessage = "Could not extract positions from \(source). Tap 'View Extracted Text' to see what was found, or try CSV import instead."
        }
    }
    
    // MARK: - Import Positions
    private func importPositions() {
        // Aggregate duplicates if enabled
        var positionsToImport = parsedPositions
        if aggregateDuplicates {
            positionsToImport = aggregatePositions(parsedPositions)
        }
        
        // Clear existing if replace mode
        if importMode == .replace {
            clearAllPositions()
        }
        
        for parsed in positionsToImport {
            // Check if we should merge with existing position
            if importMode == .merge {
                if let existingPosition = findExistingPosition(symbol: parsed.symbol) {
                    // Calculate weighted average cost
                    let totalShares = existingPosition.shares + parsed.shares
                    let totalCost = (existingPosition.shares * existingPosition.averageCost) + (parsed.shares * parsed.averageCost)
                    let newAvgCost = totalCost / totalShares
                    
                    existingPosition.shares = totalShares
                    existingPosition.averageCost = newAvgCost
                    continue
                }
            }
            
            // Create Stock
            let stock = Stock(
                symbol: parsed.symbol,
                name: parsed.symbol, // Will be updated when fetching data
                currency: Currency(rawValue: parsed.currency) ?? .usd
            )
            
            // Create Position (symbol is required first parameter)
            let position = Position(
                symbol: parsed.symbol,
                shares: parsed.shares,
                averageCost: parsed.averageCost,
                purchaseDate: Date(),
                stock: stock
            )
            
            modelContext.insert(stock)
            modelContext.insert(position)
        }
        
        try? modelContext.save()
        dismiss()
    }
    
    // MARK: - Aggregate Positions
    private func aggregatePositions(_ positions: [ParsedPosition]) -> [ParsedPosition] {
        var aggregated: [String: ParsedPosition] = [:]
        
        for position in positions {
            if var existing = aggregated[position.symbol] {
                // Calculate weighted average cost
                let totalShares = existing.shares + position.shares
                let totalCost = (existing.shares * existing.averageCost) + (position.shares * position.averageCost)
                let newAvgCost = totalCost / totalShares
                
                existing.shares = totalShares
                existing.averageCost = newAvgCost
                aggregated[position.symbol] = existing
            } else {
                aggregated[position.symbol] = position
            }
        }
        
        return Array(aggregated.values)
    }
    
    // MARK: - Find Existing Position
    private func findExistingPosition(symbol: String) -> Position? {
        let descriptor = FetchDescriptor<Position>(
            predicate: #Predicate { $0.symbol == symbol }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    // MARK: - Clear All Positions
    private func clearAllPositions() {
        do {
            let positions = try modelContext.fetch(FetchDescriptor<Position>())
            for position in positions {
                modelContext.delete(position)
            }
            try modelContext.save()
        } catch {
            print("Error clearing positions: \(error)")
        }
    }
}

// MARK: - Supporting Types

struct ParsedPosition: Identifiable {
    let id = UUID()
    var symbol: String
    var shares: Double
    var averageCost: Double
    var currency: String
    
    var estimatedValue: Double {
        shares * averageCost
    }
}

struct ParsedPositionRow: View {
    let position: ParsedPosition
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(position.symbol)
                    .font(.headline)
                Text("\(position.shares, specifier: "%.2f") shares @ \(position.currency == "GBP" ? "£" : "$")\(position.averageCost, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(position.currency == "GBP" ? "£" : "$")\(position.estimatedValue, specifier: "%.2f")")
                    .font(.subheadline.bold())
                Text("Est. Value")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red.opacity(0.7))
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(8)
    }
}

struct PlatformBadge: View {
    let name: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(name)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.2))
        .cornerRadius(8)
    }
}

struct ManualPositionEntry: View {
    let onAdd: (ParsedPosition) -> Void
    
    @State private var symbol = ""
    @State private var shares = ""
    @State private var avgCost = ""
    @State private var currency = "USD"
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                TextField("Symbol", text: $symbol)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                
                TextField("Shares", text: $shares)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
            }
            
            HStack(spacing: 12) {
                TextField("Avg Cost", text: $avgCost)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                
                Picker("Currency", selection: $currency) {
                    Text("USD").tag("USD")
                    Text("GBP").tag("GBP")
                    Text("EUR").tag("EUR")
                }
                .pickerStyle(.menu)
            }
            
            Button {
                guard !symbol.isEmpty,
                      let sharesNum = Double(shares),
                      let costNum = Double(avgCost) else { return }
                
                let position = ParsedPosition(
                    symbol: symbol.uppercased(),
                    shares: sharesNum,
                    averageCost: costNum,
                    currency: currency
                )
                onAdd(position)
                
                // Clear fields
                symbol = ""
                shares = ""
                avgCost = ""
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Position")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(symbol.isEmpty || shares.isEmpty || avgCost.isEmpty)
        }
    }
}

// MARK: - Preview
#Preview {
    PortfolioImportView()
}
