import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'rfb_channel.dart';

SocketConnector get platformConnector => (host, port) async {
      final socket = await Socket.connect(host, port);
      return _IoRfbChannel(socket);
    };

class _IoRfbChannel implements RfbChannel {
  _IoRfbChannel(this._socket);

  final Socket _socket;

  @override
  Stream<Uint8List> get stream => _socket;

  @override
  void add(List<int> bytes) => _socket.add(bytes);

  @override
  Future<void> close() => _socket.close();
}
