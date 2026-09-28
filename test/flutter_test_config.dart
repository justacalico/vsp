import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled Inter faces plus MaterialIcons so golden tests
/// render the same typography and icons as the app on every host.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final loader = FontLoader('Inter');
  for (final name in [
    'Inter-Regular.otf',
    'Inter-Medium.otf',
    'Inter-SemiBold.otf',
    'Inter-Bold.otf',
  ]) {
    loader.addFont(File('assets/fonts/$name').readAsBytes()
        .then((b) => ByteData.view(b.buffer)));
  }
  await loader.load();
  // Icons ship in the SDK, not the bundle — register the family.
  final sdkFonts = Platform.environment['FLUTTER_ROOT']!;
  final icons = FontLoader('MaterialIcons')
    ..addFont(File('$sdkFonts/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
        .readAsBytes()
        .then((b) => ByteData.view(b.buffer)));
  await icons.load();
  final mono = FontLoader('JetBrains Mono')
    ..addFont(File('assets/fonts/JetBrainsMono-Regular.ttf')
        .readAsBytes()
        .then((b) => ByteData.view(b.buffer)));
  await mono.load();
  await testMain();
}
