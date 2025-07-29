import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/location_data.dart';

/// Serviço de localização usando Fused Location Provider API
class FusedLocationService {
  static final FusedLocationService _instance = FusedLocationService._internal();
  factory FusedLocationService() => _instance;
  FusedLocationService._internal();

  static const MethodChannel _channel = MethodChannel('com.mycompany.sentinelinsights/fused_location');
  
  bool _isInitialized = false;
  bool _isLocationEnabled = false;
  StreamController<LocationData?>? _locationController;
  Timer? _locationTimer;

  // Configurações
  int _updateInterval = 5000; // 5 segundos
  int _fastestInterval = 2000; // 2 segundos
  double _smallestDisplacement = 5.0; // 5 metros

  // Cache de localização
  LocationData? _lastKnownLocation;
  DateTime? _lastLocationTime;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLocationEnabled => _isLocationEnabled;
  LocationData? get lastKnownLocation => _lastKnownLocation;
  Stream<LocationData?> get locationStream => _locationController?.stream ?? const Stream.empty();

  /// Inicializa o serviço
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Configurar canal de comunicação
      _channel.setMethodCallHandler(_handleMethodCall);
      
      // Verificar se Google Play Services está disponível
      final isAvailable = await _channel.invokeMethod('isGooglePlayServicesAvailable');
      if (!isAvailable) {
        debugPrint('FusedLocationService: Google Play Services não disponível');
        return;
      }

      // Inicializar stream controller
      _locationController = StreamController<LocationData?>.broadcast();

      // Configurar parâmetros de localização
      await _configureLocationSettings();

      _isInitialized = true;
      debugPrint('FusedLocationService: Inicializado com sucesso');

    } catch (e) {
      debugPrint('Erro ao inicializar FusedLocationService: $e');
    }
  }

  /// Configura parâmetros de localização
  Future<void> _configureLocationSettings() async {
    try {
      await _channel.invokeMethod('configureLocationSettings', {
        'updateInterval': _updateInterval,
        'fastestInterval': _fastestInterval,
        'smallestDisplacement': _smallestDisplacement,
        'priority': 'HIGH_ACCURACY',
      });
    } catch (e) {
      debugPrint('Erro ao configurar localização: $e');
    }
  }

  /// Manipula chamadas do canal nativo
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onLocationUpdate':
        _handleLocationUpdate(call.arguments);
        break;
      case 'onLocationError':
        _handleLocationError(call.arguments);
        break;
      default:
        debugPrint('Método não reconhecido: ${call.method}');
    }
  }

  /// Processa atualização de localização
  void _handleLocationUpdate(dynamic arguments) {
    try {
      final Map<String, dynamic> data = Map<String, dynamic>.from(arguments);
      
      final locationData = LocationData(
        latitude: data['latitude']?.toDouble() ?? 0.0,
        longitude: data['longitude']?.toDouble() ?? 0.0,
        accuracy: data['accuracy']?.toDouble() ?? 0.0,
        altitude: data['altitude']?.toDouble(),
        speed: data['speed']?.toDouble() ?? 0.0,
        speedAccuracy: data['speedAccuracy']?.toDouble(),
        heading: data['bearing']?.toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch),
        provider: data['provider'] ?? 'fused',
      );

      _lastKnownLocation = locationData;
      _lastLocationTime = DateTime.now();
      _locationController?.add(locationData);

    } catch (e) {
      debugPrint('Erro ao processar localização: $e');
    }
  }

  /// Processa erro de localização
  void _handleLocationError(dynamic arguments) {
    debugPrint('Erro de localização: $arguments');
    _locationController?.add(null);
  }

  /// Inicia atualizações de localização
  Future<bool> startLocationUpdates() async {
    if (!_isInitialized) await initialize();

    try {
      final result = await _channel.invokeMethod('startLocationUpdates');
      _isLocationEnabled = result == true;
      
      if (_isLocationEnabled) {
        debugPrint('FusedLocationService: Atualizações iniciadas');
      }
      
      return _isLocationEnabled;
    } catch (e) {
      debugPrint('Erro ao iniciar atualizações: $e');
      return false;
    }
  }

  /// Para atualizações de localização
  Future<void> stopLocationUpdates() async {
    try {
      await _channel.invokeMethod('stopLocationUpdates');
      _isLocationEnabled = false;
      debugPrint('FusedLocationService: Atualizações paradas');
    } catch (e) {
      debugPrint('Erro ao parar atualizações: $e');
    }
  }

  /// Obtém localização atual
  Future<LocationData?> getCurrentLocation() async {
    if (!_isInitialized) await initialize();

    try {
      final result = await _channel.invokeMethod('getCurrentLocation');
      if (result != null) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(result);
        
        final locationData = LocationData(
          latitude: data['latitude']?.toDouble() ?? 0.0,
          longitude: data['longitude']?.toDouble() ?? 0.0,
          accuracy: data['accuracy']?.toDouble() ?? 0.0,
          altitude: data['altitude']?.toDouble(),
          speed: data['speed']?.toDouble() ?? 0.0,
          speedAccuracy: data['speedAccuracy']?.toDouble(),
          heading: data['bearing']?.toDouble(),
          timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch),
          provider: data['provider'] ?? 'fused',
        );

        _lastKnownLocation = locationData;
        _lastLocationTime = DateTime.now();
        return locationData;
      }
    } catch (e) {
      debugPrint('Erro ao obter localização atual: $e');
    }

    return _lastKnownLocation;
  }

  /// Configura intervalos de atualização
  Future<void> setUpdateInterval({
    int? updateInterval,
    int? fastestInterval,
    double? smallestDisplacement,
  }) async {
    if (updateInterval != null) _updateInterval = updateInterval;
    if (fastestInterval != null) _fastestInterval = fastestInterval;
    if (smallestDisplacement != null) _smallestDisplacement = smallestDisplacement;

    if (_isInitialized) {
      await _configureLocationSettings();
    }
  }

  /// Verifica se localização está disponível
  Future<bool> isLocationAvailable() async {
    try {
      return await _channel.invokeMethod('isLocationAvailable') ?? false;
    } catch (e) {
      debugPrint('Erro ao verificar disponibilidade: $e');
      return false;
    }
  }

  /// Solicita permissões de localização
  Future<bool> requestLocationPermissions() async {
    try {
      return await _channel.invokeMethod('requestLocationPermissions') ?? false;
    } catch (e) {
      debugPrint('Erro ao solicitar permissões: $e');
      return false;
    }
  }

  /// Adiciona geofence
  Future<bool> addGeofence({
    required String id,
    required double latitude,
    required double longitude,
    required double radius,
    int? expirationDuration,
  }) async {
    try {
      return await _channel.invokeMethod('addGeofence', {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
        'expirationDuration': expirationDuration ?? -1,
      }) ?? false;
    } catch (e) {
      debugPrint('Erro ao adicionar geofence: $e');
      return false;
    }
  }

  /// Remove geofence
  Future<bool> removeGeofence(String id) async {
    try {
      return await _channel.invokeMethod('removeGeofence', {'id': id}) ?? false;
    } catch (e) {
      debugPrint('Erro ao remover geofence: $e');
      return false;
    }
  }

  /// Obtém estatísticas do serviço
  Map<String, dynamic> getServiceStatistics() {
    return {
      'isInitialized': _isInitialized,
      'isLocationEnabled': _isLocationEnabled,
      'lastLocationTime': _lastLocationTime?.toIso8601String(),
      'updateInterval': _updateInterval,
      'fastestInterval': _fastestInterval,
      'smallestDisplacement': _smallestDisplacement,
      'hasLastKnownLocation': _lastKnownLocation != null,
      'lastAccuracy': _lastKnownLocation?.accuracy,
    };
  }

  /// Calcula distância entre duas coordenadas (Haversine)
  static double calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const double earthRadius = 6371000; // metros
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Dispose
  void dispose() {
    _locationTimer?.cancel();
    _locationController?.close();
    stopLocationUpdates();
    _isInitialized = false;
  }
}

