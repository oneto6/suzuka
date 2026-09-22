import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suzuka/core/config.dart';
import 'package:universal_ble/universal_ble.dart';

sealed class AdvertiseNearbyDeviceState {}

class StatePermissionDenied extends AdvertiseNearbyDeviceState {}

class StateBluetoothTurnedOff extends AdvertiseNearbyDeviceState {}

abstract interface class Available extends AdvertiseNearbyDeviceState {
  Advertisement withAdvertisement();
  Discovery withDiscovery();
}

abstract interface class Advertisement extends Available {
  StateAvailable withoutAdvertisement();
}

abstract interface class Discovery extends Available {
  Set<String> get discovery;

  StateAvailable withoutDiscovery();

  Discovery copyWith({Set<String>? discovery});
}

class StateAvailable implements Available {
  @override
  StateAdvertisement withAdvertisement() {
    return StateAdvertisement();
  }

  @override
  StateDiscovery withDiscovery() {
    return StateDiscovery({});
  }
}

class StateAdvertisement implements Advertisement {
  @override
  StateAdvertisement withAdvertisement() {
    return this;
  }

  @override
  StateAdvertisementDiscovery withDiscovery() {
    return StateAdvertisementDiscovery({});
  }

  @override
  StateAvailable withoutAdvertisement() {
    return StateAvailable();
  }
}

class StateDiscovery implements Discovery {
  @override
  final Set<String> discovery;

  StateDiscovery(this.discovery);

  @override
  StateDiscovery copyWith({Set<String>? discovery}) {
    return StateDiscovery(discovery ?? this.discovery);
  }

  @override
  StateAvailable withoutDiscovery() {
    return StateAvailable();
  }

  @override
  StateAdvertisementDiscovery withAdvertisement() {
    return StateAdvertisementDiscovery(discovery);
  }

  @override
  StateDiscovery withDiscovery() {
    return this;
  }
}

class StateAdvertisementDiscovery implements Advertisement, Discovery {
  @override
  final Set<String> discovery;

  StateAdvertisementDiscovery(this.discovery);

  @override
  StateAdvertisementDiscovery withAdvertisement() {
    return this;
  }

  @override
  StateAdvertisementDiscovery withDiscovery() {
    return this;
  }

  @override
  StateAdvertisementDiscovery copyWith({Set<String>? discovery}) {
    return StateAdvertisementDiscovery(discovery ?? this.discovery);
  }

  @override
  StateAvailable withoutAdvertisement() {
    return StateDiscovery(discovery);
  }

  @override
  StateAvailable withoutDiscovery() {
    return StateAdvertisement();
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

  Future<AdvertiseNearbyDeviceState> _handleState(
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
      next = next.copyWith(advertisement: true);
      return next;
    }

    if (prev is StateAvailable && prev.advertisement == true) {
      if (next is! StateAvailable || next.advertisement == false) {
        await UniversalBlePeripheral.stopAdvertising();
        await UniversalBlePeripheral.removeService(bleServiceID);
        return next;
      }
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
    AdvertiseNearbyDeviceState next = _handleAvailabilityState(s);
    next = _handleState(state, next);
    state = next;
    return next;
  }
}
