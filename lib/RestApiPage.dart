import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

class RestApiPage extends StatefulWidget {
  const RestApiPage({super.key});

  @override
  State<RestApiPage> createState() => _RestApiPageState();
}

class _RestApiPageState extends State<RestApiPage> {
  final TextEditingController messageController = TextEditingController();

  // Data dari server
  int? counter;
  String value = '-';
  String updatedAt = '-';

  bool isLoading = false;
  bool isSending = false;
  String statusMessage = '';

  // GET: Mengambil data dari server
  Future<void> getData() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
      statusMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/data'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (!mounted) return;

        setState(() {
          counter = (data['counter'] as num).toInt();
          value = data['value'].toString();

          final waktu = DateTime.parse(data['timestamp']);
          updatedAt = waktu.toLocal().toString();

          statusMessage = 'Data berhasil diambil';
        });
      } else {
        if (!mounted) return;

        setState(() {
          statusMessage = 'Gagal mengambil data: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        statusMessage = 'Terjadi kesalahan: $e';
      });

      debugPrint('ERROR GET: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // POST: fungsi pengiriman pesan (sesuai modul)
  Future<Map<String, dynamic>> sendMessage(String message) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/message'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'message': message}),
    );

    if (response.statusCode != 200) {
      throw Exception('Gagal mengirim pesan');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // Dipanggil tombol: validasi, kirim, lalu tampilkan hasil
  Future<void> kirimPesan() async {
    final message = messageController.text.trim();

    if (message.isEmpty) {
      setState(() {
        statusMessage = 'Pesan tidak boleh kosong';
      });
      return;
    }

    if (isSending) return;

    setState(() {
      isSending = true;
      statusMessage = '';
    });

    try {
      final hasil = await sendMessage(message);

      if (!mounted) return;

      setState(() {
        statusMessage = 'Pesan berhasil dikirim: ${hasil['message']}';
      });

      messageController.clear();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        statusMessage = 'Terjadi kesalahan: $e';
      });

      debugPrint('ERROR POST: $e');
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Praktikum 1 - REST API'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Data dari Server',
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

            ElevatedButton.icon(
              onPressed: isLoading ? null : getData,
              icon: const Icon(Icons.download),
              label: const Text('Ambil Data (GET)'),
            ),

            const SizedBox(height: 30),

            const Text(
              'Kirim Pesan ke Server',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Masukkan pesan',
                hintText: 'Contoh: Halo dari Flutter',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: isSending ? null : kirimPesan,
              icon: const Icon(Icons.send),
              label: const Text('Kirim Pesan (POST)'),
            ),

            const SizedBox(height: 20),

            if (isLoading || isSending)
              const Center(
                child: CircularProgressIndicator(),
              ),

            if (statusMessage.isNotEmpty)
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