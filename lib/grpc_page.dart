
import 'dart:async';

import 'package:flutter/material.dart';

import 'sensor_client.dart';
import 'src/generated/sensor.pb.dart';

class GrpcPage extends StatefulWidget {
  const GrpcPage({super.key});

  @override
  State<GrpcPage> createState() => _GrpcPageState();
}

class _GrpcPageState extends State<GrpcPage> {
  // IP laptop yang menjalankan server gRPC.
  static const String host = '192.168.1.5';

  late SensorClient client;
  StreamSubscription<SensorReading>? subscription;

  bool isConnected = false;
  bool isStreaming = false;
  bool isLoading = false;

  String status = 'Belum terhubung';

  int sensorCounter = 1;
  String currentSensorId = 'sensor-01';

  SensorReading? latestReading;
  final List<SensorReading> history = [];

  @override
  void initState() {
    super.initState();
    client = SensorClient(host: host);
  }

  // Menghubungkan aplikasi ke server.
  Future<void> connectServer() async {
    setState(() {
      isLoading = true;
      status = 'Menghubungkan...';
    });

    try {
      final result = await client.getLatest(currentSensorId);

      if (!mounted) return;

      setState(() {
        isConnected = true;
        isLoading = false;
        status = 'Terhubung';
        latestReading = result;
        history.insert(0, result);
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isConnected = false;
        isLoading = false;
        status = 'Koneksi gagal';
      });
    }
  }

  // Memulai penerimaan data streaming.
  void startStreaming() {
    if (!isConnected || isStreaming) return;

    setState(() {
      sensorCounter++;

      currentSensorId =
          'sensor-${sensorCounter.toString().padLeft(2, '0')}';

      isStreaming = true;
      status = 'Streaming aktif';
    });

    subscription = client.watchSensor(currentSensorId).listen(
      (result) {
        if (!mounted) return;

        setState(() {
          latestReading = result;
          history.insert(0, result);
        });
      },
      onError: (error) {
        if (!mounted) return;

        setState(() {
          isStreaming = false;
          status = 'Streaming error';
        });
      },
      onDone: () {
        if (!mounted) return;

        setState(() {
          isStreaming = false;
          status = 'Streaming selesai';
        });
      },
    );
  }

  // Menghentikan streaming.
  Future<void> stopStreaming() async {
    await subscription?.cancel();
    subscription = null;

    if (!mounted) return;

    setState(() {
      isStreaming = false;
      status = 'Streaming dihentikan';
    });
  }

  // Memutus koneksi.
  Future<void> disconnectServer() async {
    await stopStreaming();
    await client.close();

    if (!mounted) return;

    setState(() {
      isConnected = false;
      status = 'Terputus';
      latestReading = null;
      history.clear();
    });

    client = SensorClient(host: host);
  }

  // Mengubah timestamp menjadi waktu lokal.
  String formatTimestamp(SensorReading reading) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      reading.timestamp.toInt(),
    );

    return date.toLocal().toString().substring(0, 19);
  }

  @override
  void dispose() {
    subscription?.cancel();
    client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'gRPC Sensor Monitor',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status koneksi.
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.circle,
                  color: isConnected ? Colors.green : Colors.red,
                  size: 14,
                ),
                title: const Text('Status Koneksi'),
                subtitle: Text(status),
              ),
            ),

            const SizedBox(height: 20),

            // Tombol koneksi.
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: isConnected || isLoading
                      ? null
                      : connectServer,
                  icon: const Icon(Icons.link),
                  label: const Text('Connect'),
                ),

                ElevatedButton.icon(
                  onPressed: isConnected && !isStreaming
                      ? startStreaming
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Streaming'),
                ),

                ElevatedButton.icon(
                  onPressed: isStreaming
                      ? stopStreaming
                      : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),

                OutlinedButton.icon(
                  onPressed: isConnected
                      ? disconnectServer
                      : null,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect'),
                ),
              ],
            ),

            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),

            const SizedBox(height: 24),

            const Text(
              'Data Sensor Terbaru',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            // Data sensor terbaru.
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Device ID'),
                    Text(
                      latestReading?.deviceId ?? '-',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text('Nilai Sensor'),
                    Text(
                      latestReading == null
                          ? '-'
                          : '${latestReading!.value.toStringAsFixed(1)} °C',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text('Timestamp'),
                    Text(
                      latestReading == null
                          ? '-'
                          : formatTimestamp(latestReading!),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Riwayat streaming.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Riwayat Streaming',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('${history.length} data'),
              ],
            ),

            const SizedBox(height: 12),

            if (history.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Belum ada data sensor'),
                ),
              ),

            ...history.asMap().entries.map((entry) {
              final index = entry.key;
              final reading = entry.value;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${history.length - index}'),
                  ),
                  title: Text(
                    '${reading.value.toStringAsFixed(1)} °C',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${reading.deviceId}\n${formatTimestamp(reading)}',
                  ),
                  isThreeLine: true,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
