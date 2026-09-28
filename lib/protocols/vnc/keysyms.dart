import 'package:flutter/services.dart';

/// Maps Flutter keys to X11 keysyms for RFB KeyEvent messages.
///
/// Printable latin-1 characters are their own keysym, so the map only
/// needs named keys and function keys.
int? keysymFor(LogicalKeyboardKey key, {String? character}) {
  if (character != null && character.length == 1) {
    final code = character.codeUnitAt(0);
    if (code >= 0x20 && code <= 0xFF) return code;
  }
  if (_named.containsKey(key)) return _named[key];
  // F1..F12 sit contiguously from 0xFFBE in X11.
  final fn = _fKeys.indexOf(key);
  if (fn >= 0) return 0xFFBE + fn;
  return null;
}

final _fKeys = [
  // ignore: prefer_const_declarations
  LogicalKeyboardKey.f1,
  LogicalKeyboardKey.f2,
  LogicalKeyboardKey.f3,
  LogicalKeyboardKey.f4,
  LogicalKeyboardKey.f5,
  LogicalKeyboardKey.f6,
  LogicalKeyboardKey.f7,
  LogicalKeyboardKey.f8,
  LogicalKeyboardKey.f9,
  LogicalKeyboardKey.f10,
  LogicalKeyboardKey.f11,
  LogicalKeyboardKey.f12,
];

final Map<LogicalKeyboardKey, int> _named = {
  LogicalKeyboardKey.shiftLeft: 0xFFE1,
  LogicalKeyboardKey.shiftRight: 0xFFE2,
  LogicalKeyboardKey.controlLeft: 0xFFE3,
  LogicalKeyboardKey.controlRight: 0xFFE4,
  LogicalKeyboardKey.altLeft: 0xFFE9,
  LogicalKeyboardKey.altRight: 0xFFEA,
  LogicalKeyboardKey.metaLeft: 0xFFEB,
  LogicalKeyboardKey.metaRight: 0xFFEC,
  LogicalKeyboardKey.shift: 0xFFE1,
  LogicalKeyboardKey.control: 0xFFE3,
  LogicalKeyboardKey.alt: 0xFFE9,
  LogicalKeyboardKey.meta: 0xFFEB,
  LogicalKeyboardKey.capsLock: 0xFFE5,
  LogicalKeyboardKey.backspace: 0xFF08,
  LogicalKeyboardKey.tab: 0xFF09,
  LogicalKeyboardKey.enter: 0xFF0D,
  LogicalKeyboardKey.escape: 0xFF1B,
  LogicalKeyboardKey.insert: 0xFF63,
  LogicalKeyboardKey.delete: 0xFFFF,
  LogicalKeyboardKey.home: 0xFF50,
  LogicalKeyboardKey.end: 0xFF57,
  LogicalKeyboardKey.pageUp: 0xFF55,
  LogicalKeyboardKey.pageDown: 0xFF56,
  LogicalKeyboardKey.space: 0x20,
  LogicalKeyboardKey.arrowLeft: 0xFF51,
  LogicalKeyboardKey.arrowUp: 0xFF52,
  LogicalKeyboardKey.arrowRight: 0xFF53,
  LogicalKeyboardKey.arrowDown: 0xFF54,
  LogicalKeyboardKey.numLock: 0xFF7F,
  LogicalKeyboardKey.scrollLock: 0xFF14,
  LogicalKeyboardKey.printScreen: 0xFF61,
  LogicalKeyboardKey.pause: 0xFF13,
  LogicalKeyboardKey.contextMenu: 0xFF67,
};
