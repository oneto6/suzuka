import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suzuka/feature/advertise_nearby_device.dart';

// import 'package:flutter_test/flutter_test.dart';

class AdvertiseNearbyDevice extends ConsumerWidget {
  const AdvertiseNearbyDevice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(advertiseNearbyDeviceProvider);
    return Scaffold(
      appBar: switch (state) {
        // StateConnected(:final id) => AppBar(title: Text(id)),
        _ => null,
      },
      body: switch (state) {
        StatePermissionDenied() => Center(child: Text('Permission Denied')),
        StateBluetoothTurnedOff() => Center(
          child: Text('Bluetooth Turned Off'),
        ),
        StateAvailable() => Center(child: Text('Advertising')),
      },
    );
  }
}
