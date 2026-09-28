import 'dart:async';

import '../../models/capability.dart';
import '../../models/machine.dart';
import '../../models/protocol_kind.dart';
import '../remote_session.dart';
import 'rfb_client.dart';

/// A live VNC connection. The UI binds to [client.pixels] +
/// [client.frames] and forwards input through the send* methods.
class VncSession extends RemoteSession {
  VncSession(Machine machine, this.client) : super(machine, ProtocolKind.vnc) {
    _sub = client.events.listen((e) {
      switch (e.state) {
        case RfbState.connecting:
          break;
        case RfbState.connected:
          emit(SessionPhase.connected);
        case RfbState.failed:
          emit(SessionPhase.failed, e.message);
        case RfbState.closed:
          emit(SessionPhase.closed);
      }
    });
  }

  final RfbClient client;
  late final StreamSubscription _sub;

  VncConfig get config => machine.configFor(ProtocolKind.vnc) as VncConfig;

  @override
  Future<void> close() async {
    await _sub.cancel();
    await client.close();
    emit(SessionPhase.closed);
  }
}
