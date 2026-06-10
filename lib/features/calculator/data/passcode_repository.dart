import 'dart:convert';
import 'dart:math';

import 'package:calcx/core/services/secure_storage_service.dart';
import 'package:calcx/features/calculator/domain/calculator_engine.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final calculatorEngineProvider = Provider<CalculatorEngine>((ref) {
  return const CalculatorEngine();
});

final passcodeRepositoryProvider = Provider<PasscodeRepository>((ref) {
  return PasscodeRepository(
    storage: ref.watch(secureStorageProvider),
    engine: ref.watch(calculatorEngineProvider),
  );
});

class PasscodeRepository {
  PasscodeRepository({
    required FlutterSecureStorage storage,
    required CalculatorEngine engine,
  })  : _storage = storage,
        _engine = engine;

  static const _hashKey = 'calcx.passcode.hash';
  static const _saltKey = 'calcx.passcode.salt';
  static const _notificationTextKey = 'calcx.notification.text';

  final FlutterSecureStorage _storage;
  final CalculatorEngine _engine;

  Future<bool> hasPasscode() async {
    final hash = await _storage.read(key: _hashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<void> savePasscode(String expression) async {
    final salt = _randomHex(24);
    final hash = _hash(expression, salt);
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _hashKey, value: hash);
  }

  Future<bool> matches(String expression) async {
    final salt = await _storage.read(key: _saltKey);
    final storedHash = await _storage.read(key: _hashKey);

    if (salt == null || storedHash == null) {
      return false;
    }

    return _hash(expression, salt) == storedHash;
  }

  Future<void> clearPasscode() async {
    await _storage.delete(key: _saltKey);
    await _storage.delete(key: _hashKey);
  }

  Future<String> notificationText() async {
    return await _storage.read(key: _notificationTextKey) ??
        'Your previous calculation is pending.';
  }

  Future<void> saveNotificationText(String text) async {
    await _storage.write(key: _notificationTextKey, value: text.trim());
  }

  String _hash(String expression, String salt) {
    final normalized = _engine.normalizeExpression(expression);
    final bytes = utf8.encode('$salt:$normalized');
    return sha256.convert(bytes).toString();
  }

  String _randomHex(int length) {
    final random = Random.secure();
    final values = List<int>.generate(length, (_) => random.nextInt(256));
    return values.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }
}
