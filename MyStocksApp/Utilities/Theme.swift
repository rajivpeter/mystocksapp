//
//  Theme.swift
//  MyStocksApp
//
//  Brand colors and theme configuration
//

import SwiftUI

// MARK: - Brand Colors

extension Color {
    /// Primary brand color - Teal (#09A1A1)
    /// Used for: Logic & Labels, primary actions, accent color
    static let brandPrimary = Color(hex: "09A1A1")
    
    /// Brand Blue (#5484A4)
    /// Used for: Atmospheric UI, secondary elements
    static let brandBlue = Color(hex: "5484A4")
    
    /// Brand Soft (#ACC0D3)
    /// Used for: Backgrounds, subtle elements
    static let brandSoft = Color(hex: "ACC0D3")
    
    // MARK: - Semantic Colors
    
    /// Primary accent color (brand teal)
    static let accent = brandPrimary
    
    /// Success/Profit color
    static let profit = brandPrimary
    
    /// Loss color
    static let loss = Color(hex: "E74C3C")
    
    /// Warning color
    static let warning = Color(hex: "F39C12")
    
    /// Neutral color
    static let neutral = brandSoft
    
    // MARK: - Alert Type Colors
    
    static let alertNoBrainer = brandPrimary
    static let alertStrongBuy = brandPrimary.opacity(0.8)
    static let alertBuy = brandBlue
    static let alertHold = brandSoft
    static let alertReduce = warning
    static let alertSell = loss
    
    // MARK: - UI Colors
    
    /// Card background
    static let cardBackground = Color.white.opacity(0.05)
    
    /// Secondary background
    static let secondaryBackground = Color(hex: "1A1A1A")
    
    /// Primary background (dark)
    static let primaryBackground = Color.black
    
    /// Text primary
    static let textPrimary = Color.white
    
    /// Text secondary
    static let textSecondary = brandSoft
    
    /// Divider color
    static let divider = brandSoft.opacity(0.2)
}

// MARK: - Hex Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    var hexString: String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
        
        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
    }
}

// MARK: - Theme Configuration

struct AppTheme {
    // Colors
    static let primary = Color.brandPrimary
    static let secondary = Color.brandBlue
    static let tertiary = Color.brandSoft
    
    // Spacing
    static let spacing: CGFloat = 16
    static let cornerRadius: CGFloat = 12
    static let cardCornerRadius: CGFloat = 16
    
    // Fonts
    static let titleFont = Font.system(size: 28, weight: .bold, design: .rounded)
    static let headlineFont = Font.system(size: 17, weight: .semibold)
    static let bodyFont = Font.system(size: 15, weight: .regular)
    static let captionFont = Font.system(size: 12, weight: .regular)
    
    // Shadows
    static let cardShadow = Color.black.opacity(0.1)
    
    // Gradients
    static let primaryGradient = LinearGradient(
        colors: [Color.brandPrimary, Color.brandBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let backgroundGradient = LinearGradient(
        colors: [Color.black, Color(hex: "0A0A0A")],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let cardGradient = LinearGradient(
        colors: [Color.brandPrimary.opacity(0.1), Color.brandBlue.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - View Modifiers

struct BrandCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(AppTheme.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                    .stroke(Color.brandPrimary.opacity(0.1), lineWidth: 1)
            )
    }
}

struct BrandButtonStyle: ButtonStyle {
    var isPrimary: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(isPrimary ? .black : .brandPrimary)
            .padding()
            .frame(maxWidth: .infinity)
            .background(isPrimary ? Color.brandPrimary : Color.brandPrimary.opacity(0.1))
            .cornerRadius(AppTheme.cornerRadius)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension View {
    func brandCard() -> some View {
        modifier(BrandCardStyle())
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Color Swatches
        HStack(spacing: 12) {
            ColorSwatch(color: .brandPrimary, name: "Primary\n#09A1A1")
            ColorSwatch(color: .brandBlue, name: "Blue\n#5484A4")
            ColorSwatch(color: .brandSoft, name: "Soft\n#ACC0D3")
        }
        
        // Sample Card
        VStack(alignment: .leading, spacing: 8) {
            Text("Portfolio Value")
                .font(.caption)
                .foregroundColor(.brandSoft)
            
            Text("£142,567.89")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            HStack {
                Image(systemName: "arrow.up.right")
                Text("+£2,345.67 (+1.67%)")
            }
            .foregroundColor(.brandPrimary)
        }
        .brandCard()
        
        // Buttons
        Button("Primary Action") {}
            .buttonStyle(BrandButtonStyle())
        
        Button("Secondary Action") {}
            .buttonStyle(BrandButtonStyle(isPrimary: false))
    }
    .padding()
    .background(Color.black)
}

struct ColorSwatch: View {
    let color: Color
    let name: String
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 80, height: 80)
            
            Text(name)
                .font(.caption)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
    }
}
