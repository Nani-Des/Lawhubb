import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nhap/l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:showcaseview/showcaseview.dart';
import 'Auth/auth_service.dart';
import 'Auth/auth_screen.dart';
import 'ChatModule/chat_module.dart';
import 'main_layout.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nhap/l10n/app_localizations.dart';

import 'Services/config_service.dart';
import 'Services/language_provider.dart';
import 'Services/notification_service.dart';
import 'booking_page.dart';

// #region agent log helper
void _debugLog({
  required String hypothesisId,
  required String location,
  required String message,
  required Map<String, dynamic> data,
}) {
  try {
    final logFile = File(
        r'c:\Users\HP\PROJECTS\flutter_projects\lawhubb\Lawhubb\.cursor\debug.log');
    if (!logFile.parent.existsSync()) {
      logFile.parent.createSync(recursive: true);
    }
    logFile.writeAsStringSync(
      jsonEncode({
            'sessionId': 'debug-session',
            'runId': 'pre-fix',
            'hypothesisId': hypothesisId,
            'location': location,
            'message': message,
            'data': data,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          }) +
          '\n',
      mode: FileMode.append,
    );
  } catch (_) {}
}
// #endregion

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDir = await getApplicationDocumentsDirectory();
  Hive.init(appDir.path);
  await Hive.openBox('reading_archive');
  await Hive.openBox('notes_box');
  await Hive.openBox('achievements_box');
  await Hive.initFlutter();
  await Hive.openBox('translations');
  await dotenv.load();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: dotenv.env['FIREBASE_API_KEY']!,
      appId: dotenv.env['FIREBASE_APP_ID']!,
      messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID']!,
      projectId: dotenv.env['FIREBASE_PROJECT_ID']!,
      storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET']!,
    ),
  );
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true);

  // Initialize Remote Config
  final configService = ConfigService();
  await configService.init();

  // Initialize Notification Service
  try {
    final notificationService = NotificationService();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await notificationService.initialize(navigatorKey: navigatorKey);
  } catch (e) {
    print('Error initializing NotificationService: $e');
  }

  // Initialize cached_network_image
  try {
    CachedNetworkImage.logLevel = CacheManagerLogLevel.debug;
    imageCache.maximumSizeBytes = 100 * 1024 * 1024; // 100 MB
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024;
  } catch (e) {
    print('Error initializing image cache: $e');
  }

  // await CallService().clearOldNotifications();
  // await WordFilterService().initialize();
  // CallService().initialize();

  try {
    await CallService().clearOldNotifications();
  } catch (e) {
    debugPrint('Skipping clearOldNotifications: $e');
  }
  await WordFilterService().initialize();
  CallService().initialize();

  // Initialize LanguageProvider
  final languageProvider = LanguageProvider();
  await languageProvider.init();

  runApp(MyApp(languageProvider: languageProvider));
}

// Global navigator key for notification navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final appLocalization = AppLocalizations.of(navigatorKey.currentContext!);

Future<void> _requestLocationPermission() async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      print('Location permissions denied');
      return;
    }
  }
  if (permission == LocationPermission.deniedForever) {
    print('Location permissions permanently denied');
    return;
  }
  print('Location permissions granted');
}

class MyApp extends StatelessWidget {
  final LanguageProvider languageProvider;

  const MyApp({
    super.key,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    // #region agent log
    _debugLog(
      hypothesisId: 'D',
      location: 'main.dart:MyApp.build',
      message: 'MyApp build invoked',
      data: {},
    );
    // #endregion

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(
          create: (context) {
            final userModel = UserModel();
            try {
              final userId = FirebaseAuth.instance.currentUser?.uid;
              userModel.setUserId(userId);
            } catch (e) {
              print('Error initializing user ID: $e');
            }
            return userModel;
          },
        ),
        ChangeNotifierProvider.value(value: languageProvider),
      ],
      child: ShowCaseWidget(
        builder: (context) => Consumer<LanguageProvider>(
          builder: (context, langProvider, _) => MaterialApp(
            title: AppLocalizations.of(context)?.appTitle ?? 'LawHubb',
            locale: langProvider.currentLocale,

            // 2. Define supported locales
            supportedLocales: const [
              Locale('en'), // English
              Locale('es'), // Spanish
              Locale('fr'), // French
            ],

            // 3. Add delegates
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
              useMaterial3: true,
            ),
            home: const CustomTransitionScreen(),
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
          ),
        ),
      ),
    );
  }
}

class CustomTransitionScreen extends StatefulWidget {
  const CustomTransitionScreen({super.key});

  @override
  _CustomTransitionScreenState createState() => _CustomTransitionScreenState();
}

class _CustomTransitionScreenState extends State<CustomTransitionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  Future<void> _navigateFromSplash() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final locationAsked = prefs.getBool('locationPermissionAsked') ?? false;
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted) return;
    if (user != null) {
      // Already logged in — go straight to the app
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainLayout()),
      );
    } else if (!locationAsked) {
      // First-time user — ask for location then go to auth
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LocationPermissionScreen()),
      );
    } else {
      // Returning user who is logged out — go to login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // #region agent log
    _debugLog(
      hypothesisId: 'A',
      location: 'main.dart:CustomTransitionScreen.initState',
      message: 'Splash init started',
      data: {},
    );
    // #endregion
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * 3.14159).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 2.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward().then((_) async {
      await _navigateFromSplash();
    });

    // Failsafe: if animation or network stalls, force navigation after 5 seconds
    Future.delayed(const Duration(seconds: 5), () async {
      if (mounted) {
        await _navigateFromSplash();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotationAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Image.asset('assets/Icons/Icon.png',
                    width: 200, height: 200),
              ),
            );
          },
        ),
      ),
    );
  }
}

class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/Icons/Icon.png', width: 100, height: 100),
              const SizedBox(height: 20),
              Text(
                localizations?.locationPermissionTitle ??
                    'We Need Your Location',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                localizations?.locationPermissionDescription ??
                    'To provide you with the best experience, we need your location to find Lawyers and Chambers near you.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () async {
                  await _requestLocationPermission();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('locationPermissionAsked', true);
                  if (context.mounted) {
                    final user = FirebaseAuth.instance.currentUser;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            user != null ? const MainLayout() : const AuthScreen(),
                      ),
                    );
                  }
                },
                child: Text(localizations?.allowLocationButton ??
                    'Allow Location Access'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('locationPermissionAsked', true);
                  if (context.mounted) {
                    final user = FirebaseAuth.instance.currentUser;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            user != null ? const MainLayout() : const AuthScreen(),
                      ),
                    );
                  }
                },
                child: Text(localizations?.skipButton ?? 'Skip for Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserModel with ChangeNotifier {
  String? _userId;

  String? get userId => _userId;

  void setUserId(String? userId) {
    _userId = userId;
    notifyListeners();
  }

  void clearUserId() {
    _userId = null;
    notifyListeners();
  }
}
