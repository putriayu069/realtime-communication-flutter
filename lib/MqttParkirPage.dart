import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttParkirPage extends StatefulWidget {
  const MqttParkirPage({super.key});

  @override
  State<MqttParkirPage> createState() => _MqttParkirPageState();
}

class _MqttParkirPageState extends State<MqttParkirPage> {
  static const String broker = 'broker.hivemq.com';
  static const int port = 1883;
  static const String topic = 'kampus/demo/parkir';

  final String clientId = 'parkir_${DateTime.now().microsecondsSinceEpoch}';

  final List<String> slotNames = ['A1', 'A2', 'A3', 'B1', 'B2', 'B3'];

  // false = kosong, true = terisi
  Map<String, bool> parkingSlots = {
    'A1': false,
    'A2': false,
    'A3': false,
    'B1': false,
    'B2': false,
    'B3': false,
  };

  MqttServerClient? client;
  StreamSubscription? messageSubscription;

  String selectedRole = 'subscriber';
  String connectionStatus = 'Belum terhubung';
  String lastUpdate = '-';

  bool isConnected = false;
  bool isConnecting = false;
  bool hasReceivedData = false;

  String get currentTime {
    final now = DateTime.now();

    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  int get occupiedCount => parkingSlots.values.where((value) => value).length;

  int get emptyCount => parkingSlots.length - occupiedCount;

  // =====================================================
  // KONEKSI MQTT
  // =====================================================

  Future<void> connect() async {
    if (isConnected || isConnecting) return;

    setState(() {
      isConnecting = true;
      connectionStatus = 'Menghubungkan ke broker MQTT...';
    });

    final mqtt = MqttServerClient.withPort(broker, clientId, port);

    mqtt.logging(on: true);
    mqtt.keepAlivePeriod = 30;
    mqtt.connectTimeoutPeriod = 30000;
    mqtt.setProtocolV311();

    mqtt.onConnected = () {
      debugPrint('MQTT BERHASIL TERHUBUNG');
    };

    mqtt.onDisconnected = () {
      debugPrint('MQTT TERPUTUS');

      if (!mounted) return;

      setState(() {
        isConnected = false;
        connectionStatus = 'Koneksi MQTT terputus';
      });
    };

    mqtt.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);

    try {
      debugPrint('Menghubungkan ke $broker:$port');

      final status = await mqtt.connect();

      debugPrint('Status MQTT: ${status?.state}');

      if (status?.state != MqttConnectionState.connected) {
        throw Exception('Koneksi gagal: ${status?.state}');
      }

      if (!mounted) {
        mqtt.disconnect();
        return;
      }

      client = mqtt;

      // SUBSCRIBER menerima data parkir.
      if (selectedRole == 'subscriber') {
        mqtt.subscribe(topic, MqttQos.atMostOnce);

        messageSubscription = mqtt.updates?.listen(
          (events) {
            for (final event in events) {
              final publish = event.payload as MqttPublishMessage;

              final message = MqttPublishPayload.bytesToStringAsString(
                publish.payload.message,
              );

              debugPrint('Data parkir diterima: $message');

              receiveParkingData(message);
            }
          },
          onError: (error) {
            if (!mounted) return;

            setState(() {
              connectionStatus = 'Gagal menerima data: $error';
            });
          },
        );
      }

      setState(() {
        isConnected = true;
        isConnecting = false;

        connectionStatus = selectedRole == 'subscriber'
            ? 'Terhubung - Menunggu data parkir'
            : 'Terhubung - Siap mengirim data parkir';
      });
    } catch (e) {
      debugPrint('ERROR MQTT: $e');

      mqtt.disconnect();

      if (!mounted) return;

      setState(() {
        client = null;
        isConnected = false;
        isConnecting = false;
        connectionStatus = 'Koneksi gagal: $e';
      });
    }
  }

  // =====================================================
  // PUBLISHER: MENGUBAH STATUS SLOT
  // =====================================================

  void changeSlotStatus(String slot, bool value) {
    setState(() {
      parkingSlots[slot] = value;
      connectionStatus = 'Status $slot diubah. Tekan Kirim Data Parkir.';
    });
  }

  // =====================================================
  // PUBLISHER: MENGIRIM DATA KE BROKER
  // =====================================================

  void publishParkingData() {
    if (!isConnected || client == null) {
      setState(() {
        connectionStatus = 'Hubungkan ke broker terlebih dahulu';
      });
      return;
    }

    final data = {
      'slots': parkingSlots,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(data));

    try {
      final payload = builder.payload;

      if (payload == null) {
        throw Exception('Data parkir kosong');
      }

      client!.publishMessage(topic, MqttQos.atMostOnce, payload);

      setState(() {
        lastUpdate = currentTime;
        connectionStatus = 'Data parkir berhasil dikirim';
      });

      debugPrint('Data parkir dikirim: ${jsonEncode(data)}');
    } catch (e) {
      setState(() {
        connectionStatus = 'Gagal mengirim data: $e';
      });
    }
  }

  // =====================================================
  // SUBSCRIBER: MENERIMA DATA DARI BROKER
  // =====================================================

  void receiveParkingData(String message) {
    try {
      final data = jsonDecode(message);

      if (data is! Map || data['slots'] is! Map) {
        throw const FormatException('Format data parkir tidak valid');
      }

      final receivedSlots = data['slots'] as Map;

      final updatedSlots = <String, bool>{};

      for (final slot in slotNames) {
        final value = receivedSlots[slot];

        if (value is! bool) {
          throw FormatException('Status slot $slot tidak valid');
        }

        updatedSlots[slot] = value;
      }

      if (!mounted) return;

      setState(() {
        parkingSlots = updatedSlots;
        hasReceivedData = true;
        lastUpdate = currentTime;
        connectionStatus = 'Data parkir berhasil diterima';
      });
    } catch (e) {
      debugPrint('ERROR DATA PARKIR: $e');

      if (!mounted) return;

      setState(() {
        connectionStatus = 'Format data tidak valid';
      });
    }
  }

  // =====================================================
  // DISCONNECT
  // =====================================================

  Future<void> disconnect() async {
    await messageSubscription?.cancel();
    messageSubscription = null;

    client?.disconnect();
    client = null;

    if (!mounted) return;

    setState(() {
      isConnected = false;
      isConnecting = false;
      connectionStatus = 'Koneksi diputus';
    });
  }

  // =====================================================
  // GANTI PERAN
  // =====================================================

  void changeRole(String? role) {
    if (role == null || role == selectedRole) return;

    setState(() {
      selectedRole = role;
      hasReceivedData = false;
      lastUpdate = '-';
      connectionStatus = 'Belum terhubung';
    });
  }

  @override
  void dispose() {
    messageSubscription?.cancel();
    client?.disconnect();
    super.dispose();
  }

  // =====================================================
  // TAMPILAN KARTU SLOT
  // =====================================================

  Widget buildSlotCard(String slot) {
    final isOccupied = parkingSlots[slot] ?? false;

    return Card(
      color: isOccupied
          ? Colors.red.withValues(alpha: 0.10)
          : Colors.green.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_parking,
              size: 32,
              color: isOccupied ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 8),
            Text(
              'Slot $slot',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 5),
            Text(
              isOccupied ? 'TERISI' : 'KOSONG',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isOccupied ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // TAMPILAN APLIKASI
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Praktikum 5 - MQTT Parkir'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [
            const Text(
              'Monitoring Slot Parkir IoT',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 5),

            const Text(
              'Monitoring status parkir menggunakan komunikasi MQTT.',
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 18),

            // KONFIGURASI MQTT
            Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Konfigurasi MQTT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('Broker: $broker'),
                    const Text('Port: $port'),
                    const Text('Topic: $topic'),
                    Text('Client ID: $clientId'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 15),

            // PILIH PERAN
            const Text(
              'Pilih Peran Perangkat',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              value: selectedRole,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Peran MQTT',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'subscriber',
                  child: Text('Client A - Subscriber'),
                ),
                DropdownMenuItem(
                  value: 'publisher',
                  child: Text('Client B - Publisher'),
                ),
              ],
              onChanged: isConnected || isConnecting ? null : changeRole,
            ),

            const SizedBox(height: 15),

            // STATUS KONEKSI
            Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status Koneksi',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          isConnected
                              ? Icons.check_circle
                              : isConnecting
                              ? Icons.sync
                              : Icons.error_outline,
                          color: isConnected
                              ? Colors.green
                              : isConnecting
                              ? Colors.orange
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(connectionStatus)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isConnected || isConnecting
                                ? null
                                : connect,
                            icon: const Icon(Icons.link),
                            label: Text(
                              isConnecting ? 'Menghubungkan' : 'Connect',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isConnected ? disconnect : null,
                            icon: const Icon(Icons.link_off),
                            label: const Text('Disconnect'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // RINGKASAN SLOT
            const Text(
              'Ringkasan Area Parkir',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.green.withValues(alpha: 0.10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(height: 5),
                          const Text('Kosong'),
                          Text(
                            '$emptyCount Slot',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    color: Colors.red.withValues(alpha: 0.10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Icon(Icons.directions_car, color: Colors.red),
                          const SizedBox(height: 5),
                          const Text('Terisi'),
                          Text(
                            '$occupiedCount Slot',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            // TAMPILAN SUBSCRIBER
            if (selectedRole == 'subscriber') ...[
              const Text(
                'Client A - Subscriber',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 5),

              Text(
                hasReceivedData
                    ? 'Data terakhir diterima: $lastUpdate'
                    : 'Menunggu data dari Publisher...',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),

              const SizedBox(height: 12),

              if (!hasReceivedData)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'Belum ada data parkir.\n'
                      'Hubungkan Subscriber, lalu kirim data '
                      'dari HP Publisher.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: slotNames.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.25,
                ),
                itemBuilder: (context, index) {
                  return buildSlotCard(slotNames[index]);
                },
              ),
            ],

            // TAMPILAN PUBLISHER
            if (selectedRole == 'publisher') ...[
              const Text(
                'Client B - Publisher',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 5),

              const Text(
                'Ubah status slot parkir, kemudian kirim '
                'perubahannya ke Subscriber.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),

              const SizedBox(height: 12),

              for (final slot in slotNames)
                Card(
                  child: SwitchListTile(
                    title: Text(
                      'Slot $slot',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(parkingSlots[slot]! ? 'Terisi' : 'Kosong'),
                    secondary: Icon(
                      Icons.local_parking,
                      color: parkingSlots[slot]! ? Colors.red : Colors.green,
                    ),
                    value: parkingSlots[slot]!,
                    activeColor: Colors.red,
                    onChanged: isConnected
                        ? (value) {
                            changeSlotStatus(slot, value);
                          }
                        : null,
                  ),
                ),

              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: isConnected ? publishParkingData : null,
                icon: const Icon(Icons.send),
                label: const Text('Kirim Data Parkir'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(14),
                ),
              ),
            ],

            const SizedBox(height: 15),

            // KETERANGAN
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Keterangan',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.circle, size: 12, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Hijau = Slot kosong'),
                      ],
                    ),
                    SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.circle, size: 12, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Merah = Slot terisi'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
