import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/location_data.dart';
import 'fused_location_service.dart';
import 'location_cache_service.dart';
import 'location_service.dart';

/// Modo de operação do serviço de localização
enum LocationMode {
  powerSaving,    // Economia de energia
  balanced,       // Balanceado
  highAccuracy,   // Alta precisão
  adaptive,       // Adaptativo baseado no contexto
}

/// Serviço de localização aprimorado que combina múltiplas fontes
class EnhancedLocationService {
  static final EnhancedLocationService _instance = EnhancedLocationService._internal();
  factory EnhancedLocationService() => _instance;
  EnhancedLocationService._internal();

  bool _isInitialized = false;
  LocationMode _currentMode = LocationMode.adaptive;
  
  // Serviços de localização
  final FusedLocationService _fusedLocationService = FusedLocationService();
  final LocationCacheService _cacheService = LocationCacheService();
  final LocationService _fallbackLocationService = LocationService();

  // Controle de streams
  StreamController<LocationData?>? _locationController;
  StreamSubscription? _fusedSubscription;
  StreamSubscription? _fallbackSubscription;
  Timer? _adaptiveTimer;

  // Estado atual
  LocationData? _lastKnownLocation;
  DateTime? _lastLocationTime;
  bool _isFusedLocationAvailable = false;
  bool _isLocationUpdatesActive = false;

  // Configurações adaptativas
  int _currentUpdateInterval = 5000;
  double _currentAccuracyThreshold = 20.0;
  int _consecutiveFailures = 0;
  static const int _maxConsecutiveFailures = 3;

  // Estatísticas
  int _totalLocationUpdates = 0;
  int _fusedLocationUpdates = 0;
  int _fallbackLocationUpdates = 0;
  double _averageAccuracy = 0.0;

  // Getters
  bool get isInitialized => _isInitialized;
  LocationMode get currentMode => _currentMode;
  LocationData? get lastKnownLocation => _lastKnownLocation;
  bool get isLocationUpdatesActive => _isLocationUpdatesActive;
  Stream<LocationData?> get locationStream => _locationController?.stream ?? const Stream.empty();

  /// Inicializa o serviço aprimorado
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Inicializar serviços dependentes
      await _fusedLocationService.initialize();
      await _cacheService.initialize();

      // Verificar disponibilidade do Fused Location
      _isFusedLocationAvailable = await _fusedLocationService.isLocationAvailable();

      // Configurar stream controller
      _locationController = StreamController<LocationData?>.broadcast();

      // Configurar modo inicial
      await _configureLocationMode(_currentMode);

      // Iniciar timer adaptativo
      _startAdaptiveTimer();

      _isInitialized = true;
      debugPrint('EnhancedLocationService: Inicializado (Fused: $_isFusedLocationAvailable)');

    } catch (e) {
      debugPrint('Erro ao inicializar EnhancedLocationService: $e');
    }
  }

  /// Configura modo de localização
  Future<void> _configureLocationMode(LocationMode mode) async {
    _currentMode = mode;

    switch (mode) {
      case LocationMode.powerSaving:
        _currentUpdateInterval = 30000; // 30 segundos
        _currentAccuracyThreshold = 100.0; // 100 metros
        break;
      case LocationMode.balanced:
        _currentUpdateInterval = 10000; // 10 segundos
        _currentAccuracyThreshold = 50.0; // 50 metros
        break;
      case LocationMode.highAccuracy:
        _currentUpdateInterval = 2000; // 2 segundos
        _currentAccuracyThreshold = 10.0; // 10 metros
        break;
      case LocationMode.adaptive:
        await _calculateAdaptiveSettings();
        break;
    }

    // Aplicar configurações ao Fused Location
    if (_isFusedLocationAvailable) {
      await _fusedLocationService.setUpdateInterval(
        updateInterval: _currentUpdateInterval,
        fastestInterval: (_currentUpdateInterval * 0.5).round(),
        smallestDisplacement: _currentAccuracyThreshold * 0.1,
      );
    }

    debugPrint('EnhancedLocationService: Modo $_currentMode configurado');
  }

  /// Calcula configurações adaptativas
  Future<void> _calculateAdaptiveSettings() async {
    try {
      // Obter estatísticas recentes
      final recentLocations = await _cacheService.getLocations(
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        limit: 50,
      );

      if (recentLocations.isNotEmpty) {
        // Calcular precisão média
        final accuracies = recentLocations
            .where((loc) => loc.accuracy != null)
            .map((loc) => loc.accuracy!)
            .toList();

        if (accuracies.isNotEmpty) {
          _averageAccuracy = accuracies.reduce((a, b) => a + b) / accuracies.length;
        }

        // Calcular velocidade média
        double averageSpeed = 0.0;
        if (recentLocations.length > 1) {
          final speeds = recentLocations
              .where((loc) => loc.speed != null && loc.speed! > 0)
              .map((loc) => loc.speed!)
              .toList();

          if (speeds.isNotEmpty) {
            averageSpeed = speeds.reduce((a, b) => a + b) / speeds.length;
          }
        }

        // Ajustar configurações baseado no contexto
        if (averageSpeed > 15.0) { // Movimento rápido (>54 km/h)
          _currentUpdateInterval = 3000; // Mais frequente
          _currentAccuracyThreshold = 15.0; // Mais preciso
        } else if (averageSpeed > 5.0) { // Movimento moderado (>18 km/h)
          _currentUpdateInterval = 5000; // Balanceado
          _currentAccuracyThreshold = 25.0; // Moderado
        } else { // Movimento lento ou parado
          _currentUpdateInterval = 15000; // Menos frequente
          _currentAccuracyThreshold = 50.0; // Menos preciso
        }
      } else {
        // Configurações padrão se não há histórico
        _currentUpdateInterval = 5000;
        _currentAccuracyThreshold = 25.0;
      }

    } catch (e) {
      debugPrint('Erro ao calcular configurações adaptativas: $e');
      // Usar configurações padrão
      _currentUpdateInterval = 5000;
      _currentAccuracyThreshold = 25.0;
    }
  }

  /// Inicia timer adaptativo
  void _startAdaptiveTimer() {
    _adaptiveTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      if (_currentMode == LocationMode.adaptive) {
        _configureLocationMode(LocationMode.adaptive);
      }
    });
  }

  /// Inicia atualizações de localização
  Future<bool> startLocationUpdates() async {
    if (!_isInitialized) await initialize();
    if (_isLocationUpdatesActive) return true;

    try {
      bool success = false;

      // Tentar usar Fused Location primeiro
      if (_isFusedLocationAvailable) {
        success = await _startFusedLocationUpdates();
      }

      // Fallback para LocationService se Fused falhar
      if (!success) {
        success = await _startFallbackLocationUpdates();
      }

      _isLocationUpdatesActive = success;
      
      if (success) {
        debugPrint('EnhancedLocationService: Atualizações iniciadas');
      }

      return success;

    } catch (e) {
      debugPrint('Erro ao iniciar atualizações: $e');
      return false;
    }
  }

  /// Inicia atualizações com Fused Location
  Future<bool> _startFusedLocationUpdates() async {
    try {
      final success = await _fusedLocationService.startLocationUpdates();
      
      if (success) {
        _fusedSubscription = _fusedLocationService.locationStream.listen(
          _handleFusedLocationUpdate,
          onError: _handleLocationError,
        );
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Erro ao iniciar Fused Location: $e');
      return false;
    }
  }

  /// Inicia atualizações com fallback
  Future<bool> _startFallbackLocationUpdates() async {
    try {
      _fallbackSubscription = _fallbackLocationService.positionStream?.listen(
        _handleFallbackLocationUpdate,
        onError: _handleLocationError,
      );
      
      return _fallbackSubscription != null;
    } catch (e) {
      debugPrint('Erro ao iniciar fallback location: $e');
      return false;
    }
  }

  /// Processa atualização do Fused Location
  void _handleFusedLocationUpdate(LocationData? locationData) {
    if (locationData != null) {
      _processLocationUpdate(locationData, 'fused');
      _fusedLocationUpdates++;
      _consecutiveFailures = 0;
    } else {
      _handleLocationFailure();
    }
  }

  /// Processa atualização do fallback
  void _handleFallbackLocationUpdate(dynamic position) {
    try {
      if (position != null) {
        final locationData = LocationData(
          latitude: position.latitude?.toDouble() ?? 0.0,
          longitude: position.longitude?.toDouble() ?? 0.0,
          accuracy: position.accuracy?.toDouble(),
          altitude: position.altitude?.toDouble(),
          speed: position.speed?.toDouble() ?? 0.0,
          speedAccuracy: position.speedAccuracy?.toDouble(),
          heading: position.heading?.toDouble(),
          timestamp: position.timestamp ?? DateTime.now(),
          provider: 'gps_fallback',
        );

        _processLocationUpdate(locationData, 'fallback');
        _fallbackLocationUpdates++;
        _consecutiveFailures = 0;
      } else {
        _handleLocationFailure();
      }
    } catch (e) {
      debugPrint('Erro ao processar fallback location: $e');
      _handleLocationFailure();
    }
  }

  /// Processa atualização de localização
  void _processLocationUpdate(LocationData locationData, String source) {
    try {
      // Validar qualidade da localização
      if (!_isLocationValid(locationData)) {
        debugPrint('Localização inválida rejeitada: $source');
        return;
      }

      // Filtrar localizações muito próximas temporalmente
      if (_lastLocationTime != null) {
        final timeDiff = DateTime.now().difference(_lastLocationTime!).inSeconds;
        if (timeDiff < 2) { // Menos de 2 segundos
          return;
        }
      }

      // Atualizar estado
      _lastKnownLocation = locationData;
      _lastLocationTime = DateTime.now();
      _totalLocationUpdates++;

      // Adicionar ao cache
      _cacheService.addLocation(locationData);

      // Emitir para stream
      _locationController?.add(locationData);

      // Atualizar estatísticas
      if (locationData.accuracy != null) {
        _averageAccuracy = (_averageAccuracy * 0.9) + (locationData.accuracy! * 0.1);
      }

      debugPrint('Localização processada: $source (${locationData.accuracy?.toStringAsFixed(1)}m)');

    } catch (e) {
      debugPrint('Erro ao processar localização: $e');
    }
  }

  /// Valida qualidade da localização
  bool _isLocationValid(LocationData locationData) {
    // Verificar coordenadas básicas
    if (locationData.latitude == 0.0 && locationData.longitude == 0.0) {
      return false;
    }

    // Verificar precisão
    if (locationData.accuracy != null && locationData.accuracy! > _currentAccuracyThreshold * 2) {
      return false;
    }

    // Verificar se não é muito distante da última localização conhecida
    if (_lastKnownLocation != null) {
      final distance = FusedLocationService.calculateDistance(
        _lastKnownLocation!.latitude,
        _lastKnownLocation!.longitude,
        locationData.latitude,
        locationData.longitude,
      );

      // Rejeitar se movimento muito rápido (>200 km/h)
      if (_lastLocationTime != null) {
        final timeDiff = locationData.timestamp.difference(_lastLocationTime!).inSeconds;
        if (timeDiff > 0) {
          final speed = distance / timeDiff; // m/s
          if (speed > 55.0) { // >200 km/h
            return false;
          }
        }
      }
    }

    return true;
  }

  /// Trata falha de localização
  void _handleLocationFailure() {
    _consecutiveFailures++;
    
    if (_consecutiveFailures >= _maxConsecutiveFailures) {
      debugPrint('Muitas falhas consecutivas, tentando fallback');
      
      // Se estava usando Fused, tentar fallback
      if (_fusedSubscription != null && _fallbackSubscription == null) {
        _startFallbackLocationUpdates();
      }
    }
  }

  /// Trata erro de localização
  void _handleLocationError(dynamic error) {
    debugPrint('Erro de localização: $error');
    _handleLocationFailure();
  }

  /// Para atualizações de localização
  Future<void> stopLocationUpdates() async {
    try {
      await _fusedLocationService.stopLocationUpdates();
      _fusedSubscription?.cancel();
      _fallbackSubscription?.cancel();
      
      _fusedSubscription = null;
      _fallbackSubscription = null;
      _isLocationUpdatesActive = false;
      
      debugPrint('EnhancedLocationService: Atualizações paradas');
    } catch (e) {
      debugPrint('Erro ao parar atualizações: $e');
    }
  }

  /// Obtém localização atual
  Future<LocationData?> getCurrentLocation() async {
    if (!_isInitialized) await initialize();

    try {
      // Tentar Fused Location primeiro
      if (_isFusedLocationAvailable) {
        final location = await _fusedLocationService.getCurrentLocation();
        if (location != null && _isLocationValid(location)) {
          _lastKnownLocation = location;
          return location;
        }
      }

      // Fallback para LocationService
      final position = await _fallbackLocationService.getCurrentPosition();
      if (position != null) {
        final locationData = LocationData(
          latitude: position.latitude?.toDouble() ?? 0.0,
          longitude: position.longitude?.toDouble() ?? 0.0,
          accuracy: position.accuracy?.toDouble(),
          altitude: position.altitude?.toDouble(),
          speed: position.speed?.toDouble() ?? 0.0,
          speedAccuracy: position.speedAccuracy?.toDouble(),
          heading: position.heading?.toDouble(),
          timestamp: position.timestamp ?? DateTime.now(),
          provider: 'gps_current',
        );

        if (_isLocationValid(locationData)) {
          _lastKnownLocation = locationData;
          return locationData;
        }
      }

      // Retornar última localização conhecida se disponível
      return _lastKnownLocation;

    } catch (e) {
      debugPrint('Erro ao obter localização atual: $e');
      return _lastKnownLocation;
    }
  }

  /// Define modo de localização
  Future<void> setLocationMode(LocationMode mode) async {
    if (_currentMode != mode) {
      await _configureLocationMode(mode);
      
      // Reiniciar atualizações se estiverem ativas
      if (_isLocationUpdatesActive) {
        await stopLocationUpdates();
        await startLocationUpdates();
      }
    }
  }

  /// Obtém estatísticas do serviço
  Map<String, dynamic> getServiceStatistics() {
    return {
      'isInitialized': _isInitialized,
      'currentMode': _currentMode.toString(),
      'isLocationUpdatesActive': _isLocationUpdatesActive,
      'isFusedLocationAvailable': _isFusedLocationAvailable,
      'totalLocationUpdates': _totalLocationUpdates,
      'fusedLocationUpdates': _fusedLocationUpdates,
      'fallbackLocationUpdates': _fallbackLocationUpdates,
      'averageAccuracy': _averageAccuracy,
      'currentUpdateInterval': _currentUpdateInterval,
      'currentAccuracyThreshold': _currentAccuracyThreshold,
      'consecutiveFailures': _consecutiveFailures,
      'lastLocationTime': _lastLocationTime?.toIso8601String(),
      'hasLastKnownLocation': _lastKnownLocation != null,
    };
  }

  /// Força atualização de configurações adaptativas
  Future<void> forceAdaptiveUpdate() async {
    if (_currentMode == LocationMode.adaptive) {
      await _configureLocationMode(LocationMode.adaptive);
    }
  }

  /// Dispose
  void dispose() {
    _adaptiveTimer?.cancel();
    _fusedSubscription?.cancel();
    _fallbackSubscription?.cancel();
    _locationController?.close();
    _fusedLocationService.dispose();
    _cacheService.dispose();
    _isInitialized = false;
  }
}

