
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'RestApiPage.dart';
import 'PollingPage.dart';
import 'SsePage.dart';
import 'WebsocketPage.dart';
import 'MqttPage.dart';
import 'MqttParkirPage.dart';
import 'WebRtcPage.dart';
import 'fcm_page.dart';
import 'grpc_page.dart';


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
    final List<PraktikumItem> daftar = [
      PraktikumItem(
        judul: 'Praktikum 1 - REST API',
        subjudul: 'Request-response (GET dan POST)',
        halaman: const RestApiPage(),
      ),
      PraktikumItem(
        judul: 'Praktikum 2 - Polling',
        subjudul: 'Mengambil data berkala setiap 2 detik',
        halaman: const PollingPage(),
      ),
      PraktikumItem(
        judul: 'Praktikum 3 - SSE',
        subjudul: 'Server mengirim pembaruan ke client',
        halaman: const SsePage(),
      ),
      PraktikumItem(
        judul: 'Praktikum 4 - WebSockets',
        subjudul: 'Koneksi dua arah antara client dan server',
        halaman: const WebSocketPage(),
      ),
      PraktikumItem(
        judul: 'Praktikum 5 - MQTT',
        subjudul: 'Komunikasi publish-subscribe untuk IoT',
        halaman: const MqttMenuPage(),
      ),
      PraktikumItem(
        judul: 'Praktikum 6 - WebRTC',
        subjudul: 'Komunikasi langsung antara browser',
        halaman: const WebRtcPage(),
      ),
      PraktikumItem(
        judul: 'Praktikum 7 - gRPC Streaming',
        subjudul: 'Unary RPC dan Server Streaming',
        halaman: const GrpcPage(),
      ),
      PraktikumItem(
        judul: 'Praktikum 8 - FCM',
        subjudul: 'Push Notification',
        halaman: const FcmPage(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Realtime Communication',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: daftar.length,
        itemBuilder: (context, index) {
          final item = daftar[index];

          return Card(
            child: ListTile(
              title: Text(
                item.judul,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(item.subjudul),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => item.halaman,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class MqttMenuPage extends StatelessWidget {
  const MqttMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Praktikum 5 - MQTT',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.sensors,
                color: Colors.deepPurple,
                size: 32,
              ),
              title: const Text(
                'Percobaan 1 - MQTT Sesuai Modul',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Komunikasi Publisher dan Subscriber untuk data sensor',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MqttPage(),
                  ),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.local_parking,
                color: Colors.green,
                size: 32,
              ),
              title: const Text(
                'Percobaan 2 - Monitoring Slot Parkir',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Simulasi status slot parkir menggunakan MQTT',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MqttParkirPage(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class PraktikumItem {
  final String judul;
  final String subjudul;
  final Widget halaman;

  PraktikumItem({
    required this.judul,
    required this.subjudul,
    required this.halaman,
  });
}
