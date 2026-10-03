import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suzuka/feature/blenearby/provider.dart';
import 'package:suzuka/feature/blenearby/state.dart';
import 'package:suzuka/feature/peer/provider.dart';
import 'package:suzuka/feature/peer/state.dart';

class ClientNegotiationRole extends NegotiationRole {
  final String peerOffer;
  ClientNegotiationRole(super.deviceId, this.peerOffer);
}

class HostNegotiationRole extends NegotiationRole {
  HostNegotiationRole(super.deviceId);
}

sealed class NegotiationRole {
  final String deviceId;

  NegotiationRole(this.deviceId);
  static NegotiationRole create(String deviceId, [String? peerOffer]) {
    if (peerOffer == null) {
      return HostNegotiationRole(deviceId);
    }
    return ClientNegotiationRole(deviceId, peerOffer);
  }
}

class BridgeNotifier extends Notifier<Null> {
  final NegotiationRole role;

  BridgeNotifier(this.role);
  @override
  build() {
    final blenearbyState = ref.listen(bleNearbyProvider, bleNearbyListner);
    final peerState = ref.listen(peerProvider, peerListner);
    // ref.read(bleNearbyProvider.notifier).connectDevice();
    ref.read(peerProvider.notifier);
  }

  void peerListner(Peer? previous, Peer next) {}

  void bleNearbyListner(BleNearybyState? previous, BleNearybyState next) {}
}

class Bridge extends ConsumerWidget {
  final NegotiationRole role;
  const Bridge(this.role, {super.key});

  @override
  Widget build(BuildContext context, ref) {
    return Scaffold(body: Center(child: Text('Connecting...')));
  }
}
