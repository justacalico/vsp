import '../models/machine.dart';
import '../models/protocol_kind.dart';
import 'remote_session.dart';

/// Driver interface every protocol implements. [connect] receives the
/// machine plus its already-unlocked secret map (empty for machines
/// with no secrets) and returns a live session.
abstract class ProtocolDriver {
  ProtocolKind get kind;

  /// False for protocols that are modeled but not wired up yet.
  bool get isImplemented => true;

  /// Longer text for the connect sheet when [isImplemented] is false.
  String get comingSoonNote => '';

  Future<RemoteSession> connect(Machine machine, Map<String, String> secrets);
}
