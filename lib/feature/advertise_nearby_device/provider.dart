import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suzuka/feature/advertise_nearby_device/repo.dart';
import 'package:suzuka/feature/advertise_nearby_device/state.dart';
import 'package:universal_ble/universal_ble.dart';

final advertiseNearbyDeviceProvider = NotifierProvider.autoDispose(
  AdvertiseNearbyDeviceNotifier.new,
);

class AdvertiseNearbyDeviceNotifier extends Notifier<BleNearybyState> {
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
    ref.onDispose(() {
      debugPrint('onDispose');
    });
    repo = BleNearbyRepo();
    bleNearbyRepo.initialize();
    sub = repo.stateStream.listen(listner);
    discoverySub = bleNearbyRepo.deviceStream.listen(discoveryListner);

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

  void connectDevice(String deviceId) async {
    await repo.connectDevice(deviceId);
  }

  void listner(BleNearybyState event) {
    state = event;
  }
}
