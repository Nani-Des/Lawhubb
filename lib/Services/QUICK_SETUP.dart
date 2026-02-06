/// Quick Setup Guide for Google Cloud Translation API

/// STEP 1: Get Your API Key
/// 
/// 1. Go to https://console.cloud.google.com
/// 2. Create new project named "LawHubb Translation"
/// 3. Search for "Cloud Translation API" and enable it
/// 4. Go to APIs & Services → Credentials
/// 5. Click "Create Credentials" → "API Key"
/// 6. Copy your API key

/// STEP 2: Add API Key to Your App
/// 
/// Option A: Using .env File (Development)
/// 
/// 1. Copy .env.example to .env (in project root)
/// 2. Replace "your_actual_api_key_here_from_google_cloud_console" with your key
/// 3. Update main.dart:

/*
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';

void main() async {
  // Load environment variables from .env file
  await dotenv.load(fileName: ".env");
  
  runApp(const MyApp());
}
*/

/// Option B: Using Firebase Remote Config (Production)
/// 
/// 1. Go to Firebase Console
/// 2. Click "Remote Config" in left menu
/// 3. Add parameter:
///    - Parameter key: google_translation_api_key
///    - Type: String
///    - Value: your_api_key_here
/// 4. Publish changes
/// 
/// The translation service will automatically use Remote Config in production

/// STEP 3: Test the Translation Feature
///
/// 1. Create a post in the forum
/// 2. Click "Translate" button below the post
/// 3. Select a language (English, Spanish, or French)
/// 4. Post should translate in real-time

/// STEP 4: Security Rules
/// 
/// 1. Go to Google Cloud Console → Credentials
/// 2. Click your API key
/// 3. Under "Application restrictions", select:
///    - For Android: "Android apps" → Add your package name & SHA-1
///    - For iOS: "iOS apps" → Add your bundle ID
/// 4. Under "API restrictions": Select "Cloud Translation API"
/// 5. Save

/// COMMON ISSUES & SOLUTIONS

/// Issue: "API key not configured"
/// Solution: 
/// - Ensure .env file is in project root
/// - Check .gitignore includes .env (don't commit it!)
/// - Run: flutter pub get

/// Issue: "Access denied" or "Invalid key"
/// Solution:
/// - Generate new API key
/// - Enable Cloud Translation API in GCP Console
/// - Verify API key restrictions are correct

/// Issue: "Quota exceeded"
/// Solution:
/// - Go to Google Cloud → APIs & Services → Quotas
/// - Increase quota or set daily limits
/// - Check if you have free tier remaining

/// Issue: Translation not working
/// Solution:
/// - Check internet connection
/// - Verify API key is valid
/// - Check Google Cloud Console for errors
/// - Try translating shorter text first

/// PRICING INFO
/// - Free: 500,000 characters/month
/// - Paid: $15 per million characters after free tier
/// - Enable billing: https://console.cloud.google.com/billing

/// NEXT STEPS
/// See TRANSLATION_API_SETUP.md for detailed documentation
