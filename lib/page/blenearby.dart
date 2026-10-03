import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suzuka/feature/blenearby/provider.dart';
import 'package:suzuka/feature/blenearby/state.dart';
import 'package:suzuka/feature/blenearbyAction/provider.dart';
import 'package:suzuka/page/bridge.dart';

class BleNearby extends ConsumerStatefulWidget {
  const BleNearby({super.key});

  @override
  ConsumerState<BleNearby> createState() => _BleNearbyState();
}

class _BleNearbyState extends ConsumerState<BleNearby> {
  @override
  Widget build(BuildContext context) {
    ref.listen<BlenearbyAction?>(
      blenearbyActionProvider.select((s) => s.value),
      listener,
    );
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
                          await ref
                              .read(bleNearbyProvider.notifier)
                              .connectDevice(discovery.elementAt(index));
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

  void listener(BlenearbyAction? previous, BlenearbyAction? next) {
    if (next == null) return;
    switch (next) {
      case OfferRequested(:final deviceId):
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: ((context) => Bridge(NegotiationRole.create(deviceId))),
          ),
        );
      case OfferReceived(:final deviceId, :final peerOffer):
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: ((context) =>
                Bridge(NegotiationRole.create(deviceId, peerOffer))),
          ),
        );
    }
  }
}
