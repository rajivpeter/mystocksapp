//
//  PortfolioImportView.swift
//  MyStocksApp
//
//  CSV and Screenshot import for bulk portfolio upload
//

import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import Vision

struct PortfolioImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var importMethod: ImportMethod = .csv
    @State private var showFilePicker = false
    @State private var showPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var parsedPositions: [ParsedPosition] = []
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showPreview = false
    @State private var csvText = ""
    
    enum ImportMethod: String, CaseIterable {
        case csv = "CSV File"
        case screenshot = "Screenshot"
        case manual = "Manual Entry"
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
                    
                    // Content based on method
                    switch importMethod {
                    case .csv:
                        csvImportSection
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
            
            Text("Take a screenshot of your portfolio from your broker app (IG, Interactive Investor, etc.) and we'll extract the positions using OCR.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Supported Platforms
            VStack(alignment: .leading, spacing: 8) {
                Text("Supported platforms:")
                    .font(.caption.bold())
                HStack(spacing: 16) {
                    PlatformBadge(name: "IG", icon: "chart.line.uptrend.xyaxis")
                    PlatformBadge(name: "Hargreaves", icon: "building.columns.fill")
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Preview (\(parsedPositions.count) positions)")
                    .font(.headline)
                Spacer()
                Button("Clear All") {
                    parsedPositions.removeAll()
                }
                .foregroundColor(.red)
            }
            
            ForEach(Array(parsedPositions.enumerated()), id: \.element.id) { index, position in
                ParsedPositionRow(position: position) {
                    parsedPositions.remove(at: index)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
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
    
    // MARK: - OCR Text Parser
    private func parseOCRText(_ lines: [String]) {
        parsedPositions.removeAll()
        
        // Common stock symbol patterns
        let symbolPattern = try! NSRegularExpression(pattern: "^([A-Z]{1,5}(?:\\.[A-Z]{1,2})?)$", options: [])
        let numberPattern = try! NSRegularExpression(pattern: "([0-9,]+\\.?[0-9]*)", options: [])
        
        var currentSymbol: String?
        var pendingNumbers: [Double] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check if it's a stock symbol
            let symbolRange = NSRange(trimmed.startIndex..., in: trimmed)
            if symbolPattern.firstMatch(in: trimmed, options: [], range: symbolRange) != nil {
                // Save previous position if we have one
                if let symbol = currentSymbol, pendingNumbers.count >= 2 {
                    let position = ParsedPosition(
                        symbol: symbol,
                        shares: pendingNumbers[0],
                        averageCost: pendingNumbers.count > 1 ? pendingNumbers[1] : 0,
                        currency: symbol.contains(".L") ? "GBP" : "USD"
                    )
                    parsedPositions.append(position)
                }
                
                currentSymbol = trimmed
                pendingNumbers = []
            } else {
                // Extract numbers from the line
                let range = NSRange(trimmed.startIndex..., in: trimmed)
                let matches = numberPattern.matches(in: trimmed, options: [], range: range)
                
                for match in matches {
                    if let swiftRange = Range(match.range(at: 1), in: trimmed) {
                        let numberStr = trimmed[swiftRange]
                            .replacingOccurrences(of: ",", with: "")
                        if let number = Double(numberStr), number > 0 {
                            pendingNumbers.append(number)
                        }
                    }
                }
            }
        }
        
        // Don't forget the last position
        if let symbol = currentSymbol, pendingNumbers.count >= 1 {
            let position = ParsedPosition(
                symbol: symbol,
                shares: pendingNumbers[0],
                averageCost: pendingNumbers.count > 1 ? pendingNumbers[1] : 0,
                currency: symbol.contains(".L") ? "GBP" : "USD"
            )
            parsedPositions.append(position)
        }
        
        if parsedPositions.isEmpty {
            errorMessage = "Could not extract positions from screenshot. Try a clearer image or use CSV import."
        }
    }
    
    // MARK: - Import Positions
    private func importPositions() {
        for parsed in parsedPositions {
            // Create Stock
            let stock = Stock(
                symbol: parsed.symbol,
                name: parsed.symbol, // Will be updated when fetching data
                currency: Currency(rawValue: parsed.currency) ?? .usd
            )
            
            // Create Position
            let position = Position(
                stock: stock,
                shares: parsed.shares,
                averageCost: parsed.averageCost,
                purchaseDate: Date()
            )
            
            modelContext.insert(stock)
            modelContext.insert(position)
        }
        
        try? modelContext.save()
        dismiss()
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
