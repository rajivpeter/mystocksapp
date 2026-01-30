# MyStocksApp - AI-Powered iOS Investment Advisor

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-iOS%2017+-blue.svg)](https://developer.apple.com/swiftui/)
[![CoreML](https://img.shields.io/badge/CoreML-Enabled-green.svg)](https://developer.apple.com/machine-learning/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> An intelligent iOS investment advisory app with AI-powered stock predictions, real-time alerts, chart pattern education, and broker integration.

## Features

### Core Investment Features
- **Portfolio Tracking** - Real-time P&L with multi-currency support (GBP/USD)
- **AI Stock Predictions** - LSTM + Attention neural network for price forecasting
- **Smart Alerts** - BUY/SELL/HOLD/REDUCE recommendations with confidence scores
- **No-Brainer Alerts** - Urgent opportunities pushed to your Lock Screen

### Technical Analysis
- **Chart Pattern Recognition** - ML-powered candlestick pattern detection
- **Technical Indicators** - RSI, MACD, Bollinger Bands, Moving Averages
- **Support/Resistance Levels** - Automatic detection and alerts
- **Volume Analysis** - Smart volume-based signals

### Education & Learning
- **Pattern Encyclopedia** - Learn 50+ candlestick patterns with real examples
- **Real-Time Learning** - See patterns as they form on actual stocks
- **Interactive Quizzes** - Test your pattern recognition skills
- **Strategy Builder** - Create and backtest trading strategies

### Broker Integration
- **IG Trading API** - Direct trading from the app (UK/EU)
- **Interactive Brokers** - Full API integration
- **Portfolio Sync** - Auto-sync positions from your broker

### iOS Native Features
- **Push Notifications** - Instant alerts for trading opportunities
- **Live Activities** - Real-time prices on Lock Screen & Dynamic Island
- **Widgets** - Home screen stock tickers and portfolio summary
- **Haptic Feedback** - Tactile feedback for important alerts
- **Face ID/Touch ID** - Secure authentication

## Architecture

```
MyStocksApp/
├── App/                          # App entry point & configuration
├── Models/                       # Data models (SwiftData)
│   ├── Stock.swift              # Stock entity
│   ├── Portfolio.swift          # Portfolio with positions
│   ├── Alert.swift              # Trading alerts
│   ├── ChartPattern.swift       # Pattern definitions
│   └── Prediction.swift         # ML prediction results
├── ViewModels/                   # @Observable ViewModels
│   ├── PortfolioViewModel.swift
│   ├── MarketViewModel.swift
│   ├── AlertsViewModel.swift
│   └── EducationViewModel.swift
├── Views/
│   ├── Screens/                  # Full-screen views
│   │   ├── HomeView.swift
│   │   ├── PortfolioView.swift
│   │   ├── StockDetailView.swift
│   │   ├── AlertsView.swift
│   │   └── EducationView.swift
│   ├── Components/               # Reusable UI components
│   │   ├── StockCard.swift
│   │   ├── PriceChangeIndicator.swift
│   │   ├── AlertBadge.swift
│   │   └── PatternCard.swift
│   └── Charts/                   # Chart components
│       ├── CandlestickChart.swift
│       ├── LineChart.swift
│       └── TechnicalOverlay.swift
├── Services/
│   ├── API/                      # Market data APIs
│   │   ├── PolygonService.swift
│   │   ├── AlphaVantageService.swift
│   │   └── YahooFinanceService.swift
│   ├── ML/                       # Machine Learning
│   │   ├── StockPredictor.swift
│   │   ├── PatternRecognizer.swift
│   │   └── SentimentAnalyzer.swift
│   ├── Broker/                   # Broker integrations
│   │   ├── IGTradingService.swift
│   │   └── IBKRService.swift
│   ├── Notifications/            # Push & Local notifications
│   │   ├── PushNotificationService.swift
│   │   └── LiveActivityManager.swift
│   └── Storage/                  # Data persistence
│       └── SwiftDataManager.swift
├── Education/                    # Learning content
│   ├── PatternLibrary.swift
│   └── LessonContent.swift
├── Utilities/                    # Helper functions
│   ├── Extensions.swift
│   ├── Constants.swift
│   └── Formatters.swift
└── Resources/                    # Assets & configuration
    └── Assets.xcassets/
```

## Technology Stack

| Component | Technology |
|-----------|------------|
| **UI Framework** | SwiftUI (iOS 17+) |
| **Architecture** | Modern MVVM with @Observable |
| **Data Persistence** | SwiftData |
| **Networking** | URLSession + async/await |
| **ML Framework** | CoreML + Create ML |
| **Charts** | Swift Charts + TradingView Lightweight Charts |
| **Push Notifications** | APNs + Firebase Cloud Messaging |
| **Live Activities** | ActivityKit |
| **Widgets** | WidgetKit |

## Data Sources

| Provider | Data Type | Rate Limit |
|----------|-----------|------------|
| **Polygon.io** | Real-time US stocks, options | Institutional-grade |
| **Alpha Vantage** | Global stocks, forex, crypto | 5 calls/min (free) |
| **Yahoo Finance** | Historical data, fundamentals | Generous |
| **Finnhub** | News, sentiment, company data | 60 calls/min (free) |

## Getting Started

### Prerequisites
- macOS 14+ with Xcode 15.2+
- iOS 17+ device or simulator
- Apple Developer Account (for push notifications)

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/rajivpeter/mystocksapp.git
cd mystocksapp
```

2. **Open in Xcode**
```bash
open MyStocksApp.xcodeproj
```

3. **Configure API Keys**
Create `Secrets.plist` in the project:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>POLYGON_API_KEY</key>
    <string>your_polygon_key</string>
    <key>ALPHA_VANTAGE_API_KEY</key>
    <string>your_alpha_vantage_key</string>
    <key>IG_API_KEY</key>
    <string>your_ig_api_key</string>
</dict>
</plist>
```

4. **Build and Run**
- Select your target device
- Press `Cmd + R` to build and run

### Backend Setup (for Push Notifications)

```bash
cd Backend
pip install -r requirements.txt
python app.py
```

## Alert Types

| Alert | Confidence | Description |
|-------|------------|-------------|
| 🚨 **NO-BRAINER BUY** | 90%+ | Exceptional opportunity, act immediately |
| 🟢 **STRONG BUY** | 75-89% | High conviction buy signal |
| 🟡 **BUY** | 60-74% | Good entry point |
| ⚪ **HOLD** | 40-59% | Maintain current position |
| 🟠 **REDUCE** | 25-39% | Consider taking profits |
| 🔴 **SELL** | <25% | Exit position recommended |

## ML Models

### Stock Price Predictor
- **Architecture**: LSTM with Attention mechanism
- **Training Data**: 5 years of historical data
- **Features**: OHLCV, technical indicators, sentiment
- **Output**: 1-day, 5-day, 30-day price predictions

### Pattern Recognizer
- **Architecture**: CNN for image classification
- **Patterns**: 50+ candlestick patterns
- **Accuracy**: 87% on test set

### Sentiment Analyzer
- **Model**: FinBERT (fine-tuned BERT for finance)
- **Sources**: News headlines, social media
- **Output**: Bullish/Bearish/Neutral score

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## References & Inspiration

This project was inspired by and learned from:
- [Stock-Trading-App](https://github.com/Aman04jdsj/Stock-Trading-App) - SwiftUI portfolio management
- [StockTrader](https://github.com/dduong96/StockTrader) - MVVM + Combine architecture
- [AI-Stock-Forecasts](https://github.com/alexismoulin/AI-Stock-Forecasts) - CoreML sentiment analysis
- [XCAStocks](https://github.com/alfianlosari/XCAStocks) - SwiftCharts integration
- [TradingView Lightweight Charts](https://github.com/nicklockwood/LightweightChartsIOS) - iOS charting

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This app is for educational and informational purposes only. It does not constitute financial advice. Always do your own research and consult with a qualified financial advisor before making investment decisions. Past performance does not guarantee future results.
