import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:suzuka/core/config.dart';
import 'package:suzuka/feature/advertise_nearby_device/state.dart';
import 'package:universal_ble/universal_ble.dart';

extension AvailabilityStreamX on Stream<AvailabilityState> {
  StreamSubscription<AvailabilityState> listenPair(
    void Function(AvailabilityState prev, AvailabilityState curr) listener, {
    AvailabilityState initial = AvailabilityState.unknown,
  }) {
    var previous = initial;

    return listen((curr) {
      listener(previous, curr);
      previous = curr;
    });
  }
}

class BleRepo {
  late StreamController<AvailabilityState> availabilityStreamController;
  late Stream<AvailabilityState> availabilityStream;
  late StreamController<AdvertiseNearbyDeviceState> stateStreamController;
  late Stream<AdvertiseNearbyDeviceState> stateStream;
  late StreamSubscription<AvailabilityState> sub;
  void initialize() {
    ///
    _initialize();
  }

  void _initialize() async {
    sub = UniversalBle.availabilityStream.listenPair(listner);
  }

  void dispose() {}

  Future<void> stopService() async {
    await UniversalBlePeripheral.stopAdvertising();
    await UniversalBlePeripheral.clearServices();
  }

  Future<void> addService() async {
    if ((await UniversalBlePeripheral.getServices()).contains(bleServiceID)) {
      await UniversalBlePeripheral.stopAdvertising();
      await UniversalBlePeripheral.clearServices();
    }
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

    await UniversalBlePeripheral.startAdvertising(services: [bleServiceID]);
  }

  void listner(AvailabilityState? prev, AvailabilityState now) async {
    if (prev != null && now == prev) return;

    if (now == .poweredOn && (prev != .poweredOff || prev != .poweredOn)) {
      UniversalBle.scanStream;
      bool p = await UniversalBle.hasPermissions();
      if (!p) {
        await UniversalBle.requestPermissions();
        p = await UniversalBle.hasPermissions();
        if (!p) {
          stateStreamController.add(StatePermissionDenied());
          // state = StatePermissionDenied();
          return;
        }
      }
      bool discovery = true;
      bool service = true;
      try {
        await UniversalBle.startScan();
      } catch (e) {
        discovery = false;
        debugPrint('startScan err: ${e.toString()}');
      }
      try {
        await addService();
      } catch (e) {
        service = false;
        debugPrint('addService err: ${e.toString()}');
      }
      stateStreamController.add(StateAvailable(service, discovery ? {} : null));
    }

    if (now == .poweredOff) {
      debugPrint('powered off');
      stateStreamController.add(StateBluetoothTurnedOff());
    }
    if (now == .poweredOn) {
      bool discovery = true;
      bool service = (await UniversalBlePeripheral.getServices()).contains(
        bleServiceID,
      );
      try {
        await UniversalBle.stopScan();
      } catch (e) {
        discovery =
            false; //if stopScan falled it kind of certain that discovey has failed silently
        debugPrint('stopScan err: ${e.toString()}');
      }

      try {
        await UniversalBle.startScan();
      } catch (e) {
        debugPrint('startScan err: ${e.toString()}');
      }
      stateStreamController.add(StateAvailable(service, discovery ? {} : null));
    }
  }
}

// Future<void> _initialize() async {
//   UniversalBle.scanStream;
//   bool p = await UniversalBle.hasPermissions();
//   if (!p) {
//     await UniversalBle.requestPermissions();
//     p = await UniversalBle.hasPermissions();
//     if (!p) {
//       stateStreamController.add(StatePermissionDenied());
//       // state = StatePermissionDenied();
//       return;
//     }
//   }
//   bool discovery = true;
//   bool service = true;
//   await for (var i in availabilityStream) {
//     if (i != .poweredOn) {
//       if (i == .poweredOff) {
//         stateStreamController.add(StateBluetoothTurnedOff());
//         // state = StateBluetoothTurnedOff();
//         continue;
//       }
//       stateStreamController.add(StatePermissionDenied());
//       // state = StatePermissionDenied();
//       continue;
//     }
//     debugPrint('powered on');
//     try {
//       await UniversalBle.startScan();
//     } catch (e) {
//       discovery = false;
//       debugPrint('startScan err: ${e.toString()}');
//     }
//     try {
//       await addService();
//     } catch (e) {
//       service = false;
//       debugPrint('addService err: ${e.toString()}');
//     }
//     stateStreamController.add(StateAvailable(service, discovery ? {} : null));
//     // state = StateAvailable(service, discovery ? {} : null);
//     break;
//   }
//   while (_dispose == false) {
//     await for (var i in availabilityStream) {
//       if (i == .poweredOn) {
//         continue; //poweredOn; if it emit that means it is emitted twice so nothing to do here. added for perspective
//       } else if (i != .poweredOff) {
//         stateStreamController.add(StatePermissionDenied());
//         // state = StatePermissionDenied();
//       }
//       debugPrint('powered off');
//       stateStreamController.add(StateBluetoothTurnedOff());
//       // state = StateBluetoothTurnedOff();
//       break;
//     }
//
//     await for (var i in availabilityStream) {
//       if (i != .poweredOn) {
//         if (i == .poweredOff) {
//           continue; //poweredOff; if it emit that means it is emitted twice so nothing to do here. added for perspective
//         }
//         stateStreamController.add(StatePermissionDenied());
//         // state = StatePermissionDenied();
//         continue;
//       }
//       debugPrint('powered on');
//       discovery = true;
//       () async {
//         //not to await; as so we don't want to starve the loop of emmited event
//         try {
//           await UniversalBle.stopScan();
//         } catch (e) {
//           discovery =
//               false; //if stopScan falled it kind of certain that discovey has failed silently
//           debugPrint('stopScan err: ${e.toString()}');
//         }
//
//         try {
//           await UniversalBle.startScan();
//         } catch (e) {
//           debugPrint('startScan err: ${e.toString()}');
//         }
//         stateStreamController.add(
//           StateAvailable(service, discovery ? {} : null),
//         );
//         // state = StateAvailable(service, discovery ? {} : null);
//       }();
//       break;
//     }
//   }
// }
