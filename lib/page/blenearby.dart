import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suzuka/feature/blenearby/provider.dart';
import 'package:suzuka/feature/blenearby/state.dart';
import 'package:suzuka/page/bridge.dart';

class BleNearby extends ConsumerWidget {
  const BleNearby({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bleNearbyProvider);
    return Scaffold(
      appBar: switch (state) {
        StateAvailable() => AppBar(title: Text('Available')),

        _ => null,
      },
      body: switch (state) {
        StateInitial() => Center(child: Text('Initial')),
        StatePermissionDenied() => Center(child: Text('Permission Denied')),
        StateBluetoothTurnedOff() => Center(
          child: Text('Bluetooth Turned Off'),
        ),
        StateAvailable(
          :final service,
          :final advertisement,
          :final discovery,
        ) =>
          Column(
            children: [
              Expanded(
                child: SizedBox.square(
                  child: Center(
                    child: Text(
                      (advertisement && service != null)
                          ? 'Advertising'
                          : 'No Advertising',
                    ),
                  ),
                ),
              ),
              if (discovery == null) Text('No discovery'),
              if (discovery != null)
                Expanded(
                  child: ListView.builder(
                    itemCount: discovery.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        onTap: () async {
                          final offer = await ref
                              .read(bleNearbyProvider.notifier)
                              .connectDevice(discovery.elementAt(index));

                          if (offer == null) return;
                          void func(_) => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: ((context) =>
                                  Bridge(ClientNegotiationRole(offer))),
                            ),
                          );
                          if (context.mounted) {
                            func(null);
                          }
                          WidgetsBinding.instance.addPostFrameCallback(func);
                        },
                        title: Text(discovery.elementAt(index)),
                      );
                    },
                  ),
                ),
            ],
          ),
      },
    );
  }
}
