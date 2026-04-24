import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService.initialize();
  await NotificationService.showSOSNotification(
    title: message.notification?.title ?? '🆘 SOS ALERT!',
    body: message.notification?.body ?? 'Someone needs help nearby!',
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // Initialize local notifications
  await NotificationService.initialize();

  // Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request notification permission
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Save FCM token
  await _saveFCMToken();
  // Subscribe all users to 'sos_alerts' topic
  await FirebaseMessaging.instance.subscribeToTopic('sos_alerts');
  print('✅ Subscribed to sos_alerts topic');

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const WomenSOSApp());
}

Future<void> _saveFCMToken() async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? token;

    await FirebaseFirestore.instance
        .collection('fcm_tokens')
        .doc(userId)
        .set({
      'token': token,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    print('✅ FCM Token saved: $token');
  } catch (e) {
    print('❌ FCM Token error: $e');
  }
}



class WomenSOSApp extends StatelessWidget {
  const WomenSOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SheSafe – Women SOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE91E8C),
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}