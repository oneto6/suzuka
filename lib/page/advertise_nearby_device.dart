import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suzuka/core/config.dart';
import 'package:universal_ble/universal_ble.dart';

sealed class AdvertiseNearbyDeviceState {}

class StatePermissionDenied extends AdvertiseNearbyDeviceState {}

class StateBluetoothTurnedOff extends AdvertiseNearbyDeviceState {}

class StateAvailable extends AdvertiseNearbyDeviceState {
  final bool advertisement;

  StateAvailable(this.advertisement);
  StateAvailable copyWith({bool? advertisement}) {
    return StateAvailable(advertisement ?? this.advertisement);
  }
}

class StateDiscovery extends StateAvailable {
  final Set<String> discovery;

  StateDiscovery(super.advertisement, this.discovery);
  @override
  StateDiscovery copyWith({bool? advertisement, Set<String>? discovery}) {
    return StateDiscovery(
      advertisement ?? this.advertisement,
      discovery ?? this.discovery,
    );
  }
}

final advertiseNearbyDeviceProvider = NotifierProvider(
  AdvertiseNearbyDeviceNotifier.new,
);

class AdvertiseNearbyDeviceNotifier
    extends Notifier<AdvertiseNearbyDeviceState> {
  late StreamSubscription<BlePeripheralConnectionStateChanged> _sub;
  @override
  AdvertiseNearbyDeviceState build() {
    UniversalBle.hasPermissions().then((blePermission) async {
      if (blePermission == false) {
        await UniversalBle.requestPermissions();
        blePermission = await UniversalBle.hasPermissions();
        return;
      }
    });

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

  void _handleState(
    AdvertiseNearbyDeviceState prev,
    AdvertiseNearbyDeviceState next,
  ) async {
    if (next is StateAvailable && prev is! StateAvailable) {
      await UniversalBlePeripheral.startAdvertising(services: [bleServiceID]);
      await UniversalBlePeripheral.addService(
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
      );
      return;
    }

    if (next is! StateAvailable && prev is StateAvailable) {
      await UniversalBlePeripheral.stopAdvertising();
      await UniversalBlePeripheral.removeService(bleServiceID);
      return;
    }
  }

  AdvertiseNearbyDeviceState _handleAvailabilityState(AvailabilityState s) {
    return switch (s) {
      AvailabilityState.unknown ||
      AvailabilityState.resetting ||
      AvailabilityState.unsupported ||
      AvailabilityState.unauthorized => StatePermissionDenied(),
      AvailabilityState.poweredOff => StateBluetoothTurnedOff(),
      AvailabilityState.poweredOn => StateAvailable(false),
    };
  }

  AdvertiseNearbyDeviceState onAvailabilityChange(AvailabilityState s) {
    final AdvertiseNearbyDeviceState next = _handleAvailabilityState(s);
    _handleState(state, next);
    state = next;
    return next;
  }
}
