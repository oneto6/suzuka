import 'dart:async';
import 'dart:math';

import 'package:ble_peripheral_plus/ble_peripheral.dart' as peripheral;
import 'package:flutter/foundation.dart';
import 'package:suzuka/core/config.dart';
import 'package:suzuka/feature/blenearby/client_composetion.dart';
import 'package:suzuka/feature/blenearby/host_composetion.dart';
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
typedef DataStreamParams = ({
  String deviceId,
  String characteristicId,
  Uint8List value,
  int? timestamp,
});

class BleNearbyRepo {
  final StreamController<BleNearybyState> _stateStreamController =
      StreamController<BleNearybyState>.broadcast();
  Stream<BleNearybyState> get stateStream => _stateStreamController.stream;
  late StreamSubscription<AvailabilityState> _sub;
  late Stream<BleDevice> deviceStream;
  late BleNearybyState _state;
  final StreamController<BleNearbyEvent> _eventStreamController =
      StreamController<BleNearbyEvent>();
  Stream<BleNearbyEvent> get eventStream => _eventStreamController.stream;

  final StreamController<DataStreamParams> _dataStream = .new();

  HostComposetion get host => HostComposetion(this, _eventStreamController);

  ClientComposetion get client => ClientComposetion(this, _dataStream);

  void _emit(BleNearybyState state) {
    _state = state;
    _stateStreamController.add(_state);
  }

  void dispose() async {
    debugPrint('BleNearbyRepo dispose');
    _sub.cancel();
    UniversalBle.onValueChange = null;
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
    UniversalBle.onValueChange = onValueChange;

    final p = await UniversalBle.hasPermissions();
    debugPrint('hasPermissions: $p');
    if (!p) {
      await UniversalBle.requestPermissions();
    }

    _sub = UniversalBle.availabilityStream.listenPair(_listner);
    _emit(StateInitial());
    peripheral.BlePeripheral.setWriteRequestCallback(
      HostComposetion(this, _eventStreamController).writeHandler,
    );
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
            uuid: bleChunkWrite,
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

  void onValueChange(
    String deviceId,
    String characteristicId,
    Uint8List value,
    int? timestamp,
  ) {
    _dataStream.add((
      deviceId: deviceId,
      characteristicId: characteristicId,
      value: value,
      timestamp: timestamp,
    ));
  }
}

sealed class BleNearbyEvent {
  final String deviceId;

  BleNearbyEvent(this.deviceId);
}

class OfferReceived extends BleNearbyEvent {
  final String offer;

  OfferReceived(super.deviceId, this.offer);
}

List<Uint8List> packetize(Uint8List data, int packetSize, int msgId) {
  const headerSize = 12;

  if (packetSize <= headerSize) {
    throw ArgumentError.value(
      packetSize,
      'packetSize',
      'Must be greater than $headerSize bytes',
    );
  }

  final payloadSize = packetSize - headerSize;
  final packets = <Uint8List>[];

  for (var offset = 0; offset < data.length; offset += payloadSize) {
    final end = (offset + payloadSize).clamp(0, data.length);
    final payload = Uint8List.sublistView(data, offset, end);
    final packet = Uint8List(headerSize + payload.length);
    final header = ByteData.sublistView(packet);

    header.setUint64(0, msgId, Endian.big);
    header.setUint32(8, offset, Endian.big);

    packet.setRange(headerSize, packet.length, payload);
    packets.add(packet);
  }

  return packets;
}

int generateMsgId() {
  final random = Random.secure();

  return (random.nextInt(1 << 31) << 32) | random.nextInt(1 << 32);
}
