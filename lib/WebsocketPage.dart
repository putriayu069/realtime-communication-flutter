
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';

class WebSocketPage extends StatefulWidget {
  const WebSocketPage({super.key});

  @override
  State<WebSocketPage> createState() => _WebSocketPageState();
}

class _LogItem {
  final String pengirim;
  final String isi;
  final String waktu;

  _LogItem(this.pengirim, this.isi, this.waktu);
}

class _WebSocketPageState extends State<WebSocketPage> {
  final TextEditingController messageController =
      TextEditingController();

  WebSocketChannel? channel;
  StreamSubscription? subscription;

  final String clientId =
      'client-${DateTime.now().microsecondsSinceEpoch}';

  bool isConnected = false;
  bool isConnecting = false;
  bool showAutoData = false;

  final List<_LogItem> logs = [];
  String statusMessage = 'Belum terhubung';

  String _jam() {
    final now = DateTime.now();

    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  void addLog(String pengirim, String isi) {
    if (!mounted) return;

    setState(() {
      logs.insert(0, _LogItem(pengirim, isi, _jam()));

      if (logs.length > 30) {
        logs.removeLast();
      }
    });
  }

  // Menutup koneksi WebSocket
  void closeConnection() {
    subscription?.cancel();
    subscription = null;

    channel?.sink.close();
    channel = null;
  }

  // Menghubungkan aplikasi ke server WebSocket
  Future<void> connect() async {
    if (isConnected || isConnecting) return;

    setState(() {
      isConnecting = true;
      statusMessage = 'Menghubungkan ke $wsUrl ...';
    });

    try {
      channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      await channel!.ready;

      if (!mounted) {
        closeConnection();
        return;
      }

      setState(() {
        isConnecting = false;
        isConnected = true;
        statusMessage = 'Terhubung ke server sebagai $clientId';
      });

      addLog('Sistem', 'Berhasil terhubung ke server');

      subscription = channel!.stream.listen(
        handleMessage,
        onError: (error) {
          closeConnection();

          if (!mounted) return;

          setState(() {
            isConnected = false;
            isConnecting = false;
            statusMessage = 'WebSocket error: $error';
          });

          addLog('Sistem', 'Koneksi mengalami error');
        },
        onDone: () {
          closeConnection();

          if (!mounted) return;

          setState(() {
            isConnected = false;
            isConnecting = false;
            statusMessage = 'Koneksi WebSocket ditutup';
          });

          addLog('Sistem', 'Koneksi terputus');
        },
        cancelOnError: true,
      );
    } catch (e) {
      closeConnection();

      if (!mounted) return;

      setState(() {
        isConnecting = false;
        isConnected = false;
        statusMessage = 'Gagal terhubung: $e';
      });

      debugPrint('ERROR WS: $e');
    }
  }

  // Memutus koneksi
  void disconnect() {
    closeConnection();

    setState(() {
      isConnected = false;
      isConnecting = false;
      statusMessage = 'Koneksi diputus';
    });

    addLog('Sistem', 'Berhasil memutus koneksi');
  }

  // Mengirim pesan ke server untuk di-broadcast
  void sendMessage() {
    final message = messageController.text.trim();

    if (message.isEmpty) {
      setState(() {
        statusMessage = 'Pesan tidak boleh kosong';
      });
      return;
    }

    if (!isConnected || channel == null) {
      setState(() {
        statusMessage = 'Belum terhubung ke server';
      });
      return;
    }

    final chatData = {
      'clientId': clientId,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      channel!.sink.add(jsonEncode(chatData));
      messageController.clear();
    } catch (e) {
      setState(() {
        statusMessage = 'Gagal mengirim pesan: $e';
      });
    }
  }

  // Memproses pesan yang diterima dari server
  void handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message.toString());

      if (data is Map) {
        // Data otomatis dari server setiap 2 detik
        if (data.containsKey('counter')) {
          if (showAutoData) {
            addLog(
              'Server (data)',
              'Counter: ${data['counter']}, '
                  'Value: ${data['value']}',
            );
          }
          return;
        }

        // Pesan broadcast dari server
        if (data['type'] == 'chat') {
          final rawMessage = data['message'];
          String isiPesan = rawMessage.toString();
          String pengirim = 'Client lain';

          // Membaca detail pesan dari client
          try {
            final detail = jsonDecode(isiPesan);

            if (detail is Map) {
              isiPesan =
                  detail['message']?.toString() ?? isiPesan;

              if (detail['clientId'] == clientId) {
                pengirim = 'Saya';
              } else {
                pengirim =
                    detail['clientId']?.toString() ?? 'Client lain';
              }
            }
          } catch (_) {}

          addLog(pengirim, isiPesan);
          return;
        }

        // Mendukung balasan echo dari server lama
        if (data['type'] == 'echo') {
          addLog(
            'Server (echo)',
            extractText(data['message']),
          );
          return;
        }
      }

      addLog('Server', message.toString());
    } catch (_) {
      addLog('Server', message.toString());
    }
  }

  // Mengambil isi pesan dari JSON
  String extractText(dynamic message) {
    if (message is String) {
      try {
        final inner = jsonDecode(message);

        if (inner is Map && inner['message'] != null) {
          return inner['message'].toString();
        }
      } catch (_) {}
    }

    return message.toString();
  }

  @override
  void dispose() {
    closeConnection();
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Praktikum 4 - WebSocket'),
        backgroundColor:
            Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Komunikasi Dua Arah (WebSocket)',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'ID Client: $clientId',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        (isConnected || isConnecting)
                            ? null
                            : connect,
                    icon: const Icon(Icons.link),
                    label: const Text('Connect'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        isConnected ? disconnect : null,
                    icon: const Icon(Icons.link_off),
                    label: const Text('Disconnect'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Tampilkan data otomatis dari server',
              ),
              value: showAutoData,
              onChanged: (value) {
                setState(() {
                  showAutoData = value;
                });
              },
            ),

            const SizedBox(height: 8),

            TextField(
              controller: messageController,
              enabled: isConnected,
              onSubmitted: (_) => sendMessage(),
              decoration: const InputDecoration(
                labelText: 'Masukkan pesan',
                hintText: 'Contoh: Halo dari Flutter',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: isConnected ? sendMessage : null,
              icon: const Icon(Icons.send),
              label: const Text('Kirim Pesan'),
            ),

            const SizedBox(height: 20),

            const Text(
              'Pesan',
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
                    ? const Text('Belum ada pesan')
                    : Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          for (final log in logs)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(
                                vertical: 3,
                              ),
                              child: Text(
                                '[${log.waktu}] '
                                '${log.pengirim}: ${log.isi}',
                              ),
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
