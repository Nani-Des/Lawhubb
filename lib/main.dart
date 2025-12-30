import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
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
import 'ChatModule/chat_module.dart';
import 'main_layout.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'Services/config_service.dart';
import 'Services/language_provider.dart';
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

// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling background message: ${message.messageId}');
}

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

  // Initialize FCM
  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications
    final FlutterLocalNotificationsPlugin localNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);
    await localNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) async {
        if (response.payload != null) {
          final data = Map<String, dynamic>.from(jsonDecode(response.payload!));
          final userId = FirebaseAuth.instance.currentUser?.uid;
          if (userId != null &&
              (data['type'] == 'new_booking' ||
                  data['type'] == 'status_update' ||
                  data['type'] == 'reminder')) {
            Navigator.of(navigatorKey.currentContext!).pushReplacement(
              MaterialPageRoute(
                  builder: (context) => BookingPage(currentUserId: userId)),
            );
          }
        }
      },
    );

    // Store FCM token
    String? token = await messaging.getToken();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (token != null && userId != null) {
      await FirebaseFirestore.instance.collection('Users').doc(userId).update({
        'fcmToken': token,
      });
    }

    // Handle initial message
    RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null && userId != null) {
      if (initialMessage.data['type'] == 'new_booking' ||
          initialMessage.data['type'] == 'status_update' ||
          initialMessage.data['type'] == 'reminder') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(navigatorKey.currentContext!).pushReplacement(
            MaterialPageRoute(
                builder: (context) => BookingPage(currentUserId: userId)),
          );
        });
      }
    }

    // Handle message opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null &&
          (message.data['type'] == 'new_booking' ||
              message.data['type'] == 'status_update' ||
              message.data['type'] == 'reminder')) {
        Navigator.of(navigatorKey.currentContext!).pushReplacement(
          MaterialPageRoute(
              builder: (context) => BookingPage(currentUserId: userId)),
        );
      }
    });
  } catch (e) {
    print('Error initializing FCM: $e');
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
            title: AppLocalizations.of(context)?.appTitle ?? 'LawHub',
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
            navigatorKey: navigatorKey, // Add navigator key
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

    _controller.forward().then((_) {
      // #region agent log
      _debugLog(
        hypothesisId: 'A',
        location: 'main.dart:CustomTransitionScreen.afterForward',
        message: 'Splash animation completed',
        data: {},
      );
      // #endregion
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => const LocationPermissionScreen()),
      );
      // #region agent log
      _debugLog(
        hypothesisId: 'B',
        location: 'main.dart:CustomTransitionScreen.afterNavigate',
        message: 'Navigation from splash triggered',
        data: {},
      );
      // #endregion
    });

    // Add failsafe timeout to force navigation even if Firebase/network is stuck
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => const LocationPermissionScreen()),
        );
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
                  // #region agent log
                  _debugLog(
                    hypothesisId: 'C',
                    location: 'main.dart:LocationPermissionScreen.allow',
                    message: 'Allow location tapped',
                    data: {},
                  );
                  // #endregion
                  await _requestLocationPermission();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const MainLayout()),
                  );
                },
                child: Text(localizations?.allowLocationButton ??
                    'Allow Location Access'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const MainLayout()),
                  );
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
