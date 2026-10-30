import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';

// Handler pesan saat aplikasi di background / ditutup.
// Wajib berupa fungsi top-level (di luar class).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('Notifikasi background: ${message.notification?.title}');
}

class FcmPage extends StatefulWidget {
  const FcmPage({super.key});

  @override
  State<FcmPage> createState() => _FcmPageState();
}

class _FcmPageState extends State<FcmPage> {
  final List<StreamSubscription> subscriptions = [];
  final List<String> logs = [];

  String? token;
  String permissionStatus = '-';
  String statusMessage = 'Menyiapkan Firebase...';

  @override
  void initState() {
    super.initState();
    initializePushNotification();
  }

  void addLog(String text) {
    if (!mounted) return;

    final now = DateTime.now();
    final jam = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';

    setState(() {
      logs.insert(0, '[$jam] $text');
      if (logs.length > 20) logs.removeLast();
    });
  }

  String describe(RemoteMessage m) {
    final title = m.notification?.title ?? '-';
    final body = m.notification?.body ?? '-';
    final data = m.data.isEmpty ? '' : ' | data: ${m.data}';
    return '$title - $body$data';
  }

  Future<void> initializePushNotification() async {
    try {
      // 1. Inisialisasi Firebase
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      // 2. Daftarkan handler background
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );

      final messaging = FirebaseMessaging.instance;

      // 3. Minta izin notifikasi
      final settings = await messaging.requestPermission();
      if (!mounted) return;

      setState(() {
        permissionStatus = settings.authorizationStatus.name;
      });

      // 4. Ambil FCM registration token
      final newToken = await messaging.getToken();
      debugPrint('FCM token: $newToken');

      if (!mounted) return;

      setState(() {
        token = newToken;
        statusMessage = newToken == null
            ? 'Token tidak tersedia (cek Google Play Services / izin)'
            : 'Siap menerima notifikasi';
      });

      // 5. Pesan saat aplikasi sedang dibuka (foreground)
      subscriptions.add(
        FirebaseMessaging.onMessage.listen((message) {
          addLog('FOREGROUND: ${describe(message)}');
        }),
      );

      // 6. Notifikasi di tray ditekan saat aplikasi di background
      subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          addLog('DIBUKA dari notifikasi: ${describe(message)}');
        }),
      );

      // 7. Aplikasi dibuka dari kondisi tertutup lewat notifikasi
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        addLog('DIBUKA (dari tertutup): ${describe(initial)}');
      }

      // 8. Token diperbarui oleh Firebase
      subscriptions.add(
        messaging.onTokenRefresh.listen((t) {
          if (!mounted) return;
          setState(() => token = t);
          addLog('Token diperbarui');
        }),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        statusMessage = 'Gagal inisialisasi: $e';
      });

      debugPrint('ERROR FCM: $e');
    }
  }

  Future<void> copyToken() async {
    if (token == null) return;

    await Clipboard.setData(ClipboardData(text: token!));

    if (!mounted) return;

    setState(() {
      statusMessage = 'Token disalin. Tempel di Firebase Console.';
    });
  }

  @override
  void dispose() {
    for (final s in subscriptions) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Praktikum 8 - FCM'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Push Notification (FCM)',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Izin notifikasi: $permissionStatus'),
                    const SizedBox(height: 10),
                    const Text('FCM token:'),
                    const SizedBox(height: 4),
                    SelectableText(token ?? '-'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 15),

            ElevatedButton.icon(
              onPressed: token == null ? null : copyToken,
              icon: const Icon(Icons.copy),
              label: const Text('Salin Token'),
            ),

            const SizedBox(height: 20),

            const Text(
              'Notifikasi yang diterima',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: logs.isEmpty
                    ? const Text('Belum ada notifikasi')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final log in logs)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 3),
                              child: Text(log),
                            ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              color: Colors.deepPurple.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(statusMessage),
              ),
            ),
          ],
        ),
      ),
    );
  }
}