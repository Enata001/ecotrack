import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  Map<String, dynamic> _config = const {};

  String get mapsApiKey => _config['mapsApiKey'] ?? '';
  String get environment => _config['environment'] ?? 'dev';

  Future<void> load({String flavor = 'dev'}) async {
    final content = await rootBundle.loadString('assets/cfg/$flavor.json');
    _config = jsonDecode(content) as Map<String, dynamic>;
  }
}
