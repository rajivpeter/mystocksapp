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
    
    @State private var importMethod: ImportMethod = .csv
    @State private var importMode: ImportMode = .merge
    @State private var showFilePicker = false
    @State private var showPDFPicker = false
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
        case csv = "CSV"
        case pdf = "PDF"
        case screenshot = "Photo"
        case manual = "Manual"
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
                    case .csv:
                        csvImportSection
                    case .pdf:
                        pdfImportSection
                    case .screenshot:
                        screenshotImportSection
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
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .fileImporter(
                isPresented: $showPDFPicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handlePDFImport(result)
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
    
    // MARK: - PDF Import Section
    private var pdfImportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PDF Statement Import")
                .font(.headline)
            
            Text("Upload a PDF statement from your broker. We'll extract your holdings from the document.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Supported Formats
            VStack(alignment: .leading, spacing: 8) {
                Text("Supported statement formats:")
                    .font(.caption.bold())
                HStack(spacing: 12) {
                    ForEach(["IG", "ii", "HL", "Freetrade", "Trading 212"], id: \.self) { broker in
                        Text(broker)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.brandPrimary.opacity(0.2))
                            .cornerRadius(6)
                    }
                }
            }
            
            // Tips
            VStack(alignment: .leading, spacing: 4) {
                Label("Works best with monthly/quarterly statements", systemImage: "checkmark.circle")
                Label("Holdings/portfolio summary pages are ideal", systemImage: "checkmark.circle")
                Label("Text-based PDFs work better than scanned images", systemImage: "info.circle")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            // Upload Button
            Button {
                showPDFPicker = true
            } label: {
                HStack {
                    Image(systemName: "doc.text.fill")
                    Text("Select PDF Statement")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.brandPrimary)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            if isProcessing {
                HStack {
                    ProgressView()
                    Text("Extracting positions from PDF...")
                        .foregroundColor(.secondary)
                }
                .padding()
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
    
    // MARK: - CSV Import Section
    private var csvImportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CSV Import")
                .font(.headline)
            
            Text("Upload a CSV file with your portfolio positions. Expected format:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Format Example
            VStack(alignment: .leading, spacing: 4) {
                Text("symbol,shares,average_cost,currency")
                    .font(.system(.caption, design: .monospaced))
                Text("AAPL,100,150.50,USD")
                    .font(.system(.caption, design: .monospaced))
                Text("TSLA,50,200.00,USD")
                    .font(.system(.caption, design: .monospaced))
                Text("VOD.L,1000,0.85,GBP")
                    .font(.system(.caption, design: .monospaced))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
            
            // Upload Button
            Button {
                showFilePicker = true
            } label: {
                HStack {
                    Image(systemName: "doc.badge.plus")
                    Text("Select CSV File")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            // Or paste CSV
            Text("Or paste CSV content:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextEditor(text: $csvText)
                .font(.system(.caption, design: .monospaced))
                .frame(height: 150)
                .padding(8)
                .background(Color.gray.opacity(0.1))
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
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Screenshot Import Section
    private var screenshotImportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Screenshot Import")
                .font(.headline)
            
            Text("Take a screenshot of your portfolio from your broker app. For best results:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Tips for better OCR
            VStack(alignment: .leading, spacing: 6) {
                Label("Ensure stock symbols are clearly visible", systemImage: "textformat")
                Label("Include the holdings/positions table", systemImage: "tablecells")
                Label("Crop to just the portfolio section", systemImage: "crop")
                Label("Use landscape mode for wide tables", systemImage: "rectangle.landscape.rotate")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            // Supported Platforms
            VStack(alignment: .leading, spacing: 8) {
                Text("Tested with:")
                    .font(.caption.bold())
                HStack(spacing: 12) {
                    PlatformBadge(name: "IG", icon: "chart.line.uptrend.xyaxis")
                    PlatformBadge(name: "HL", icon: "building.columns.fill")
                    PlatformBadge(name: "ii", icon: "chart.bar.fill")
                    PlatformBadge(name: "Freetrade", icon: "sparkles")
                }
            }
            
            // Upload Button
            Button {
                showPhotoPicker = true
            } label: {
                HStack {
                    Image(systemName: "photo.badge.plus")
                    Text("Select Screenshot")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            if isProcessing {
                HStack {
                    ProgressView()
                    Text("Processing screenshot...")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            // Debug option
            if !rawOCRText.isEmpty {
                Button {
                    showRawText = true
                } label: {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("View Extracted Text")
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
    
    // MARK: - File Import Handler
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Permission denied to access file"
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let contents = try String(contentsOf: url, encoding: .utf8)
                parseCSVText(contents)
            } catch {
                errorMessage = "Failed to read file: \(error.localizedDescription)"
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
    
    // MARK: - PDF Import Handler
    private func handlePDFImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Permission denied to access PDF"
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            isProcessing = true
            errorMessage = nil
            
            Task {
                await extractTextFromPDF(url: url)
            }
            
        case .failure(let error):
            errorMessage = "PDF import failed: \(error.localizedDescription)"
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
        
        // Known stock symbols from common UK/US exchanges
        let knownSymbols = Set([
            // UK stocks (FTSE)
            "BARC", "LLOY", "HSBA", "BP", "SHEL", "VOD", "AZN", "GSK", "ULVR", "RIO",
            "GLEN", "AAL", "BHP", "RR", "IAG", "AVV", "BA", "BATS", "DGE", "REL",
            // US stocks
            "AAPL", "MSFT", "GOOGL", "GOOG", "AMZN", "TSLA", "META", "NVDA", "JPM", "V",
            "JNJ", "WMT", "PG", "MA", "HD", "DIS", "NFLX", "PYPL", "INTC", "AMD",
            "CRM", "ADBE", "CSCO", "PFE", "KO", "PEP", "MRK", "ABT", "TMO", "COST"
        ])
        
        // Patterns for different broker formats
        // Pattern 1: Symbol followed by numbers on same line (e.g., "AAPL 100 150.50")
        let inlinePattern = try! NSRegularExpression(
            pattern: "([A-Z]{1,5}(?:\\.[A-Z]{1,2})?)\\s+([0-9,]+(?:\\.\\d+)?)\\s+(?:[£$])?([0-9,]+(?:\\.\\d+)?)",
            options: []
        )
        
        // Pattern 2: Stock symbol (standalone or with company name)
        let symbolPattern = try! NSRegularExpression(
            pattern: "\\b([A-Z]{2,5}(?:\\.[A-Z]{1,2})?)\\b",
            options: []
        )
        
        // Pattern 3: Numbers (shares, prices, values)
        let numberPattern = try! NSRegularExpression(
            pattern: "(?:^|\\s)([£$])?([0-9,]+(?:\\.\\d{1,4})?)(?:\\s|$|[^0-9])",
            options: []
        )
        
        var foundPositions: [String: (shares: Double, cost: Double, currency: String)] = [:]
        
        // First pass: Try inline pattern (most reliable)
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            if let match = inlinePattern.firstMatch(in: line, options: [], range: range) {
                if let symbolRange = Range(match.range(at: 1), in: line),
                   let sharesRange = Range(match.range(at: 2), in: line),
                   let priceRange = Range(match.range(at: 3), in: line) {
                    
                    let symbol = String(line[symbolRange])
                    let sharesStr = String(line[sharesRange]).replacingOccurrences(of: ",", with: "")
                    let priceStr = String(line[priceRange]).replacingOccurrences(of: ",", with: "")
                    
                    if let shares = Double(sharesStr), let price = Double(priceStr) {
                        let currency = symbol.contains(".L") || line.contains("£") ? "GBP" : "USD"
                        
                        if foundPositions[symbol] != nil {
                            // Aggregate if already exists
                            let existing = foundPositions[symbol]!
                            let totalShares = existing.shares + shares
                            let totalCost = (existing.shares * existing.cost) + (shares * price)
                            foundPositions[symbol] = (totalShares, totalCost / totalShares, currency)
                        } else {
                            foundPositions[symbol] = (shares, price, currency)
                        }
                    }
                }
            }
        }
        
        // Second pass: Look for known symbols and nearby numbers
        if foundPositions.isEmpty {
            var currentSymbol: String?
            var currentNumbers: [Double] = []
            var currentCurrency = "USD"
            
            for line in lines {
                let range = NSRange(line.startIndex..., in: line)
                
                // Look for known symbols
                let symbolMatches = symbolPattern.matches(in: line, options: [], range: range)
                for match in symbolMatches {
                    if let symbolRange = Range(match.range(at: 1), in: line) {
                        let potentialSymbol = String(line[symbolRange])
                        
                        // Check if it's a known symbol or looks like a valid ticker
                        if knownSymbols.contains(potentialSymbol) || 
                           potentialSymbol.count >= 2 && potentialSymbol.count <= 5 &&
                           !["THE", "AND", "FOR", "PLC", "LTD", "INC", "USD", "GBP", "EUR"].contains(potentialSymbol) {
                            
                            // Save previous symbol's data
                            if let symbol = currentSymbol, !currentNumbers.isEmpty {
                                let shares = currentNumbers[0]
                                let cost = currentNumbers.count > 1 ? currentNumbers[1] : 0
                                foundPositions[symbol] = (shares, cost, currentCurrency)
                            }
                            
                            currentSymbol = potentialSymbol
                            currentNumbers = []
                            currentCurrency = potentialSymbol.contains(".L") ? "GBP" : "USD"
                        }
                    }
                }
                
                // Look for numbers
                if currentSymbol != nil {
                    let numMatches = numberPattern.matches(in: line, options: [], range: range)
                    for match in numMatches {
                        if let currencyRange = Range(match.range(at: 1), in: line) {
                            let curr = String(line[currencyRange])
                            if curr == "£" { currentCurrency = "GBP" }
                            else if curr == "$" { currentCurrency = "USD" }
                        }
                        
                        if let numRange = Range(match.range(at: 2), in: line) {
                            let numStr = String(line[numRange]).replacingOccurrences(of: ",", with: "")
                            if let num = Double(numStr), num > 0 && num < 10_000_000 {
                                currentNumbers.append(num)
                            }
                        }
                    }
                }
            }
            
            // Save last symbol
            if let symbol = currentSymbol, !currentNumbers.isEmpty {
                let shares = currentNumbers[0]
                let cost = currentNumbers.count > 1 ? currentNumbers[1] : 0
                foundPositions[symbol] = (shares, cost, currentCurrency)
            }
        }
        
        // Convert to ParsedPosition array
        for (symbol, data) in foundPositions {
            let position = ParsedPosition(
                symbol: symbol,
                shares: data.shares,
                averageCost: data.cost,
                currency: data.currency
            )
            parsedPositions.append(position)
        }
        
        // Sort by symbol
        parsedPositions.sort { $0.symbol < $1.symbol }
        
        if parsedPositions.isEmpty {
            errorMessage = "Could not extract positions from \(source). Tap 'View Extracted Text' to see what was found, or try CSV/PDF import."
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
