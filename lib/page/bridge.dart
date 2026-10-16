import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suzuka/feature/blenearby/provider.dart';
import 'package:suzuka/feature/blenearby/state.dart';
import 'package:suzuka/feature/peer/provider.dart';
import 'package:suzuka/feature/peer/repo.dart';
import 'package:suzuka/feature/peer/state.dart';

class ClientNegotiationRole extends NegotiationRole {
  ClientNegotiationRole(super.deviceId);
  @override
  String toString() {
    return 'NegotiationRole(ClientNegotiationRole) deviceId: $deviceId';
  }
}

class HostNegotiationRole extends NegotiationRole {
  final String peerOffer;

  HostNegotiationRole(super.deviceId, this.peerOffer);
  @override
  String toString() {
    return 'NegotiationRole(HostNegotiationRole) deviceId: $deviceId, peerOffer: $peerOffer';
  }
}

sealed class NegotiationRole {
  final String deviceId;

  NegotiationRole(this.deviceId);
  static NegotiationRole create(String deviceId, [String? peerOffer]) {
    if (peerOffer != null) {
      return HostNegotiationRole(deviceId, peerOffer);
    }
    return ClientNegotiationRole(deviceId);
  }
}

sealed class BridgeState {}

class InitState extends BridgeState {}

class NegotiationState extends BridgeState {}

class FailedState extends BridgeState {}

final bridgeProvider = NotifierProvider.family
    .autoDispose<BridgeNotifier, BridgeState, NegotiationRole>(
      BridgeNotifier.new,
    );

class BridgeNotifier extends Notifier<BridgeState> {
  final NegotiationRole role;
  late ProviderSubscription<Peer> sub;
  BridgeNotifier(this.role);
  @override
  build() {
    state = NegotiationState();
    final _ = ref.listen(bleNearbyProvider, bleNearbyListner);
    final _ = ref.listen(peerProvider, peerListner);
    sub = ref.listen(peerProvider, (p, n) {
      if (n is! Ready) return;
      sub.close();
      _init();
    });

    return state;
  }

  void peerListner(Peer? previous, Peer next) {
    debugPrint('peerListner  $next');
  }

  void bleNearbyListner(BleNearybyState? previous, BleNearybyState next) {}

  Future<void> _init() async {
    switch (role) {
      case ClientNegotiationRole(:final deviceId):
        Offer offer = await ref.read(peerProvider.notifier).createOffer();
        String? response;
        try {
          response = await ref
              .read(bleNearbyProvider.notifier)
              .client
              .sendOffer(deviceId, jsonEncode(offer));
        } catch (e) {
          debugPrint('ClientNegotiationRole sendOffer failed: $e');
          response = null;
        }
        if (response == null) {
          state = FailedState();
          return;
        }
        final map = <String, String>{};
        try {
          final d = jsonDecode(response);
          if (d is! Map<String, dynamic>) {
            throw Exception('d is not Map<String, dynamic>');
          }
          for (final i in d.entries) {
            final value = i.value;
            if (value is! String) throw Exception('value is not String');
            map[i.key] = i.value;
          }
        } catch (e) {
          debugPrint('ClientNegotiationRole peerOffer jsonDecode failed: $e');
          state = FailedState();
          return;
        }
        ref.read(peerProvider.notifier).setOfferAnswer(map);
      case HostNegotiationRole(:final deviceId, :final peerOffer):
        Map<String, String> map = {};
        try {
          var d = json.decode(peerOffer);
          if (d is! Map<String, dynamic>) {
            throw Exception('d is not Map<String, dynamic>');
          }
          for (final i in d.entries) {
            final value = i.value;
            if (value is! String) throw Exception('value is not String');
            map[i.key] = i.value;
          }
        } catch (e) {
          debugPrint(
            'HostNegotiationRole peerOffer jsonDecode failed: $e, peerOffer: $peerOffer',
          );
          state = FailedState();
          return;
        }
        var answerOffer = await ref
            .read(peerProvider.notifier)
            .answerOffer(map);

        final data = jsonEncode(answerOffer);
        await ref
            .read(bleNearbyProvider.notifier)
            .host
            .sendAnswerOffer(deviceId, data);
    }
  }
}

class Bridge extends ConsumerWidget {
  final NegotiationRole role;
  const Bridge(this.role, {super.key});

  @override
  Widget build(BuildContext context, ref) {
    final state = ref.watch(bridgeProvider(role));
    return Scaffold(
      appBar: AppBar(),
      body: switch (state) {
        InitState() => Text('Init...'),
        NegotiationState() => Text('Negotiation... ${role.toString()}'),
        FailedState() => Text('FailedState'),
      },
    );
  }
}
