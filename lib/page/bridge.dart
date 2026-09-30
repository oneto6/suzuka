import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suzuka/feature/blenearby/provider.dart';
import 'package:suzuka/feature/peer/provider.dart';

class ClientNegotiationRole extends NegotiationRole {
  final String peerOffer;
  ClientNegotiationRole(this.peerOffer);
}

class HostNegotiationRole extends NegotiationRole {}

sealed class NegotiationRole {
  static NegotiationRole create([String? peerSDP]) {
    if (peerSDP == null) {
      return HostNegotiationRole();
    }
    return ClientNegotiationRole(peerSDP);
  }
}

class Bridge extends ConsumerWidget {
  final NegotiationRole role;
  const Bridge(this.role, {super.key});

  @override
  Widget build(BuildContext context, ref) {
    ref.listen(bleNearbyProvider, (_, _) {});
    final peerState = ref.watch(peerProvider);

    return Scaffold(body: Center(child: Text('Connecting...')));
  }
}
