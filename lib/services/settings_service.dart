import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // Configurações de telemática
  double _hardBrakingThreshold = 8.0;
  double _rapidAccelerationThreshold = 4.0;
  double _sharpTurnThreshold = 2.0;
  double _speedingThreshold = 10.0; // km/h acima do limite
  double _highGForceThreshold = 12.0;

  // Configurações de interface
  bool _isDarkMode = false;
  String _language = 'pt_BR';
  String _temperatureUnit = 'celsius';
  String _distanceUnit = 'km';
  String _speedUnit = 'kmh';

  // Configurações de notificação
  bool _tripNotificationsEnabled = true;
  bool _safetyAlertsEnabled = true;
  bool _speedingAlertsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  // Configurações de privacidade
  bool _locationSharingEnabled = false;
  bool _analyticsEnabled = true;
  bool _crashReportingEnabled = true;

  // Configurações de economia de bateria
  bool _backgroundLocationEnabled = true;
  int _locationUpdateInterval = 5; // segundos
  bool _sensorOptimizationEnabled = true;

  // Getters
  bool get isInitialized => _isInitialized;
  
  // Configurações de telemática
  double get hardBrakingThreshold => _hardBrakingThreshold;
  double get rapidAccelerationThreshold => _rapidAccelerationThreshold;
  double get sharpTurnThreshold => _sharpTurnThreshold;
  double get speedingThreshold => _speedingThreshold;
  double get highGForceThreshold => _highGForceThreshold;

  // Configurações de interface
  bool get isDarkMode => _isDarkMode;
  String get language => _language;
  String get temperatureUnit => _temperatureUnit;
  String get distanceUnit => _distanceUnit;
  String get speedUnit => _speedUnit;

  // Configurações de notificação
  bool get tripNotificationsEnabled => _tripNotificationsEnabled;
  bool get safetyAlertsEnabled => _safetyAlertsEnabled;
  bool get speedingAlertsEnabled => _speedingAlertsEnabled;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;

  // Configurações de privacidade
  bool get locationSharingEnabled => _locationSharingEnabled;
  bool get analyticsEnabled => _analyticsEnabled;
  bool get crashReportingEnabled => _crashReportingEnabled;

  // Configurações de economia de bateria
  bool get backgroundLocationEnabled => _backgroundLocationEnabled;
  int get locationUpdateInterval => _locationUpdateInterval;
  bool get sensorOptimizationEnabled => _sensorOptimizationEnabled;

  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadSettings();
      _isInitialized = true;
      debugPrint('SettingsService: Inicializado com sucesso');
    } catch (e) {
      debugPrint('Erro ao inicializar SettingsService: $e');
      _isInitialized = false;
    }
  }

  Future<void> _loadSettings() async {
    if (_prefs == null) return;

    // Carregar configurações de telemática
    _hardBrakingThreshold = _prefs!.getDouble('hard_braking_threshold') ?? 8.0;
    _rapidAccelerationThreshold = _prefs!.getDouble('rapid_acceleration_threshold') ?? 4.0;
    _sharpTurnThreshold = _prefs!.getDouble('sharp_turn_threshold') ?? 2.0;
    _speedingThreshold = _prefs!.getDouble('speeding_threshold') ?? 10.0;
    _highGForceThreshold = _prefs!.getDouble('high_g_force_threshold') ?? 12.0;

    // Carregar configurações de interface
    _isDarkMode = _prefs!.getBool('dark_mode') ?? false;
    _language = _prefs!.getString('language') ?? 'pt_BR';
    _temperatureUnit = _prefs!.getString('temperature_unit') ?? 'celsius';
    _distanceUnit = _prefs!.getString('distance_unit') ?? 'km';
    _speedUnit = _prefs!.getString('speed_unit') ?? 'kmh';

    // Carregar configurações de notificação
    _tripNotificationsEnabled = _prefs!.getBool('trip_notifications') ?? true;
    _safetyAlertsEnabled = _prefs!.getBool('safety_alerts') ?? true;
    _speedingAlertsEnabled = _prefs!.getBool('speeding_alerts') ?? true;
    _soundEnabled = _prefs!.getBool('sound_enabled') ?? true;
    _vibrationEnabled = _prefs!.getBool('vibration_enabled') ?? true;

    // Carregar configurações de privacidade
    _locationSharingEnabled = _prefs!.getBool('location_sharing') ?? false;
    _analyticsEnabled = _prefs!.getBool('analytics_enabled') ?? true;
    _crashReportingEnabled = _prefs!.getBool('crash_reporting') ?? true;

    // Carregar configurações de economia de bateria
    _backgroundLocationEnabled = _prefs!.getBool('background_location') ?? true;
    _locationUpdateInterval = _prefs!.getInt('location_update_interval') ?? 5;
    _sensorOptimizationEnabled = _prefs!.getBool('sensor_optimization') ?? true;
  }

  // Métodos para configurações de telemática
  Future<void> setHardBrakingThreshold(double value) async {
    _hardBrakingThreshold = value;
    await _prefs?.setDouble('hard_braking_threshold', value);
    notifyListeners();
  }

  Future<void> setRapidAccelerationThreshold(double value) async {
    _rapidAccelerationThreshold = value;
    await _prefs?.setDouble('rapid_acceleration_threshold', value);
    notifyListeners();
  }

  Future<void> setSharpTurnThreshold(double value) async {
    _sharpTurnThreshold = value;
    await _prefs?.setDouble('sharp_turn_threshold', value);
    notifyListeners();
  }

  Future<void> setSpeedingThreshold(double value) async {
    _speedingThreshold = value;
    await _prefs?.setDouble('speeding_threshold', value);
    notifyListeners();
  }

  Future<void> setHighGForceThreshold(double value) async {
    _highGForceThreshold = value;
    await _prefs?.setDouble('high_g_force_threshold', value);
    notifyListeners();
  }

  // Métodos para configurações de interface
  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    await _prefs?.setBool('dark_mode', value);
    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    _language = value;
    await _prefs?.setString('language', value);
    notifyListeners();
  }

  Future<void> setTemperatureUnit(String value) async {
    _temperatureUnit = value;
    await _prefs?.setString('temperature_unit', value);
    notifyListeners();
  }

  Future<void> setDistanceUnit(String value) async {
    _distanceUnit = value;
    await _prefs?.setString('distance_unit', value);
    notifyListeners();
  }

  Future<void> setSpeedUnit(String value) async {
    _speedUnit = value;
    await _prefs?.setString('speed_unit', value);
    notifyListeners();
  }

  // Métodos para configurações de notificação
  Future<void> setTripNotificationsEnabled(bool value) async {
    _tripNotificationsEnabled = value;
    await _prefs?.setBool('trip_notifications', value);
    notifyListeners();
  }

  Future<void> setSafetyAlertsEnabled(bool value) async {
    _safetyAlertsEnabled = value;
    await _prefs?.setBool('safety_alerts', value);
    notifyListeners();
  }

  Future<void> setSpeedingAlertsEnabled(bool value) async {
    _speedingAlertsEnabled = value;
    await _prefs?.setBool('speeding_alerts', value);
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    await _prefs?.setBool('sound_enabled', value);
    notifyListeners();
  }

  Future<void> setVibrationEnabled(bool value) async {
    _vibrationEnabled = value;
    await _prefs?.setBool('vibration_enabled', value);
    notifyListeners();
  }

  // Métodos para configurações de privacidade
  Future<void> setLocationSharingEnabled(bool value) async {
    _locationSharingEnabled = value;
    await _prefs?.setBool('location_sharing', value);
    notifyListeners();
  }

  Future<void> setAnalyticsEnabled(bool value) async {
    _analyticsEnabled = value;
    await _prefs?.setBool('analytics_enabled', value);
    notifyListeners();
  }

  Future<void> setCrashReportingEnabled(bool value) async {
    _crashReportingEnabled = value;
    await _prefs?.setBool('crash_reporting', value);
    notifyListeners();
  }

  // Métodos para configurações de economia de bateria
  Future<void> setBackgroundLocationEnabled(bool value) async {
    _backgroundLocationEnabled = value;
    await _prefs?.setBool('background_location', value);
    notifyListeners();
  }

  Future<void> setLocationUpdateInterval(int value) async {
    _locationUpdateInterval = value;
    await _prefs?.setInt('location_update_interval', value);
    notifyListeners();
  }

  Future<void> setSensorOptimizationEnabled(bool value) async {
    _sensorOptimizationEnabled = value;
    await _prefs?.setBool('sensor_optimization', value);
    notifyListeners();
  }

  // Métodos utilitários
  Future<void> resetToDefaults() async {
    if (_prefs == null) return;

    await _prefs!.clear();
    
    // Recarregar valores padrão
    _hardBrakingThreshold = 8.0;
    _rapidAccelerationThreshold = 4.0;
    _sharpTurnThreshold = 2.0;
    _speedingThreshold = 10.0;
    _highGForceThreshold = 12.0;
    
    _isDarkMode = false;
    _language = 'pt_BR';
    _temperatureUnit = 'celsius';
    _distanceUnit = 'km';
    _speedUnit = 'kmh';
    
    _tripNotificationsEnabled = true;
    _safetyAlertsEnabled = true;
    _speedingAlertsEnabled = true;
    _soundEnabled = true;
    _vibrationEnabled = true;
    
    _locationSharingEnabled = false;
    _analyticsEnabled = true;
    _crashReportingEnabled = true;
    
    _backgroundLocationEnabled = true;
    _locationUpdateInterval = 5;
    _sensorOptimizationEnabled = true;

    notifyListeners();
    debugPrint('Configurações restauradas para valores padrão');
  }

  Future<String> exportSettings() async {
    final settings = {
      'telematics': {
        'hard_braking_threshold': _hardBrakingThreshold,
        'rapid_acceleration_threshold': _rapidAccelerationThreshold,
        'sharp_turn_threshold': _sharpTurnThreshold,
        'speeding_threshold': _speedingThreshold,
        'high_g_force_threshold': _highGForceThreshold,
      },
      'interface': {
        'dark_mode': _isDarkMode,
        'language': _language,
        'temperature_unit': _temperatureUnit,
        'distance_unit': _distanceUnit,
        'speed_unit': _speedUnit,
      },
      'notifications': {
        'trip_notifications': _tripNotificationsEnabled,
        'safety_alerts': _safetyAlertsEnabled,
        'speeding_alerts': _speedingAlertsEnabled,
        'sound_enabled': _soundEnabled,
        'vibration_enabled': _vibrationEnabled,
      },
      'privacy': {
        'location_sharing': _locationSharingEnabled,
        'analytics_enabled': _analyticsEnabled,
        'crash_reporting': _crashReportingEnabled,
      },
      'battery': {
        'background_location': _backgroundLocationEnabled,
        'location_update_interval': _locationUpdateInterval,
        'sensor_optimization': _sensorOptimizationEnabled,
      },
    };

    return jsonEncode(settings);
  }

  Future<bool> importSettings(String settingsJson) async {
    try {
      final settings = jsonDecode(settingsJson) as Map<String, dynamic>;
      
      // Importar configurações de telemática
      if (settings.containsKey('telematics')) {
        final telematics = settings['telematics'] as Map<String, dynamic>;
        await setHardBrakingThreshold(telematics['hard_braking_threshold']?.toDouble() ?? 8.0);
        await setRapidAccelerationThreshold(telematics['rapid_acceleration_threshold']?.toDouble() ?? 4.0);
        await setSharpTurnThreshold(telematics['sharp_turn_threshold']?.toDouble() ?? 2.0);
        await setSpeedingThreshold(telematics['speeding_threshold']?.toDouble() ?? 10.0);
        await setHighGForceThreshold(telematics['high_g_force_threshold']?.toDouble() ?? 12.0);
      }

      // Importar configurações de interface
      if (settings.containsKey('interface')) {
        final interface = settings['interface'] as Map<String, dynamic>;
        await setDarkMode(interface['dark_mode'] ?? false);
        await setLanguage(interface['language'] ?? 'pt_BR');
        await setTemperatureUnit(interface['temperature_unit'] ?? 'celsius');
        await setDistanceUnit(interface['distance_unit'] ?? 'km');
        await setSpeedUnit(interface['speed_unit'] ?? 'kmh');
      }

      // Importar outras configurações...
      
      debugPrint('Configurações importadas com sucesso');
      return true;
      
    } catch (e) {
      debugPrint('Erro ao importar configurações: $e');
      return false;
    }
  }

  Map<String, dynamic> getSettingsReport() {
    return {
      'initialized': _isInitialized,
      'total_settings': 20,
      'telematics_configured': _hardBrakingThreshold != 8.0 || 
                              _rapidAccelerationThreshold != 4.0 ||
                              _sharpTurnThreshold != 2.0,
      'notifications_enabled': _tripNotificationsEnabled || _safetyAlertsEnabled,
      'privacy_settings': {
        'location_sharing': _locationSharingEnabled,
        'analytics': _analyticsEnabled,
      },
      'battery_optimization': _sensorOptimizationEnabled,
    };
  }
}

