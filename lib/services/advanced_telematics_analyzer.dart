import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/location_data.dart';
import '../models/telematics_event.dart';

/// Analisador avançado de telemática para cálculo preciso de scores e eventos
class AdvancedTelematicsAnalyzer {
  static final AdvancedTelematicsAnalyzer _instance = AdvancedTelematicsAnalyzer._internal();
  factory AdvancedTelematicsAnalyzer() => _instance;
  AdvancedTelematicsAnalyzer._internal();

  // Histórico de dados para análise
  final List<LocationData> _locationHistory = [];
  final List<double> _speedHistory = [];
  final List<double> _accelerationHistory = [];
  
  // Contadores de eventos
  int _hardBrakingCount = 0;
  int _rapidAccelerationCount = 0;
  int _sharpTurnCount = 0;
  int _speedingCount = 0;
  
  // Configurações de thresholds
  static const double _hardBrakingThreshold = 4.0; // m/s²
  static const double _rapidAccelerationThreshold = 3.0; // m/s²
  static const double _sharpTurnThreshold = 0.5; // rad/s
  static const double _speedingThreshold = 80.0; // km/h
  static const double _excessiveSpeedingThreshold = 100.0; // km/h
  
  // Configurações de análise
  static const int _maxHistorySize = 100;
  static const double _minSpeedForAnalysis = 5.0; // km/h
  
  /// Adiciona nova localização para análise
  void addLocationData(LocationData location) {
    _locationHistory.add(location);
    _speedHistory.add(location.speed ?? 0.0);
    
    // Manter tamanho do histórico
    if (_locationHistory.length > _maxHistorySize) {
      _locationHistory.removeAt(0);
      _speedHistory.removeAt(0);
    }
    
    // Analisar apenas se há dados suficientes e velocidade significativa
    if (_locationHistory.length >= 2 && (location.speed ?? 0.0) > _minSpeedForAnalysis) {
      _analyzeLocationData(location);
    }
  }

  /// Analisa dados de localização para detectar eventos
  void _analyzeLocationData(LocationData currentLocation) {
    if (_locationHistory.length < 2) return;
    
    LocationData previousLocation = _locationHistory[_locationHistory.length - 2];
    
    // Calcular aceleração
    double acceleration = _calculateAcceleration(previousLocation, currentLocation);
    _accelerationHistory.add(acceleration);
    
    if (_accelerationHistory.length > _maxHistorySize) {
      _accelerationHistory.removeAt(0);
    }
    
    // Detectar eventos
    _detectHardBraking(acceleration);
    _detectRapidAcceleration(acceleration);
    _detectSpeeding(currentLocation.speed ?? 0.0);
    _detectSharpTurn(previousLocation, currentLocation);
  }

  /// Calcula aceleração entre duas localizações
  double _calculateAcceleration(LocationData previous, LocationData current) {
    double timeDiff = current.timestamp.difference(previous.timestamp).inMilliseconds / 1000.0;
    if (timeDiff <= 0) return 0.0;
    
    // Converter velocidades de km/h para m/s
    double previousSpeedMs = (previous.speed ?? 0.0) / 3.6;
    double currentSpeedMs = (current.speed ?? 0.0) / 3.6;
    
    return (currentSpeedMs - previousSpeedMs) / timeDiff;
  }

  /// Detecta frenagem brusca
  void _detectHardBraking(double acceleration) {
    if (acceleration < -_hardBrakingThreshold) {
      _hardBrakingCount++;
      debugPrint('🚨 Frenagem brusca detectada: ${acceleration.toStringAsFixed(2)} m/s²');
    }
  }

  /// Detecta aceleração rápida
  void _detectRapidAcceleration(double acceleration) {
    if (acceleration > _rapidAccelerationThreshold) {
      _rapidAccelerationCount++;
      debugPrint('🚨 Aceleração rápida detectada: ${acceleration.toStringAsFixed(2)} m/s²');
    }
  }

  /// Detecta excesso de velocidade
  void _detectSpeeding(double speed) {
    if (speed > _speedingThreshold) {
      _speedingCount++;
      
      if (speed > _excessiveSpeedingThreshold) {
        debugPrint('🚨 Excesso de velocidade GRAVE detectado: ${speed.toStringAsFixed(1)} km/h');
      } else {
        debugPrint('⚠️ Excesso de velocidade detectado: ${speed.toStringAsFixed(1)} km/h');
      }
    }
  }

  /// Detecta curvas acentuadas
  void _detectSharpTurn(LocationData previous, LocationData current) {
    if ((current.speed ?? 0.0) < _minSpeedForAnalysis) return;
    
    // Calcular mudança de direção
    double headingChange = _calculateHeadingChange(previous.heading ?? 0.0, current.heading ?? 0.0);
    double timeDiff = current.timestamp.difference(previous.timestamp).inMilliseconds / 1000.0;
    
    if (timeDiff > 0) {
      double angularVelocity = headingChange / timeDiff;
      
      if (angularVelocity.abs() > _sharpTurnThreshold) {
        _sharpTurnCount++;
        debugPrint('🚨 Curva acentuada detectada: ${angularVelocity.toStringAsFixed(2)} rad/s');
      }
    }
  }

  /// Calcula mudança de direção considerando a natureza circular dos ângulos
  double _calculateHeadingChange(double previousHeading, double currentHeading) {
    double diff = currentHeading - previousHeading;
    
    // Normalizar para [-180, 180]
    while (diff > 180) diff -= 360;
    while (diff < -180) diff += 360;
    
    return diff * math.pi / 180; // Converter para radianos
  }

  /// Calcula score de segurança baseado nos eventos detectados
  double calculateSafetyScore({
    double distance = 0.0,
    int durationMinutes = 0,
  }) {
    double score = 100.0;
    
    // Penalizar por eventos (pesos ajustados)
    score -= _hardBrakingCount * 8.0;
    score -= _rapidAccelerationCount * 6.0;
    score -= _sharpTurnCount * 5.0;
    score -= _speedingCount * 3.0;
    
    // Penalizar mais por velocidade excessiva
    double excessiveSpeeding = _speedHistory.where((speed) => speed > _excessiveSpeedingThreshold).length.toDouble();
    score -= excessiveSpeeding * 10.0;
    
    // Bônus por condução suave (sem eventos)
    if (_getTotalEvents() == 0 && distance > 1.0) {
      score += 5.0; // Bônus por condução perfeita
    }
    
    // Penalizar por condução muito agressiva
    if (_getTotalEvents() > 10) {
      score -= 20.0; // Penalidade extra por condução muito agressiva
    }
    
    // Garantir que o score esteja entre 0 e 100
    return math.max(0.0, math.min(100.0, score));
  }

  /// Calcula score baseado na velocidade média
  double calculateSpeedScore() {
    if (_speedHistory.isEmpty) return 100.0;
    
    double avgSpeed = _speedHistory.reduce((a, b) => a + b) / _speedHistory.length;
    double score = 100.0;
    
    // Penalizar velocidade média muito alta
    if (avgSpeed > _speedingThreshold) {
      score -= (avgSpeed - _speedingThreshold) * 2.0;
    }
    
    // Penalizar velocidade média muito baixa (pode indicar trânsito ou condução hesitante)
    if (avgSpeed < 20.0 && avgSpeed > 5.0) {
      score -= (20.0 - avgSpeed) * 0.5;
    }
    
    return math.max(0.0, math.min(100.0, score));
  }

  /// Calcula score baseado na suavidade da condução
  double calculateSmoothnessScore() {
    if (_accelerationHistory.length < 10) return 100.0;
    
    // Calcular variância da aceleração (menor variância = condução mais suave)
    double mean = _accelerationHistory.reduce((a, b) => a + b) / _accelerationHistory.length;
    double variance = _accelerationHistory
        .map((x) => math.pow(x - mean, 2))
        .reduce((a, b) => a + b) / _accelerationHistory.length;
    
    double score = 100.0 - (variance * 10.0);
    return math.max(0.0, math.min(100.0, score));
  }

  /// Obtém contagem total de eventos
  int getTotalEventCount() {
    return _hardBrakingCount + _rapidAccelerationCount + _sharpTurnCount + _speedingCount;
  }

  /// Obtém contagem de eventos por tipo
  Map<String, int> getEventCounts() {
    return {
      'hardBraking': _hardBrakingCount,
      'rapidAcceleration': _rapidAccelerationCount,
      'sharpTurn': _sharpTurnCount,
      'speeding': _speedingCount,
    };
  }

  /// Obtém estatísticas detalhadas
  Map<String, dynamic> getDetailedStats() {
    return {
      'totalEvents': getTotalEventCount(),
      'eventCounts': getEventCounts(),
      'safetyScore': calculateSafetyScore(),
      'speedScore': calculateSpeedScore(),
      'smoothnessScore': calculateSmoothnessScore(),
      'avgSpeed': _speedHistory.isNotEmpty ? _speedHistory.reduce((a, b) => a + b) / _speedHistory.length : 0.0,
      'maxSpeed': _speedHistory.isNotEmpty ? _speedHistory.reduce(math.max) : 0.0,
      'dataPoints': _locationHistory.length,
    };
  }

  /// Reseta contadores (para nova viagem)
  void reset() {
    _locationHistory.clear();
    _speedHistory.clear();
    _accelerationHistory.clear();
    _hardBrakingCount = 0;
    _rapidAccelerationCount = 0;
    _sharpTurnCount = 0;
    _speedingCount = 0;
  }

  /// Inicializa o analisador
  Future<void> initialize() async {
    debugPrint('AdvancedTelematicsAnalyzer: Inicializado');
  }

  /// Obtém total de eventos (método auxiliar)
  int _getTotalEvents() {
    return _hardBrakingCount + _rapidAccelerationCount + _sharpTurnCount + _speedingCount;
  }
}
