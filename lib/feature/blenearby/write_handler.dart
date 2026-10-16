import 'dart:async';
import 'dart:convert';

import 'package:ble_peripheral_plus/ble_peripheral.dart' as peripheral;
import 'package:flutter/foundation.dart';
import 'package:suzuka/core/config.dart';
import 'package:suzuka/feature/blenearby/repo.dart';

//size, index, data

final store = <(String, int), Uint8List>{};

class WriteHandler {
  BleNearbyRepo bleNearbyRepo;

  StreamController<BleNearbyEvent> eventStreamController;

  WriteHandler(this.bleNearbyRepo, this.eventStreamController);
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
