import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService(LocalAuthentication());
});

class BiometricService {
  const BiometricService(this._auth);

  final LocalAuthentication _auth;

  Future<bool> canAuthenticate() async {
    final supported = await _auth.isDeviceSupported();
    final canCheck = await _auth.canCheckBiometrics;
    return supported && canCheck;
  }

  Future<bool> unlock() async {
    if (!await canAuthenticate()) {
      return false;
    }

    return _auth.authenticate(
      localizedReason: 'Unlock your CalcX private space',
    );
  }
}
