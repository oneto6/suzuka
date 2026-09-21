import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suzuka/core/config.dart';
import 'package:universal_ble/universal_ble.dart';

extension ExtensionDevice on BleDevice {
  Device toDevice() {
    return Device(deviceId, name);
  }
}

class Device {
  final String id;
  final String? name;

  Device(this.id, this.name);

  factory Device.copyFrom(String id, String? Function()? name) {
    return Device(id, name?.call());
  }

  @override
  operator ==(Object other) {
    if (other is Device) {
      return id == other.id;
    }
    return false;
  }

  @override
  int get hashCode => id.hashCode;
}

sealed class StateNearbyDevice {}

class PermissionRequredState extends StateNearbyDevice {}

class TurnOnBluetoothState extends StateNearbyDevice {}

class DeviceListState extends StateNearbyDevice {
  final List<Device> device;

  DeviceListState(this.device);
}

final nearbyDeviceProvider = NotifierProvider(NearbyDevice.new);

class NearbyDevice extends Notifier<StateNearbyDevice> {
  final deviceList = <Device>[];
  late Timer timer;
  @override
  StateNearbyDevice build() {
    ///
    final sub = UniversalBle.scanStream.listen(
      (BleDevice event) => addDevice(event.toDevice()),
    );
    ref.onDispose(sub.cancel);

    ///

    ///
    UniversalBle.onConnectionChange = onConnectionChange;
    ref.onDispose(() {
      UniversalBle.onConnectionChange = null;
    });

    ///

    ///
    ref.onResume(startScan);
    ref.onCancel(stopScan);
    ref.onDispose(stopScan);

    ///

    ///
    UniversalBle.requestPermissions().then((value) async {
      var hasPermission = await UniversalBle.hasPermissions();
      if (!hasPermission) return;
      startScan();
      timer = _getTimer;
      ref.onDispose(timer.cancel);
      ref.onCancel(timer.cancel);
      ref.onResume(() {
        timer = _getTimer;
      });
      state = DeviceListState([]);
    });

    ///

    return PermissionRequredState();
  }

  void onConnectionChange(String deviceId, bool isConnected, String? error) {
    if (isConnected) {}
  }

  void startScan() async => await UniversalBle.startScan(
    scanFilter: ScanFilter(withServices: [bleServiceID]),
  );
  void stopScan() => UniversalBle.stopScan();

  Timer get _getTimer => Timer.periodic(Duration(seconds: 2), (Timer timer) {
    final list = <Device>[];
    for (var d in deviceList) {
      list.add(d);
    }
    deviceList.clear();
    state = DeviceListState(list);
  });

  void addDevice(Device device) {
    if (deviceList.contains(device)) {
      return;
    }
    deviceList.add(device);
  }

  void connectDevice(Device device) async {
    await UniversalBle.connect(device.id);
    final data = Uint8List.fromList(utf8.encode('hello, from macos'));
    for (var d in await UniversalBle.discoverServices(device.id)) {
      debugPrint(
        'discoverServices: ${d.uuid}, characteristics: ${d.characteristics}',
      );
    }
    await UniversalBle.write(device.id, bleServiceID, bleWrite, data);
    debugPrint('data sent');
    // await UniversalBle.disconnect(device.id);
  }
}
