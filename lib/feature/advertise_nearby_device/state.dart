sealed class AdvertiseNearbyDeviceState {}

class StatePermissionDenied extends AdvertiseNearbyDeviceState {}

class StateBluetoothTurnedOff extends AdvertiseNearbyDeviceState {}

class StateAvailable extends AdvertiseNearbyDeviceState {
  final bool advertisement;
  final Set<String>? discovery;

  StateAvailable(this.advertisement, this.discovery);

  AdvertiseNearbyDeviceState copyWith({
    bool? advertisement,
    Set<String>? Function()? discovery,
  }) {
    return StateAvailable(
      advertisement ?? this.advertisement,
      discovery == null ? this.discovery : discovery(),
    );
  }
}
