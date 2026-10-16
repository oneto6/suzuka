import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:suzuka/core/config.dart';
import 'package:suzuka/feature/blenearby/repo.dart';
import 'package:universal_ble/universal_ble.dart';

class ClientComposetion {
  final BleNearbyRepo bleNearbyRepo;
  final StreamController<DataStreamParams> _dataStream;

  ClientComposetion(this.bleNearbyRepo, this._dataStream);

  Future<String?> sendOffer(String deviceId, String offer) async {
    try {
      await UniversalBle.connect(deviceId);
    } catch (e) {
      debugPrint('connect device err: ${e.toString()}');
      return null;
    }
    final data = await _sendOffer(deviceId, offer);
    await UniversalBle.disconnect(deviceId);
    return data;
  }

  Future<String?> _sendOffer(String deviceId, String offer) async {
    final dataTransaction = Completer<List<int>>();
    await UniversalBle.pair(deviceId);
    debugPrint('_sendOffer');

    BleConnectionState s = await UniversalBle.getConnectionState(deviceId);
    debugPrint('connection state: $s');

    final store = <(String, int), Uint8List>{};
    final sub = listner(deviceId, store, dataTransaction);
    final g = await getServiceChar(deviceId);
    if (g == null) return null;
    final (service, notifyChar, writeChar, writeChunkChar) = g;
    await UniversalBle.subscribeNotifications(
      deviceId,
      service.uuid,
      notifyChar.uuid,
    );
    await handleSendOffer(offer, deviceId, service, writeChar, writeChunkChar);
    final recivedOffer = await dataTransaction.future;
    sub.cancel();
    await UniversalBle.unsubscribe(deviceId, service.uuid, notifyChar.uuid);
    return utf8.decode(recivedOffer);
  }

  Future<void> handleSendOffer(
    String offer,
    String deviceId,
    BleService service,
    BleCharacteristic writeChar,
    BleCharacteristic writeChunkChar,
  ) async {
    final data = utf8.encode(offer);
    final msgId = generateMsgId();
    debugPrint('sent offer length: ${data.length}, msgId: $msgId');
    await UniversalBle.write(
      deviceId,
      service.uuid,
      writeChar.uuid,
      utf8.encode(
        json.encode({
          "msgID": msgId,
          "type": "msg-init",
          "length": data.length,
        }),
      ),
    );
    final mtu = await UniversalBle.requestMtu(deviceId, 512 + 3);
    for (final i in packetize(data, mtu - 3, msgId)) {
      await UniversalBle.write(
        deviceId,
        service.uuid,
        writeChunkChar.uuid,
        i,
        // withoutResponse: true,
      );
    }
    await UniversalBle.write(
      deviceId,
      service.uuid,
      writeChar.uuid,
      utf8.encode(
        json.encode({"msgID": msgId, "type": "msg-end", "length": data.length}),
      ),
    );
  }

  StreamSubscription<DataStreamParams> listner(
    String deviceId,
    Map<(String, int), Uint8List> store,
    Completer<List<int>> dataTransaction,
  ) {
    return _dataStream.stream
        .where((event) => event.deviceId == deviceId)
        .listen((e) {
          debugPrint(
            'listner  deviceId: ${e.deviceId}, data: ${utf8.decode(e.value)}',
          );
          switch (e.characteristicId.toLowerCase()) {
            case bleWrite:
              final d = jsonDecode(utf8.decode(e.value));
              if (d is! Map<String, dynamic>) return;
              final type = d['type'];
              final length = d['length'];
              final msgId = d['msgID'];
              if (length is! int || msgId is! int) return;
              if (type == 'msg-init') {
                store[(deviceId, msgId)] = Uint8List(length);
              } else if (type == 'msg-end') {
                final uint8List = store[(deviceId, msgId)];
                if (uint8List == null) return;
                dataTransaction.complete(uint8List);
              }
              break;
            case bleChunkWrite:
              final header = ByteData.sublistView(e.value, 0, 12);
              final msgID = header.getUint64(0, Endian.big);
              final offset = header.getUint32(8, Endian.big);
              final payload = e.value.sublist(12);
              final v = store[(deviceId, msgID)];
              if (v == null) return;
              v.setRange(offset, offset + payload.length, payload);
          }
        });
  }
}

Future<(BleService, BleCharacteristic, BleCharacteristic, BleCharacteristic)?>
getServiceChar(String deviceId) async {
  BleService? service;
  BleCharacteristic? notifyChar;
  BleCharacteristic? writeChar;
  BleCharacteristic? writeChunkChar;

  for (final s in await UniversalBle.discoverServices(deviceId)) {
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

    if (characteristic.uuid.toLowerCase() == bleChunkWrite.toLowerCase()) {
      writeChunkChar = characteristic;
    }
  }

  if (notifyChar == null || writeChar == null || writeChunkChar == null) {
    return null;
  }
  return (service, notifyChar, writeChar, writeChunkChar);
}
