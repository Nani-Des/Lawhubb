import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../Forums/Chat/chat_screen.dart';
import '../booking_page.dart';
import '../utils/app_navigation.dart';
import '../Forums/Public/Widgets/user_profile_screen.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  // Notification channel IDs
  static const String _channelMessages = 'messages';
  static const String _channelBookings = 'bookings';
  static const String _channelInsights = 'insights';
  static const String _channelSocial = 'social';

  /// Initialize the notification service
  Future<void> initialize({GlobalKey<NavigatorState>? navigatorKey}) async {
    if (_initialized) return;
    _navigatorKey = navigatorKey;

    try {
      // Request permissions
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Initialize Android notification channels
        await _initializeAndroidChannels();

        // Initialize local notifications
        await _initializeLocalNotifications();

        // Set up message handlers
        _setupMessageHandlers();

        // Store FCM token for current user
        await _storeFCMToken();

        // Listen for token refresh
        _messaging.onTokenRefresh.listen((newToken) async {
          await _storeFCMTokenForUser(newToken);
        });

        _initialized = true;
        debugPrint('NotificationService initialized successfully');
      } else {
        debugPrint('Notification permission denied');
      }
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  /// Initialize Android notification channels
  Future<void> _initializeAndroidChannels() async {
    const AndroidNotificationChannel messagesChannel = AndroidNotificationChannel(
      _channelMessages,
      'Messages',
      description: 'Notifications for new messages and chats',
      importance: Importance.high,
      playSound: true,
    );

    const AndroidNotificationChannel bookingsChannel = AndroidNotificationChannel(
      _channelBookings,
      'Bookings',
      description: 'Notifications for booking updates and reminders',
      importance: Importance.high,
      playSound: true,
    );

    const AndroidNotificationChannel insightsChannel = AndroidNotificationChannel(
      _channelInsights,
      'Law Insights',
      description: 'Notifications for insights, comments, and likes',
      importance: Importance.defaultImportance,
      playSound: true,
    );

    const AndroidNotificationChannel socialChannel = AndroidNotificationChannel(
      _channelSocial,
      'Social',
      description: 'Notifications for follows, replies, and social interactions',
      importance: Importance.defaultImportance,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(messagesChannel);
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(bookingsChannel);
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(insightsChannel);
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(socialChannel);
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Set up Firebase Messaging handlers
  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background messages (opened app from notification)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Initial message (app opened from terminated state)
    _messaging.getInitialMessage().then((message) {
      if (message != null) {
        _handleNotificationTap(message);
      }
    });
  }

  /// Handle foreground messages (app is open)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Received foreground message: ${message.messageId}');
    debugPrint('Message data: ${message.data}');
    debugPrint('Message notification: ${message.notification?.title}');

    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      final channelId = _getChannelIdForType(data['type'] ?? '');
      
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId,
        _getChannelName(channelId),
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        notificationDetails,
        payload: jsonEncode(data),
      );
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateFromNotification(message.data);
    });
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigateFromNotification(data);
        });
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  /// Navigate based on notification type
  void _navigateFromNotification(Map<String, dynamic> data) {
    final context = _navigatorKey?.currentContext;
    if (context == null) {
      debugPrint('Navigator context not available for notification navigation');
      return;
    }

    final type = data['type'] as String?;
    if (type == null) return;

    try {
      switch (type) {
        case 'new_message':
          _navigateToChat(context, data);
          break;

        case 'new_booking':
        case 'status_update':
        case 'cancelled':
        case 'reminder':
          _navigateToBookings(context, data);
          break;

        case 'new_insight_comment':
        case 'new_insight_like':
        case 'new_insight':
          // For insights, we'll navigate to the Law Insights page
          // The user can then tap on the specific insight
          debugPrint('Insight notification received: ${data['insightId']}');
          break;

        case 'new_follow':
        case 'new_reply':
          _navigateToProfile(context, data);
          break;

        default:
          debugPrint('Unknown notification type: $type');
      }
    } catch (e) {
      debugPrint('Error navigating from notification: $e');
    }
  }

  /// Navigate to chat screen
  void _navigateToChat(BuildContext context, Map<String, dynamic> data) {
    final chatId = data['chatId'] as String?;
    final senderId = data['senderId'] as String?;
    if (chatId != null && senderId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chatId,
            recipientId: senderId,
            recipientName: data['senderName'] as String? ?? 'User',
            recipientPic: data['senderPic'] as String? ?? '',
            recipientRole: (data['senderRole'] as bool?) ?? false,
          ),
        ),
      );
    }
  }

  /// Navigate to bookings page
  void _navigateToBookings(BuildContext context, Map<String, dynamic> data) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      pushAppRoute(
        context,
        BookingPage(currentUserId: userId),
      );
    }
  }

  /// Navigate to user profile
  void _navigateToProfile(BuildContext context, Map<String, dynamic> data) {
    final userId = data['userId'] as String?;
    if (userId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => UserProfileScreen(userId: userId),
        ),
      );
    }
  }

  /// Get channel ID for notification type
  String _getChannelIdForType(String type) {
    switch (type) {
      case 'new_message':
        return _channelMessages;
      case 'new_booking':
      case 'status_update':
      case 'cancelled':
      case 'reminder':
        return _channelBookings;
      case 'new_insight_comment':
      case 'new_insight_like':
      case 'new_insight':
        return _channelInsights;
      case 'new_follow':
      case 'new_reply':
        return _channelSocial;
      default:
        return _channelMessages;
    }
  }

  /// Get channel name
  String _getChannelName(String channelId) {
    switch (channelId) {
      case _channelMessages:
        return 'Messages';
      case _channelBookings:
        return 'Bookings';
      case _channelInsights:
        return 'Law Insights';
      case _channelSocial:
        return 'Social';
      default:
        return 'Notifications';
    }
  }

  /// Store FCM token for current user
  Future<void> _storeFCMToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await _messaging.getToken();
      if (token != null) {
        await _storeFCMTokenForUser(token);
      }
    }
  }

  /// Store FCM token for a specific user
  Future<void> _storeFCMTokenForUser(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('No user logged in, cannot store FCM token');
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
      debugPrint('FCM token stored for user ${user.uid}');
    } catch (e) {
      debugPrint('Error storing FCM token: $e');
    }
  }

  /// Store FCM token for a specific user ID (useful after login)
  Future<void> storeTokenForUserId(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(userId)
            .set({'fcmToken': token}, SetOptions(merge: true));
        debugPrint('FCM token stored for user $userId');
      }
    } catch (e) {
      debugPrint('Error storing FCM token for user $userId: $e');
    }
  }

  /// Clear FCM token (on logout)
  Future<void> clearToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .update({'fcmToken': FieldValue.delete()});
        debugPrint('FCM token cleared for user ${user.uid}');
      } catch (e) {
        debugPrint('Error clearing FCM token: $e');
      }
    }
  }

  /// Get current FCM token
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }
}

// Background message handler (must be top-level)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling background message: ${message.messageId}');
  debugPrint('Background message data: ${message.data}');
}
