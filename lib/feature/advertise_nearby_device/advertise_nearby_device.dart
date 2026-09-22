import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suzuka/core/config.dart';
import 'package:suzuka/feature/advertise_nearby_device/state.dart';
import 'package:universal_ble/universal_ble.dart';

final advertiseNearbyDeviceProvider = NotifierProvider(
  AdvertiseNearbyDeviceNotifier.new,
);

class AdvertiseNearbyDeviceNotifier
    extends Notifier<AdvertiseNearbyDeviceState> {
  late StreamSubscription<BlePeripheralConnectionStateChanged> _sub;
  late StreamSubscription discoverySub;
  @override
  AdvertiseNearbyDeviceState build() {
    // UniversalBle.hasPermissions().then((blePermission) async {
    //   if (blePermission == false) {
    //     await UniversalBle.requestPermissions();
    //     blePermission = await UniversalBle.hasPermissions();
    //     if (blePermission == false || state is StatePermissionDenied) return;
    //
    //     return;
    //   }
    // });

    ///
    UniversalBle.onAvailabilityChange = onAvailabilityChange;
    ref.onDispose(() {
      UniversalBle.onAvailabilityChange = null;
    });

    ///
    _sub = UniversalBlePeripheral.connectionStateStream.listen((event) async {
      final s = state;
      if (s is! StateAvailable) return;
    });
    ref.onDispose(_sub.cancel);
    UniversalBlePeripheral.setWriteRequestHandlers(writeHandler);

    UniversalBle.getBluetoothAvailabilityState().then(onAvailabilityChange);
    return StatePermissionDenied();
  }

  PeripheralWriteRequestResult writeHandler(
    String deviceId,
    String characteristicId,
    int offset,
    Uint8List? value,
  ) {
    return PeripheralWriteRequestResult();
  }

  Future<AdvertiseNearbyDeviceState> _handleState(
    AdvertiseNearbyDeviceState prev,
    AdvertiseNearbyDeviceState next,
  ) async {
    if (next is StateAvailable && prev is! StateAvailable) {
      await startAdvertiseNDiscovery();
      next = next.copyWith(advertisement: true);
      return next;
    }
    if ((prev is StateAvailable && prev.advertisement == true) &&
        (next is! StateAvailable || next.advertisement == false)) {
      await stopAdvertiseNDiscovery();
      return next;
    }
    return next;
  }

  Future<void> stopAdvertiseNDiscovery() async {
    final future = [
      UniversalBlePeripheral.stopAdvertising(),
      UniversalBlePeripheral.removeService(bleServiceID),
    ];
    discoverySub.cancel();
    await Future.wait(future);
  }

  Future<void> startAdvertiseNDiscovery() async {
    final future = [
      UniversalBlePeripheral.startAdvertising(services: [bleServiceID]),
      UniversalBlePeripheral.addService(
        BlePeripheralService(
          uuid: bleServiceID,
          characteristics: [
            BlePeripheralCharacteristic(
              uuid: bleWrite,
              properties: [.write],
              permissions: [.writeable],
            ),
            BlePeripheralCharacteristic(
              uuid: bleNotify,
              properties: [.notify],
              permissions: [],
            ),
          ],
        ),
      ),
    ];

    discoverySub = UniversalBle.scanStream.listen(discoveryListner);
    await Future.wait(future);
  }

  AdvertiseNearbyDeviceState _handleAvailabilityState(AvailabilityState s) {
    return switch (s) {
      AvailabilityState.unknown ||
      AvailabilityState.resetting ||
      AvailabilityState.unsupported ||
      AvailabilityState.unauthorized => StatePermissionDenied(),
      AvailabilityState.poweredOff => StateBluetoothTurnedOff(),
      AvailabilityState.poweredOn => StateAvailable(false, null),
    };
  }

  void onAvailabilityChange(AvailabilityState s) async {
    AdvertiseNearbyDeviceState next = _handleAvailabilityState(s);
    next = await _handleState(state, next);
    state = next;
  }

  void discoveryListner(BleDevice event) {}
}
