import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

const peerConnexionconfiguration = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
  ],
  'iceTransportPolicy': "all",
};

class SuzukaWebrtc {
  static Future<String?> createOffer() async {
    final completer = Completer<RTCIceGatheringState>();
    void onIceGatheringState(RTCIceGatheringState state) {
      debugPrint('onIceGatheringState: $state');
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !completer.isCompleted) {
        completer.complete(state);
      }
    }

    onSignalingState(RTCSignalingState state) {
      debugPrint('onSignalingState: $state');
    }

    final pc = await createPeerConnection(peerConnexionconfiguration);
    await pc.addTransceiver(kind: .RTCRtpMediaTypeAudio);
    pc.onIceCandidate = onIceCandidate;
    pc.onIceGatheringState = onIceGatheringState;
    var offer = await pc.createOffer();
    pc.onSignalingState = onSignalingState;

    await pc.setLocalDescription(offer);
    await completer.future;
    offer = await pc.createOffer();
    return offer.sdp;
  }
}

void onIceCandidate(RTCIceCandidate candidate) {
  debugPrint('candidate: ${candidate.toMap()}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sdp = await SuzukaWebrtc.createOffer();
  debugPrint('sdp: $sdp');
}
