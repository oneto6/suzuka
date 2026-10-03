import 'dart:async';
import 'dart:convert';

import 'package:ble_peripheral_plus/ble_peripheral.dart' as peripheral;
import 'package:flutter/foundation.dart';
import 'package:suzuka/core/config.dart';
import 'package:suzuka/feature/blenearby/state.dart';
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

final bleNearbyRepo = BleNearbyRepo();

class BleNearbyRepo {
  late StreamController<BleNearybyState> _stateStreamController;
  late Stream<BleNearybyState> stateStream;
  late StreamSubscription<AvailabilityState> _sub;
  late Stream<BleDevice> deviceStream;
  late BleNearybyState _state;

  void Function(String, String)? _offerReceivedCallback;

  set offerReceivedCallback(void Function(String, String) callback) {
    _offerReceivedCallback = callback;
  }

  void _emit(BleNearybyState state) {
    _state = state;
    _stateStreamController.add(_state);
  }

  void dispose() async {
    debugPrint('BleNearbyRepo dispose');
    _sub.cancel();
    _stateStreamController.close();
    final AvailabilityState availabilityState =
        await UniversalBle.getBluetoothAvailabilityState();
    if (availabilityState == .poweredOn) {
      await stopScan();
      await stopService();
      return;
    }
    await for (var i in UniversalBle.availabilityStream) {
      if (i != .poweredOn) continue;
    }
    try {
      await stopScan();
    } catch (e) {
      debugPrint('stopScan err: ${e.toString()}');
    }
    try {
      await stopService();
    } catch (e) {
      debugPrint('stopService err: ${e.toString()}');
    }
  }

  Future<void> initialize() async {
    debugPrint('BleNearbyRepo initialize');
    deviceStream = UniversalBle.scanStream;
    _stateStreamController = StreamController<BleNearybyState>.broadcast();
    stateStream = _stateStreamController.stream;

    final p = await UniversalBle.hasPermissions();
    debugPrint('hasPermissions: $p');
    if (!p) {
      await UniversalBle.requestPermissions();
    }

    _sub = UniversalBle.availabilityStream.listenPair(_listner);
    _emit(StateInitial());
    peripheral.BlePeripheral.setWriteRequestCallback(writeHandle);
    peripheral.BlePeripheral.setAdvertisingStatusUpdateCallback((b, s) async {
      debugPrint('setAdvertisingStatusUpdateCallback: $b $s');
      var state = _state;
      if (state is! StateAvailable) return;
      _emit(state.copyWith(advertisement: b));
    });
    peripheral.BlePeripheral.setServiceAddedCallback((s, err) {
      debugPrint('setServiceAddedCallback: $s $err');
    });
  }

  Future<void> stopService() async {
    await peripheral.BlePeripheral.clearServices();
    await peripheral.BlePeripheral.stopAdvertising();
  }

  Future<void> addService() async {
    await peripheral.BlePeripheral.isSupported();
    await peripheral.BlePeripheral.addService(
      peripheral.BleService(
        uuid: bleServiceID,
        primary: true,
        characteristics: [
          peripheral.BleCharacteristic(
            uuid: bleWrite,
            properties: [peripheral.CharacteristicProperties.write.index],
            permissions: [
              peripheral.AttributePermissions.writeEncryptionRequired.index,
            ],
          ),
          peripheral.BleCharacteristic(
            uuid: bleNotify,
            properties: [peripheral.CharacteristicProperties.notify.index],
            permissions: [],
          ),
          peripheral.BleCharacteristic(
            uuid: bleRead,
            properties: [peripheral.CharacteristicProperties.read.index],
            permissions: [
              peripheral.AttributePermissions.readEncryptionRequired.index,
            ],
          ),
        ],
      ),
    );
    await peripheral.BlePeripheral.startAdvertising(
      services: [bleServiceID],
      requireBonding: true,
    );
  }

  void _listner(AvailabilityState prev, AvailabilityState now) async {
    if (prev == now) return;
    debugPrint('listner prev: $prev now: $now');

    if (now == .poweredOff) {
      _handlePoweroff();
    }
    if (now == .poweredOn) {
      await _handlePoweron();
    }
  }

  void _handlePoweroff() {
    debugPrint('powered off');
    _emit(StateBluetoothTurnedOff());
  }

  Future<void> _handlePoweron() async {
    debugPrint('handlePoweron');
    try {
      await stopService();
    } catch (e) {
      debugPrint('stopService err: ${e.toString()}');
    }
    try {
      await peripheral.BlePeripheral.initialize();
    } catch (e) {
      debugPrint('initialize err: ${e.toString()}');
    }

    try {
      await addService();
    } catch (e) {
      debugPrint('addService err: ${e.toString()}');
    }
    try {
      await stopScan();
    } catch (e) {
      debugPrint('stopScan err: ${e.toString()}');
    }

    try {
      await startScan();
    } catch (e) {
      debugPrint('startScan err: ${e.toString()}');
    }
    String? service;
    for (var i in await peripheral.BlePeripheral.getServices()) {
      debugPrint('service: ${i.toString()}');
      if (i.toLowerCase() == bleServiceID) service = i;
    }

    bool discovery = (await UniversalBle.isScanning());
    debugPrint('discovery: $discovery, service: $service');
    BleNearybyState state = _state;

    if (state is! StateAvailable) {
      state = StateAvailable.name(service, false, {});
    } else {
      state = state.copyWith(
        service: service,
        discovery: () => discovery ? {} : null,
      );
    }
    _emit(state);
  }

  Future<void> stopScan() => UniversalBle.stopScan();

  Future<void> startScan() => UniversalBle.startScan(
    scanFilter: ScanFilter(withServices: [bleServiceID]),
  );

  Future<String?> connectDevice(String deviceId) async {
    try {
      await UniversalBle.connect(deviceId);
    } catch (e) {
      debugPrint('connect device err: ${e.toString()}');
      return null;
    }
    final data = await _connectDevice(deviceId);
    await UniversalBle.disconnect(deviceId);
    return data;
  }

  peripheral.WriteRequestResult? writeHandle(
    String deviceId,
    String characteristicId,
    int offset,
    Uint8List? value,
  ) {
    debugPrint('writeHandle');
    if (value == null) return null;
    final offer = utf8.decode(value);
    debugPrint('write handler offer: $offer ');

    // peripheral.BlePeripheral.updateCharacteristic(
    //   characteristicId: bleNotify,
    //   value: utf8.encode('sdp recipents msg'),
    //   deviceId: deviceId,
    // );
    _offerReceivedCallback?.call(deviceId, offer);
    return null;
  }

  Future<String?> _connectDevice(String deviceId) async {
    final dataTransaction = Completer<List<int>>();
    void onValueChange(
      String deviceId,
      String characteristicId,
      Uint8List value,
      int? timestamp,
    ) {
      final msg = utf8.decode(value);
      debugPrint('onValueChange: $deviceId $characteristicId $msg $timestamp');
      dataTransaction.complete(value);
    }

    await UniversalBle.pair(deviceId);
    debugPrint('_connectDevice');

    BleConnectionState s = await UniversalBle.getConnectionState(deviceId);
    debugPrint('connection state: $s');
    var serviceList = await UniversalBle.discoverServices(deviceId);

    BleService? service;
    BleCharacteristic? notifyChar;
    BleCharacteristic? writeChar;
    debugPrint(
      'service: $service notifyChar: $notifyChar writeChar: $writeChar',
    );

    for (final s in serviceList) {
      if (s.uuid.toLowerCase() == bleServiceID.toLowerCase()) {
        service = s;
        break;
      }
    }

    if (service == null) return null;

    for (final characteristic in service.characteristics) {
      if (characteristic.uuid.toLowerCase() == bleNotify.toLowerCase()) {
        notifyChar = characteristic;
      }

      if (characteristic.uuid.toLowerCase() == bleWrite.toLowerCase()) {
        writeChar = characteristic;
      }
    }

    if (notifyChar == null || writeChar == null) return null;
    UniversalBle.onValueChange = onValueChange;
    await UniversalBle.subscribeNotifications(
      deviceId,
      service.uuid,
      notifyChar.uuid,
    );
    await UniversalBle.write(
      deviceId,
      service.uuid,
      writeChar.uuid,
      utf8.encode('sdp msg'),
      // withoutResponse: true,
    );
    final data = await dataTransaction.future;
    debugPrint('data: ${utf8.decode(data)}');
    UniversalBle.onValueChange = null;
    await UniversalBle.unsubscribe(deviceId, service.uuid, notifyChar.uuid);
    return utf8.decode(data);
  }
}
