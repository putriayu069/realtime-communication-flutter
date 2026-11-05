import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttPage extends StatefulWidget {
  const MqttPage({super.key});

  @override
  State<MqttPage> createState() => _MqttPageState();
}

class _MqttPageState extends State<MqttPage> {
  static const String broker = 'broker.hivemq.com';
  static const int port = 1883;
  static const String topic = 'kampus/demo/sensor01';

  final TextEditingController temperatureController =
      TextEditingController(text: '28.5');

  final String clientId =
      'flutter_${DateTime.now().millisecondsSinceEpoch}';

  MqttServerClient? client;
  StreamSubscription? messageSubscription;

  String selectedRole = 'subscriber';
  String connectionStatus = 'Belum terhubung';

  bool isConnected = false;
  bool isConnecting = false;

  double? latestTemperature;
  String latestTime = '-';

  final List<Map<String, String>> history = [];

  String get currentTime {
    final now = DateTime.now();

    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  // =====================================================
  // KONEKSI MQTT
  // =====================================================

  Future<void> connect() async {
    if (isConnected || isConnecting) return;

    setState(() {
      isConnecting = true;
      connectionStatus = 'Menghubungkan ke HiveMQ...';
    });

    final mqtt = MqttServerClient.withPort(
      broker,
      clientId,
      port,
    );

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
      debugPrint('Client ID: $clientId');

      final status = await mqtt.connect();

      debugPrint('Status MQTT: ${status?.state}');

      if (status?.state != MqttConnectionState.connected) {
        throw Exception(
          'Koneksi MQTT gagal: ${status?.state}',
        );
      }

      if (!mounted) {
        mqtt.disconnect();
        return;
      }

      client = mqtt;

      // Jika Subscriber, berlangganan ke topik.
      if (selectedRole == 'subscriber') {
        mqtt.subscribe(topic, MqttQos.atMostOnce);

        messageSubscription = mqtt.updates?.listen(
          (events) {
            for (final event in events) {
              final publish =
                  event.payload as MqttPublishMessage;

              final message =
                  MqttPublishPayload.bytesToStringAsString(
                publish.payload.message,
              );

              debugPrint('Pesan diterima: $message');

              receiveSensorData(message);
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
        connectionStatus = 'Terhubung ke broker MQTT';
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
  // MENERIMA DATA SENSOR
  // =====================================================

  void receiveSensorData(String message) {
    try {
      final data = jsonDecode(message);

      if (data is! Map) {
        throw const FormatException('Format data tidak valid');
      }

      final temperature =
          double.parse(data['temperature'].toString());

      final timestamp =
          data['timestamp']?.toString() ?? currentTime;

      if (!mounted) return;

      setState(() {
        latestTemperature = temperature;
        latestTime = timestamp;

        history.insert(0, {
          'temperature': temperature.toStringAsFixed(1),
          'time': currentTime,
        });

        if (history.length > 20) {
          history.removeLast();
        }

        connectionStatus = 'Data sensor berhasil diterima';
      });
    } catch (e) {
      debugPrint('Format pesan MQTT tidak valid: $e');

      if (!mounted) return;

      setState(() {
        connectionStatus = 'Format data tidak valid';
      });
    }
  }

  // =====================================================
  // MENGIRIM DATA SENSOR
  // =====================================================

  void publishSensorData() {
    if (!isConnected || client == null) {
      setState(() {
        connectionStatus =
            'Hubungkan ke broker terlebih dahulu';
      });
      return;
    }

    final temperature =
        double.tryParse(temperatureController.text.trim());

    if (temperature == null ||
        !temperature.isFinite ||
        temperature < -100 ||
        temperature > 200) {
      setState(() {
        connectionStatus = 'Masukkan nilai suhu yang valid';
      });
      return;
    }

    final sensorData = {
      'temperature': temperature,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(sensorData));

    try {
      final payload = builder.payload;

      if (payload == null) {
        throw Exception('Data sensor kosong');
      }

      client!.publishMessage(
        topic,
        MqttQos.atMostOnce,
        payload,
      );

      setState(() {
        connectionStatus =
            'Data suhu ${temperature.toStringAsFixed(1)} °C dikirim';
      });
    } catch (e) {
      setState(() {
        connectionStatus = 'Gagal mengirim data: $e';
      });
    }
  }

  // =====================================================
  // MEMUTUSKAN KONEKSI
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
  // MENGGANTI PERAN
  // =====================================================

  void changeRole(String? role) {
    if (role == null || role == selectedRole) return;

    setState(() {
      selectedRole = role;
      latestTemperature = null;
      latestTime = '-';
      history.clear();
      connectionStatus = 'Belum terhubung';
    });
  }

  @override
  void dispose() {
    messageSubscription?.cancel();
    client?.disconnect();
    temperatureController.dispose();
    super.dispose();
  }

  // =====================================================
  // TAMPILAN APLIKASI
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Praktikum 5 - MQTT'),
        backgroundColor:
            Theme.of(context).colorScheme.inversePrimary,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [
            const Text(
              'Monitoring Sensor IoT',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Komunikasi Publish - Subscribe menggunakan MQTT',
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 20),

            // INFORMASI BROKER

            Card(
              child: Padding(
                padding: const EdgeInsets.all(15),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const Text(
                      'Konfigurasi MQTT',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 12),

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

              onChanged:
                  isConnected || isConnecting
                      ? null
                      : changeRole,
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
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

                        Expanded(
                          child: Text(
                            connectionStatus,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                isConnected || isConnecting
                                    ? null
                                    : connect,

                            icon: const Icon(Icons.link),

                            label: Text(
                              isConnecting
                                  ? 'Menghubungkan'
                                  : 'Connect',
                            ),
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
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // BAGIAN PUBLISHER

            if (selectedRole == 'publisher') ...[
              const Text(
                'Client B - Publisher',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Masukkan nilai suhu sensor untuk dikirim ke broker MQTT.',
              ),

              const SizedBox(height: 15),

              TextField(
                controller: temperatureController,
                enabled: isConnected,

                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),

                decoration: const InputDecoration(
                  labelText: 'Nilai Suhu',
                  suffixText: '°C',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.thermostat),
                ),
              ),

              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed:
                    isConnected ? publishSensorData : null,

                icon: const Icon(Icons.send),

                label: const Text('Publish Data Sensor'),
              ),
            ],

            // BAGIAN SUBSCRIBER

            if (selectedRole == 'subscriber') ...[
              const Text(
                'Client A - Subscriber',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Card(
                color: Colors.green.withValues(alpha: 0.08),

                child: Padding(
                  padding: const EdgeInsets.all(20),

                  child: Column(
                    children: [
                      const Icon(
                        Icons.thermostat,
                        size: 42,
                        color: Colors.orange,
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Suhu Sensor Terakhir',
                        style: TextStyle(color: Colors.grey),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        latestTemperature == null
                            ? '-- °C'
                            : '${latestTemperature!.toStringAsFixed(1)} °C',

                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Diterima: $latestTime',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 15),

              const Text(
                'Riwayat Data Sensor',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),

                  child: history.isEmpty
                      ? const Text(
                          'Belum ada data sensor.\n'
                          'Menunggu pesan dari Publisher...',
                        )
                      : Column(
                          children: [
                            for (final item in history)
                              ListTile(
                                dense: true,

                                leading: const Icon(
                                  Icons.thermostat,
                                  color: Colors.orange,
                                ),

                                title: Text(
                                  '${item['temperature']} °C',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                trailing: Text(item['time']!),
                              ),
                          ],
                        ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            const Text(
              'Eksperimen Topik',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 5),

            const Text(
              'Topik utama: kampus/demo/sensor01\n'
              'Coba ubah topik pada kode untuk mengamati '
              'pemisahan pesan antar topik.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}