
import '../lib/sensor_client.dart';

Future<void> main() async {
  final client = SensorClient(host: 'localhost');

  try {
    print('Memulai streaming data sensor...');

    await for (final result in client.watchSensor('sensor-01')) {
      print('Device ID: ${result.deviceId}');
      print('Nilai: ${result.value}');
      print('Timestamp: ${result.timestamp}');
      print('--------------------------');
    }

    print('Streaming selesai!');
  } catch (e) {
    print('Terjadi error: $e');
  } finally {
    await client.close();
  }
}
