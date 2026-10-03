import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suzuka/feature/blenearby/bblenearby.dart';

sealed class BlenearbyAction {
  final String deviceId;

  BlenearbyAction(this.deviceId);
}

class OfferRequested extends BlenearbyAction {
  OfferRequested(super.deviceId);
}

class OfferReceived extends BlenearbyAction {
  final String peerOffer;

  OfferReceived(super.deviceId, this.peerOffer);
}

final blenearbyActionProvider = StreamProvider.autoDispose(
  (ref) => ref.watch(bleNearbyProvider.notifier).blenearbyActionStream,
);
