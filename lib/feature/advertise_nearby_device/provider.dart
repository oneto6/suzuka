import 'dart:async';
import 'dart:convert';
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
  late StreamSubscription<BleDevice> discoverySub;
  late Timer timer;
  final device = <String>{};

  @override
  AdvertiseNearbyDeviceState build() {
    UniversalBle.scanStream.listen(discoveryListner);
    _handler();
    UniversalBlePeripheral.setWriteRequestHandlers(writeHandler);

    return StateInitial();
  }

  Future<void> stopService() async {
    await UniversalBlePeripheral.clearServices();
    await UniversalBlePeripheral.stopAdvertising();
  }

  Future<void> addService() async {
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

  PeripheralWriteRequestResult writeHandler(
    String deviceId,
    String characteristicId,
    int offset,
    Uint8List? value,
  ) {
    if (value == null) return PeripheralWriteRequestResult();
    final v = utf8.decode(value);
    debugPrint('write handler value: $v ');
    UniversalBlePeripheral.updateCharacteristicValue(
      characteristicId: bleNotify,
      value: utf8.encode('sdp recipents msg'),
      deviceId: deviceId,
    );
    return PeripheralWriteRequestResult();
  }

  Future<void> stopAdvertiseNDiscovery() async {
    debugPrint('stopAdvertiseNDiscovery');
    await UniversalBlePeripheral.stopAdvertising();
    await UniversalBlePeripheral.removeService(bleServiceID);
    discoverySub.cancel();
    await UniversalBle.stopScan();
    timer.cancel();
  }

  Timer get getTimer => Timer.periodic(Duration(seconds: 2), (_) {
    final s = state;
    if (s is! StateAvailable) return;
    final discovery = s.discovery;
    if (discovery == null) return;
    state = s.copyWith(discovery: () => device);
  });

  void discoveryListner(BleDevice event) {
    if (device.contains(event.deviceId)) return;
    device.add(event.deviceId);
  }

  Future<void> _connectDevice(String deviceId) async {
    void onValueChange(
      String deviceId,
      String characteristicId,
      Uint8List value,
      int? timestamp,
    ) {
      final msg = utf8.decode(value);
      debugPrint('onValueChange: $deviceId $characteristicId $msg $timestamp');
      UniversalBle.onValueChange = null;
    }

    debugPrint('_connectDevice');

    await UniversalBle.connect(deviceId);
    debugPrint('connected');
    BleConnectionState s = await UniversalBle.getConnectionState(deviceId);
    debugPrint('connection state: $s');
    await Future.delayed(Duration(seconds: 1));

    for (var s in await UniversalBle.discoverServices(deviceId)) {
      debugPrint('uuid: ${s.uuid}');
      if (s.uuid != bleServiceID) continue;
      for (var c in s.characteristics) {
        debugPrint('discoverServices: ${c.uuid}');
      }
    }

    UniversalBle.onValueChange = onValueChange;
    await UniversalBle.subscribeNotifications(
      deviceId,
      bleServiceID,
      bleNotify,
    );
    await UniversalBle.write(
      deviceId,
      bleServiceID,
      bleWrite,
      utf8.encode('sdp msg'),
    );
  }

  Future<void> _handler() async {
    bool p = await UniversalBle.hasPermissions();
    if (!p) {
      await UniversalBle.requestPermissions();
      p = await UniversalBle.hasPermissions();
      if (!p) {
        state = StatePermissionDenied();
        return;
      }
    }
    bool discovery = true;
    bool service = true;
    await for (var i in UniversalBle.availabilityStream) {
      if (i != .poweredOn) {
        if (i == .poweredOff) {
          state = StateBluetoothTurnedOff();
          continue;
        }
        state = StatePermissionDenied();
        continue;
      }
      debugPrint('powered on');
      try {
        await UniversalBle.startScan();
      } catch (e) {
        discovery = false;
        debugPrint('startScan err: ${e.toString()}');
      }
      timer = getTimer;
      try {
        await addService();
      } catch (e) {
        service = false;
        debugPrint('addService err: ${e.toString()}');
      }
      state = StateAvailable(service, discovery ? {} : null);
      break;
    }
    while (true) {
      await for (var i in UniversalBle.availabilityStream) {
        if (i != .poweredOff) {
          if (i == .poweredOn) {
            continue; //poweredOn; if it emit that means it is emitted twice so nothing to do here. added for perspective
          }
          state = StatePermissionDenied();
          continue;
        }
        debugPrint('powered off');
        timer.cancel();
        state = StateBluetoothTurnedOff();
        break;
      }

      await for (var i in UniversalBle.availabilityStream) {
        if (i != .poweredOn) {
          if (i == .poweredOff) {
            continue; //poweredOff; if it emit that means it is emitted twice so nothing to do here. added for perspective
          }
          state = StatePermissionDenied();
          continue;
        }
        debugPrint('powered on');
        discovery = true;
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
        timer = getTimer;
        state = StateAvailable(service, discovery ? {} : null);
        break;
      }
    }
  }

  void connectDevice(String deviceId) async {
    await _connectDevice(deviceId);
  }
}
