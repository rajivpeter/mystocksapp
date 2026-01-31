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
    
    // Uncertain mappings that need user confirmation
    @State private var uncertainMappings: [UncertainMapping] = []
    @State private var showMappingConfirmation = false
    @State private var currentMappingIndex = 0
    @State private var editingSymbol = ""
    
    // Exchange rate for currency conversion (USD to GBP)
    @State private var usdToGbpRate: Double = 0.79 // Default fallback
    
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
            .sheet(isPresented: $showMappingConfirmation) {
                mappingConfirmationSheet
            }
            .onAppear {
                fetchExchangeRate()
            }
        }
    }
    
    // MARK: - Mapping Confirmation Sheet
    private var mappingConfirmationSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if currentMappingIndex < uncertainMappings.count {
                    let mapping = uncertainMappings[currentMappingIndex]
                    
                    Text("Confirm Symbol Mapping")
                        .font(.headline)
                    
                    Text("Found: \"\(mapping.originalName)\"")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        Text("Suggested: \(mapping.suggestedSymbol)")
                            .font(.title2.bold())
                        
                        Text("\(mapping.shares.formatted()) shares @ \(mapping.currency == "GBP" ? "£" : "$")\(mapping.totalCost.formatted())")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter correct symbol (or leave as-is):")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Symbol", text: $editingSymbol)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.allCharacters)
                            .font(.title3.monospaced())
                    }
                    .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        Button("Skip") {
                            skipCurrentMapping()
                        }
                        .foregroundColor(.secondary)
                        
                        Button("Confirm") {
                            confirmCurrentMapping()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top)
                    
                    Text("\(currentMappingIndex + 1) of \(uncertainMappings.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                } else {
                    Text("All mappings confirmed!")
                        .font(.headline)
                    
                    Button("Continue to Import") {
                        finalizeMappings()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("Verify Symbols")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showMappingConfirmation = false
                    }
                }
            }
        }
    }
    
    private func skipCurrentMapping() {
        // Remove this uncertain mapping (don't import it)
        if currentMappingIndex < uncertainMappings.count {
            uncertainMappings[currentMappingIndex].isResolved = false
        }
        moveToNextMapping()
    }
    
    private func confirmCurrentMapping() {
        if currentMappingIndex < uncertainMappings.count {
            let symbol = editingSymbol.isEmpty ? uncertainMappings[currentMappingIndex].suggestedSymbol : editingSymbol.uppercased()
            uncertainMappings[currentMappingIndex].finalSymbol = symbol
            uncertainMappings[currentMappingIndex].isResolved = true
        }
        moveToNextMapping()
    }
    
    private func moveToNextMapping() {
        if currentMappingIndex < uncertainMappings.count - 1 {
            currentMappingIndex += 1
            if currentMappingIndex < uncertainMappings.count {
                editingSymbol = uncertainMappings[currentMappingIndex].suggestedSymbol
            }
        } else {
            finalizeMappings()
        }
    }
    
    private func finalizeMappings() {
        // Add confirmed uncertain mappings to parsed positions
        for mapping in uncertainMappings where mapping.isResolved {
            if let symbol = mapping.finalSymbol {
                let avgCost = mapping.shares > 0 ? mapping.totalCost / mapping.shares : 0
                let position = ParsedPosition(
                    symbol: symbol,
                    shares: mapping.shares,
                    averageCost: avgCost,
                    currency: mapping.currency,
                    originalName: mapping.originalName,
                    isConfirmed: true
                )
                parsedPositions.append(position)
            }
        }
        
        showMappingConfirmation = false
        uncertainMappings.removeAll()
        currentMappingIndex = 0
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
        // Convert everything to GBP
        let totalGBP = positions.reduce(0.0) { total, position in
            total + position.valueInGBP(usdToGbpRate: usdToGbpRate)
        }
        
        let hasUSD = positions.contains { $0.currency == "USD" }
        
        if hasUSD {
            // Show converted total with rate info
            return "£\(totalGBP.formatted(.number.precision(.fractionLength(2)))) (incl. USD @ \(usdToGbpRate.formatted(.number.precision(.fractionLength(2)))))"
        } else {
            return "£\(totalGBP.formatted(.number.precision(.fractionLength(2))))"
        }
    }
    
    // Fetch current exchange rate
    private func fetchExchangeRate() {
        Task {
            do {
                // Use a free exchange rate API
                let url = URL(string: "https://api.exchangerate-api.com/v4/latest/USD")!
                let (data, _) = try await URLSession.shared.data(from: url)
                
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let rates = json["rates"] as? [String: Double],
                   let gbpRate = rates["GBP"] {
                    await MainActor.run {
                        self.usdToGbpRate = gbpRate
                        print("💱 Exchange rate updated: 1 USD = \(gbpRate) GBP")
                    }
                }
            } catch {
                print("⚠️ Failed to fetch exchange rate: \(error). Using default \(usdToGbpRate)")
            }
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
        uncertainMappings.removeAll()
        
        print("📄 Parsing \(source): \(lines.count) lines")
        
        // IG PDF format detection
        let fullText = lines.joined(separator: "\n")
        let isIGFormat = fullText.lowercased().contains("holdings") || fullText.contains("IG")
        
        // Company name to ticker symbol mapping (comprehensive)
        let companyToSymbol: [String: (symbol: String, currency: String)] = [
            // UK Companies (GBP)
            "barclays": ("BARC", "GBP"), "diageo": ("DGE", "GBP"), "hsbc": ("HSBA", "GBP"),
            "lloyds": ("LLOY", "GBP"), "vodafone": ("VOD", "GBP"), "astrazeneca": ("AZN", "GBP"),
            "glaxosmithkline": ("GSK", "GBP"), "gsk": ("GSK", "GBP"), "unilever": ("ULVR", "GBP"),
            "rio tinto": ("RIO", "GBP"), "glencore": ("GLEN", "GBP"), "anglo american": ("AAL", "GBP"),
            "bhp": ("BHP", "GBP"), "rolls-royce": ("RR", "GBP"), "rolls royce": ("RR", "GBP"),
            "british airways": ("IAG", "GBP"), "aviva": ("AV", "GBP"), "british american tobacco": ("BATS", "GBP"),
            "reckitt": ("RKT", "GBP"), "legal & general": ("LGEN", "GBP"), "prudential": ("PRU", "GBP"),
            "bp": ("BP", "GBP"), "shell": ("SHEL", "GBP"), "national grid": ("NG", "GBP"),
            "sse": ("SSE", "GBP"), "tesco": ("TSCO", "GBP"), "sainsbury": ("SBRY", "GBP"),
            "itv": ("ITV", "GBP"), "standard chartered": ("STAN", "GBP"), "natwest": ("NWG", "GBP"),
            // US Companies (USD)
            "apple": ("AAPL", "USD"), "microsoft": ("MSFT", "USD"), "alphabet": ("GOOGL", "USD"),
            "google": ("GOOGL", "USD"), "amazon": ("AMZN", "USD"), "tesla": ("TSLA", "USD"),
            "meta": ("META", "USD"), "nvidia": ("NVDA", "USD"), "jpmorgan": ("JPM", "USD"),
            "visa": ("V", "USD"), "walmart": ("WMT", "USD"), "mastercard": ("MA", "USD"),
            "disney": ("DIS", "USD"), "netflix": ("NFLX", "USD"), "paypal": ("PYPL", "USD"),
            "intel": ("INTC", "USD"), "amd": ("AMD", "USD"), "salesforce": ("CRM", "USD"),
            "adobe": ("ADBE", "USD"), "cisco": ("CSCO", "USD"), "pfizer": ("PFE", "USD"),
            "merck": ("MRK", "USD"), "costco": ("COST", "USD"), "unitedhealth": ("UNH", "USD"),
            "comcast": ("CMCSA", "USD"), "verizon": ("VZ", "USD"), "at&t": ("T", "USD"),
            "boeing": ("BA", "USD"), "caterpillar": ("CAT", "USD"), "honeywell": ("HON", "USD"),
            "ford": ("F", "USD"), "uber": ("UBER", "USD"), "airbnb": ("ABNB", "USD"),
        ]
        
        var foundPositions: [String: (shares: Double, avgCost: Double, currency: String)] = [:]
        var currentCurrency = "GBP"
        var processedSymbols = Set<String>()
        
        // APPROACH 1: Look for lines with tab/space-separated data (table rows)
        // IG PDFs typically have: Company Name | Quantity | Cost | Price | Value | P/L | %
        for line in lines {
            let lineLower = line.lowercased()
            
            // Track currency section
            if lineLower.contains("holdings gbp") || lineLower.contains("gbp") && lineLower.contains("holdings") {
                currentCurrency = "GBP"
                continue
            }
            if lineLower.contains("holdings usd") || lineLower.contains("usd") && lineLower.contains("holdings") {
                currentCurrency = "USD"
                continue
            }
            
            // Skip headers/totals
            if lineLower.contains("details") && lineLower.contains("quantity") { continue }
            if lineLower.hasPrefix("total") { continue }
            
            // Extract numbers from THIS LINE ONLY
            let numbersOnLine = extractNumbersStrict(from: line)
            
            // Try to match company name
            for (companyName, info) in companyToSymbol {
                if lineLower.contains(companyName) && !processedSymbols.contains(info.symbol) {
                    if numbersOnLine.count >= 2 {
                        // First number should be quantity (shares)
                        // Find the first "reasonable" share count (< 100,000 for most retail investors)
                        let shares = numbersOnLine[0]
                        let totalCost = numbersOnLine[1]
                        
                        // Sanity check - shares should be reasonable
                        if shares > 0 && shares < 100000 {
                            let avgCost = shares > 0 ? totalCost / shares : 0
                            let currency = currentCurrency
                            
                            // Additional sanity: avgCost should be > 0 and < 100000
                            if avgCost > 0 && avgCost < 100000 {
                                foundPositions[info.symbol] = (shares, avgCost, currency)
                                processedSymbols.insert(info.symbol)
                                print("✅ Found: \(info.symbol) - \(shares) shares @ \(currency)\(String(format: "%.2f", avgCost))")
                            }
                        }
                    }
                    break
                }
            }
        }
        
        // APPROACH 2: If approach 1 found nothing, try joining lines and looking for patterns
        if foundPositions.isEmpty {
            print("📄 Line-by-line parsing found nothing, trying pattern matching...")
            
            // Join all text and look for: CompanyName followed by numbers
            let joinedText = lines.joined(separator: " ")
            
            for (companyName, info) in companyToSymbol {
                if joinedText.lowercased().contains(companyName) {
                    // Find position of company name
                    if let range = joinedText.lowercased().range(of: companyName) {
                        let afterCompany = String(joinedText[range.upperBound...])
                        let numbers = extractNumbersStrict(from: String(afterCompany.prefix(100)))
                        
                        if numbers.count >= 2 {
                            let shares = numbers[0]
                            let totalCost = numbers[1]
                            
                            // Strict sanity checks
                            if shares > 0 && shares < 50000 && totalCost > 0 && totalCost < 10000000 {
                                let avgCost = totalCost / shares
                                if avgCost > 0.01 && avgCost < 50000 {
                                    foundPositions[info.symbol] = (shares, avgCost, "GBP")
                                    print("✅ Pattern match: \(info.symbol) - \(shares) shares @ \(String(format: "%.2f", avgCost))")
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Convert to ParsedPosition array with validation
        var validPositions: [ParsedPosition] = []
        var invalidCount = 0
        
        for (symbol, data) in foundPositions {
            // Final sanity check
            let isValid = data.shares > 0 && data.shares < 100000 && data.avgCost > 0 && data.avgCost < 100000
            
            if isValid {
                let position = ParsedPosition(
                    symbol: symbol,
                    shares: data.shares,
                    averageCost: data.avgCost,
                    currency: data.currency,
                    originalName: nil,
                    isConfirmed: true
                )
                validPositions.append(position)
            } else {
                invalidCount += 1
                print("⚠️ Skipping invalid: \(symbol) - \(data.shares) shares @ \(data.avgCost)")
            }
        }
        
        parsedPositions = validPositions
        
        // Sort by estimated value descending
        parsedPositions.sort { $0.estimatedValue > $1.estimatedValue }
        
        print("📊 Valid positions: \(parsedPositions.count), Invalid skipped: \(invalidCount)")
        
        // Show appropriate message based on results
        if parsedPositions.isEmpty {
            errorMessage = """
            PDF parsing couldn't extract valid positions.
            
            Recommended: Use CSV import instead.
            Format: Symbol, Shares, AvgCost, Currency
            Example: AAPL, 43, 197.11, USD
            
            Tap 'Paste CSV Data' to manually enter your positions.
            """
        } else if invalidCount > 0 {
            errorMessage = "Found \(parsedPositions.count) valid positions. \(invalidCount) entries were skipped due to invalid data."
        }
    }
    
    // MARK: - Helper: Extract Numbers from Text (Original)
    private func extractNumbers(from text: String) -> [Double] {
        var numbers: [Double] = []
        
        // Pattern to match numbers with optional commas and decimals
        let pattern = try! NSRegularExpression(
            pattern: "(?<![A-Za-z])([0-9]{1,3}(?:,?[0-9]{3})*(?:\\.[0-9]{1,4})?)(?![0-9])",
            options: []
        )
        
        let range = NSRange(text.startIndex..., in: text)
        let matches = pattern.matches(in: text, options: [], range: range)
        
        for match in matches {
            if let numRange = Range(match.range(at: 1), in: text) {
                let numStr = String(text[numRange]).replacingOccurrences(of: ",", with: "")
                if let num = Double(numStr), num > 0 {
                    numbers.append(num)
                }
            }
        }
        
        return numbers
    }
    
    // MARK: - Strict Number Extraction (for better accuracy)
    private func extractNumbersStrict(from text: String) -> [Double] {
        var numbers: [Double] = []
        
        // Split by common delimiters
        let components = text.components(separatedBy: CharacterSet(charactersIn: " \t|"))
        
        for component in components {
            let cleaned = component
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: "£", with: "")
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: "%", with: "")
            
            // Skip if it contains letters (except for decimal point)
            let hasLetters = cleaned.contains { $0.isLetter }
            if hasLetters { continue }
            
            // Try to parse as number
            if let num = Double(cleaned), num > 0 {
                numbers.append(num)
            }
        }
        
        return numbers
    }
    
    // MARK: - Import Positions
    private func importPositions() {
        print("📥 Starting import of \(parsedPositions.count) positions...")
        
        guard !parsedPositions.isEmpty else {
            errorMessage = "No positions to import"
            return
        }
        
        // Aggregate duplicates if enabled
        var positionsToImport = parsedPositions
        if aggregateDuplicates {
            positionsToImport = aggregatePositions(parsedPositions)
        }
        
        print("📥 After aggregation: \(positionsToImport.count) positions")
        
        // Clear existing if replace mode
        if importMode == .replace {
            clearAllPositions()
        }
        
        var importedCount = 0
        var updatedCount = 0
        
        for parsed in positionsToImport {
            // Skip invalid positions
            guard parsed.shares > 0 else {
                print("⚠️ Skipping \(parsed.symbol): invalid shares (\(parsed.shares))")
                continue
            }
            
            // Check if we should merge with existing position
            if importMode == .merge {
                if let existingPosition = findExistingPosition(symbol: parsed.symbol) {
                    // Calculate weighted average cost
                    let totalShares = existingPosition.shares + parsed.shares
                    let totalCost = (existingPosition.shares * existingPosition.averageCost) + (parsed.shares * parsed.averageCost)
                    let newAvgCost = totalCost / totalShares
                    
                    existingPosition.shares = totalShares
                    existingPosition.averageCost = newAvgCost
                    updatedCount += 1
                    print("✅ Updated: \(parsed.symbol) - now \(totalShares) shares")
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
            importedCount += 1
            print("✅ Imported: \(parsed.symbol) - \(parsed.shares) shares @ \(parsed.currency)\(parsed.averageCost)")
        }
        
        do {
            try modelContext.save()
            print("💾 Saved \(importedCount) new, \(updatedCount) updated positions")
            dismiss()
        } catch {
            print("❌ Failed to save: \(error)")
            errorMessage = "Failed to save positions: \(error.localizedDescription)"
        }
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
    var originalName: String? // Company name from PDF/OCR
    var isConfirmed: Bool = true // True if auto-matched with high confidence
    
    var estimatedValue: Double {
        shares * averageCost
    }
    
    // Convert to GBP using exchange rate
    func valueInGBP(usdToGbpRate: Double) -> Double {
        if currency == "GBP" {
            return estimatedValue
        } else {
            return estimatedValue * usdToGbpRate
        }
    }
}

// Uncertain mapping that needs user confirmation
struct UncertainMapping: Identifiable {
    let id = UUID()
    var originalName: String
    var suggestedSymbol: String
    var shares: Double
    var totalCost: Double
    var currency: String
    var isResolved: Bool = false
    var finalSymbol: String?
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
