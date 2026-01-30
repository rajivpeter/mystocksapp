#!/usr/bin/env python3
"""
MyStocksApp Backend Server
Handles push notifications, price monitoring, and alert generation
"""

import os
import json
import logging
from datetime import datetime, timedelta
from flask import Flask, request, jsonify
from flask_cors import CORS
import yfinance as yf
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)
CORS(app)

# Configuration
PORT = int(os.getenv('PORT', 8080))
APNS_KEY_ID = os.getenv('APNS_KEY_ID')
APNS_TEAM_ID = os.getenv('APNS_TEAM_ID')
APNS_KEY_PATH = os.getenv('APNS_KEY_PATH')

# In-memory storage for device tokens (use Redis in production)
device_tokens = {}
price_alerts = []
active_monitors = {}


# ==================== HEALTH CHECK ====================

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'version': '1.0.0'
    })


# ==================== DEVICE REGISTRATION ====================

@app.route('/api/devices/register', methods=['POST'])
def register_device():
    """Register a device token for push notifications"""
    data = request.get_json()
    
    if not data or 'token' not in data:
        return jsonify({'error': 'Token required'}), 400
    
    token = data['token']
    user_id = data.get('user_id', 'anonymous')
    
    device_tokens[token] = {
        'user_id': user_id,
        'registered_at': datetime.now().isoformat(),
        'platform': data.get('platform', 'ios')
    }
    
    logger.info(f"Registered device token for user {user_id}")
    
    return jsonify({
        'success': True,
        'message': 'Device registered successfully'
    })


@app.route('/api/devices/unregister', methods=['POST'])
def unregister_device():
    """Unregister a device token"""
    data = request.get_json()
    
    if not data or 'token' not in data:
        return jsonify({'error': 'Token required'}), 400
    
    token = data['token']
    
    if token in device_tokens:
        del device_tokens[token]
        logger.info(f"Unregistered device token")
    
    return jsonify({
        'success': True,
        'message': 'Device unregistered successfully'
    })


# ==================== PRICE ALERTS ====================

@app.route('/api/alerts/price', methods=['POST'])
def create_price_alert():
    """Create a price alert"""
    data = request.get_json()
    
    required_fields = ['symbol', 'target_price', 'direction']
    if not all(field in data for field in required_fields):
        return jsonify({'error': 'Missing required fields'}), 400
    
    alert = {
        'id': len(price_alerts) + 1,
        'symbol': data['symbol'].upper(),
        'target_price': float(data['target_price']),
        'direction': data['direction'],  # 'above' or 'below'
        'device_token': data.get('device_token'),
        'created_at': datetime.now().isoformat(),
        'triggered': False
    }
    
    price_alerts.append(alert)
    
    logger.info(f"Created price alert for {alert['symbol']} at {alert['target_price']}")
    
    return jsonify({
        'success': True,
        'alert': alert
    })


@app.route('/api/alerts/price', methods=['GET'])
def get_price_alerts():
    """Get all price alerts"""
    return jsonify({
        'alerts': price_alerts
    })


@app.route('/api/alerts/price/<int:alert_id>', methods=['DELETE'])
def delete_price_alert(alert_id):
    """Delete a price alert"""
    global price_alerts
    price_alerts = [a for a in price_alerts if a['id'] != alert_id]
    
    return jsonify({
        'success': True,
        'message': 'Alert deleted'
    })


# ==================== MARKET DATA ====================

@app.route('/api/quote/<symbol>', methods=['GET'])
def get_quote(symbol):
    """Get real-time quote for a symbol"""
    try:
        ticker = yf.Ticker(symbol)
        info = ticker.info
        
        quote = {
            'symbol': symbol.upper(),
            'name': info.get('shortName', symbol),
            'current_price': info.get('currentPrice') or info.get('regularMarketPrice', 0),
            'previous_close': info.get('previousClose', 0),
            'open': info.get('open') or info.get('regularMarketOpen', 0),
            'high': info.get('dayHigh') or info.get('regularMarketDayHigh', 0),
            'low': info.get('dayLow') or info.get('regularMarketDayLow', 0),
            'volume': info.get('volume') or info.get('regularMarketVolume', 0),
            'market_cap': info.get('marketCap'),
            'pe_ratio': info.get('trailingPE'),
            'high_52_week': info.get('fiftyTwoWeekHigh', 0),
            'low_52_week': info.get('fiftyTwoWeekLow', 0),
            'currency': info.get('currency', 'USD'),
            'exchange': info.get('exchange', 'UNKNOWN'),
            'timestamp': datetime.now().isoformat()
        }
        
        # Calculate change
        if quote['previous_close'] > 0:
            quote['change'] = quote['current_price'] - quote['previous_close']
            quote['change_percent'] = (quote['change'] / quote['previous_close']) * 100
        else:
            quote['change'] = 0
            quote['change_percent'] = 0
        
        return jsonify(quote)
        
    except Exception as e:
        logger.error(f"Error fetching quote for {symbol}: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/quotes', methods=['POST'])
def get_quotes():
    """Get quotes for multiple symbols"""
    data = request.get_json()
    
    if not data or 'symbols' not in data:
        return jsonify({'error': 'Symbols required'}), 400
    
    symbols = data['symbols']
    quotes = []
    
    for symbol in symbols:
        try:
            ticker = yf.Ticker(symbol)
            info = ticker.info
            
            quotes.append({
                'symbol': symbol.upper(),
                'name': info.get('shortName', symbol),
                'current_price': info.get('currentPrice') or info.get('regularMarketPrice', 0),
                'previous_close': info.get('previousClose', 0),
                'change_percent': info.get('regularMarketChangePercent', 0),
                'currency': info.get('currency', 'USD')
            })
        except Exception as e:
            logger.error(f"Error fetching quote for {symbol}: {str(e)}")
    
    return jsonify({'quotes': quotes})


# ==================== PATTERN DETECTION ====================

@app.route('/api/patterns/<symbol>', methods=['GET'])
def detect_patterns(symbol):
    """Detect candlestick patterns for a symbol"""
    try:
        ticker = yf.Ticker(symbol)
        hist = ticker.history(period="3mo")
        
        if hist.empty:
            return jsonify({'error': 'No historical data available'}), 404
        
        patterns = []
        
        # Simple pattern detection (in production, use the full PatternRecognizer)
        # Check last few candles for basic patterns
        
        if len(hist) >= 1:
            last = hist.iloc[-1]
            body = abs(last['Close'] - last['Open'])
            range_val = last['High'] - last['Low']
            
            if range_val > 0:
                # Doji detection
                if body / range_val < 0.1:
                    patterns.append({
                        'name': 'Doji',
                        'type': 'indecision',
                        'confidence': 60,
                        'description': 'Market indecision detected'
                    })
                
                # Hammer detection
                lower_shadow = min(last['Open'], last['Close']) - last['Low']
                upper_shadow = last['High'] - max(last['Open'], last['Close'])
                
                if lower_shadow > body * 2 and upper_shadow < body * 0.1:
                    patterns.append({
                        'name': 'Hammer',
                        'type': 'bullish_reversal',
                        'confidence': 70,
                        'description': 'Potential bullish reversal'
                    })
        
        return jsonify({
            'symbol': symbol.upper(),
            'patterns': patterns,
            'analyzed_at': datetime.now().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Error detecting patterns for {symbol}: {str(e)}")
        return jsonify({'error': str(e)}), 500


# ==================== PUSH NOTIFICATIONS ====================

def send_push_notification(token, title, body, data=None):
    """Send push notification to a device"""
    # In production, use APNs or Firebase
    # This is a placeholder implementation
    
    logger.info(f"Sending push notification: {title} - {body}")
    
    notification = {
        'token': token,
        'title': title,
        'body': body,
        'data': data or {},
        'sent_at': datetime.now().isoformat()
    }
    
    # TODO: Implement actual APNs/FCM sending
    # from apns2.client import APNsClient
    # from apns2.payload import Payload
    
    return notification


@app.route('/api/notifications/send', methods=['POST'])
def send_notification():
    """Send a push notification"""
    data = request.get_json()
    
    if not data or 'token' not in data:
        return jsonify({'error': 'Token required'}), 400
    
    notification = send_push_notification(
        token=data['token'],
        title=data.get('title', 'MyStocksApp'),
        body=data.get('body', ''),
        data=data.get('data')
    )
    
    return jsonify({
        'success': True,
        'notification': notification
    })


@app.route('/api/notifications/broadcast', methods=['POST'])
def broadcast_notification():
    """Broadcast notification to all registered devices"""
    data = request.get_json()
    
    if not data:
        return jsonify({'error': 'Data required'}), 400
    
    title = data.get('title', 'MyStocksApp')
    body = data.get('body', '')
    
    sent_count = 0
    for token in device_tokens.keys():
        send_push_notification(token, title, body, data.get('data'))
        sent_count += 1
    
    return jsonify({
        'success': True,
        'sent_count': sent_count
    })


# ==================== TRADING ALERTS ====================

@app.route('/api/alerts/trading', methods=['POST'])
def create_trading_alert():
    """Create a trading alert (buy/sell recommendation)"""
    data = request.get_json()
    
    required_fields = ['symbol', 'alert_type', 'confidence', 'reason']
    if not all(field in data for field in required_fields):
        return jsonify({'error': 'Missing required fields'}), 400
    
    alert = {
        'id': f"alert_{datetime.now().strftime('%Y%m%d%H%M%S')}",
        'symbol': data['symbol'].upper(),
        'alert_type': data['alert_type'],  # BUY, SELL, HOLD, etc.
        'confidence': int(data['confidence']),
        'reason': data['reason'],
        'current_price': data.get('current_price', 0),
        'target_price': data.get('target_price'),
        'stop_loss': data.get('stop_loss'),
        'suggested_shares': data.get('suggested_shares'),
        'suggested_amount': data.get('suggested_amount'),
        'created_at': datetime.now().isoformat()
    }
    
    # Send push notifications to all devices
    for token in device_tokens.keys():
        emoji = {
            'NO-BRAINER BUY': '🚨',
            'STRONG BUY': '🟢',
            'BUY': '🟡',
            'HOLD': '⚪',
            'REDUCE': '🟠',
            'SELL': '🔴'
        }.get(alert['alert_type'], '📊')
        
        send_push_notification(
            token=token,
            title=f"{emoji} {alert['alert_type']}: {alert['symbol']}",
            body=f"{alert['reason']} (Confidence: {alert['confidence']}%)",
            data={'alert_id': alert['id'], 'symbol': alert['symbol']}
        )
    
    logger.info(f"Created trading alert: {alert['alert_type']} for {alert['symbol']}")
    
    return jsonify({
        'success': True,
        'alert': alert
    })


# ==================== LIVE ACTIVITY UPDATES ====================

@app.route('/api/liveactivity/update', methods=['POST'])
def update_live_activity():
    """Update a Live Activity with new price data"""
    data = request.get_json()
    
    if not data or 'push_token' not in data or 'symbol' not in data:
        return jsonify({'error': 'push_token and symbol required'}), 400
    
    # Get current price
    try:
        ticker = yf.Ticker(data['symbol'])
        info = ticker.info
        
        current_price = info.get('currentPrice') or info.get('regularMarketPrice', 0)
        previous_close = info.get('previousClose', 0)
        
        update_payload = {
            'aps': {
                'timestamp': int(datetime.now().timestamp()),
                'event': 'update',
                'content-state': {
                    'currentPrice': current_price,
                    'priceChange': current_price - previous_close,
                    'priceChangePercent': ((current_price - previous_close) / previous_close * 100) if previous_close > 0 else 0,
                    'lastUpdated': datetime.now().isoformat()
                }
            }
        }
        
        # TODO: Send via APNs with push-type: liveactivity
        
        return jsonify({
            'success': True,
            'payload': update_payload
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ==================== MAIN ====================

if __name__ == '__main__':
    logger.info(f"Starting MyStocksApp Backend on port {PORT}")
    app.run(host='0.0.0.0', port=PORT, debug=True)
