import 'package:bingo_core/bingo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias guardadas en el dispositivo (sucesor de
/// `GameModeSettings.java`): último modo de juego del anfitrión, su
/// patrón personalizado, el nombre del jugador y el Broker de desarrollo.
class Settings {
  Settings._(this._prefs);

  static Future<Settings> load() async => Settings._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  static const _kMode = 'gameMode';
  static const _kPattern = 'customPattern';
  static const _kName = 'playerName';
  static const _kBroker = 'devBrokerUrl';
  static const _kCoffee = 'coffeeDismissedUntil';
  static const _kAutoMark = 'autoMark';

  GameMode get mode {
    final mode = GameMode.fromName(_prefs.getString(_kMode));
    // Personalizado sin patrón guardado no sirve: se vuelve a cartón lleno.
    return mode == GameMode.personalized && customPattern == null ? GameMode.complete : mode;
  }

  /// null si nunca se ha guardado uno (o lo guardado no es válido).
  Pattern? get customPattern {
    final p = decodePattern(_prefs.getString(_kPattern));
    return isValidPattern(p) ? p : null;
  }

  Future<void> saveMode(GameMode mode, Pattern? customPattern) async {
    await _prefs.setString(_kMode, mode.name);
    if (customPattern != null) await _prefs.setString(_kPattern, encodePattern(customPattern));
  }

  /// AutoSelector: marcar solo las balotas cantadas en el cartón.
  bool get autoMark => _prefs.getBool(_kAutoMark) ?? false;
  Future<void> saveAutoMark(bool value) => _prefs.setBool(_kAutoMark, value);

  String get playerName => _prefs.getString(_kName) ?? '';
  Future<void> savePlayerName(String name) => _prefs.setString(_kName, name);

  String? get devBrokerUrl => _prefs.getString(_kBroker);
  Future<void> saveDevBrokerUrl(String url) => _prefs.setString(_kBroker, url);

  DateTime get coffeeDismissedUntil =>
      DateTime.fromMillisecondsSinceEpoch(_prefs.getInt(_kCoffee) ?? 0);
  Future<void> postponeCoffee(Duration d) =>
      _prefs.setInt(_kCoffee, DateTime.now().add(d).millisecondsSinceEpoch);
}
