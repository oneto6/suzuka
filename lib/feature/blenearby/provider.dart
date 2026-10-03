import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suzuka/feature/blenearby/repo.dart';
import 'package:suzuka/feature/blenearby/state.dart';
import 'package:suzuka/feature/blenearbyAction/provider.dart';
import 'package:universal_ble/universal_ble.dart';

final bleNearbyProvider = NotifierProvider.autoDispose(BleNearbyNotifier.new);

class BleNearbyNotifier extends Notifier<BleNearybyState> {
  late StreamController<BlenearbyAction> _blenearbyActionController;
  Stream<BlenearbyAction> get blenearbyActionStream =>
      _blenearbyActionController.stream;
  late StreamSubscription<BleDevice> discoverySub;
  final device = <String, BleDevice>{};
  late BleNearbyRepo repo;
  late StreamSubscription<BleNearybyState> sub;
  late Timer timer;

  Timer get getTimer => Timer.periodic(Duration(seconds: 2), (_) {
    final s = state;
    if (s is! StateAvailable || s.discovery == null) return;
    state = s.copyWith(discovery: () => device.keys.toSet());
    // if (device.isNotEmpty) debugPrint(device.values.first.services.toString());
    device.clear();
  });

  @override
  BleNearybyState build() {
    _blenearbyActionController = StreamController<BlenearbyAction>();
    ref.onDispose(_blenearbyActionController.close);
    repo = BleNearbyRepo();
    bleNearbyRepo.initialize();
    sub = repo.stateStream.listen(listner);
    discoverySub = bleNearbyRepo.deviceStream.listen(discoveryListner);
    bleNearbyRepo.offerReceivedCallback = offerReceivedCallback;

    timer = getTimer;

    ///
    ref.onDispose(timer.cancel);
    ref.onDispose(discoverySub.cancel);
    ref.onDispose(sub.cancel);
    ref.onDispose(bleNearbyRepo.dispose);
    return StateInitial();
  }

  void discoveryListner(BleDevice event) {
    device[event.deviceId] = event;
  }

  Future<void> connectDevice(String deviceId) async {
    _blenearbyActionController.add(OfferRequested(deviceId));
    // final sdp = await repo.connectDevice(deviceId);
    // if (sdp == null) return;
  }

  void listner(BleNearybyState event) {
    state = event;
  }

  void offerReceivedCallback(String deviceId, String p1) {
    _blenearbyActionController.add(OfferReceived(deviceId, p1));
  }
}
