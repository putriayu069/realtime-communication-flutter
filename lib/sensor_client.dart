
import 'package:grpc/grpc.dart';
import 'package:realtime_communication/src/generated/sensor.pbgrpc.dart';
import 'package:realtime_communication/src/generated/sensor.pb.dart';

class SensorClient {
  late final ClientChannel channel;
  late final SensorServiceClient stub;

  // Menghubungkan client ke server gRPC
  SensorClient({String host = '192.168.1.5'}) {
    channel = ClientChannel(
      host,
      port: 50051,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );

    stub = SensorServiceClient(channel);
  }

  // Unary RPC: mengambil satu data sensor
  Future<SensorReading> getLatest(String deviceId) async {
    final request = SensorRequest()..deviceId = deviceId;
    return stub.getLatest(request);
  }

  // Server Streaming: menerima banyak data sensor
  Stream<SensorReading> watchSensor(String deviceId) {
    final request = SensorRequest()..deviceId = deviceId;
    return stub.watchSensor(request);
  }

  // Menutup koneksi gRPC
  Future<void> close() async {
    await channel.shutdown();
  }
}
