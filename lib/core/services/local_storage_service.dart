import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageKeys {
  LocalStorageKeys._();
  static const String hasSeenOnboarding = 'has_seen_onboarding';
}

class LocalStorageService {
  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  bool getBool(String key, {bool defaultValue = false}) {
    return _prefs.getBool(key) ?? defaultValue;
  }

  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  String? getString(String key) => _prefs.getString(key);

  Future<void> setString(String key, String value) => _prefs.setString(key, value);

  Future<void> remove(String key) => _prefs.remove(key);
}
