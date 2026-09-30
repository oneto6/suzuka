sealed class BleNearybyState {}

class StateInitial extends BleNearybyState {}

class StatePermissionDenied extends BleNearybyState {}

class StateBluetoothTurnedOff extends BleNearybyState {}

class StateAvailable extends BleNearybyState {
  final String? service;
  final bool advertisement;
  final Set<String>? discovery;

  StateAvailable.name(this.service, this.advertisement, this.discovery);

  StateAvailable copyWith({
    String? service,
    bool? advertisement,
    Set<String>? Function()? discovery,
  }) {
    return StateAvailable.name(
      service ?? this.service,
      advertisement ?? this.advertisement,
      discovery == null ? this.discovery : discovery(),
    );
  }

  @override
  toString() {
    return 'StateAvailable{advertisement: $advertisement, discovery: $discovery}';
  }
}

enum UnauthorizedSubState { off, on }

sealed class BleState {
  const BleState();
}

class BleInitial extends BleState {
  const BleInitial();
}

class BleOn extends BleState {
  const BleOn();
}

class BleOff extends BleState {
  const BleOff();
}

class BleUnauthorized extends BleState {
  final UnauthorizedSubState subState;
  const BleUnauthorized(this.subState);
}
