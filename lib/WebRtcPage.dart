
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebRtcPage extends StatefulWidget {
  const WebRtcPage({super.key});

  @override
  State<WebRtcPage> createState() => _WebRtcPageState();
}

class _WebRtcPageState extends State<WebRtcPage> {
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  late Future<void> rendererReady;

  final TextEditingController serverController =
      TextEditingController(text: 'ws://192.168.1.5:3001');

  final TextEditingController roomController =
      TextEditingController(text: 'praktikum-webrtc');

  WebSocketChannel? signalingChannel;
  StreamSubscription? signalingSubscription;

  RTCPeerConnection? peerConnection;
  MediaStream? localStream;

  final List<RTCIceCandidate> pendingCandidates = [];

  bool isConnected = false;
  bool isCalling = false;

  String status = 'Belum terhubung';

  @override
  void initState() {
    super.initState();
    rendererReady = initializeRenderers();
  }

  // Menyiapkan tampilan video
  Future<void> initializeRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  // Membuat koneksi peer-to-peer
  Future<void> createPeerConnectionHandler() async {
    final configuration = {
      'iceServers': [
        {
          'urls': 'stun:stun.l.google.com:19302',
        },
      ],
    };

    peerConnection = await createPeerConnection(configuration);
  peerConnection!.onIceConnectionState = (state) {
  debugPrint('ICE CONNECTION STATE: $state');
};

peerConnection!.onConnectionState = (state) {
  debugPrint('PEER CONNECTION STATE: $state');
};
    // Mengirim ICE candidate ke signaling server
    peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        sendSignal({
          'type': 'candidate',
          'candidate': candidate.toMap(),
        });
      }
    };

    // Menampilkan video dari perangkat lain
   peerConnection!.onTrack = (event) async {
  debugPrint('Remote track: ${event.track.kind}');
  debugPrint('Track enabled: ${event.track.enabled}');
  debugPrint('Track muted: ${event.track.muted}');
  debugPrint('Jumlah stream: ${event.streams.length}');
  debugPrint('Track kind: ${event.track.kind}');
debugPrint('Track enabled: ${event.track.enabled}');
debugPrint('Track muted: ${event.track.muted}');
debugPrint('Track ID: ${event.track.id}');
debugPrint('Stream ID: ${event.streams.first.id}');
debugPrint('=== REMOTE STREAM DITERIMA ===');
debugPrint('Video track: ${event.streams[0].getVideoTracks().length}');
debugPrint('Audio track: ${event.streams[0].getAudioTracks().length}');
debugPrint('Renderer source: ${remoteRenderer.srcObject != null}');

  if (event.streams.isNotEmpty) {
    remoteRenderer.srcObject = event.streams[0];

    debugPrint(
      'Remote video renderer: ${remoteRenderer.videoWidth} x ${remoteRenderer.videoHeight}',
    );

    if (mounted) {
      setState(() {
        status = 'Video remote diterima';
      });
    }
  }
};

    // Menambahkan kamera dan mikrofon lokal
    for (final track in localStream!.getTracks()) {
      await peerConnection!.addTrack(track, localStream!);
    }
  }

  // Mengirim pesan signaling
  void sendSignal(Map<String, dynamic> data) {
    signalingChannel?.sink.add(jsonEncode(data));
  }

  // Memulai kamera, mikrofon, dan signaling
  Future<void> startCall() async {
    if (isCalling) return;

    try {
      setState(() {
        status = 'Memulai kamera dan mikrofon...';
      });

      await rendererReady;

      final serverUrl = serverController.text.trim();
      final room = roomController.text.trim();

      if (serverUrl.isEmpty || room.isEmpty) {
        throw Exception('Alamat server dan room harus diisi');
      }

      localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': 640,
          'height': 480,
        },
      });

      localRenderer.srcObject = localStream;

      for (final track in localStream!.getVideoTracks()) {
  debugPrint('=== VIDEO LOKAL HP ===');
  debugPrint('Enabled: ${track.enabled}');
  debugPrint('Muted: ${track.muted}');
  debugPrint('ID: ${track.id}');
}

      await createPeerConnectionHandler();

      signalingChannel =
          WebSocketChannel.connect(Uri.parse(serverUrl));

      await signalingChannel!.ready;

      signalingSubscription =
          signalingChannel!.stream.listen(
        (message) async {
          try {
            await handleSignal(jsonDecode(message));
          } catch (e) {
            debugPrint('Gagal memproses signaling: $e');
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              status = 'Signaling error: $error';
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              isConnected = false;
              status = 'Signaling terputus';
            });
          }
        },
      );

      sendSignal({
        'type': 'join',
        'room': room,
      });

      setState(() {
        isCalling = true;
        isConnected = true;
        status = 'Menunggu perangkat lain...';
      });
    } catch (e) {
      debugPrint('WebRTC error: $e');

      if (mounted) {
        setState(() {
          status = 'Gagal memulai: $e';
        });
      }

      await endCall();
    }
  }

  // Mengolah pesan dari signaling server
  Future<void> handleSignal(dynamic message) async {
    final data = Map<String, dynamic>.from(message);

    switch (data['type']) {
      case 'joined':
        if (mounted) {
          setState(() {
            status = 'Berhasil masuk room. Menunggu peer...';
          });
        }
        break;

      case 'peer-joined':
        await createOffer();
        break;

      case 'offer':
        await receiveOffer(data);
        break;

      case 'answer':
        await receiveAnswer(data);
        break;

      case 'candidate':
        await receiveCandidate(data);
        break;

      case 'peer-left':
        if (mounted) {
          setState(() {
            status = 'Perangkat lain telah keluar';
          });
        }
        break;
    }
  }

  // Membuat SDP offer
  Future<void> createOffer() async {
    final offer = await peerConnection!.createOffer();

    await peerConnection!.setLocalDescription(offer);

    sendSignal({
      'type': 'offer',
      'sdp': offer.sdp,
      'sdpType': offer.type,
    });

    if (mounted) {
      setState(() {
        status = 'Offer dikirim, menunggu answer...';
      });
    }
  }

  // Menerima offer dan membuat SDP answer
  Future<void> receiveOffer(Map<String, dynamic> data) async {
    final offer = RTCSessionDescription(
      data['sdp'],
      data['sdpType'],
    );

    await peerConnection!.setRemoteDescription(offer);

    final answer = await peerConnection!.createAnswer();

    await peerConnection!.setLocalDescription(answer);

    sendSignal({
      'type': 'answer',
      'sdp': answer.sdp,
      'sdpType': answer.type,
    });

    await addPendingCandidates();
  }

  // Menerima SDP answer
  Future<void> receiveAnswer(Map<String, dynamic> data) async {
    final answer = RTCSessionDescription(
      data['sdp'],
      data['sdpType'],
    );

    await peerConnection!.setRemoteDescription(answer);

    await addPendingCandidates();

    if (mounted) {
      setState(() {
        status = 'SDP berhasil dipertukarkan';
      });
    }
  }

  // Menerima ICE candidate
  Future<void> receiveCandidate(Map<String, dynamic> data) async {
    final candidateData =
        Map<String, dynamic>.from(data['candidate']);

    final candidate = RTCIceCandidate(
      candidateData['candidate'],
      candidateData['sdpMid'],
      candidateData['sdpMLineIndex'],
    );

    final description =
        await peerConnection!.getRemoteDescription();

    if (description == null) {
      pendingCandidates.add(candidate);
    } else {
      await peerConnection!.addCandidate(candidate);
    }
  }

  // Menambahkan ICE candidate yang sempat menunggu
  Future<void> addPendingCandidates() async {
    for (final candidate in pendingCandidates) {
      await peerConnection!.addCandidate(candidate);
    }

    pendingCandidates.clear();
  }

  // Mengakhiri panggilan
  Future<void> endCall() async {
    await signalingSubscription?.cancel();
    signalingSubscription = null;

    await signalingChannel?.sink.close();
    signalingChannel = null;

    await peerConnection?.close();
    peerConnection = null;

    await localStream?.dispose();
    localStream = null;

    remoteRenderer.srcObject = null;
    localRenderer.srcObject = null;

    pendingCandidates.clear();

    if (mounted) {
      setState(() {
        isConnected = false;
        isCalling = false;
        status = 'Panggilan diakhiri';
      });
    }
  }

  @override
  void dispose() {
    signalingSubscription?.cancel();
    signalingChannel?.sink.close();
    peerConnection?.close();
    localStream?.dispose();

    localRenderer.dispose();
    remoteRenderer.dispose();

    serverController.dispose();
    roomController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Praktikum 6 - WebRTC'),
        backgroundColor:
            Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'A. Pengaturan Signaling',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: serverController,
              decoration: const InputDecoration(
                labelText: 'Alamat Signaling Server',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: roomController,
              decoration: const InputDecoration(
                labelText: 'Nama Room',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            Text('Status: $status'),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: isCalling ? null : startCall,
              icon: const Icon(Icons.video_call),
              label: const Text('Mulai Kamera & Hubungkan'),
            ),

            ElevatedButton.icon(
              onPressed: isCalling ? endCall : null,
              icon: const Icon(Icons.call_end),
              label: const Text('Akhiri Panggilan'),
            ),

            const SizedBox(height: 24),

            const Text(
              'B. Video Lokal',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              height: 220,
              child: RTCVideoView(
                localRenderer,
                mirror: true,
                objectFit:
                    RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'C. Video Remote',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              height: 220,
              child: RTCVideoView(
                remoteRenderer,
                objectFit:
                    RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
