# Codemagic CI/CD Setup Guide

This guide helps you set up Codemagic to build your iOS app from Windows without needing a Mac.

## Prerequisites

1. **Apple Developer Account** (you have this)
2. **Codemagic Account** - Sign up at [codemagic.io](https://codemagic.io)
3. **App Store Connect API Key**

## Step 1: Create App Store Connect API Key

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to **Users and Access** → **Keys** → **App Store Connect API**
3. Click **Generate API Key**
4. Give it a name like "Codemagic CI/CD"
5. Select **App Manager** role
6. Download the `.p8` key file (you can only download it once!)
7. Note down:
   - **Key ID** (e.g., `ABC123DEF4`)
   - **Issuer ID** (shown at top of Keys page)

## Step 2: Set Up Codemagic

### Connect Repository

1. Sign in to [Codemagic](https://codemagic.io)
2. Click **Add application**
3. Select **GitHub** and authorize access
4. Select `rajivpeter/mystocksapp` repository
5. Choose **codemagic.yaml** configuration

### Set Up App Store Connect Integration

1. Go to **Teams** → **Integrations** → **App Store Connect**
2. Click **Connect**
3. Enter your App Store Connect API key details:
   - **Key ID**: Your API Key ID (e.g., `ABC123DEF4`)
   - **Issuer ID**: Your Issuer ID (shown at top of Keys page)
   - **API Key**: Upload or paste the contents of your `.p8` file
4. Name the integration: `codemagic` (this matches the yaml config)

### Code Signing

1. Go to **Settings** → **Code signing identities**
2. Codemagic will automatically:
   - Generate development certificates
   - Create provisioning profiles
   - Sign your app

## Step 3: Configure Bundle ID

In App Store Connect:

1. Go to **Certificates, Identifiers & Profiles**
2. Click **Identifiers** → **+**
3. Select **App IDs** → **App**
4. Enter:
   - Description: `MyStocksApp`
   - Bundle ID: `com.yantra.mystocksapp` (Explicit)
5. Enable capabilities:
   - Push Notifications
   - Associated Domains (for widgets)
   - App Groups

## Step 4: Create App in App Store Connect

1. Go to **My Apps** → **+** → **New App**
2. Fill in:
   - Platform: iOS
   - Name: MyStocksApp
   - Primary Language: English
   - Bundle ID: `com.yantra.mystocksapp`
   - SKU: `mystocksapp-2026`
3. Create the app

## Step 5: Trigger Your First Build

### Option A: Push to GitHub
```bash
git push origin main
```

### Option B: Manual Build
1. Go to Codemagic dashboard
2. Select your app
3. Click **Start new build**
4. Select workflow: **ios-app**
5. Click **Start new build**

## Workflow Types

| Workflow | Purpose | Trigger |
|----------|---------|---------|
| `ios-app` | Production build → TestFlight | Push to `main` |
| `ios-dev` | Development build | Push to `develop` or `feature/*` |
| `ios-simulator` | Simulator build + tests | Pull requests |

## Build Artifacts

After each build, you'll receive:
- `.ipa` file (installable app)
- Debug symbols (`.dSYM`)
- Build logs

## Costs

Codemagic pricing (as of 2026):
- **Free tier**: 500 build minutes/month
- **Pay as you go**: $0.038/minute (Mac Mini M2)
- Average build: 10-15 minutes = ~$0.50/build

## Troubleshooting

### "No signing certificate found"
- Ensure App Store Connect API key has correct permissions
- Check that bundle ID matches exactly

### "Provisioning profile doesn't match"
- Delete existing profiles in Apple Developer Portal
- Let Codemagic regenerate them

### Build timeout
- Increase `max_build_duration` in codemagic.yaml
- Check for slow dependencies

## Notifications

Configure Slack notifications:

```yaml
publishing:
  slack:
    channel: '#ios-builds'
    notify_on_build_start: false
    notify:
      success: true
      failure: true
```

## Local Testing (Optional)

If you get access to a Mac:

```bash
# Clone repo
git clone https://github.com/rajivpeter/mystocksapp.git
cd mystocksapp

# Open in Xcode
open MyStocksApp.xcworkspace

# Or build from command line
xcodebuild -scheme MyStocksApp -sdk iphonesimulator build
```

## Support

- Codemagic Docs: https://docs.codemagic.io
- Codemagic Slack: https://slack.codemagic.io
- Apple Developer: https://developer.apple.com
