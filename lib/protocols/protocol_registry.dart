import '../models/machine.dart';
import '../models/protocol_kind.dart';
import 'protocol_driver.dart';
import 'remote_session.dart';
import 'ssh/ssh_driver.dart';
import 'vnc/rfb_client.dart';
import 'vnc/vnc_driver.dart';

/// Placeholder driver for protocols that are modeled but not
/// implemented yet. Machines can still advertise the capability, the
/// editor can configure it, and the connect sheet greys it out with
/// [comingSoonNote]. Swap in a real driver when it lands.
class PlannedDriver extends ProtocolDriver {
  PlannedDriver(this.kind, this.comingSoonNote);

  @override
  final ProtocolKind kind;

  @override
  bool get isImplemented => false;

  @override
  final String comingSoonNote;

  @override
  Future<RemoteSession> connect(
          Machine machine, Map<String, String> secrets) =>
      Future.error(UnsupportedError('${kind.label} is not supported yet'));
}

/// Maps each [ProtocolKind] to its driver. Everything protocol-agnostic
/// in the app (connect sheet, session routing, capability badges) goes
/// through here, so a new protocol registers once and is done.
class ProtocolRegistry {
  ProtocolRegistry({
    SshSocketConnector? sshConnector,
    PrivateKeyLoader? keyLoader,
    HostKeyVerifier? hostKeyVerifier,
    SocketConnector? vncConnector,
  }) : drivers = {
          ProtocolKind.ssh: SshDriver(
            socketConnector: sshConnector,
            privateKeyLoader: keyLoader,
            hostKeyVerifier: hostKeyVerifier,
          ),
          ProtocolKind.vnc: VncDriver(connector: vncConnector),
          ProtocolKind.rdp: PlannedDriver(
            ProtocolKind.rdp,
            'RDP support is planned. The protocol is already modeled, so '
            'this machine keeps its settings until the driver ships.',
          ),
          ProtocolKind.moonlight: PlannedDriver(
            ProtocolKind.moonlight,
            'Moonlight/Sunshine streaming is planned. Keep the pairing '
            'details here for when the driver ships.',
          ),
        };

  final Map<ProtocolKind, ProtocolDriver> drivers;

  ProtocolDriver driverFor(ProtocolKind kind) => drivers[kind]!;
}
