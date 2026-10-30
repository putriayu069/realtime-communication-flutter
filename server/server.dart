
import 'dart:io';
import 'dart:async';

import 'package:grpc/grpc.dart';
import '../lib/src/generated/sensor.pbgrpc.dart';
import '../lib/src/generated/sensor.pb.dart';
import 'package:fixnum/fixnum.dart';

class SensorService extends SensorServiceBase {
  // Unary RPC: mengirim satu data sensor
  @override
  Future<SensorReading> getLatest(
    ServiceCall call,
    SensorRequest request,
  ) async {
    print('Permintaan data terbaru dari: ${request.deviceId}');

    return SensorReading(
      deviceId: request.deviceId,
      value: 28.5,
      timestamp: Int64(DateTime.now().millisecondsSinceEpoch),
    );
  }

  // Server Streaming: mengirim data sensor berkali-kali
  @override
  Stream<SensorReading> watchSensor(
    ServiceCall call,
    SensorRequest request,
  ) async* {
    print('Memulai streaming sensor: ${request.deviceId}');

    for (int i = 0; i < 10; i++) {
      yield SensorReading(
        deviceId: request.deviceId,
        value: 25 + i.toDouble(),
        timestamp: Int64(DateTime.now().millisecondsSinceEpoch),
      );

      await Future.delayed(const Duration(seconds: 2));
    }
  }
}

Future<void> main() async {
  final server = Server([SensorService()]);

  await server.serve(
    address: InternetAddress.anyIPv4,
    port: 50051,
  );

  print('Server gRPC berjalan di port 50051');
}
