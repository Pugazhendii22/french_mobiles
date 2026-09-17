import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase/catalog_firebase.dart';
import 'features/home/pages/home_page.dart';
import 'shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  try {
    await Firebase.initializeApp(options: catalogFirebaseOptions);
  } catch (_) {
    // Firebase unavailable (e.g. missing web config); app still renders.
  }
  try {
    await initializeCatalogApp();
  } catch (_) {
    // Secondary app failed to init; fall back to the default app.
  }
  try {
    await GoogleSignIn.instance.initialize(
      serverClientId: '1086357315686-gd3cjbuqqll9umc7peffkd04laiq6hmt.apps.googleusercontent.com',
    );
  } catch (_) {
    // Google Sign-In unavailable; app still renders.
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.home});

  /// Replaces the home screen.
  ///
  /// Only for tests: the real one reads Firebase on its first frame, so the
  /// app shell cannot otherwise be built without it.
  @visibleForTesting
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Trade-In App Flow',
      // The design system, applied once. Screens used to wrap themselves in
      // AppTheme.light individually because MaterialApp still carried the
      // original inline theme; those wrappers are now redundant rather than
      // load-bearing, and the screens that never had one — the checkup
      // flow — stop inheriting black-on-green buttons and a white page.
      theme: AppTheme.light,
      home: home ?? const HomePage(),
    );
  }
}
