import 'dart:async';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

StreamController<BleDevice> bleDeviceStreamController =
    StreamController<BleDevice>.broadcast();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // UniversalBle.hasPermissions().then((b) async {
  //   debugPrint('hasPermissions: $b');
  //   if (!b) {
  //     await UniversalBle.requestPermissions();
  //   }
  //   final cap = await UniversalBlePeripheral.getCapabilities();
  //   debugPrint('peripheral mode: ${cap.supportsPeripheralMode}');
  //   if (!cap.supportsPeripheralMode) return;
  //   var as = await UniversalBlePeripheral.getAvailabilityState();
  //   debugPrint('peripheral availability state: $as');
  //   if (as != .ready) {
  //     var i = 0;
  //     while (i < 2 && as != .ready) {
  //       await Future.delayed(Duration(seconds: 1));
  //       as = await UniversalBlePeripheral.getAvailabilityState();
  //       debugPrint('peripheral availability state: $as');
  //       i++;
  //     }
  //     if (as != .ready) return;
  //   }
  //
  //   await UniversalBlePeripheral.addService(
  //     BlePeripheralService(
  //       uuid: bleServiceID,
  //       characteristics: [
  //         BlePeripheralCharacteristic(
  //           uuid: bleWrite,
  //           properties: [.write],
  //           permissions: [.writeable],
  //         ),
  //         BlePeripheralCharacteristic(
  //           uuid: bleNotify,
  //           properties: [.notify],
  //           permissions: [],
  //         ),
  //       ],
  //     ),
  //   );
  //   debugPrint('service added');
  // });
  // UniversalBle.onAvailabilityChange = onAvailabilityChange;

  // UniversalBle.availabilityStream.listen((s) async {
  //   if (s != .poweredOn) return;
  //   debugPrint('powered on');
  //   UniversalBle.scanStream.listen(bleDeviceStreamController.add);
  //   await UniversalBle.startScan();
  // });

  // () async {
  //   await for (var i in UniversalBle.availabilityStream) {
  //     debugPrint('availability state: $i');
  //     if (i == .poweredOn) {
  //       break;
  //     }
  //   }
  //   final cap = await UniversalBlePeripheral.getCapabilities();
  //   debugPrint(
  //     'capabilities supportsPeripheralMode: ${cap.supportsPeripheralMode}',
  //   );
  //   if (!cap.supportsPeripheralMode) return;
  //   for (
  //     var r = await UniversalBlePeripheral.getAvailabilityState();
  //     r != .ready;
  //   ) {
  //     debugPrint('peripheral availability state: $r');
  //     await Future.delayed(Duration(seconds: 1));
  //     r = await UniversalBlePeripheral.getAvailabilityState();
  //   }
  //   var r = await UniversalBlePeripheral.getAvailabilityState();
  //   debugPrint('peripheral availability state: $r');
  // }();
  var notify = 0;
  bleDeviceStreamController.stream.listen((event) {
    notify++;
    debugPrint('notify: $notify');
  });
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: .dark,
      home: Scaffold(
        appBar: AppBar(),
        body: StreamBuilder(
          stream: bleDeviceStreamController.stream,
          builder: (context, snapshot) {
            return Text(snapshot.data.toString());
          },
        ),
      ),
    );
  }
}
