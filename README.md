<div align="center">
  <br/>
  <h1>🎓 Scopus</h1>
  <p><strong>The modern, offline-first academic workspace.</strong></p>
  <p>Built by Johan • Powered by Flutter, Firebase, and Google Drive</p>
</div>

<br/>

## ✨ About Scopus

Scopus is a desktop-first academic management application designed to bring order to student life. Say goodbye to scattered files and disorganized notes. Scopus seamlessly organizes your coursework, subjects, and assignments into a structured, unified interface—automatically backing everything up to your personal Google Drive and syncing metadata via Firebase.

With a beautiful **Dark Academic** theme tailored for Windows, Scopus feels like a native desktop application, complete with deep keyboard shortcuts, intelligent error handling, and robust offline capabilities.

---

## 🚀 Key Features

*   🔒 **Secure Authentication**: Frictionless Google Sign-In with robust, auto-refreshing session restoration.
*   🗂️ **Google Drive Integration**: Automatically provisions a structured academic workspace in your Google Drive (`AcademicWorkspace/Semester/Subject`). Upload documents safely with resumable chunks and real-time progress tracking.
*   📡 **Offline-First Architecture**: Lose connection? No problem. Scopus uses a local SQLite queue to securely store your assignment updates and automatically syncs them to Firestore the second you reconnect.
*   📚 **Semester & Subject Management**: Keep everything cleanly segmented by semester and subject. Archive past semesters for a clutter-free dashboard.
*   ✅ **Assignment Tracking**: Manage assignments through a dedicated control panel (Running, Done, Missed) with date tracking.
*   🎨 **Dark Academic Design System**: A premium, meticulously crafted dark theme designed to be easy on the eyes during late-night study sessions.
*   ⌨️ **Desktop Polish**: Built for the desktop. Full support for `Enter` to submit, `Escape` to dismiss, dynamic hover scrollbars, and rapid navigation.

---

## 🛠️ Tech Stack

*   **Framework**: [Flutter](https://flutter.dev/) (Windows Desktop)
*   **State Management**: [Riverpod](https://riverpod.dev/)
*   **Backend & Sync**: [Firebase Auth](https://firebase.google.com/products/auth) & [Cloud Firestore](https://firebase.google.com/products/firestore)
*   **Storage**: [Google Drive API v3](https://developers.google.com/drive) (using the restricted `drive.file` scope for ultimate user privacy)
*   **Local Persistence**: [SQLite (sqflite_ffi)](https://pub.dev/packages/sqflite_common_ffi) for offline operation queuing.

---

## 🏗️ Architecture Highlights

### The Sync Daemon
Scopus implements a robust background synchronization engine. When the app detects network loss, modifying operations (like completing an assignment) are intercepted and serialized into a local SQLite queue. Upon reconnection, the daemon automatically replays the queue against Firestore, guaranteeing data consistency without blocking the UI.

### Safe Drive Operations
To prevent orphaned files, Scopus strictly enforces network safety on Google Drive operations. If you're offline, uploading files or deleting subjects is intelligently disabled—ensuring the local database state never drifts from the remote Drive folder structure.

---

## 💻 Getting Started

### Prerequisites
*   Flutter SDK (configured for Windows desktop development)
*   A Firebase project with Authentication and Firestore enabled.
*   A Google Cloud Console project with the Drive API enabled and a Desktop OAuth 2.0 client ID.

### Running the App
```bash
# Clone the repository
git clone https://github.com/yourusername/scopus.git

# Navigate to the directory
cd scopus

# Get dependencies
flutter pub get

# Run on Windows
flutter run -d windows
```

---
<div align="center">
  <sub>Built by Johan</sub>
</div>
