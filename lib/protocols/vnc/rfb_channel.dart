import 'dart:async';
import 'dart:typed_data';

import 'rfb_channel_stub.dart'
    if (dart.library.io) 'rfb_channel_io.dart';

/// Byte stream the RFB client talks over. Backed by a dart:io [Socket]
/// on native builds; the web build (landing page only) gets a stub that
/// throws — protocol drivers never run there.
abstract class RfbChannel {
  Stream<Uint8List> get stream;
  void add(List<int> bytes);
  Future<void> close();
}

typedef SocketConnector = Future<RfbChannel> Function(String host, int port);

/// Platform default connector: real TCP on native, throws on web.
SocketConnector get defaultConnector => platformConnector;
