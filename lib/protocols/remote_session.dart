import 'dart:async';

import '../models/machine.dart';
import '../models/protocol_kind.dart';

enum SessionPhase { connecting, connected, failed, closed }

class SessionStatus {
  const SessionStatus(this.phase, [this.message]);

  final SessionPhase phase;
  final String? message;
}

/// A live connection to a machine over one protocol. Each driver
/// returns its own subclass exposing whatever the UI needs (a terminal,
/// a framebuffer, a file browser).
abstract class RemoteSession {
  RemoteSession(this.machine, this.kind);

  final Machine machine;
  final ProtocolKind kind;

  final _status = StreamController<SessionStatus>.broadcast();
  SessionPhase phase = SessionPhase.connecting;

  Stream<SessionStatus> get status => _status.stream;

  void emit(SessionPhase phase, [String? message]) {
    this.phase = phase;
    if (!_status.isClosed) _status.add(SessionStatus(phase, message));
  }

  Future<void> close();

  Future<void> dispose() async {
    await close();
    // Listeners get done on the event loop's schedule; a waiting
    // StreamBuilder would otherwise hold this open.
    if (!_status.isClosed) unawaited(_status.close());
  }
}
