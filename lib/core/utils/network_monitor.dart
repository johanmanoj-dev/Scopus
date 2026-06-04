import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A StreamProvider that listens to network connectivity changes.
///
/// Yields `true` if the device is connected to a network (WiFi, mobile, ethernet, etc.),
/// and `false` if the device is offline (none).
final networkStatusProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  
  // Yield the initial status immediately
  final initialStatus = await connectivity.checkConnectivity();
  yield !initialStatus.contains(ConnectivityResult.none);

  // Yield subsequent changes
  await for (final statusList in connectivity.onConnectivityChanged) {
    yield !statusList.contains(ConnectivityResult.none);
  }
});
