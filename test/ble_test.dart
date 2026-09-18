import 'package:flutter/material.dart';
// import 'package:flutter_test/flutter_test.dart';

import 'package:suzuka/main.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  UniversalBle.scanStream.listen(listner);
}

void listner(BleDevice event) {
  debugPrint('bleDevice event: ${event.toString()}');
}
