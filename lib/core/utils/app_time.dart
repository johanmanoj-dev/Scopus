import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class AppTime {
  static Duration _offset = Duration.zero;
  
  // Indian Standard Time is UTC +5:30
  static const Duration _istOffset = Duration(hours: 5, minutes: 30);

  /// Synchronizes local time with an internet time server via a fast HTTP HEAD request.
  /// If offline, it gracefully falls back to local device time offset estimation.
  static Future<void> sync() async {
    try {
      // We use google.com because it's highly available and always returns a reliable Date header
      final response = await http
          .head(Uri.parse('https://google.com'))
          .timeout(const Duration(seconds: 5));
          
      if (response.statusCode == 200) {
        final dateHeader = response.headers['date'];
        if (dateHeader != null) {
          final serverTimeUtc = HttpDate.parse(dateHeader);
          final localTimeUtc = DateTime.now().toUtc();
          
          // Calculate difference between true internet UTC and device local UTC
          _offset = serverTimeUtc.difference(localTimeUtc);
          debugPrint('AppTime synced with internet. Offset: ${_offset.inSeconds} seconds.');
        }
      }
    } catch (e) {
      debugPrint('AppTime sync failed, falling back to local device time: $e');
      _offset = Duration.zero;
    }
  }

  /// Returns the current synchronized Indian Standard Time (IST).
  static DateTime now() {
    // Determine true current UTC time
    final trueUtc = DateTime.now().toUtc().add(_offset);
    
    // Convert to IST
    return trueUtc.add(_istOffset);
  }
}
