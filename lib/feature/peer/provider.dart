import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suzuka/feature/peer/repo.dart';
import 'package:suzuka/feature/peer/state.dart';

final peerProvider = NotifierProvider<PeerNotifier, Peer>(PeerNotifier.new);

class PeerNotifier extends Notifier<Peer> {
  late StreamSubscription<Peer> _sub;
  PeerNotifier();
  @override
  Peer build() {
    _sub = peerRepo.stream.listen(listner);
    ref.onDispose(_sub.cancel);
    peerRepo.initialize();
    ref.onDispose(peerRepo.dispose);
    return Init();
  }

  Future<Offer> createOffer() async => await peerRepo.createOffer();

  Future<void> setOfferAnswer(Map<String, String> map) async =>
      await peerRepo.setOfferAnswer(map);

  Future<Offer> answerOffer(Map<String, String> offer) async =>
      await peerRepo.answerOffer(offer);

  void listner(Peer event) {}
}
