import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Face ID/huella para reingresar sin escribir la contraseña. `local_auth`
/// solo confirma la identidad del dueño del dispositivo (no entrega
/// credenciales), así que el correo/contraseña se guardan aparte en el
/// Keychain/Keystore (flutter_secure_storage) la primera vez que el usuario
/// activa esta opción, y se recuperan tras un Face ID exitoso para loguear
/// igual que si los hubiera escrito.
class BiometricService {
  static const _storage = FlutterSecureStorage();
  static const _emailKey = 'biometric_email';
  static const _passwordKey = 'biometric_password';
  static const _enabledPrefsKey = 'biometric_enabled';

  final LocalAuthentication _auth = LocalAuthentication();

  static final BiometricService _instance = BiometricService._();
  factory BiometricService() => _instance;
  BiometricService._();

  Future<bool> get isDeviceSupported async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  /// "Face ID", "huella digital" o "biometría" según lo que el equipo tenga.
  Future<String> get biometricLabel async {
    try {
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) return 'Face ID';
      if (types.contains(BiometricType.fingerprint)) return 'huella digital';
    } catch (_) {}
    return 'Face ID';
  }

  Future<bool> authenticate(
      {String reason = 'Confirma tu identidad para iniciar sesión'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEnabledFor(String email) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_enabledPrefsKey) != true) return false;
    final savedEmail = await _storage.read(key: _emailKey);
    return savedEmail != null &&
        savedEmail.toLowerCase() == email.trim().toLowerCase();
  }

  Future<void> enable(String email, String password) async {
    await _storage.write(key: _emailKey, value: email.trim());
    await _storage.write(key: _passwordKey, value: password);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledPrefsKey, true);
  }

  Future<({String email, String password})?> getSavedCredentials() async {
    final email = await _storage.read(key: _emailKey);
    final password = await _storage.read(key: _passwordKey);
    if (email == null || password == null) return null;
    return (email: email, password: password);
  }
}
