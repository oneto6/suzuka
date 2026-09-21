import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suzuka/feature/nearby_device.dart';

class NearybyDevice extends ConsumerWidget {
  const NearybyDevice({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final state = ref.watch(nearbyDeviceProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Nearby Devices')),
      body: switch (state) {
        PermissionRequredState() => const Center(
          child: Text('Permission denied'),
        ),
        TurnOnBluetoothState() => const Center(
          child: Text('Turn on bluetooth'),
        ),
        DeviceListState(:final device) => ListView.builder(
          itemCount: device.length,
          itemBuilder: (context, index) {
            return ListTile(
              onTap: () => ref
                  .read(nearbyDeviceProvider.notifier)
                  .connectDevice(device[index]),
              title: Text(device[index].name ?? device[index].id),
            );
          },
        ),
      },
    );
  }
}
