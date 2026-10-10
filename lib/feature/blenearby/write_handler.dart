import 'dart:convert';

import 'package:ble_peripheral_plus/ble_peripheral.dart' as peripheral;
import 'package:flutter/foundation.dart';
import 'package:suzuka/core/config.dart';
import 'package:suzuka/feature/blenearby/repo.dart';

//size, index, data
class EntryStore {
  int size;
  int index;
  Uint8List data;
  EntryStore(this.size, this.index, this.data);
}

final store = <String, EntryStore>{};

class WriteHandler {
  BleNearbyRepo bleNearbyRepo;

  WriteHandler(this.bleNearbyRepo);

  peripheral.WriteRequestResult? handler(
    String deviceId,
    String characteristicId,
    int offset,
    Uint8List? value,
  ) {
    if (value == null) return null;

    switch (characteristicId) {
      case bleWrite:
        debugPrint('writeHandle(bleWrite)');

        final d = jsonDecode(utf8.decode(value));
        if (d is! Map<String, dynamic>) return null;

        final length = d['length'];
        if (length is! int || length <= 0 || length > 16 * 1024) {
          return null;
        }
        debugPrint('length: $length');

        store[deviceId] = EntryStore(length, 0, Uint8List(length));
        return null;

      case bleChunkWrite:
        debugPrint('writeHandle(bleChunkWrite)');

        final e = store[deviceId];
        if (e == null) return null;
        debugPrint('chunk length: ${value.length}');

        // Prevent writing beyond the allocated buffer.
        if (e.index + value.length > e.size) {
          store.remove(deviceId);
          return null;
        }

        e.data.setRange(e.index, e.index + value.length, value);
        e.index += value.length;

        debugPrint('e.index < e.size: ${e.index < e.size}');
        if (e.index < e.size) {
          return null;
        }
        debugPrint(
          'offerReceivedCallback: $deviceId, offerReceivedCallback == null: ${this.offerReceivedCallback == null},  hashcode: ${offerReceivedCallback.hashCode}',
        );
        offerReceivedCallback?.call(deviceId, utf8.decode(e.data));
        store.remove(deviceId);
        return null;
    }

    return null;
  }
}
// debugPrint('writeHandle');
// if (value == null) {
//   bleNearbyRepo._offerReceivedCallback?.call(deviceId, null);
//   return null;
// }
// final offer = utf8.decode(value);
// debugPrint('write handler offer: $offer ');
//
// _offerReceivedCallback?.call(deviceId, offer);
// return null;
