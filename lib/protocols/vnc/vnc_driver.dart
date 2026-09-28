import 'dart:async';

import '../../models/capability.dart';
import '../../models/machine.dart';
import '../../models/protocol_kind.dart';
import '../protocol_driver.dart';
import '../remote_session.dart';
import 'rfb_client.dart';
import 'vnc_session.dart';

class VncDriver extends ProtocolDriver {
  VncDriver({this.connector});

  /// Injectable socket factory for tests.
  final SocketConnector? connector;

  @override
  ProtocolKind get kind => ProtocolKind.vnc;

  @override
  Future<RemoteSession> connect(
      Machine machine, Map<String, String> secrets) async {
    final config = machine.configFor(ProtocolKind.vnc) as VncConfig;
    final client = RfbClient(
      host: machine.host,
      port: config.port,
      password: secrets['vnc.password'],
      shared: config.shared,
      connector: connector,
    );
    final session = VncSession(machine, client);
    unawaited(client.connect().catchError((_) => client.close()));
    return session;
  }
}
