import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suzuka/feature/advertise_nearby_device/repo.dart';
import 'package:suzuka/feature/advertise_nearby_device/state.dart';
import 'package:universal_ble/universal_ble.dart';

final advertiseNearbyDeviceProvider = NotifierProvider.autoDispose(
  AdvertiseNearbyDeviceNotifier.new,
);

class AdvertiseNearbyDeviceNotifier
    extends Notifier<AdvertiseNearbyDeviceState> {
  late StreamSubscription<BleDevice> discoverySub;
  final device = <String, BleDevice>{};
  late BleRepo repo;
  late StreamSubscription<AdvertiseNearbyDeviceState> sub;
  late Timer timer;

  Timer get getTimer => Timer.periodic(Duration(seconds: 2), (_) {
    final s = state;
    if (s is! StateAvailable || s.discovery == null) return;
    state = s.copyWith(discovery: () => device.keys.toSet());
    // if (device.isNotEmpty) debugPrint(device.values.first.services.toString());
    device.clear();
  });

  @override
  AdvertiseNearbyDeviceState build() {
    ref.onDispose(() {
      debugPrint('onDispose');
    });
    repo = blerepo;
    blerepo.initialize();
    sub = repo.stateStream.listen(listner);
    discoverySub = blerepo.deviceStream.listen(discoveryListner);

    timer = getTimer;

    ///
    ref.onDispose(timer.cancel);
    ref.onDispose(discoverySub.cancel);
    ref.onDispose(sub.cancel);
    ref.onDispose(blerepo.dispose);
    return StateInitial();
  }

  void discoveryListner(BleDevice event) {
    device[event.deviceId] = event;
  }

  void connectDevice(String deviceId) async {
    await repo.connectDevice(deviceId);
  }

  void listner(AdvertiseNearbyDeviceState event) {
    state = event;
  }
}
