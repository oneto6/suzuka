import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:suzuka/feature/peer/state.dart';

const config = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
  ],
};

extension RTCSessionDescriptionExtension on RTCSessionDescription {
  static RTCSessionDescription fromMap(Map<String, dynamic> map) {
    return RTCSessionDescription(map['sdp'], map['type']);
  }
}

class PeerRepo {
  late Peer state;

  late StreamController<Peer> _stateStreamController;
  Stream<Peer> get stream => _stateStreamController.stream;
  late StreamSubscription<Peer> _sub;
  late RTCPeerConnection conn;

  Future<void> dispose() async {
    _sub.cancel();
    await _stateStreamController.close();
    await WebRTC.initialize();
  }

  Future<void> initialize() async {
    _stateStreamController = StreamController();
    _sub = stream.listen(listner);
    await WebRTC.initialize();
    conn = await createPeerConnection(config);
    conn.onSignalingState = onSignalingState;
    conn.onIceCandidate = onIceCandidate;
    conn.onIceGatheringState = onIceGatheringState;
    conn.onIceConnectionState = onIceConnectionState;
    conn.onConnectionState = onConnectionState;
    conn.onDataChannel = onDataChannel;
  }

  Future<Map<String, String>> createOffer() async {
    conn = await createPeerConnection(config);
    final offer = await conn.createOffer();
    _stateStreamController.add(Host());
    return offer.toMap();
  }

  Future<void> setOfferAnswer(Map<String, String> map) async {
    var rSDP = RTCSessionDescriptionExtension.fromMap(map);
    await conn.setRemoteDescription(rSDP);
  }

  Future<Map<String, String>> answerOffer(Map<String, String> offer) async {
    RTCSessionDescription rSDP;
    try {
      rSDP = RTCSessionDescriptionExtension.fromMap(offer);
    } catch (e) {
      throw Exception('flutter_webrtcsdp is null');
    }
    await conn.setRemoteDescription(rSDP);
    final rtcSD = await conn.createAnswer();
    debugPrint('sdp answer: ${rtcSD.toMap().toString()}');
    _stateStreamController.add(Client());
    return rtcSD.toMap();
  }

  void listner(Peer event) {}

  void onSignalingState(RTCSignalingState state) {
    debugPrint('onSignalingState: $state');
  }

  void onDataChannel(RTCDataChannel channel) {
    debugPrint('onDataChannel: $channel');
  }

  onIceCandidate(RTCIceCandidate candidate) {
    debugPrint('onIceCandidate: $candidate');
  }

  onIceGatheringState(RTCIceGatheringState state) {
    debugPrint('onIceGatheringState: $state');
  }

  onIceConnectionState(RTCIceConnectionState state) {
    debugPrint('onIceConnectionState: $state');
  }

  onConnectionState(RTCPeerConnectionState state) {
    debugPrint('onConnectionState: $state');
  }
}
