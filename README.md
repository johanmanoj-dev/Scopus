<div align="center">

# Scopus

**A cross-platform academic workspace manager built with Flutter.**

Organise your semesters, subjects, assignments, and study files — all synced to your Google Drive and accessible from any device.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%7C%20Auth-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows-lightgrey)](https://flutter.dev/multi-platform)

</div>

---

## Overview

Scopus is a personal academic organiser designed for students who want their study data to be structured, safe, and always available. It provides a single hub for tracking semester progress, managing subjects, staying on top of deadlines, and storing study files — all backed by a real-time cloud database and Google Drive storage.

The app features a premium **Dark Academic** aesthetic (deep blacks, crimson, and gold tones) with a fully adaptive UI that works natively on both Android and Windows.

---

## Features

### 🎓 Academic Structure
- **Multi-semester management** — create and switch between semesters. Each semester is isolated.
- **Subject organisation** — add subjects per semester with automatic Google Drive folder creation.
- **Smart dashboard** — get an at-a-glance summary of your current academic load.

### 📋 Assignment Tracking
- Create assignments with title, subject, and due date.
- Assignments are automatically sorted into three smart categories:
  - **Running** — active assignments yet to be submitted.
  - **Done** — completed assignments, with timestamp.
  - **Missed** — past-due assignments that were not marked done (auto-detected).
- Mark assignments done with a single tap.

### 📁 File Management
- Upload study files (PDFs, documents, etc.) directly from your device.
- Files are uploaded to a structured **Google Drive workspace** (`AcademicWorkspace / Semester / Subject /`).
- Cached locally on-device to avoid re-downloading on every open.
- Open files natively using your device's default apps.
- The app only has access to files **it creates** (`drive.file` scope — least privilege).

### ☁️ Cloud Sync & Offline Support
- All data (semesters, subjects, assignments) is stored in **Cloud Firestore** with real-time listeners.
- A local **SQLite offline queue** captures mutations (create, complete, delete) made while offline.
- On reconnect, the **SyncManager** automatically replays the queue against Firestore — no data is lost.
- Network status is monitored continuously via `connectivity_plus`.

### 🔒 Authentication
- Sign in securely with **Google**.
  - **Android** — uses the native Google Sign-In SDK (no browser redirect).
  - **Windows** — uses a desktop OAuth2 PKCE flow (browser-based, localhost callback).
- Tokens are persisted securely and silently restored on app restart — no need to sign in every time.
- Drive session is restored in the background, so the UI is never blocked waiting for auth.

### 🎨 UI & Navigation (Android)
- **Bottom navigation bar** for quick tab switching.
- **Swipe-to-navigate** — swipe left/right anywhere on the screen to move between tabs (Dashboard, Subjects, Assignments, Settings).
- **Hardware back button** — intelligently redirects to the Dashboard from any sub-screen, and exits the app only from the Dashboard.
- Fully animated page transitions using fade + slide animations.

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3 / Dart 3 |
| **State Management** | Riverpod 2 |
| **Routing** | GoRouter 17 (StatefulShellRoute) |
| **Authentication** | Firebase Auth + Google Sign-In + googleapis_auth |
| **Database (Cloud)** | Cloud Firestore |
| **File Storage** | Google Drive API v3 (via `http`) |
| **Local Cache** | SQLite via `sqflite` / `sqflite_common_ffi` |
| **Offline Queue** | SQLite + SyncManager |
| **Networking** | connectivity_plus |
| **Secrets Management** | flutter_dotenv |
| **Typography** | Google Fonts (Inter) |
| **Build Targets** | Android, Windows |

---

## Project Structure

```
lib/
├── core/
│   ├── database/         # SQLite cache + offline queue (CacheDatabase)
│   ├── errors/           # Centralised error handling + custom exceptions
│   ├── providers/        # Riverpod providers (auth, semesters, subjects, assignments, files)
│   ├── routes/           # GoRouter configuration (AppRouter)
│   ├── services/         # Business logic (GoogleAuthService, DriveService, FirestoreService)
│   ├── themes/           # Dark Academic ThemeData (AppTheme)
│   └── utils/            # AppTime, SyncManager, NetworkMonitor, GoRouterRefreshStream
├── models/               # Pure Dart data models (Assignment, Semester, Subject, AuthUser)
├── ui/
│   ├── layouts/          # ShellLayout (sidebar on Windows, bottom nav + swipe on Android)
│   ├── screens/          # Full-page screens (Dashboard, Subjects, Assignments, Settings, ...)
│   └── widgets/          # Reusable components (AssignmentCard, Sidebar, AppPrimaryButton, ...)
└── main.dart             # App entry point — Firebase init, dotenv load, parallel startup
```

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (^3.11.5)
- A [Firebase project](https://console.firebase.google.com/) with:
  - **Authentication** enabled (Google provider)
  - **Cloud Firestore** enabled
- A [Google Cloud project](https://console.cloud.google.com/) with:
  - **Google Drive API** enabled
  - An **OAuth 2.0 Desktop App** credential created

### 1. Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/scopus.git
cd scopus
```

### 2. Configure Firebase

1. Download your platform-specific Firebase config files:
   - `google-services.json` → place in `android/app/`
   - For Windows, configure via `flutterfire configure` to generate `lib/firebase_options.dart`
2. These files are in `.gitignore` and must be created locally — they are never committed.

### 3. Create the `.env` file

Create a file named `.env` in the project root with your Google OAuth Desktop credentials:

```env
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-client-secret
```

> **How to get these:** Go to [Google Cloud Console](https://console.cloud.google.com) → APIs & Services → Credentials → Create Credentials → **OAuth 2.0 Client ID** → Select **Desktop app**.

### 4. Install dependencies

```bash
flutter pub get
```

### 5. Run the app

```bash
# Android (with device connected)
flutter run

# Windows
flutter run -d windows

# Profile mode (true performance, no debug overhead)
flutter run --profile
```

### 6. Production Build (Android)

```bash
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
```

---

## Security

All sensitive credentials are stored **outside** of the Git repository:

| Secret | Location | Git Status |
|---|---|---|
| Google OAuth Client Secret | `.env` (project root) | ✅ Ignored |
| Firebase API Keys | `lib/firebase_options.dart` | ✅ Ignored |
| Android Firebase Config | `android/app/google-services.json` | ✅ Ignored |
| User Auth Tokens | `%APPDATA%\Scopus\auth.json` (Windows) / App sandbox (Android) | ✅ On-device only |

The Google Drive scope used is `drive.file` — the **least privileged scope** available. The app can only see and manage files and folders that it creates; it has zero access to the user's existing Drive files.

---

## Architecture Notes

- **Routing** — `StatefulShellRoute` is used to preserve the navigation stack of each tab when the user switches between them via swipe or the bottom nav bar.
- **Parallel startup** — Firebase init, local DB init, and time sync run in parallel to minimise cold-start latency.
- **Drive session restore** — the Google Auth token is refreshed silently in a background task after startup; the UI is never blocked.
- **Offline writes** — any assignment mutation while offline is written to the local SQLite `offline_queue` table and replayed by `SyncManager` the next time connectivity is detected.
- **Platform-conditional UI** — `dart:io`'s `Platform.isAndroid` branches the navigation layout at build time. Android gets `PageView`-based swipe navigation; Windows gets a persistent sidebar.

---

## Contributing

This is a personal project, but pull requests for bug fixes and improvements are welcome.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes
4. Open a Pull Request

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
