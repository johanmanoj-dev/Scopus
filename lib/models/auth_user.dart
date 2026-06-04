/// Represents a signed-in user in the Scopus app.
/// Decoupled from Firebase's [User] so the rest of the app
/// doesn't depend on Firebase directly.
class AuthUser {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;

  /// The Google Drive folder ID of `AcademicWorkspace/`.
  /// Set after [DriveService.initializeWorkspace] runs on first login.
  /// Null until workspace has been initialized.
  final String? rootFolderId;

  const AuthUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.rootFolderId,
  });

  /// A short display name — falls back to the email prefix if no name is set.
  String get name => displayName ?? email.split('@').first;

  AuthUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    String? rootFolderId,
  }) {
    return AuthUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      rootFolderId: rootFolderId ?? this.rootFolderId,
    );
  }

  @override
  String toString() => 'AuthUser(uid: $uid, email: $email, rootFolderId: $rootFolderId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AuthUser && other.uid == uid);

  @override
  int get hashCode => uid.hashCode;
}
