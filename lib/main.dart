import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:window_manager/window_manager.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/database/cache_database.dart';
import 'core/errors/app_error_handler.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/semester_provider.dart';
import 'core/routes/app_router.dart';
import 'core/services/google_auth_service.dart';
import 'core/themes/app_theme.dart';
import 'core/utils/app_time.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Desktop platforms need the FFI-based SQLite; Android/iOS have native sqflite.
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    // Initialize window_manager for custom title bar
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 720),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden, // Hides the native "island" title bar
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // ── Parallel startup ────────────────────────────────────────────────
  // CacheDatabase is local and fast, safe to await before runApp.
  await CacheDatabase().init();

  // AppTime.sync() makes an HTTP request. Run it in the background to prevent
  // blocking runApp() for up to 5 seconds on slow networks.
  unawaited(AppTime.sync());

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── Drive restore in background ─────────────────────────────────────
  // Don't block runApp on Firebase auth or Drive restore.
  // Instead, launch a background async task that waits for the first auth
  // resolution, then restores Drive.
  unawaited(() async {
    // Wait up to 2 seconds for Firebase Auth to fully restore its persisted session from disk.
    // If we don't wait for the initial cache load, currentUser might be temporarily null
    // which would cause restoreDriveSession to prematurely abort.
    await FirebaseAuth.instance
        .authStateChanges()
        .where((user) => user != null)
        .first
        .timeout(const Duration(seconds: 2), onTimeout: () => null);

    // On Android: calls signInSilently() which can take 2-6 seconds.
    // On Windows: reads auth.json + calls Google token endpoint (~1s).
    await GoogleAuthService().restoreDriveSession();
  }());

  runApp(const ProviderScope(child: ScopusApp()));
}

/// Root application widget.
///
/// Converted to [ConsumerStatefulWidget] so it can listen to auth and
/// semester state changes and notify GoRouter to re-evaluate its redirect.
class ScopusApp extends ConsumerStatefulWidget {
  const ScopusApp({super.key});

  @override
  ConsumerState<ScopusApp> createState() => _ScopusAppState();
}

class _ScopusAppState extends ConsumerState<ScopusApp> {
  /// Single ChangeNotifier that GoRouter listens to for refreshes.
  /// We notify it whenever auth state OR active semester state changes.
  late final _RouterNotifier _notifier;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _notifier = _RouterNotifier();
    _router = AppRouter.create(_notifier);
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Drive GoRouter re-evaluation when auth or semester state changes.
    ref.listen(authStateProvider, (previous, next) => _notifier.notify());
    ref.listen(activeSemesterProvider, (previous, next) => _notifier.notify());

    return MaterialApp.router(
      title: 'Scopus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkAcademicTheme,
      routerConfig: _router,
      scaffoldMessengerKey: AppErrorHandler.scaffoldMessengerKey,
      builder: (context, child) {
        if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
          return child!;
        }
        // Custom seamless title bar for desktop
        return Scaffold(
          backgroundColor: const Color(0xFF323339), // Background color matching the top bar
          // Placing WindowCaption in appBar safely limits its height to 46.0 pixels!
          appBar: const PreferredSize(
            preferredSize: Size.fromHeight(32.0),
            child: WindowCaption(
              brightness: Brightness.dark,
              backgroundColor: Color(0xFF323339), // Custom #323339 title bar
            ),
          ),
          body: child!,
        );
      },
    );
  }
}

/// Thin [ChangeNotifier] that GoRouter uses as its [refreshListenable].
class _RouterNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
