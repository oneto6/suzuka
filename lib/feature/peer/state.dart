sealed class Peer {}

class Init extends Peer {}

sealed class Negotiation extends Peer {}

class Host extends Negotiation {}

class Client extends Negotiation {}

class Failed extends Negotiation {
  final String peerSDP;

  Failed(this.peerSDP);
}

class Connected extends Peer {
  Connected();
}

class Disconnected extends Peer {
  final Object reason;

  Disconnected(this.reason);
}
