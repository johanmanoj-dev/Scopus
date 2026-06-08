import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../errors/app_exception.dart';
import '../errors/app_error_handler.dart';
import '../../models/auth_user.dart';
import 'drive_service.dart';
import 'firestore_service.dart';

/// Handles all Google Sign-In and Firebase Authentication for Scopus.
///
/// Auth flow:
///   1. Desktop OAuth client opens browser — Desktop clients ALWAYS return a
///      refresh_token (no Google restriction), unlike Web clients.
///   2. clientViaUserConsent exchanges code → AutoRefreshingAuthClient
///      (access token auto-refreshes every hour, no manual work needed)
///   3. Refresh token stored in flutter_secure_storage (Windows DPAPI)
///   4. Firebase signInWithCredential(accessToken) establishes Firebase session
///   5. On app restart: restoreDriveSession() silently rebuilds Drive client
///      from the stored refresh token — no browser prompt needed
class GoogleAuthService {
  // ── OAuth Client (Desktop) ─────────────────────────────────────
  // MUST use a Desktop application client (not Web) so that Google
  // reliably returns a refresh_token in the localhost PKCE flow.
  // Web clients in desktop redirect flows may silently omit the refresh_token.
  //
  // Create at: console.cloud.google.com → APIs & Services → Credentials
  //   → + Create Credentials → OAuth 2.0 Client ID → Desktop app
  static ClientId get _clientId => ClientId(
    dotenv.env['GOOGLE_CLIENT_ID']!,
    dotenv.env['GOOGLE_CLIENT_SECRET']!,
  );

  /// Custom HTML page shown in the browser after the OAuth flow completes.
  /// We load the logo dynamically from the assets folder (assets/images/logo.png)
  /// to avoid a giant 500KB base64 string in code.
  static Future<String> _getPostAuthPage() async {
    String base64Logo = "";
    try {
      final ByteData data = await rootBundle.load('assets/images/logo.png');
      base64Logo = base64Encode(data.buffer.asUint8List());
    } catch (e) {
      print('Could not load logo for post auth page: $e');
    }

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Scopus Login Success</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      background: #0a0a0a;
      color: #ffffff;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
    }
    .container {
      text-align: center;
      padding: 48px;
      animation: fadeIn 0.5s ease-in-out;
    }
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(12px); }
      to { opacity: 1; transform: translateY(0); }
    }
    .logo {
      width: 80px;
      height: 80px;
      background: #111;
      border-radius: 22px;
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 0 auto 28px;
      border: 1px solid rgba(255,255,255,0.08);
    }
    .logo img { width: 48px; height: 48px; }
    .check-ring {
      width: 52px;
      height: 52px;
      border-radius: 50%;
      border: 2px solid #22c55e;
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 0 auto 24px;
      animation: pop 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275) 0.2s both;
    }
    @keyframes pop {
      from { opacity: 0; transform: scale(0.6); }
      to { opacity: 1; transform: scale(1); }
    }
    h1 {
      font-size: 22px;
      font-weight: 600;
      letter-spacing: -0.3px;
      margin-bottom: 10px;
    }
    p {
      font-size: 14px;
      color: #6b7280;
      line-height: 1.6;
    }
    .divider {
      width: 40px;
      height: 1px;
      background: rgba(255,255,255,0.08);
      margin: 28px auto;
    }
    .app-name {
      font-size: 11px;
      letter-spacing: 2px;
      text-transform: uppercase;
      color: #374151;
    }
  </style>
  <link rel="icon" type="image/png" href="data:image/png;base64,$base64Logo" />
</head>
<body>
  <div class="container">
    <div class="logo">
      <img src="data:image/png;base64,$base64Logo" alt="Scopus Logo" />
    </div>
    <div class="check-ring">
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#22c55e" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
        <polyline points="20 6 9 17 4 12"></polyline>
      </svg>
    </div>
    <h1>Login Success</h1>
    <p>You have successfully signed in.<br>You can safely close this window.</p>
    <div class="divider"></div>
    <div class="app-name">Scopus</div>
  </div>
  <script>
    setTimeout(() => {
      window.close();
    }, 5000);
  </script>
</body>
</html>
''';
  }

  // email + profile → user identity
  // openid → idToken for Firebase Auth
  // drive.file → ONLY files/folders the app itself creates (least privilege)
  static const List<String> _scopes = [
    'openid',
    'email',
    'profile',
    'https://www.googleapis.com/auth/drive.file',
  ];

  // ── Android Google Sign-In ─────────────────────────────────────
  // Native account picker on Android — no browser, no localhost server.
  // Session persistence and token refresh are managed internally by GoogleSignIn.
  //
  // serverClientId MUST be the Web OAuth client ID from google-services.json
  // (client_type: 3). Without it, Google Play Services throws Error 10
  // (DEVELOPER_ERROR) because it can't validate which server to authenticate for.
  //
  // Internal (not private) so _GoogleSignInHttpClient can read currentUser
  // without caching a stale GoogleSignInAccount reference.
  // ignore: library_private_types_in_public_api
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '29526936061-0kodpve0mjp2peeit9hqvgmticb8avig.apps.googleusercontent.com',
    scopes: ['email', 'profile', 'https://www.googleapis.com/auth/drive.file'],
  );

  // ── Token File Storage ─────────────────────────────────────────────────────
  // Cross-platform token storage:
  //   Windows: %APPDATA%\Scopus\auth.json (filesystem ACLs)
  //   Android: getApplicationDocumentsDirectory()/Scopus/auth.json (app sandbox)

  Future<File> _getTokenFile() async {
    final String baseDir;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      baseDir = Platform.environment['APPDATA'] ?? '';
    } else {
      // Android / iOS — use the app's private documents directory
      final docsDir = await getApplicationDocumentsDirectory();
      baseDir = docsDir.path;
    }
    return File(
      '$baseDir${Platform.pathSeparator}Scopus${Platform.pathSeparator}auth.json',
    );
  }

  Future<void> _writeToken(String token) async {
    try {
      final file = await _getTokenFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({'refresh_token': token}));
    } catch (e) {
      print('[Drive] Token write failed: $e');
    }
  }

  Future<String?> _readToken() async {
    try {
      final file = await _getTokenFile();
      if (!await file.exists()) return null;
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return data['refresh_token'] as String?;
    } catch (e) {
      print('[Drive] Token read failed: $e');
      return null;
    }
  }

  Future<void> _deleteToken() async {
    try {
      final file = await _getTokenFile();
      if (await file.exists()) await file.delete();
    } catch (e) {
      print('[Drive] Token delete failed: $e');
    }
  }

  // ── Firebase Auth ────────────────────────────────────────────────
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // AutoRefreshingAuthClient when signed in via clientViaUserConsent.
  // Plain AuthClient after session restore via refreshCredentials().
  // Null until signed in (or restoreDriveSession succeeds).
  AuthClient? _authClient;

  // Held only for the restore path so we can close it on sign-out.
  // clientViaUserConsent manages its own internal base client.
  http.Client? _restoreBaseClient;

  // ── Auth State ───────────────────────────────────────────────────

  /// Firebase Auth's real auth state stream.
  /// Persists across restarts — no re-login needed on app reopen.
  Stream<AuthUser?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map(
      (user) => user != null ? _toAuthUser(user) : null,
    );
  }

  /// The currently signed-in user, sourced from Firebase Auth.
  AuthUser? get currentUser {
    final user = _firebaseAuth.currentUser;
    return user != null ? _toAuthUser(user) : null;
  }

  /// Authenticated HTTP client for Drive API calls.
  AuthClient? get authClient => _authClient;

  // ── Drive Session Restore ────────────────────────────────────────

  /// Call this from main() after Firebase.initializeApp().
  ///
  /// If Firebase Auth has a persisted session but Drive access is gone
  /// (app restarted), silently rebuilds the Drive client from the stored
  /// refresh token — no browser prompt or user interaction needed.
  Future<void> restoreDriveSession() async {
    if (_firebaseAuth.currentUser == null) return;
    if (_authClient != null) return;

    // ── Android: use GoogleSignIn's built-in silent restore ──────
    if (Platform.isAndroid) {
      try {
        print('[Drive] Attempting silent restore (Android)...');
        // Timeout prevents the app from freezing at the splash screen if
        // Google Play Services is slow to respond or misconfigured.
        final account = await _googleSignIn.signInSilently().timeout(
          const Duration(seconds: 6),
          onTimeout: () => null,
        );
        if (account != null) {
          _authClient = _GoogleSignInHttpClient();

          print('[Drive] ✅ Session restored silently (Android)');
        } else {
          print('[Drive] ℹ️  No previous Google Sign-In session on Android');
        }
      } catch (e) {
        print('[Drive] ❌ Android silent restore failed ($e)');
      }
      return;
    }

    // ── Windows/Desktop: use stored refresh token ────────────────

    print('[Drive][DIAG] ── Restore attempt ────────────────────────────');

    print('[Drive][DIAG] Firebase UID: ${_firebaseAuth.currentUser?.uid}');

    final refreshToken = await _readToken();

    print(
      '[Drive][DIAG] Stored token on restore: '
      '${refreshToken != null ? "PRESENT" : "NULL ← root cause C (storage not persisting across launches)"}',
    );

    if (refreshToken == null) {
      return;
    }
    try {
      final baseClient = http.Client();
      final expiredCredentials = AccessCredentials(
        AccessToken(
          'Bearer',
          '',
          DateTime.fromMillisecondsSinceEpoch(0).toUtc(),
        ),
        refreshToken,
        _scopes,
      );
      final newCredentials = await refreshCredentials(
        _clientId,
        expiredCredentials,
        baseClient,
      );
      _restoreBaseClient = baseClient;
      _authClient = autoRefreshingClient(_clientId, newCredentials, baseClient);

      print('[Drive] ✅ Session restored silently');
    } catch (e) {
      print('[Drive] ❌ Restore failed ($e)');
      final isRevoked =
          e.toString().contains('invalid_grant') ||
          e.toString().contains('Token has been expired or revoked');
      if (isRevoked) {
        await _deleteToken();

        print('[Drive] 🗑  Token revoked — cleared from storage');
      } else {
        print('[Drive] ℹ️  Transient error — token kept for next restart');
      }
    }
  }

  // ── Drive Reconnect (without Firebase sign-out) ──────────────────

  /// Re-authorises Google Drive without touching the Firebase Auth session.
  ///
  /// Opens a browser OAuth flow, stores the new refresh token, and rebuilds
  /// [authClient]. Call this when [authClient] is null after a restart.
  Future<void> reconnectDriveOnly() async {
    _authClient?.close();
    _authClient = null;

    // ── Android: re-run native sign-in picker ───────────────────
    if (Platform.isAndroid) {
      await _googleSignIn.signOut(); // force fresh account selection
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw const AuthException('Sign-in was cancelled.', code: 'cancelled');
      }
      _authClient = _GoogleSignInHttpClient();

      print('[Drive] ✅ Reconnected (Android)');
      return;
    }

    // ── Windows: browser PKCE flow ───────────────────────────────
    _restoreBaseClient?.close();
    _restoreBaseClient = null;

    _authClient = await clientViaUserConsent(
      _clientId,
      _scopes,
      _openBrowserForAuth,
      customPostAuthPage: await _getPostAuthPage(),
    );

    final refreshToken = _authClient!.credentials.refreshToken;
    if (refreshToken != null) {
      await _writeToken(refreshToken);

      print('[Drive] ✅ Reconnected — token stored');
    } else {
      print('[Drive] ⚠️  Reconnected but no refresh token returned');
    }
  }

  // ── Sign In ──────────────────────────────────────────────────────

  Future<AuthUser?> signInWithGoogle() async {
    try {
      // ── Android: native account picker ──────────────────────────
      if (Platform.isAndroid) {
        // Always sign out first to clear any stale GMS internal state.
        // A previous failed signInSilently() or expired session can leave
        // GoogleSignIn in a corrupt state that causes DEVELOPER_ERROR (10)
        // on subsequent signIn() calls. signOut() only clears GoogleSignIn's
        // in-memory state — it does NOT affect Firebase Auth.
        await _googleSignIn.signOut();

        final account = await _googleSignIn.signIn();
        if (account == null) {
          throw const AuthException(
            'Sign-in was cancelled.',
            code: 'cancelled',
          );
        }
        final auth = await account.authentication;

        // Firebase sign-in using both tokens (idToken available from google_sign_in)
        final oauthCredential = GoogleAuthProvider.credential(
          accessToken: auth.accessToken,
          idToken: auth.idToken,
        );
        final userCredential = await _firebaseAuth.signInWithCredential(
          oauthCredential,
        );

        if (userCredential.user == null) {
          throw const AuthException(
            'Firebase sign-in returned no user.',
            code: 'null-user',
          );
        }

        // Drive HTTP client — always reads GoogleSignIn.currentUser at
        // request time so it never holds a stale account reference.
        _authClient = _GoogleSignInHttpClient();

        AuthUser authUser = _toAuthUser(userCredential.user!);

        // Drive workspace (idempotent)
        try {
          final driveService = DriveService(_authClient!);
          final rootFolderId = await driveService.initializeWorkspace();
          authUser = authUser.copyWith(rootFolderId: rootFolderId);

          print('[DriveService] ✅ rootFolderId=$rootFolderId');
        } on DriveException catch (e) {
          print('[DriveService] ❌ ${e.message}');
          AppErrorHandler.show(e);
        } catch (e) {
          AppErrorHandler.show(
            DriveException('Drive workspace setup failed: $e'),
          );
        }

        // Firestore profile
        try {
          await FirestoreService().saveUserProfile(authUser);

          print('[FirestoreService] ✅ uid=${authUser.uid}');
        } on FirestoreException catch (e) {
          print('[FirestoreService] ❌ ${e.message}');
          AppErrorHandler.show(e);
        }

        return authUser;
      }

      // ── Windows/Desktop: browser PKCE flow ──────────────────────
      // Step 1 — OAuth2 browser flow.
      // _openBrowserForAuth injects access_type=offline + prompt=consent
      // into the URL, so Google returns a refresh_token in the code exchange.
      // clientViaUserConsent returns an AutoRefreshingAuthClient directly.
      _authClient = await clientViaUserConsent(
        _clientId,
        _scopes,
        _openBrowserForAuth,
        customPostAuthPage: await _getPostAuthPage(),
      );

      // Step 2 — Persist the refresh token for Drive session restore on restart
      final refreshToken = _authClient!.credentials.refreshToken;

      print('[Drive][DIAG] ── Sign-in token check ──────────────────────');

      print(
        '[Drive][DIAG] credentials.refreshToken: '
        '${refreshToken != null ? "PRESENT (${refreshToken.length} chars)" : "NULL ← root cause A"}',
      );

      if (refreshToken != null) {
        try {
          await _writeToken(refreshToken);
          final verify = await _readToken();

          print(
            '[Drive][DIAG] Storage write verify: '
            '${verify != null ? "OK" : "FILE WRITE FAILED"}',
          );
        } catch (e) {
          print('[Drive][DIAG] Storage write THREW: $e');
        }
      }

      final accessToken = _authClient!.credentials.accessToken.data;

      // Step 3 — Sign into Firebase Auth using the access token.
      final oauthCredential = GoogleAuthProvider.credential(
        accessToken: accessToken,
      );
      final userCredential = await _firebaseAuth.signInWithCredential(
        oauthCredential,
      );

      if (userCredential.user == null) {
        throw const AuthException(
          'Firebase sign-in returned no user.',
          code: 'null-user',
        );
      }

      AuthUser authUser = _toAuthUser(userCredential.user!);

      // Step 4 — Initialize Drive workspace (idempotent)
      try {
        final driveService = DriveService(_authClient!);
        final rootFolderId = await driveService.initializeWorkspace();
        authUser = authUser.copyWith(rootFolderId: rootFolderId);

        print('[DriveService] ✅ rootFolderId=$rootFolderId');
      } on DriveException catch (e) {
        print('[DriveService] ❌ ${e.message}');
        AppErrorHandler.show(e);
      } catch (e) {
        AppErrorHandler.show(
          DriveException('Drive workspace setup failed: $e'),
        );
      }

      // Step 5 — Save user profile to Firestore
      try {
        await FirestoreService().saveUserProfile(authUser);

        print('[FirestoreService] ✅ uid=${authUser.uid}');
      } on FirestoreException catch (e) {
        print('[FirestoreService] ❌ ${e.message}');
        AppErrorHandler.show(e);
      }

      // Firebase Auth notifies authStateChanges → GoRouter redirects to shell.
      return authUser;
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        _firebaseErrorMessage(e.code),
        code: e.code,
        originalError: e,
      );
    } on AccessDeniedException catch (e) {
      throw AuthException(
        'Sign-in was cancelled.',
        code: 'cancelled',
        originalError: e,
      );
    } catch (e) {
      throw AuthException(
        'Sign-in failed: ${e.toString()}',
        code: 'unknown',
        originalError: e,
      );
    }
  }

  // ── Sign Out ─────────────────────────────────────────────────────

  Future<void> signOut() async {
    try {
      _authClient?.close();
      _authClient = null;

      if (Platform.isAndroid) {
        // GoogleSignIn manages its own session — sign out clears it
        await _googleSignIn.signOut();
      } else {
        // Windows: close HTTP clients and delete stored refresh token
        _restoreBaseClient?.close();
        _restoreBaseClient = null;
        await _deleteToken();
      }

      await _firebaseAuth.signOut();
      // Firebase Auth notifies authStateChanges with null →
      // GoRouter redirects to /login automatically.
    } catch (e) {
      throw AuthException('Sign-out failed.', originalError: e);
    }
  }

  // ── Browser Helper ───────────────────────────────────────────────

  void _openBrowserForAuth(String url) async {
    final uri = Uri.parse(url);

    // ROOT CAUSE FIX: googleapis_auth's PKCE flow does NOT include
    // access_type=offline in the authorization URL. Without it, Google
    // never returns a refresh_token regardless of prompt=consent.
    //
    // We inject both parameters here using proper URI replacement
    // (not string concatenation) to ensure correct percent-encoding.
    //   access_type=offline → Google includes refresh_token in token response
    //   prompt=consent      → forces consent screen so token is always returned
    //                         (even if user previously authorized the app)
    final modifiedUri = uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'access_type': 'offline',
        'prompt': 'consent',
      },
    );

    try {
      final launched = await launchUrl(
        modifiedUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && (Platform.isWindows)) {
        await Process.run('explorer', [modifiedUri.toString()]);
      }
    } catch (_) {
      if (Platform.isWindows) {
        await Process.run('explorer', [modifiedUri.toString()]);
      }
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────

  AuthUser _toAuthUser(User firebaseUser) {
    return AuthUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName,
      photoUrl: firebaseUser.photoURL,
    );
  }

  String _firebaseErrorMessage(String code) {
    switch (code) {
      case 'account-exists-with-different-credential':
        return 'This account uses a different sign-in method.';
      case 'invalid-credential':
        return 'The credential is invalid or expired. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      default:
        return 'Authentication failed ($code).';
    }
  }

  // ── Singleton ────────────────────────────────────────────────────
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();
}

// ─────────────────────────────────────────────────────────────────────────────
// Android Drive HTTP Client
// Wraps GoogleSignIn so every Drive API request automatically carries
// a fresh access token. Instead of caching the GoogleSignInAccount at sign-in
// time (which becomes stale when the access token expires), we always read
// GoogleSignIn.currentUser at request time to get the live account object.
// GoogleSignIn refreshes the token internally via Google Play Services.
// ─────────────────────────────────────────────────────────────────────────────

class _GoogleSignInHttpClient extends http.BaseClient implements AuthClient {
  final http.Client _inner = http.Client();

  _GoogleSignInHttpClient();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Always read the current user — never use a cached/stale account reference.
    final account = GoogleAuthService._googleSignIn.currentUser;
    if (account == null) {
      throw const AuthException(
        'Google Sign-In session lost. Please sign in again.',
        code: 'no-current-user',
      );
    }
    final auth = await account.authentication;
    if (auth.accessToken == null) {
      throw const AuthException(
        'Could not obtain access token. Please sign in again.',
        code: 'no-access-token',
      );
    }
    request.headers['Authorization'] = 'Bearer ${auth.accessToken}';
    return _inner.send(request);
  }

  // AuthClient interface — credentials not used on Android path
  @override
  AccessCredentials get credentials => AccessCredentials(
    AccessToken('Bearer', '', DateTime.now().toUtc()),
    null,
    [],
  );

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
