# Google Cloud Translation API Setup Guide

This implementation uses the **official Google Cloud Translation API** for production-ready translation services.

## Features

- ✅ Official, supported API from Google
- ✅ Production-ready with error handling
- ✅ SLA and guaranteed availability
- ✅ Pay-per-use pricing
- ✅ Supports 100+ languages (configured for English, Spanish, French)

## Setup Instructions

### Step 1: Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Click "Select a Project" → "NEW PROJECT"
3. Enter project name (e.g., "LawHubb Translation")
4. Click "CREATE"

### Step 2: Enable Cloud Translation API

1. In the Cloud Console, search for "Cloud Translation API"
2. Click on it and press "ENABLE"
3. Wait for the API to be enabled

### Step 3: Create an API Key

1. Go to [APIs & Services → Credentials](https://console.cloud.google.com/apis/credentials)
2. Click "CREATE CREDENTIALS" → "API Key"
3. Copy the generated API key
4. **IMPORTANT**:
   - Restrict this key to only Cloud Translation API
   - Set application restrictions (HTTP referrers for web, package names for mobile)

### Step 4: Configure API Key in Your App

#### Option A: Using Flutter Environment (Recommended for Development)

1. Create a `.env` file in your project root:

```
GOOGLE_TRANSLATION_API_KEY=your_api_key_here
```

2. Add `flutter_dotenv` to `pubspec.yaml`:

```yaml
dependencies:
  flutter_dotenv: ^5.0.2
```

3. Update `main.dart`:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load();
  runApp(const MyApp());
}
```

#### Option B: Using Firebase Remote Config (Recommended for Production)

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a parameter: `google_translation_api_key`
3. Set value to your API key
4. Update `translation_service.dart`:

```dart
static Future<String> get _apiKey async {
  final remoteConfig = FirebaseRemoteConfig.instance;
  await remoteConfig.ensureInitialized();
  return remoteConfig.getString('google_translation_api_key');
}
```

#### Option C: Android Build Config

1. Open `android/app/build.gradle`:

```gradle
buildTypes {
    release {
        buildConfigField "String", "GOOGLE_TRANSLATION_API_KEY", "\"your_api_key_here\""
    }
    debug {
        buildConfigField "String", "GOOGLE_TRANSLATION_API_KEY", "\"your_api_key_here\""
    }
}
```

2. Update `translation_service.dart`:

```dart
import 'package:nhap/generated_plugin_registrant.dart';

static const String _apiKey = String.fromEnvironment('GOOGLE_TRANSLATION_API_KEY');
```

### Step 5: Set API Usage Restrictions (Security)

1. Go to your API key in [Credentials](https://console.cloud.google.com/apis/credentials)
2. Click on your key to edit
3. Under "Application Restrictions":
   - **For Android**: Select "Android apps" → Add your app's package name & SHA-1 certificate
   - **For iOS**: Select "iOS apps" → Add your app's bundle ID
   - **For Web**: Select "HTTP referrers" → Add your domain

4. Under "API Restrictions":
   - Select "Cloud Translation API"

## Usage

The translation feature is already integrated into posts. Users can:

1. Tap the "Translate" button below any post
2. Select from: English, Spanish, or French
3. Post content is translated and displayed with a language badge
4. Tap "Change Translation" to switch languages
5. Select "View Original" to see the original post

## Pricing

Google Cloud Translation API uses **pay-per-use pricing**:

- **Free Tier**: 500,000 characters/month free
- **Paid Tier**: $15 per million characters (after free tier)

**Estimated costs**:

- 1,000 translations of 100 characters: $1.50/month
- 10,000 translations of 100 characters: $15/month

Enable billing: [Google Cloud Billing](https://console.cloud.google.com/billing)

## Troubleshooting

### Error: "API key not configured"

- Solution: Ensure your API key is set as environment variable or remote config

### Error: "Access denied"

- Solution: Check that API key has Cloud Translation API enabled
- Solution: Verify application restrictions match your app's package/domain

### Error: "Rate limit exceeded"

- Solution: Implement request queuing or caching
- Solution: Upgrade to a higher quota if needed

### Error: "Invalid language code"

- Solution: Check supported language codes (currently: en, es, fr)

## Monitoring & Quotas

1. Go to [APIs & Services → Quotas](https://console.cloud.google.com/apis/dashboard)
2. Search for "Cloud Translation API"
3. Set quotas to prevent unexpected charges:
   - Daily requests limit
   - Characters per day limit

## Documentation

- [Google Cloud Translation API Docs](https://cloud.google.com/translate/docs)
- [REST API Reference](https://cloud.google.com/translate/docs/reference/rest/v2/translate)
- [Supported Languages](https://cloud.google.com/translate/docs/languages)

## Security Best Practices

🔒 **DO**:

- Use environment variables or Firebase Remote Config
- Restrict API key to specific applications
- Enable API quotas to prevent abuse
- Rotate API keys periodically
- Use separate keys for dev/test/prod

🚫 **DON'T**:

- Hardcode API key in source code
- Commit `.env` file to version control
- Share API keys in public repositories
- Use unrestricted API keys

## Support

For issues with Google Cloud Translation API:

- [Google Cloud Support](https://cloud.google.com/support)
- [Stack Overflow - google-cloud-translation](https://stackoverflow.com/questions/tagged/google-cloud-translation)
