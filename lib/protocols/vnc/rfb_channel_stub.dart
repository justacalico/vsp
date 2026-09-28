import 'rfb_channel.dart';

SocketConnector get platformConnector => (host, port) => Future.error(
    UnsupportedError('Raw sockets are not available on web'));
