import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

class SsePage extends StatefulWidget {
  const SsePage({super.key});

  @override
  State<SsePage> createState() => _SsePageState();
}

class _SsePageState extends State<SsePage> {
  http.Client? client;
  StreamSubscription<String>? subscription;

  bool isConnected = false;
  bool isConnecting = false;

  // Data terbaru dari server
  int? counter;
  String value = '-';
  String updatedAt = '-';

  // Riwayat event yang diterima (maksimal 10)
  final List<String> eventLog = [];

  String statusMessage = 'Belum terhubung';

  // Menutup koneksi tanpa mengubah tampilan
  void closeConnection() {
    subscription?.cancel();
    subscription = null;

    client?.close();
    client = null;
  }

  // Mulai berlangganan event dari server (SSE)
  Future<void> connect() async {
    if (isConnected || isConnecting) return;

    setState(() {
      isConnecting = true;
      counter = null;
      value = '-';
      updatedAt = '-';
      eventLog.clear();
      statusMessage = 'Menghubungkan ke server...';
    });

    client = http.Client();

    try {
      final request = http.Request(
        'GET',
        Uri.parse('$baseUrl/api/events'),
      );
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';

      final response = await client!.send(request);

      if (!mounted) {
        closeConnection();
        return;
      }

      if (response.statusCode != 200) {
        closeConnection();
        setState(() {
          isConnecting = false;
          statusMessage = 'Gagal terhubung: ${response.statusCode}';
        });
        return;
      }

      setState(() {
        isConnecting = false;
        isConnected = true;
        statusMessage = 'Terhubung. Menunggu data dari server...';
      });

      // Membaca aliran teks dari server baris demi baris
      subscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            handleLine,
            onError: (e) {
              closeConnection();
              if (!mounted) return;

              setState(() {
                isConnected = false;
                statusMessage = 'SSE error: $e';
              });

              debugPrint('SSE error: $e');
            },
            onDone: () {
              closeConnection();
              if (!mounted) return;

              setState(() {
                isConnected = false;
                statusMessage = 'Koneksi ditutup oleh server';
              });
            },
            cancelOnError: true,
          );
    } catch (e) {
      closeConnection();
      if (!mounted) return;

      setState(() {
        isConnecting = false;
        isConnected = false;
        statusMessage = 'Terjadi kesalahan: $e';
      });

      debugPrint('ERROR SSE: $e');
    }
  }

  // Memutus koneksi SSE
  void disconnect() {
    closeConnection();

    setState(() {
      isConnected = false;
      isConnecting = false;
      statusMessage = 'Koneksi diputus';
    });
  }

  // Memproses satu baris dari stream SSE
  // Format event: "data: {...}" lalu satu baris kosong
  void handleLine(String line) {
    if (!line.startsWith('data:')) return;

    final raw = line.substring(5).trim();
    if (raw.isEmpty) return;

    try {
      final data = jsonDecode(raw);

      // Event "connected" berisi {} -> abaikan
      if (data is! Map || !data.containsKey('counter')) return;

      final waktu = DateTime.parse(data['timestamp']).toLocal();

      if (!mounted) return;

      setState(() {
        counter = (data['counter'] as num).toInt();
        value = data['value'].toString();
        updatedAt = waktu.toString();

        eventLog.insert(
          0,
          'Counter $counter | Value $value | '
          '${waktu.hour.toString().padLeft(2, '0')}:'
          '${waktu.minute.toString().padLeft(2, '0')}:'
          '${waktu.second.toString().padLeft(2, '0')}',
        );
        if (eventLog.length > 10) eventLog.removeLast();

        statusMessage = 'Terhubung. Data baru diterima otomatis.';
      });

      debugPrint('SSE: $data');
    } catch (e) {
      debugPrint('Gagal membaca event: $e');
    }
  }

  @override
  void dispose() {
    closeConnection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Praktikum 3 - SSE'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Data dari Server (SSE)',
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
                    Text('Counter: ${counter ?? "-"}'),
                    const SizedBox(height: 10),
                    Text('Value: $value'),
                    const SizedBox(height: 10),
                    Text('Waktu pembaruan:\n$updatedAt'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        (isConnected || isConnecting) ? null : connect,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Connect'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isConnected ? disconnect : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Disconnect'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (eventLog.isNotEmpty) ...[
              const Text(
                'Event yang diterima',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final log in eventLog)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(log),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

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