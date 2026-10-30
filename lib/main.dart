import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

import 'PollingPage.dart';
import 'RestApiPage.dart';
import 'SsePage.dart';
import 'WebSocketPage.dart';
import 'MqttPage.dart';
import 'WebRtcPage.dart';
import 'fcm_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}
 
class MyApp extends StatelessWidget {
  const MyApp({super.key});
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Realtime Communication',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: const MenuPage(),
    );
  }
}
 
class MenuPage extends StatelessWidget {
  const MenuPage({super.key});
 
  @override
  Widget build(BuildContext context) {
    // Untuk menambah praktikum berikutnya: buat file halamannya,
    // import di atas, lalu tambahkan satu baris di daftar ini.
    final List<_PraktikumItem> daftar = [
      _PraktikumItem(
        judul: 'Praktikum 1 - REST API',
        subjudul: 'Request-response (GET dan POST)',
        halaman: const RestApiPage(),
      ),
      _PraktikumItem(
        judul: 'Praktikum 2 - Polling',
        subjudul: 'Mengambil data berkala setiap 2 detik',
        halaman: const PollingPage(),
      ),
       _PraktikumItem(
        judul: 'Praktikum 3 - SSE',
        subjudul: 'Server mengirim pembaruan ke client',
        halaman: const SsePage(),
      ),
      _PraktikumItem(
        judul: 'Praktikum 4 - WebSockets',
        subjudul: 'Koneksi dua arah antara client dan server',
        halaman: const WebSocketPage(),
      ),
      _PraktikumItem(
        judul: 'Praktikum 5 - MQTT',
        subjudul: 'Komunikasi publish-subscribe untuk IoT',
        halaman: const MqttPage(),
      ),
      _PraktikumItem(
        judul: 'Praktikum 6 - WebRTC',
        subjudul: 'Komunikasi langsung antara browser',
        halaman: const WebRtcPage(),
      ),
            _PraktikumItem(
        judul: 'Praktikum 8 - FCM',
        subjudul: 'Push notification',
        halaman: const FcmPage(),
      ),
    ];
 
    return Scaffold(
      appBar: AppBar(
        title: const Text('Realtime Communication'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: daftar.length,
        itemBuilder: (context, index) {
          final item = daftar[index];
 
          return Card(
            child: ListTile(
              title: Text(item.judul),
              subtitle: Text(item.subjudul),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => item.halaman),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
 
class _PraktikumItem {
  final String judul;
  final String subjudul;
  final Widget halaman;
 
  _PraktikumItem({
    required this.judul,
    required this.subjudul,
    required this.halaman,
  });
}