import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suzuka/feature/peer/repo.dart';
import 'package:suzuka/feature/peer/state.dart';

final peerProvider = NotifierProvider<PeerNotifier, Peer>(PeerNotifier.new);

class PeerNotifier extends Notifier<Peer> {
  late PeerRepo repo;
  late StreamSubscription<Peer> _sub;
  PeerNotifier();
  @override
  Peer build() {
    repo = PeerRepo();
    repo.initialize().then((_) async {
      ref.onDispose(repo.dispose);
      _sub = repo.stream.listen(listner);
      ref.onDispose(_sub.cancel);
    });
    return Init();
  }

  Future<Map<String, String>> createOffer() async => await repo.createOffer();
  Future<void> setOfferAnswer(Map<String, String> map) async =>
      await repo.setOfferAnswer(map);
  Future<Map<String, String>> answerOffer(Map<String, String> offer) async =>
      await repo.answerOffer(offer);

  void listner(Peer event) {}
}
