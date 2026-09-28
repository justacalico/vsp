import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'ui/home_screen.dart';
import 'ui/landing_screen.dart';
import 'ui/theme.dart';

/// Root widget. [state] is created once in `main()` above the app, so a
/// hot restart keeps nothing but a window resize keeps everything.
class VspApp extends StatelessWidget {
  const VspApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        title: 'VSP',
        debugShowCheckedModeBanner: false,
        theme: VspTheme.light(),
        darkTheme: VspTheme.dark(),
        themeMode: ThemeMode.system,
        // Web is a landing page only — the client itself is native.
        home: kIsWeb ? const LandingScreen() : const HomeScreen(),
      ),
    );
  }
}
