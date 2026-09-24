import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SecurityService {
  static const MethodChannel _channel = MethodChannel('calcx/security');

  static Future<void> enableSecure() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod('enableSecure');
      } catch (e) {
        debugPrint('Error enabling secure screen flag: ');
      }
    }
  }

  static Future<void> disableSecure() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod('disableSecure');
      } catch (e) {
        debugPrint('Error disabling secure screen flag: ');
      }
    }
  }
}
