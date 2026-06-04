import 'dart:convert';
import 'dart:typed_data';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import '../errors/app_exception.dart';

/// Manages the user's Google Drive workspace for Scopus.
///
/// Drive structure:
/// ─────────────────────────────────────────────────────
///   AcademicWorkspace/
///   ├── Semester 1/               ← named by user
///   │    ├── Physics/             ← named by user; files uploaded directly here
///   │    ├── Mathematics/
///   │    └── ...
///   ├── Semester 2/
///   │    └── ...
///   └── ...
/// ─────────────────────────────────────────────────────
///
/// No predefined subfolders inside subject folders.
/// Files are uploaded directly into the subject folder.
///
/// Scope: drive.file — app only sees files/folders IT created.
/// The app NEVER accesses the user's existing Drive files.
class DriveService {
  static const _driveApiBase = 'https://www.googleapis.com/drive/v3';
  static const _rootFolderName = 'AcademicWorkspace';
  static const _folderMimeType = 'application/vnd.google-apps.folder';

  final AuthClient _client;

  DriveService(this._client);

  // ── Root Workspace Initialization ──────────────────────────────

  /// Ensures the root `AcademicWorkspace/` folder exists in Drive.
  ///
  /// - If it already exists → returns the existing folder ID.
  /// - If not → creates it and returns the new folder ID.
  ///
  /// This is called once after first login ("first run" flow).
  Future<String> initializeWorkspace() async {
    try {
      // 1. Search for an existing AcademicWorkspace folder
      final existingId = await _findFolder(
        name: _rootFolderName,
        parentId: null, // root of Drive
      );

      if (existingId != null) {
        return existingId;
      }

      // 2. Not found — create it
      final newId = await _createFolder(
        name: _rootFolderName,
        parentId: null,
      );

      return newId;
    } on DriveException {
      rethrow;
    } catch (e) {
      throw DriveException(
        'Failed to initialize Drive workspace: $e',
        code: 'workspace-init-failed',
        originalError: e,
      );
    }
  }

  // ── Folder Operations ───────────────────────────────────────────

  /// Creates a folder inside [parentId] (or Drive root if null).
  /// Returns the new folder's ID.
  Future<String> createFolder({
    required String name,
    required String parentId,
  }) async {
    return _createFolder(name: name, parentId: parentId);
  }

  /// Finds a folder by [name] inside [parentId] (or Drive root).
  /// Returns the folder ID, or null if not found.
  Future<String?> findFolder({
    required String name,
    required String parentId,
  }) async {
    return _findFolder(name: name, parentId: parentId);
  }

  /// Finds or creates a folder — idempotent convenience method.
  Future<String> ensureFolder({
    required String name,
    required String parentId,
  }) async {
    final existing = await _findFolder(name: name, parentId: parentId);
    if (existing != null) return existing;
    return _createFolder(name: name, parentId: parentId);
  }

  // ── Phase 2 — Semester & Subject Folders ───────────────────────

  /// Creates (or finds) a semester folder inside [rootFolderId]
  /// (`AcademicWorkspace/`).
  ///
  /// Idempotent — safe to call even if the folder already exists.
  /// Returns the semester folder's Drive ID.
  Future<String> createSemesterFolder(
    String rootFolderId,
    String semesterTitle,
  ) {
    return ensureFolder(name: semesterTitle, parentId: rootFolderId);
  }

  /// Creates (or finds) a subject folder inside [semesterFolderId].
  ///
  /// Structure: `AcademicWorkspace / Semester / SubjectName`
  /// Idempotent — safe to call even if the folder already exists.
  /// Returns the subject folder's Drive ID.
  Future<String> createSubjectFolder(
    String semesterFolderId,
    String subjectTitle,
  ) {
    return ensureFolder(name: subjectTitle, parentId: semesterFolderId);
  }

  /// Moves [folderId] to Drive Trash (recoverable by the user).
  ///
  /// Called when a subject is deleted. The folder moves to Trash
  /// rather than being permanently destroyed, giving the user a safety net.
  Future<void> trashFolder(String folderId) async {
    final uri = Uri.parse('$_driveApiBase/files/$folderId');
    final response = await _client.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'trashed': true}),
    );
    _assertOk(response, 'trash folder $folderId');
  }

  /// Renames [folderId] to [newName] in Drive.
  ///
  /// Called when a semester or subject is renamed. The folder name
  /// is updated in place — no new folder is created.
  Future<void> renameFolder(String folderId, String newName) async {
    final uri = Uri.parse('$_driveApiBase/files/$folderId');
    final response = await _client.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': newName}),
    );
    _assertOk(response, 'rename folder $folderId to "$newName"');
  }

  // ── Phase 3 — File Operations ────────────────────────────────────

  /// Uploads a file to a specific Drive folder using Resumable Upload.
  ///
  /// Supports files up to 30MB safely.
  /// Returns a record with the Drive file ID and a webViewLink.
  Future<({String driveFileId, String webViewLink})> uploadFile({
    required String parentFolderId,
    required String fileName,
    required String mimeType,
    required Uint8List fileBytes,
    void Function(int sent, int total)? onProgress,
  }) async {
    final initUri = Uri.parse(
        'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&fields=id,webViewLink');
    
    final metadata = {
      'name': fileName,
      'parents': [parentFolderId],
    };

    final initResponse = await _client.post(
      initUri,
      headers: {
        'Content-Type': 'application/json',
        'X-Upload-Content-Type': mimeType,
      },
      body: jsonEncode(metadata),
    );

    _assertOk(initResponse, 'initialize upload session for "$fileName"');

    final uploadUrl = initResponse.headers['location'];
    if (uploadUrl == null) {
      throw DriveException(
        'Failed to get upload session URL for $fileName',
        code: 'upload-session-failed',
      );
    }

    final request = http.StreamedRequest('PUT', Uri.parse(uploadUrl));
    request.headers.addAll({
      'Content-Type': mimeType,
      'Content-Length': fileBytes.length.toString(),
    });

    final total = fileBytes.length;
    int sent = 0;
    const chunkSize = 256 * 1024; // 256 KB chunks

    final responseFuture = _client.send(request);

    for (int i = 0; i < total; i += chunkSize) {
      int end = (i + chunkSize < total) ? i + chunkSize : total;
      request.sink.add(fileBytes.sublist(i, end));
      sent = end;
      if (onProgress != null) {
        onProgress(sent, total);
      }
      // Yield to event loop to allow UI updates
      await Future.delayed(Duration.zero);
    }
    request.sink.close();

    final streamResponse = await responseFuture;
    final responseBody = await streamResponse.stream.bytesToString();
    final uploadResponse = http.Response(responseBody, streamResponse.statusCode, headers: streamResponse.headers);

    _assertOk(uploadResponse, 'upload file bytes for "$fileName"');

    if (uploadResponse.body.isEmpty) {
      throw DriveException(
        'Upload succeeded but Drive returned an empty response for "$fileName"',
        code: 'upload-empty-response',
      );
    }

    final body = jsonDecode(uploadResponse.body) as Map<String, dynamic>;
    final driveFileId = body['id'] as String?;
    if (driveFileId == null || driveFileId.isEmpty) {
      throw DriveException(
        'Drive did not return a file ID for "$fileName"',
        code: 'upload-missing-id',
      );
    }

    return (
      driveFileId: driveFileId,
      webViewLink: body['webViewLink'] as String? ?? '',
    );
  }

  /// Moves [driveFileId] to Drive Trash (recoverable by the user).
  Future<void> trashFile(String driveFileId) async {
    final uri = Uri.parse('$_driveApiBase/files/$driveFileId');
    final response = await _client.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'trashed': true}),
    );
    _assertOk(response, 'trash file $driveFileId');
  }

  // ── Internal Drive API calls ────────────────────────────────────

  Future<String?> _findFolder({
    required String name,
    String? parentId,
  }) async {
    final parentClause = parentId != null
        ? " and '$parentId' in parents"
        : " and 'root' in parents";

    final query =
        "name='$name' and mimeType='$_folderMimeType' and trashed=false$parentClause";

    final uri = Uri.parse('$_driveApiBase/files').replace(
      queryParameters: {
        'q': query,
        'fields': 'files(id, name)',
        'spaces': 'drive',
      },
    );

    final response = await _client.get(uri);
    _assertOk(response, 'search folder "$name"');

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final files = body['files'] as List<dynamic>;

    if (files.isEmpty) return null;
    return (files.first as Map<String, dynamic>)['id'] as String;
  }

  Future<String> _createFolder({
    required String name,
    String? parentId,
  }) async {
    final metadata = <String, dynamic>{
      'name': name,
      'mimeType': _folderMimeType,
      if (parentId != null) 'parents': [parentId],
    };

    final response = await _client.post(
      Uri.parse('$_driveApiBase/files?fields=id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(metadata),
    );

    _assertOk(response, 'create folder "$name"');

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['id'] as String;
  }

  void _assertOk(http.Response response, String operation) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    String message = 'Drive API error (${response.statusCode})';
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      
      // Check for standard Google API error
      final errorMap = body['error'] as Map<String, dynamic>?;
      if (errorMap != null && errorMap['message'] != null) {
        message = errorMap['message'] as String;
      } 
      // Check for OAuth token refresh error (e.g. invalid_grant)
      else if (body['error'] is String) {
        message = 'Auth Token Error: ${body['error']} - ${body['error_description']}';
        if (body['error'] == 'invalid_grant') {
          message = 'Your session expired or was revoked. Please sign out and sign back in.';
        }
      } else {
        message += ' | Raw: ${response.body}';
      }
    } catch (_) {
      message += ' | Raw: ${response.body}';
    }

    throw DriveException(
      'Failed to $operation: $message',
      code: 'drive-api-${response.statusCode}',
    );
  }

  // ── Singleton factory ───────────────────────────────────────────
  // DriveService is NOT a global singleton — a new instance is
  // created after each sign-in using the authenticated client.
  // Use [GoogleAuthService().authClient] to get the client.
}
