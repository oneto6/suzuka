sealed class Peer {}

sealed class StateInit extends Peer {}

class Init extends StateInit {}

class Ready extends StateInit {}

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
