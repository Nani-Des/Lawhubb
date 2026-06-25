# Lawhubb

Mobile Flutter app for law chambers to manage members, referrals, documents, schedules, and communications.

Overview
- Lawhubb is a cross-platform Flutter application that connects chamber members, manages referrals, stores documents, and supports voice/video and notifications.
- The app uses Firebase for authentication, database, storage, functions, and push messaging.
- It includes native platform projects (Android, iOS, macOS, Windows, Linux) and a web build target.
- The codebase contains client UI in `lib/` and optional Cloud Functions in `functions/`.

Tech Stack
- Dart / Flutter
- Ollama--
- Rag pipeline
- Firebase (Auth, Firestore, Storage, Database, Functions, Messaging)
- Google Maps, Agora RTC, audio/video packages
- Hive (local storage), Dio (HTTP), Provider (state)

Getting Started
Prerequisites
- Flutter SDK (compatible with Dart >=3.5)
- Android SDK / Xcode for mobile builds (or use `flutter run` for a connected device)
- Firebase project and config
- Git

Steps
1. Clone the repo
```
git clone https://github.com/Nani-Des/Lawhubb.git
cd Lawhubb
```
2. Install Flutter dependencies
```
flutter pub get
```
3. Configure Firebase
- Place your Firebase config and any environment variables referenced by the app (the repo references a `.env`) into the project per your platform (edit `lib` firebase initializer or use `flutter_dotenv`).
4. Run on a device or emulator
```
flutter run
```
5. Build APK (Android) or IPA/Xcode as needed
```
flutter build apk
flutter build ios
```

Usage
- Run the app on a connected device:
```
flutter run
```
- Open the app and sign in with an account from your configured Firebase project to access member and admin features.

Project Structure
```
pubspec.yaml
firebase.json
lib/               # Flutter application source (UI, pages, providers)
android/           # Android native project
ios/               # iOS native project
web/               # Web build target
functions/         # Firebase Cloud Functions (optional)
assets/            # Images, audio, knowledge packs, JSON data
test/              # Unit and widget tests
```

Status
working

Author
- Nani-Des — https://github.com/Nani-Des


![App Screenshot](assets/Lawhubb.drawio.png)
