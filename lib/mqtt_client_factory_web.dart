
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

MqttClient createMqttClient(String clientId) {
  final client = MqttBrowserClient(
    'wss://broker.hivemq.com/mqtt',
    clientId,
  );

  client.port = 8884;
  client.keepAlivePeriod = 20;
  client.connectTimeoutPeriod = 15000;

  client.websocketProtocols =
      MqttClientConstants.protocolsSingleDefault;

  return client;
}
