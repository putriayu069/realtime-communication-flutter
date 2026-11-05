

import 'package:grpc/grpc.dart';

import 'src/generated/sensor.pb.dart';
import 'src/generated/sensor.pbgrpc.dart';

class SensorClient {
  late ClientChannel _channel;
  late SensorServiceClient _stub;

  SensorClient({required String host}) {
    _channel = ClientChannel(
      host,
      port: 50051,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );

    _stub = SensorServiceClient(_channel);
  }

  // Mengambil satu data sensor
  Future<SensorReading> getLatest(String deviceId) {
    final request = SensorRequest()
      ..deviceId = deviceId;

    return _stub.getLatest(request);
  }

  // Menerima data sensor secara streaming
  Stream<SensorReading> watchSensor(String deviceId) {
    final request = SensorRequest()
      ..deviceId = deviceId;

    return _stub.watchSensor(request);
  }

  // Menutup koneksi
  Future<void> close() async {
    await _channel.shutdown();
  }
}
