// Pengaturan bersama untuk semua halaman praktikum.
// Ganti di sini saja jika alamat server berubah.
//
// - Server praktikum : https://praktikum.mqtt.my.id
// - Server sendiri   : http://localhost:3000 (web/desktop)
//                      http://10.0.2.2:3000 (emulator Android)
const String baseUrl = 'http://192.168.1.5:3000';

// Alamat WebSocket otomatis mengikuti baseUrl:
// http  -> ws
// https -> wss
String get wsUrl => baseUrl.replaceFirst('http', 'ws');