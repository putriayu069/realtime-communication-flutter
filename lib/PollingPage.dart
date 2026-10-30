import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

class PollingPage extends StatefulWidget {
  const PollingPage({super.key});

  @override
  State<PollingPage> createState() => _PollingPageState();
}

class _PollingPageState extends State<PollingPage> {
  // Interval polling (sesuai modul: 2 detik)
  static const Duration pollingInterval = Duration(seconds: 2);

  Timer? pollingTimer;
  bool isPolling = false;
  bool isFetching = false; // mencegah request bertumpuk

  // Data dari server
  int? counter;
  String value = '-';
  String updatedAt = '-';

  String statusMessage = 'Polling belum dimulai';

  // Mulai polling
  void startPolling() {
    pollingTimer?.cancel();

    setState(() {
      isPolling = true;
      counter = null;
      statusMessage = 'Polling berjalan setiap '
          '${pollingInterval.inSeconds} detik';
    });

    fetchData(); // request pertama langsung

    pollingTimer = Timer.periodic(pollingInterval, (_) => fetchData());
  }

  // Hentikan polling
  void stopPolling() {
    pollingTimer?.cancel();
    pollingTimer = null;

    setState(() {
      isPolling = false;
      statusMessage = 'Polling dihentikan';
    });
  }

  // GET berulang ke server
  Future<void> fetchData() async {
    if (isFetching) return;
    isFetching = true;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/data'),
      );

      if (!mounted || !isPolling) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          counter = (data['counter'] as num).toInt();
          value = data['value'].toString();

          final waktu = DateTime.parse(data['timestamp']);
          updatedAt = waktu.toLocal().toString();

          statusMessage = 'Data terbaru: $data';
        });

        debugPrint('Data terbaru: $data');
      } else {
        setState(() {
          statusMessage = 'Gagal mengambil data: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted || !isPolling) return;

      setState(() {
        statusMessage = 'Polling error: $e';
      });

      debugPrint('Polling error: $e');
    } finally {
      isFetching = false;
    }
  }

  @override
  void dispose() {
    pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Praktikum 2 - Polling'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Data dari Server (Polling)',
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
                    onPressed: isPolling ? null : startPolling,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Polling'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isPolling ? stopPolling : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

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