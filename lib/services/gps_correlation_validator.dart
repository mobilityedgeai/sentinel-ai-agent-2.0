import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/telematics_event.dart';
import '../models/location_data.dart';
import 'fused_location_service.dart';
import 'location_cache_service.dart';

/// Resultado da validação GPS
class GpsValidationResult {
  final bool isValid;
  final bool hasGpsData;
  final double confidence;
  final String reason;
  final Map<String, dynamic> metadata;
  
  GpsValidationResult({
    required this.isValid,
    required this.hasGpsData,
    required this.confidence,
    required this.reason,
    this.metadata = const {},
  });
}

/// Valida eventos de telemática correlacionando com dados GPS
/// Agora integrado com Fused Location API para maior precisão
class GpsCorrelationValidator {
  static final GpsCorrelationValidator _instance = GpsCorrelationValidator._internal();
  factory GpsCorrelationValidator() => _instance;
  GpsCorrelationValidator._internal();

  bool _isInitialized = false;
  final FusedLocationService _fusedLocationService = FusedLocationService();
  final LocationCacheService _cacheService = LocationCacheService();
  final List<LocationData> _gpsHistory = [];
  final List<double> _accuracyHistory = [];
  
  // Configurações de validação aprimoradas
  static const int _gpsHistorySize = 50; // Últimas 50 posições
  static const double _speedThreshold = 2.0; // m/s (7.2 km/h) - mínimo para considerar movimento
  static const double _accelerationThreshold = 1.0; // m/s² - mínimo para validar aceleração
  static const double _highAccuracyThreshold = 10.0; // metros - precisão alta
  static const double _mediumAccuracyThreshold = 20.0; // metros - precisão média
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _fusedLocationService.initialize();
      await _cacheService.initialize();
      _isInitialized = true;
      debugPrint('GpsCorrelationValidator: Inicializado com Fused Location API');
    } catch (e) {
      debugPrint('Erro ao inicializar GpsCorrelationValidator: $e');
    }
  }

  /// Valida um evento de telemática usando dados GPS com maior precisão
  Future<GpsValidationResult> validateEvent(
    TelematicsEventType eventType,
    double magnitude,
    DateTime timestamp
  ) async {
    if (!_isInitialized) {
      return GpsValidationResult(
        isValid: true, // Assumir válido se GPS não disponível
        hasGpsData: false,
        confidence: 0.5,
        reason: 'GPS não inicializado'
      );
    }
    
    // Obter posição atual com alta precisão
    try {
      final currentPosition = await _fusedLocationService.getCurrentLocation();
      if (currentPosition != null) {
        _updateGpsHistory(currentPosition);
        
        // Salvar no cache para análise posterior
        await _cacheService.addLocation(currentPosition);
      }
    } catch (e) {
      debugPrint('Erro ao obter posição GPS: $e');
    }
    
    if (_gpsHistory.isEmpty) {
      return GpsValidationResult(
        isValid: true,
        hasGpsData: false,
        confidence: 0.5,
        reason: 'Sem dados GPS disponíveis'
      );
    }
    
    // Verificar qualidade dos dados GPS
    final dataQuality = _assessDataQuality();
    
    // Validar baseado no tipo de evento com qualidade considerada
    GpsValidationResult result;
    switch (eventType) {
      case TelematicsEventType.hardBraking:
        result = _validateHardBraking(magnitude);
        break;
      case TelematicsEventType.rapidAcceleration:
        result = _validateRapidAcceleration(magnitude);
        break;
      case TelematicsEventType.sharpTurn:
        result = _validateSharpTurn(magnitude);
        break;
      case TelematicsEventType.speeding:
        result = _validateSpeeding(magnitude);
        break;
      case TelematicsEventType.highGForce:
        result = _validateHighGForce(magnitude);
        break;
      default:
        result = GpsValidationResult(
          isValid: true,
          hasGpsData: true,
          confidence: 0.7,
          reason: 'Tipo de evento não validável por GPS'
        );
    }
    
    // Ajustar confiança baseada na qualidade dos dados
    final adjustedConfidence = result.confidence * dataQuality.qualityScore;
    
    return GpsValidationResult(
      isValid: result.isValid,
      hasGpsData: result.hasGpsData,
      confidence: adjustedConfidence,
      reason: result.reason,
      metadata: {
        ...result.metadata,
        'dataQuality': dataQuality.toMap(),
        'fusedLocationUsed': true,
        'cacheEnabled': true,
      }
    );
  }
  
  void _updateGpsHistory(LocationData position) {
    _gpsHistory.add(position);
    _accuracyHistory.add(position.accuracy ?? 0.0);
    
    if (_gpsHistory.length > _gpsHistorySize) {
      _gpsHistory.removeAt(0);
    }
    if (_accuracyHistory.length > _gpsHistorySize) {
      _accuracyHistory.removeAt(0);
    }
  }
  
  /// Avalia a qualidade dos dados GPS
  _DataQuality _assessDataQuality() {
    if (_gpsHistory.isEmpty) {
      return _DataQuality(
        qualityScore: 0.5,
        averageAccuracy: 999.0,
        dataFreshness: 0.0,
        consistencyScore: 0.5
      );
    }
    
    // Calcular precisão média
    final averageAccuracy = _accuracyHistory.isNotEmpty 
        ? _accuracyHistory.reduce((a, b) => a + b) / _accuracyHistory.length
        : 999.0;
    
    // Calcular frescor dos dados
    final lastUpdate = _gpsHistory.last.timestamp;
    final secondsSinceUpdate = DateTime.now().difference(lastUpdate).inSeconds;
    final dataFreshness = math.max(0.0, 1.0 - (secondsSinceUpdate / 30.0)); // 30s máximo
    
    // Calcular consistência (variação da precisão)
    double consistencyScore = 0.5;
    if (_accuracyHistory.length >= 5) {
      final variance = _calculateVariance(_accuracyHistory);
      consistencyScore = math.max(0.1, 1.0 - (variance / 100.0)); // Normalizar
    }
    
    // Score geral de qualidade
    double qualityScore = 0.5;
    if (averageAccuracy < _highAccuracyThreshold) {
      qualityScore = 0.9;
    } else if (averageAccuracy < _mediumAccuracyThreshold) {
      qualityScore = 0.7;
    } else {
      qualityScore = 0.4;
    }
    
    // Ajustar por frescor e consistência
    qualityScore = qualityScore * dataFreshness * consistencyScore;
    
    return _DataQuality(
      qualityScore: qualityScore,
      averageAccuracy: averageAccuracy,
      dataFreshness: dataFreshness,
      consistencyScore: consistencyScore
    );
  }
  
  double _calculateVariance(List<double> values) {
    if (values.length < 2) return 0.0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values
        .map((x) => math.pow(x - mean, 2))
        .reduce((a, b) => a + b) / values.length;
    
    return variance.toDouble();
  }
  
  GpsValidationResult _validateHardBraking(double magnitude) {
    if (_gpsHistory.length < 3) {
      return GpsValidationResult(
        isValid: true,
        hasGpsData: true,
        confidence: 0.5,
        reason: 'Histórico GPS insuficiente'
      );
    }
    
    // Calcular desaceleração baseada no GPS com maior precisão
    final recent = _gpsHistory.length >= 5 
      ? _gpsHistory.sublist(_gpsHistory.length - 5)  // Usar mais pontos para maior precisão
      : _gpsHistory;
    
    // Calcular desaceleração usando regressão linear simples
    final gpsDeceleration = _calculateAccelerationFromGPS(recent, false);
    
    if (gpsDeceleration == null) {
      return GpsValidationResult(
        isValid: true,
        hasGpsData: true,
        confidence: 0.5,
        reason: 'Dados GPS temporais inválidos'
      );
    }
    
    // Verificar se há correlação entre sensor e GPS
    final expectedDeceleration = magnitude / 2.0; // Conversão aproximada
    final correlation = _calculateCorrelation(gpsDeceleration.abs(), expectedDeceleration);
    
    final isValid = correlation > 0.4 && gpsDeceleration < -1.5; // Desaceleração significativa
    final confidence = math.max(0.1, math.min(1.0, correlation));
    
    return GpsValidationResult(
      isValid: isValid,
      hasGpsData: true,
      confidence: confidence,
      reason: isValid 
        ? 'GPS confirma desaceleração (${gpsDeceleration.toStringAsFixed(2)} m/s²)'
        : 'GPS não confirma desaceleração significativa',
      metadata: {
        'gpsDeceleration': gpsDeceleration,
        'expectedDeceleration': expectedDeceleration,
        'correlation': correlation,
      }
    );
  }
  
  GpsValidationResult _validateRapidAcceleration(double magnitude) {
    if (_gpsHistory.length < 3) {
      return GpsValidationResult(
        isValid: true,
        hasGpsData: true,
        confidence: 0.5,
        reason: 'Histórico GPS insuficiente'
      );
    }
    
    // Calcular aceleração baseada no GPS
    final recent = _gpsHistory.length >= 5 
      ? _gpsHistory.sublist(_gpsHistory.length - 5)
      : _gpsHistory;
    
    final gpsAcceleration = _calculateAccelerationFromGPS(recent, true);
    
    if (gpsAcceleration == null) {
      return GpsValidationResult(
        isValid: true,
        hasGpsData: true,
        confidence: 0.5,
        reason: 'Dados GPS temporais inválidos'
      );
    }
    
    // Verificar correlação
    final expectedAcceleration = magnitude / 2.0;
    final correlation = _calculateCorrelation(gpsAcceleration, expectedAcceleration);
    
    final isValid = correlation > 0.4 && gpsAcceleration > 1.5;
    final confidence = math.max(0.1, math.min(1.0, correlation));
    
    return GpsValidationResult(
      isValid: isValid,
      hasGpsData: true,
      confidence: confidence,
      reason: isValid 
        ? 'GPS confirma aceleração (${gpsAcceleration.toStringAsFixed(2)} m/s²)'
        : 'GPS não confirma aceleração significativa',
      metadata: {
        'gpsAcceleration': gpsAcceleration,
        'expectedAcceleration': expectedAcceleration,
        'correlation': correlation,
      }
    );
  }
  
  /// Calcula aceleração a partir de dados GPS usando regressão linear
  double? _calculateAccelerationFromGPS(List<LocationData> positions, bool isAcceleration) {
    if (positions.length < 2) return null;
    
    // Preparar dados para regressão linear
    final List<double> times = [];
    final List<double> speeds = [];
    
    final baseTime = positions.first.timestamp.millisecondsSinceEpoch / 1000.0;
    
    for (final position in positions) {
      final time = position.timestamp.millisecondsSinceEpoch / 1000.0 - baseTime;
      final speed = position.speed ?? 0.0;
      
      times.add(time);
      speeds.add(speed);
    }
    
    // Calcular regressão linear simples
    final n = times.length;
    final sumX = times.reduce((a, b) => a + b);
    final sumY = speeds.reduce((a, b) => a + b);
    final sumXY = List.generate(n, (i) => times[i] * speeds[i]).reduce((a, b) => a + b);
    final sumX2 = times.map((x) => x * x).reduce((a, b) => a + b);
    
    final denominator = n * sumX2 - sumX * sumX;
    if (denominator.abs() < 0.001) return null; // Evitar divisão por zero
    
    final slope = (n * sumXY - sumX * sumY) / denominator;
    
    return slope; // Slope é a aceleração (m/s²)
  }
  
  double _calculateCorrelation(double actual, double expected) {
    if (expected == 0) return actual == 0 ? 1.0 : 0.0;
    
    final ratio = actual / expected;
    final correlation = 1.0 - (ratio - 1.0).abs();
    
    return math.max(0.0, math.min(1.0, correlation));
  }
  
  GpsValidationResult _validateSharpTurn(double magnitude) {
    if (_gpsHistory.length < 4) {
      return GpsValidationResult(
        isValid: true,
        hasGpsData: true,
        confidence: 0.5,
        reason: 'Histórico GPS insuficiente'
      );
    }
    
    // Calcular mudança de direção baseada no GPS com maior precisão
    final recent = _gpsHistory.length >= 6 
      ? _gpsHistory.sublist(_gpsHistory.length - 6)
      : _gpsHistory;
    
    double totalHeadingChange = 0.0;
    double maxSingleChange = 0.0;
    
    for (int i = 1; i < recent.length; i++) {
      final prev = recent[i-1];
      final curr = recent[i];
      
      if (prev.heading != null && curr.heading != null) {
        double headingChange = (curr.heading! - prev.heading!).abs();
        if (headingChange > 180) {
          headingChange = 360 - headingChange; // Normalizar para menor ângulo
        }
        totalHeadingChange += headingChange;
        maxSingleChange = math.max(maxSingleChange, headingChange);
      }
    }
    
    // Verificar se há mudança significativa de direção
    final isValid = totalHeadingChange > 20.0 || maxSingleChange > 15.0;
    final confidence = math.min(1.0, math.max(totalHeadingChange / 60.0, maxSingleChange / 30.0));
    
    return GpsValidationResult(
      isValid: isValid,
      hasGpsData: true,
      confidence: confidence,
      reason: isValid 
        ? 'GPS confirma mudança de direção (total: ${totalHeadingChange.toStringAsFixed(1)}°, máx: ${maxSingleChange.toStringAsFixed(1)}°)'
        : 'GPS não confirma mudança significativa de direção',
      metadata: {
        'totalHeadingChange': totalHeadingChange,
        'maxSingleChange': maxSingleChange,
      }
    );
  }
  
  GpsValidationResult _validateSpeeding(double magnitude) {
    if (_gpsHistory.isEmpty) {
      return GpsValidationResult(
        isValid: true,
        hasGpsData: false,
        confidence: 0.5,
        reason: 'Sem dados GPS'
      );
    }
    
    final currentSpeed = _gpsHistory.last.speed ?? 0.0;
    final speedKmh = currentSpeed * 3.6; // m/s para km/h
    
    // Verificar se velocidade GPS confirma excesso com maior precisão
    final tolerance = _getSpeedTolerance();
    final isValid = speedKmh >= (magnitude - tolerance);
    final confidence = isValid ? 0.95 : 0.1; // Alta confiança para velocidade
    
    return GpsValidationResult(
      isValid: isValid,
      hasGpsData: true,
      confidence: confidence,
      reason: isValid 
        ? 'GPS confirma velocidade (${speedKmh.toStringAsFixed(1)} km/h vs ${magnitude.toStringAsFixed(1)} km/h)'
        : 'GPS não confirma velocidade reportada (${speedKmh.toStringAsFixed(1)} km/h vs ${magnitude.toStringAsFixed(1)} km/h)',
      metadata: {
        'gpsSpeedKmh': speedKmh,
        'reportedSpeedKmh': magnitude,
        'tolerance': tolerance,
      }
    );
  }
  
  double _getSpeedTolerance() {
    // Tolerância baseada na precisão atual
    if (_accuracyHistory.isEmpty) return 5.0;
    
    final currentAccuracy = _accuracyHistory.last;
    if (currentAccuracy < _highAccuracyThreshold) {
      return 2.0; // Alta precisão = baixa tolerância
    } else if (currentAccuracy < _mediumAccuracyThreshold) {
      return 5.0; // Precisão média = tolerância média
    } else {
      return 10.0; // Baixa precisão = alta tolerância
    }
  }
  
  GpsValidationResult _validateHighGForce(double magnitude) {
    // Força G alta pode ser validada indiretamente por mudanças bruscas
    if (_gpsHistory.length < 3) {
      return GpsValidationResult(
        isValid: true,
        hasGpsData: true,
        confidence: 0.6,
        reason: 'Histórico GPS insuficiente para validar força G'
      );
    }
    
    // Verificar se há mudanças bruscas na velocidade ou direção
    final recent = _gpsHistory.length >= 5 
      ? _gpsHistory.sublist(_gpsHistory.length - 5)
      : _gpsHistory;
    
    final acceleration = _calculateAccelerationFromGPS(recent, true);
    
    if (acceleration == null) {
      return GpsValidationResult(
        isValid: true,
        hasGpsData: true,
        confidence: 0.5,
        reason: 'Dados GPS temporais inválidos'
      );
    }
    
    // Força G alta deve corresponder a mudanças significativas
    final isValid = acceleration.abs() > 2.5; // Mudança significativa
    final confidence = math.min(1.0, acceleration.abs() / 6.0);
    
    return GpsValidationResult(
      isValid: isValid,
      hasGpsData: true,
      confidence: confidence,
      reason: isValid 
        ? 'GPS confirma mudança brusca (${acceleration.toStringAsFixed(2)} m/s²)'
        : 'GPS não confirma mudança brusca significativa',
      metadata: {
        'gpsAcceleration': acceleration,
        'expectedMagnitude': magnitude,
      }
    );
  }
  
  /// Obtém estatísticas do validador GPS aprimoradas
  Map<String, dynamic> getValidationStatistics() {
    final currentSpeed = _gpsHistory.isNotEmpty ? _gpsHistory.last.speed : 0.0;
    final averageSpeed = _gpsHistory.isNotEmpty 
      ? _gpsHistory.map((p) => p.speed ?? 0.0).reduce((a, b) => a + b) / _gpsHistory.length
      : 0.0;
    
    final dataQuality = _assessDataQuality();
    
    return {
      'isInitialized': _isInitialized,
      'gpsHistorySize': _gpsHistory.length,
      'currentSpeed': (currentSpeed ?? 0.0) * 3.6, // km/h
      'averageSpeed': averageSpeed * 3.6, // km/h
      'hasRecentData': _gpsHistory.isNotEmpty && 
        DateTime.now().difference(_gpsHistory.last.timestamp).inSeconds < 30,
      'fusedLocationEnabled': _fusedLocationService.isInitialized,
      'cacheEnabled': _cacheService.isInitialized,
      'dataQuality': dataQuality.toMap(),
      'averageAccuracy': _accuracyHistory.isNotEmpty 
          ? _accuracyHistory.reduce((a, b) => a + b) / _accuracyHistory.length
          : 999.0,
    };
  }
  
  /// Limpa histórico GPS
  void clearHistory() {
    _gpsHistory.clear();
    _accuracyHistory.clear();
  }
}

/// Classe para avaliar qualidade dos dados GPS
class _DataQuality {
  final double qualityScore;
  final double averageAccuracy;
  final double dataFreshness;
  final double consistencyScore;
  
  _DataQuality({
    required this.qualityScore,
    required this.averageAccuracy,
    required this.dataFreshness,
    required this.consistencyScore,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'qualityScore': qualityScore,
      'averageAccuracy': averageAccuracy,
      'dataFreshness': dataFreshness,
      'consistencyScore': consistencyScore,
    };
  }
}

