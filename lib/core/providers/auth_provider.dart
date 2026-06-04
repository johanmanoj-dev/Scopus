import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Streams the current Firebase Auth UID.
/// Emits null when signed out, non-null string when signed in.
final authStateProvider = StreamProvider<String?>((ref) {
  return FirebaseAuth.instance
      .authStateChanges()
      .map((user) => user?.uid);
});

/// The current user's UID as a synchronous [Provider].
///
/// Throws [StateError] if the user is not signed in.
/// Only watch this in screens that are behind the auth guard —
/// GoRouter ensures unauthenticated users never reach those screens.
final currentUidProvider = Provider<String>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull;
  if (uid == null) throw StateError('currentUidProvider: no signed-in user');
  return uid;
});
