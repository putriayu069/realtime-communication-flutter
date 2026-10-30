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

  late MqttServerClient client;
  StreamSubscription? updatesSubscription;

  bool isConnected = false;
  bool isSubscribed = false;
  bool isConnecting = false;

  String connectionStatus = 'Belum terhubung';
  String receivedMessage = '-';
  String receivedTopic = '-';

  final TextEditingController topicController =
      TextEditingController(text: 'kampus/demo/sensor01');

  final TextEditingController temperatureController =
      TextEditingController(text: '28.5');

  // Menghubungkan aplikasi ke broker MQTT
  Future<void> connectMqtt() async {
    if (isConnecting || isConnected) return;

    setState(() {
      isConnecting = true;
      connectionStatus = 'Sedang menghubungkan...';
    });

    final clientId =
        'flutter_client_${DateTime.now().millisecondsSinceEpoch}';

    client = MqttServerClient.withPort(
      broker,
      clientId,
      1883,
    );

    client.logging(on: false);
    client.keepAlivePeriod = 20;

    client.onConnected = () {
      if (!mounted) return;

      setState(() {
        isConnected = true;
        isConnecting = false;
        connectionStatus = 'Berhasil terhubung ke broker';
      });
    };

    client.onDisconnected = () {
      if (!mounted) return;

      setState(() {
        isConnected = false;
        isSubscribed = false;
        isConnecting = false;
        connectionStatus = 'Terputus dari broker';
      });
    };

    try {
      await client.connect();

      if (client.connectionStatus?.state ==
          MqttConnectionState.connected) {
        if (!mounted) return;

        setState(() {
          isConnected = true;
          isConnecting = false;
          connectionStatus = 'Berhasil terhubung ke broker';
        });
      } else {
        client.disconnect();

        if (!mounted) return;

        setState(() {
          isConnected = false;
          isConnecting = false;
          connectionStatus = 'Gagal terhubung ke broker';
        });
      }
    } catch (e) {
      client.disconnect();

      if (!mounted) return;

      setState(() {
        isConnected = false;
        isConnecting = false;
        connectionStatus = 'Koneksi gagal: $e';
      });

      debugPrint('Koneksi MQTT gagal: $e');
    }
  }

  // Subscribe dan menerima pesan dari topik
  void subscribeMqtt() {
    if (!isConnected || isSubscribed) return;

    final selectedTopic = topicController.text.trim();

    if (selectedTopic.isEmpty) {
      setState(() {
        connectionStatus = 'Topik tidak boleh kosong';
      });
      return;
    }

    client.subscribe(selectedTopic, MqttQos.atMostOnce);

    updatesSubscription?.cancel();

    updatesSubscription = client.updates?.listen((messages) {
      for (final message in messages) {
        final received = message.payload as MqttPublishMessage;

        final payload = MqttPublishPayload.bytesToStringAsString(
          received.payload.message,
        );

        if (!mounted) return;

        setState(() {
          receivedTopic = message.topic;
          receivedMessage = payload;
        });
      }
    });

    setState(() {
      isSubscribed = true;
      connectionStatus = 'Subscribe ke topik: $selectedTopic';
    });
  }

  // Mengirim data sensor ke broker
  void publishMqtt() {
    if (!isConnected) return;

    final selectedTopic = topicController.text.trim();
    final temperature =
        double.tryParse(temperatureController.text.trim());

    if (selectedTopic.isEmpty) {
      setState(() {
        connectionStatus = 'Topik tidak boleh kosong';
      });
      return;
    }

    if (temperature == null) {
      setState(() {
        connectionStatus = 'Masukkan nilai suhu yang valid';
      });
      return;
    }

    final data = {
      'temperature': temperature,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(data));

    final payload = builder.payload;

    if (payload == null) return;

    client.publishMessage(
      selectedTopic,
      MqttQos.atMostOnce,
      payload,
    );

    setState(() {
      connectionStatus = 'Data berhasil dikirim ke $selectedTopic';
    });
  }

  // Memutuskan koneksi MQTT
  void disconnectMqtt() {
    updatesSubscription?.cancel();
    updatesSubscription = null;

    if (isConnected || isConnecting) {
      client.disconnect();
    }

    setState(() {
      isConnected = false;
      isConnecting = false;
      isSubscribed = false;
      connectionStatus = 'Terputus dari broker';
    });
  }

  @override
  void dispose() {
    updatesSubscription?.cancel();

    if (isConnected || isConnecting) {
      client.disconnect();
    }

    topicController.dispose();
    temperatureController.dispose();

    super.dispose();
  }

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
              'A. Koneksi MQTT',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Broker: $broker'),
                    const SizedBox(height: 8),
                    Text('Status: $connectionStatus'),
                  ],
                ),
              ),
            ),

            ElevatedButton.icon(
              onPressed:
                  (isConnected || isConnecting) ? null : connectMqtt,
              icon: const Icon(Icons.wifi),
              label: Text(
                isConnecting ? 'Menghubungkan...' : 'Connect MQTT',
              ),
            ),

            ElevatedButton.icon(
              onPressed: isConnected ? disconnectMqtt : null,
              icon: const Icon(Icons.wifi_off),
              label: const Text('Disconnect MQTT'),
            ),

            const SizedBox(height: 25),

            const Text(
              'B. Pengaturan Topik',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: topicController,
              decoration: const InputDecoration(
                labelText: 'Topik MQTT',
                hintText: 'kampus/demo/sensor01',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.topic),
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'C. Client A - Subscribe',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed:
                  (isConnected && !isSubscribed) ? subscribeMqtt : null,
              icon: const Icon(Icons.notifications_active),
              label: const Text('Subscribe Topik'),
            ),

            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Data Diterima',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Topik: $receivedTopic'),
                    const SizedBox(height: 8),
                    Text('Pesan: $receivedMessage'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'D. Client B - Publish',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: temperatureController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Suhu Sensor (°C)',
                hintText: 'Contoh: 28.5',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.thermostat),
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: isConnected ? publishMqtt : null,
              icon: const Icon(Icons.send),
              label: const Text('Publish Data Sensor'),
            ),

            const SizedBox(height: 15),

            const Text(
              'Client A menerima pesan dari topik yang sama '
              'dengan topik yang digunakan Client B untuk mengirim data.',
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