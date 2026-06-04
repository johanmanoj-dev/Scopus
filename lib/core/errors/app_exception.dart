/// Base exception for all Scopus app errors.
/// Provides a consistent interface for error handling across services.
class AppException implements Exception {
  final String message;
  final String? code;
  final Object? originalError;

  const AppException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'AppException[$code]: $message';
}

/// Thrown when any authentication operation fails.
class AuthException extends AppException {
  const AuthException(
    super.message, {
    super.code,
    super.originalError,
  });
}

/// Thrown when Google Drive API operations fail.
class DriveException extends AppException {
  const DriveException(
    super.message, {
    super.code,
    super.originalError,
  });
}

/// Thrown when Firestore read/write operations fail.
class FirestoreException extends AppException {
  const FirestoreException(
    super.message, {
    super.code,
    super.originalError,
  });
}

/// Thrown when there is no network connectivity.
class NetworkException extends AppException {
  const NetworkException([
    super.message = 'No internet connection.',
  ]);
}
