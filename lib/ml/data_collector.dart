import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/telematics_event.dart';
import '../models/location_data.dart';
import '../services/sensor_service.dart';
import '../services/phone_stability_detector.dart';
import '../services/gps_correlation_validator.dart';
import '../services/smart_driving_mode.dart';

/// Amostra de dados para treinamento de ML
class MLDataSample {
  final String id;
  final DateTime timestamp;
  final TelematicsEventType eventType;
  final double magnitude;
  final Map<String, double> sensorFeatures;
  final Map<String, double> contextFeatures;
  final Map<String, double> preprocessingFeatures;
  final bool isValidEvent; // Ground truth (será definido manualmente ou por validação)
  final double? userFeedback; // Feedback do usuário (0.0 = falso positivo, 1.0 = verdadeiro)
  
  MLDataSample({
    required this.id,
    required this.timestamp,
    required this.eventType,
    required this.magnitude,
    required this.sensorFeatures,
    required this.contextFeatures,
    required this.preprocessingFeatures,
    required this.isValidEvent,
    this.userFeedback,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'event_type': eventType.toString().split('.').last,
      'magnitude': magnitude,
      'sensor_features': jsonEncode(sensorFeatures),
      'context_features': jsonEncode(contextFeatures),
      'preprocessing_features': jsonEncode(preprocessingFeatures),
      'is_valid_event': isValidEvent ? 1 : 0,
      'user_feedback': userFeedback,
    };
  }
  
  factory MLDataSample.fromMap(Map<String, dynamic> map) {
    return MLDataSample(
      id: map['id'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      eventType: TelematicsEventType.values.firstWhere(
        (e) => e.toString().split('.').last == map['event_type'],
        orElse: () => TelematicsEventType.hardBraking,
      ),
      magnitude: map['magnitude'],
      sensorFeatures: Map<String, double>.from(jsonDecode(map['sensor_features'])),
      contextFeatures: Map<String, double>.from(jsonDecode(map['context_features'])),
      preprocessingFeatures: Map<String, double>.from(jsonDecode(map['preprocessing_features'])),
      isValidEvent: map['is_valid_event'] == 1,
      userFeedback: map['user_feedback'],
    );
  }
}

/// Sistema de coleta de dados para treinamento de Machine Learning
class MLDataCollector {
  static final MLDataCollector _instance = MLDataCollector._internal();
  factory MLDataCollector() => _instance;
  MLDataCollector._internal();

  bool _isCollecting = false;
  final List<MLDataSample> _collectedSamples = [];
  final StreamController<MLDataSample> _sampleController = StreamController<MLDataSample>.broadcast();
  
  // Serviços necessários
  final PhoneStabilityDetector _phoneStabilityDetector = PhoneStabilityDetector();
  final GpsCorrelationValidator _gpsValidator = GpsCorrelationValidator();
  final SmartDrivingMode _smartDrivingMode = SmartDrivingMode();
  
  // Configurações
  static const int _maxSamples = 10000; // Máximo de amostras em memória
  static const Duration _sampleInterval = Duration(milliseconds: 100); // 10Hz
  
  bool get isCollecting => _isCollecting;
  Stream<MLDataSample> get sampleStream => _sampleController.stream;
  List<MLDataSample> get collectedSamples => List.unmodifiable(_collectedSamples);
  
  Future<void> initialize() async {
    await _phoneStabilityDetector.initialize();
    await _gpsValidator.initialize();
    await _smartDrivingMode.initialize();
    debugPrint('MLDataCollector: Inicializado');
  }

  /// Inicia a coleta de dados
  Future<void> startCollection() async {
    if (_isCollecting) return;
    
    _isCollecting = true;
    debugPrint('MLDataCollector: Iniciando coleta de dados');
  }
  
  /// Para a coleta de dados
  void stopCollection() {
    _isCollecting = false;
    debugPrint('MLDataCollector: Parando coleta de dados');
  }

  /// Coleta uma amostra de dados quando um evento é detectado
  Future<MLDataSample?> collectEventSample(
    TelematicsEventType eventType,
    double magnitude,
    SensorData sensorData,
    LocationData? locationData,
  ) async {
    if (!_isCollecting) return null;
    
    try {
      // FEATURE ENGINEERING: Extrair características dos sensores
      final sensorFeatures = await _extractSensorFeatures(sensorData);
      
      // FEATURE ENGINEERING: Extrair características do contexto
      final contextFeatures = await _extractContextFeatures(locationData);
      
      // FEATURE ENGINEERING: Extrair características dos algoritmos de pré-processamento
      final preprocessingFeatures = await _extractPreprocessingFeatures(
        eventType, magnitude, sensorData, locationData
      );
      
      // Criar amostra
      final sample = MLDataSample(
        id: _generateSampleId(),
        timestamp: DateTime.now(),
        eventType: eventType,
        magnitude: magnitude,
        sensorFeatures: sensorFeatures,
        contextFeatures: contextFeatures,
        preprocessingFeatures: preprocessingFeatures,
        isValidEvent: true, // Será ajustado posteriormente
      );
      
      // Adicionar à coleção
      _addSample(sample);
      
      // Notificar listeners
      _sampleController.add(sample);
      
      return sample;
      
    } catch (e) {
      debugPrint('Erro ao coletar amostra: $e');
      return null;
    }
  }
  
  /// Extrai características dos dados de sensores
  Future<Map<String, double>> _extractSensorFeatures(SensorData sensorData) async {
    return {
      // Aceleração
      'accel_x': sensorData.accelerationX,
      'accel_y': sensorData.accelerationY,
      'accel_z': sensorData.accelerationZ,
      'accel_magnitude': math.sqrt(
        sensorData.accelerationX * sensorData.accelerationX +
        sensorData.accelerationY * sensorData.accelerationY +
        sensorData.accelerationZ * sensorData.accelerationZ
      ),
      
      // Giroscópio
      'gyro_x': sensorData.gyroscopeX,
      'gyro_y': sensorData.gyroscopeY,
      'gyro_z': sensorData.gyroscopeZ,
      'gyro_magnitude': math.sqrt(
        sensorData.gyroscopeX * sensorData.gyroscopeX +
        sensorData.gyroscopeY * sensorData.gyroscopeY +
        sensorData.gyroscopeZ * sensorData.gyroscopeZ
      ),
      
      // Magnetômetro
      'mag_x': sensorData.magnetometerX ?? 0.0,
      'mag_y': sensorData.magnetometerY ?? 0.0,
      'mag_z': sensorData.magnetometerZ ?? 0.0,
      'mag_magnitude': math.sqrt(
        (sensorData.magnetometerX ?? 0.0) * (sensorData.magnetometerX ?? 0.0) +
        (sensorData.magnetometerY ?? 0.0) * (sensorData.magnetometerY ?? 0.0) +
        (sensorData.magnetometerZ ?? 0.0) * (sensorData.magnetometerZ ?? 0.0)
      ),
      
      // Características derivadas
      'total_magnitude': math.sqrt(
        sensorData.accelerationX * sensorData.accelerationX +
        sensorData.accelerationY * sensorData.accelerationY +
        sensorData.accelerationZ * sensorData.accelerationZ +
        sensorData.gyroscopeX * sensorData.gyroscopeX +
        sensorData.gyroscopeY * sensorData.gyroscopeY +
        sensorData.gyroscopeZ * sensorData.gyroscopeZ
      ),
    };
  }
  
  /// Extrai características do contexto (GPS, velocidade, etc.)
  Future<Map<String, double>> _extractContextFeatures(LocationData? locationData) async {
    if (locationData == null) {
      return {
        'speed': 0.0,
        'heading': 0.0,
        'accuracy': 100.0,
        'has_gps': 0.0,
      };
    }
    
    return {
      'speed': (locationData.speed ?? 0.0) * 3.6, // m/s para km/h
      'heading': locationData.heading ?? 0.0,
      'accuracy': locationData.accuracy ?? 100.0,
      'has_gps': 1.0,
      'altitude': locationData.altitude ?? 0.0,
    };
  }
  
  /// Extrai características dos algoritmos de pré-processamento
  Future<Map<String, double>> _extractPreprocessingFeatures(
    TelematicsEventType eventType,
    double magnitude,
    SensorData sensorData,
    LocationData? locationData,
  ) async {
    // Phone Stability Score
    final stabilityScore = await _phoneStabilityDetector.calculateStabilityScore(sensorData);
    
    // GPS Validation
    final gpsValidation = await _gpsValidator.validateEvent(eventType, magnitude, DateTime.now());
    
    // Smart Driving Context
    final drivingContext = await _smartDrivingMode.getCurrentContext();
    final thresholdAdjustments = _smartDrivingMode.getThresholdAdjustments(drivingContext);
    
    return {
      // Phone Stability
      'phone_stability_score': stabilityScore,
      'phone_is_mounted': _phoneStabilityDetector.isPhoneMounted(stabilityScore) ? 1.0 : 0.0,
      
      // GPS Validation
      'gps_validation_confidence': gpsValidation.confidence,
      'gps_is_valid': gpsValidation.isValid ? 1.0 : 0.0,
      'gps_has_data': gpsValidation.hasGpsData ? 1.0 : 0.0,
      
      // Smart Driving Mode
      'driving_context_score': _drivingContextToScore(drivingContext),
      'threshold_multiplier_braking': thresholdAdjustments.hardBrakingMultiplier,
      'threshold_multiplier_acceleration': thresholdAdjustments.rapidAccelerationMultiplier,
      'threshold_multiplier_turn': thresholdAdjustments.sharpTurnMultiplier,
      'threshold_multiplier_gforce': thresholdAdjustments.highGForceMultiplier,
    };
  }
  
  double _drivingContextToScore(DrivingContext context) {
    switch (context) {
      case DrivingContext.ideal: return 1.0;
      case DrivingContext.good: return 0.8;
      case DrivingContext.moderate: return 0.6;
      case DrivingContext.challenging: return 0.4;
      case DrivingContext.difficult: return 0.2;
      case DrivingContext.poor: return 0.0;
    }
  }
  
  void _addSample(MLDataSample sample) {
    _collectedSamples.add(sample);
    
    // Limitar número de amostras em memória
    if (_collectedSamples.length > _maxSamples) {
      _collectedSamples.removeAt(0);
    }
  }
  
  String _generateSampleId() {
    return 'ml_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1000)}';
  }
  
  /// Adiciona feedback do usuário a uma amostra
  void addUserFeedback(String sampleId, bool isValidEvent) {
    final sampleIndex = _collectedSamples.indexWhere((s) => s.id == sampleId);
    if (sampleIndex != -1) {
      final sample = _collectedSamples[sampleIndex];
      final updatedSample = MLDataSample(
        id: sample.id,
        timestamp: sample.timestamp,
        eventType: sample.eventType,
        magnitude: sample.magnitude,
        sensorFeatures: sample.sensorFeatures,
        contextFeatures: sample.contextFeatures,
        preprocessingFeatures: sample.preprocessingFeatures,
        isValidEvent: isValidEvent,
        userFeedback: isValidEvent ? 1.0 : 0.0,
      );
      
      _collectedSamples[sampleIndex] = updatedSample;
      debugPrint('Feedback adicionado para amostra $sampleId: ${isValidEvent ? "válido" : "falso positivo"}');
    }
  }
  
  /// Obtém estatísticas da coleta
  Map<String, dynamic> getCollectionStatistics() {
    final eventCounts = <String, int>{};
    final validEventCounts = <String, int>{};
    final feedbackCounts = <String, int>{};
    
    for (final sample in _collectedSamples) {
      final eventType = sample.eventType.toString().split('.').last;
      eventCounts[eventType] = (eventCounts[eventType] ?? 0) + 1;
      
      if (sample.isValidEvent) {
        validEventCounts[eventType] = (validEventCounts[eventType] ?? 0) + 1;
      }
      
      if (sample.userFeedback != null) {
        feedbackCounts[eventType] = (feedbackCounts[eventType] ?? 0) + 1;
      }
    }
    
    return {
      'isCollecting': _isCollecting,
      'totalSamples': _collectedSamples.length,
      'maxSamples': _maxSamples,
      'eventCounts': eventCounts,
      'validEventCounts': validEventCounts,
      'feedbackCounts': feedbackCounts,
      'samplesWithFeedback': _collectedSamples.where((s) => s.userFeedback != null).length,
    };
  }
  
  /// Exporta dados para treinamento
  List<Map<String, dynamic>> exportTrainingData() {
    return _collectedSamples.map((sample) => sample.toMap()).toList();
  }
  
  /// Limpa dados coletados
  void clearCollectedData() {
    _collectedSamples.clear();
    debugPrint('MLDataCollector: Dados limpos');
  }
  
  void dispose() {
    stopCollection();
    _sampleController.close();
  }
}

