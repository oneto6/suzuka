import 'dart:async';
import 'dart:convert';
import 'package:ble_peripheral_plus/ble_peripheral.dart' as peripheral;
import 'package:flutter/foundation.dart';
import 'package:suzuka/core/config.dart';
import 'package:suzuka/feature/blenearby/repo.dart';

class HostComposetion {
  BleNearbyRepo repo;
  final store = <(String, int), Uint8List>{};

  StreamController<BleNearbyEvent> eventStreamController;

  HostComposetion(this.repo, this.eventStreamController);

  Future<void> sendAnswerOffer(String deviceId, String data) async {
    await peripheral.BlePeripheral.updateCharacteristic(
      characteristicId: bleNotify,
      value: utf8.encode(data),
      deviceId: deviceId,
    );
  }

  Null _writeHandler(
    String deviceId,
    String characteristicId,
    int offset,
    Uint8List? value,
  ) {
    if (value == null) throw 'value is null';

    switch (characteristicId) {
      case bleWrite:
        debugPrint('writeHandle(bleWrite)');

        final d = jsonDecode(utf8.decode(value));
        if (d is! Map<String, dynamic>) throw 'd is not Map<String, dynamic>';

        final length = d['length'];
        if (length is! int || length <= 0 || length > 16 * 1024) {
          throw 'length is not int or length <= 0 or length > 16 * 1024';
        }
        final type = d['type'];
        final msgId = d['msgID'];
        if (type == null || msgId == null) throw 'type or msgId is null';
        debugPrint('length: $length');
        switch (type) {
          case 'msg-init':
            store[(deviceId, msgId)] = Uint8List(length);
          case 'msg-end':
            final uint8List = store[(deviceId, msgId)];
            if (uint8List == null) throw 'uint8List is null';
            store.remove((deviceId, msgId));
            eventStreamController.add(
              OfferReceived(deviceId, utf8.decode(uint8List)),
            );
          default:
            throw 'type is not msg-init or msg-end';
        }

      case bleChunkWrite:
        debugPrint('writeHandle(bleChunkWrite)');

        final header = ByteData.sublistView(value, 0, 12);
        final msgId = header.getUint64(0, Endian.big);
        final offset = header.getUint32(8, Endian.big);
        final payload = value.sublist(12);
        final uint8list = store[(deviceId, msgId)];
        if (uint8list == null) throw 'uint8list is null';
        uint8list.setRange(offset, offset + payload.length, payload);

        debugPrint(
          'chunk length: ${value.length}, offset: $offset, msgId: $msgId',
        );

      default:
        throw 'characteristicId is not bleWrite or bleChunkWrite';
    }
    return null;
  }

  Null writeHandler(
    String deviceId,
    String characteristicId,
    int offset,
    Uint8List? value,
  ) {
    try {
      return _writeHandler(deviceId, characteristicId, offset, value);
    } catch (e) {
      debugPrint('writeHandler err: $e');
      return null;
    }
  }
}
