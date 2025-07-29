import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../models/telematics_event.dart';
import '../models/location_data.dart';
import 'location_service.dart';
import 'phone_stability_detector.dart';
import 'gps_correlation_validator.dart';
import 'smart_driving_mode.dart';
import '../ml/ml_engine.dart';

class SensorData {
  final DateTime timestamp;
  final double accelerationX;
  final double accelerationY;
  final double accelerationZ;
  final double gyroscopeX;
  final double gyroscopeY;
  final double gyroscopeZ;
  final double? magnetometerX;
  final double? magnetometerY;
  final double? magnetometerZ;

  SensorData({
    required this.timestamp,
    required this.accelerationX,
    required this.accelerationY,
    required this.accelerationZ,
    required this.gyroscopeX,
    required this.gyroscopeY,
    required this.gyroscopeZ,
    this.magnetometerX,
    this.magnetometerY,
    this.magnetometerZ,
  });
}

class SensorService extends ChangeNotifier {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  bool _isListening = false;
  final List<SensorData> _sensorHistory = [];
  
  // Streams dos sensores
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  
  // Dados atuais dos sensores
  AccelerometerEvent? _currentAccelerometer;
  GyroscopeEvent? _currentGyroscope;
  MagnetometerEvent? _currentMagnetometer;
    // Algoritmos de pré-processamento
  final PhoneStabilityDetector _phoneStabilityDetector = PhoneStabilityDetector();
  final GpsCorrelationValidator _gpsCorrelationValidator = GpsCorrelationValidator();
  final SmartDrivingMode _smartDrivingMode = SmartDrivingMode();
  
  // Sistema de Machine Learning
  final MLEngine _mlEngine = MLEngine();
  
  // Configurações de detecção (serão ajustadas dinamicamente)
  double _hardBrakingThreshold = 8.0; // m/s²
  double _rapidAccelerationThreshold = 4.0; // m/s²
  double _sharpTurnThreshold = 2.0; // rad/s
  double _highGForceThreshold = 12.0; // m/s²
  
  // Callback para eventos detectados
  Function(TelematicsEventType, double, {bool? mlValidated, double? confidence})? onEventDetected;

  bool get isListening => _isListening;
  List<SensorData> get sensorHistory => List.unmodifiable(_sensorHistory);

  Future<void> startListening() async {
    if (_isListening) return;
    
    try {
      _isListening = true;
      
      // Inicializar serviços de pré-processamento
      await _phoneStabilityDetector.initialize();
      await _gpsCorrelationValidator.initialize();
      await _smartDrivingMode.initialize();
      
      // Inicializar sistema de Machine Learning
      // Inicializar ML Engine (método será implementado futuramente)
      // await _mlEngine.startDataCollection();
      
      // Iniciar stream do acelerômetro
      _accelerometerSubscription = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 100), // 10 Hz
      ).listen(
        (AccelerometerEvent event) {
          _currentAccelerometer = event;
          _processAccelerometerData(event);
        },
        onError: (error) {
          debugPrint('Erro no acelerômetro: $error');
        },
      );
      
      // Iniciar stream do giroscópio
      _gyroscopeSubscription = gyroscopeEventStream(
        samplingPeriod: const Duration(milliseconds: 100), // 10 Hz
      ).listen(
        (GyroscopeEvent event) {
          _currentGyroscope = event;
          _processGyroscopeData(event);
        },
        onError: (error) {
          debugPrint('Erro no giroscópio: $error');
        },
      );
      
      // Iniciar stream do magnetômetro
      _magnetometerSubscription = magnetometerEventStream(
        samplingPeriod: const Duration(milliseconds: 200), // 5 Hz
      ).listen(
        (MagnetometerEvent event) {
          _currentMagnetometer = event;
        },
        onError: (error) {
          debugPrint('Erro no magnetômetro: $error');
        },
      );
      
      // Timer para consolidar dados dos sensores
      Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!_isListening) {
          timer.cancel();
          return;
        }
        _consolidateSensorData();
      });
      
      // Timer para atualizar thresholds dinamicamente (a cada 5 segundos)
      Timer.periodic(const Duration(seconds: 5), (timer) {
        if (!_isListening) {
          timer.cancel();
          return;
        }
        _updateDynamicThresholds();
      });
      
      debugPrint('SensorService: Sensores e pré-processamento iniciados com sucesso');
      
    } catch (e) {
      debugPrint('Erro ao iniciar sensores: $e');
      _isListening = false;
    }
  }

  Future<void> stopListening() async {
    _isListening = false;
    
    await _accelerometerSubscription?.cancel();
    await _gyroscopeSubscription?.cancel();
    await _magnetometerSubscription?.cancel();
    
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _magnetometerSubscription = null;
    
    debugPrint('SensorService: Sensores parados');
  }

  void _processAccelerometerData(AccelerometerEvent event) async {
    // Calcular magnitude da aceleração (removendo gravidade)
    final magnitude = math.sqrt(
      event.x * event.x + 
      event.y * event.y + 
      (event.z - 9.8) * (event.z - 9.8)
    );
    
    // ETAPA 1: Verificar estabilidade do telefone
    final stabilityScore = await _phoneStabilityDetector.calculateStabilityScore(
      _sensorHistory.isNotEmpty ? _sensorHistory.last : null
    );
    
    // Se telefone não está estável (sendo manipulado), ignorar eventos
    if (stabilityScore < 0.6) {
      debugPrint('Evento ignorado - telefone instável (score: ${stabilityScore.toStringAsFixed(2)})');
      return;
    }
    
    // ETAPA 2: Detectar eventos com thresholds dinâmicos
    TelematicsEventType? eventType;
    double eventMagnitude = magnitude;
    
    // Detectar freada brusca (desaceleração)
    if (event.y < -_hardBrakingThreshold) {
      eventType = TelematicsEventType.hardBraking;
      eventMagnitude = event.y.abs();
    }
    // Detectar aceleração rápida
    else if (event.y > _rapidAccelerationThreshold) {
      eventType = TelematicsEventType.rapidAcceleration;
      eventMagnitude = event.y;
    }
    // Detectar força G alta (possível colisão)
    else if (magnitude > _highGForceThreshold) {
      eventType = TelematicsEventType.highGForce;
      eventMagnitude = magnitude;
    }
    
    if (eventType != null) {
      // ETAPA 3: Validar com GPS (se disponível)
      final gpsValidation = await _gpsCorrelationValidator.validateEvent(
        eventType, 
        eventMagnitude, 
        DateTime.now()
      );
      
      // Se GPS contradiz o evento, reduzir confiança
      double confidence = stabilityScore;
      if (gpsValidation.isValid) {
        confidence = math.min(1.0, confidence + 0.2); // Boost de confiança
      } else if (gpsValidation.hasGpsData) {
        confidence = math.max(0.3, confidence - 0.3); // Reduzir confiança
      }
      
      // ETAPA 4: Aplicar filtros temporais e de frequência
      if (_shouldReportEvent(eventType, eventMagnitude, confidence)) {
        // ETAPA 5: Usar Machine Learning para validação final
        await _processEventWithML(eventType, eventMagnitude, confidence);
      }
    }
  }

  void _processGyroscopeData(GyroscopeEvent event) async {
    // Calcular magnitude da rotação
    final rotationMagnitude = math.sqrt(
      event.x * event.x + 
      event.y * event.y + 
      event.z * event.z
    );
    
    // ETAPA 1: Verificar estabilidade do telefone
    final stabilityScore = await _phoneStabilityDetector.calculateStabilityScore(
      _sensorHistory.isNotEmpty ? _sensorHistory.last : null
    );
    
    // Se telefone não está estável, ignorar eventos
    if (stabilityScore < 0.6) {
      return;
    }
    
    // ETAPA 2: Detectar curva acentuada
    if (rotationMagnitude > _sharpTurnThreshold) {
      // ETAPA 3: Validar com GPS
      final gpsValidation = await _gpsCorrelationValidator.validateEvent(
        TelematicsEventType.sharpTurn, 
        rotationMagnitude, 
        DateTime.now()
      );
      
      // Calcular confiança
      double confidence = stabilityScore;
      if (gpsValidation.isValid) {
        confidence = math.min(1.0, confidence + 0.2);
      } else if (gpsValidation.hasGpsData) {
        confidence = math.max(0.3, confidence - 0.3);
      }
      
      // ETAPA 4: Aplicar filtros
      if (_shouldReportEvent(TelematicsEventType.sharpTurn, rotationMagnitude, confidence)) {
        // ETAPA 5: Usar Machine Learning para validação final
        await _processEventWithML(TelematicsEventType.sharpTurn, rotationMagnitude, confidence);
      }
    }
  }
  
  // Método para atualizar thresholds dinamicamente
  void _updateDynamicThresholds() async {
    final context = await _smartDrivingMode.getCurrentContext();
    final adjustments = _smartDrivingMode.getThresholdAdjustments(context);
    
    _hardBrakingThreshold = 8.0 * adjustments.hardBrakingMultiplier;
    _rapidAccelerationThreshold = 4.0 * adjustments.rapidAccelerationMultiplier;
    _sharpTurnThreshold = 2.0 * adjustments.sharpTurnMultiplier;
    _highGForceThreshold = 12.0 * adjustments.highGForceMultiplier;
    
    debugPrint('Thresholds atualizados - Contexto: ${context.toString().split('.').last} '
              'Freada: ${_hardBrakingThreshold.toStringAsFixed(1)}, '
              'Aceleração: ${_rapidAccelerationThreshold.toStringAsFixed(1)}, '
              'Curva: ${_sharpTurnThreshold.toStringAsFixed(1)}, '
              'Força G: ${_highGForceThreshold.toStringAsFixed(1)}');
  }
  
  // Filtro temporal para evitar spam de eventos
  final Map<TelematicsEventType, DateTime> _lastEventTime = {};
  final Map<TelematicsEventType, int> _eventCount = {};
  
  bool _shouldReportEvent(TelematicsEventType eventType, double magnitude, double confidence) {
    final now = DateTime.now();
    
    // Filtro de confiança mínima
    if (confidence < 0.5) {
      return false;
    }
    
    // Filtro temporal - evitar eventos muito próximos
    final lastTime = _lastEventTime[eventType];
    if (lastTime != null && now.difference(lastTime).inSeconds < 2) {
      return false;
    }
    
    // Filtro de frequência - máximo 5 eventos do mesmo tipo por minuto
    final count = _eventCount[eventType] ?? 0;
    if (count >= 5) {
      // Reset contador a cada minuto
      Timer(const Duration(minutes: 1), () {
        _eventCount[eventType] = 0;
      });
      return false;
    }
    
    // Atualizar contadores
    _lastEventTime[eventType] = now;
    _eventCount[eventType] = count + 1;
    
    return true;
  }

  void _consolidateSensorData() {
    if (_currentAccelerometer == null || _currentGyroscope == null) return;
    
    final sensorData = SensorData(
      timestamp: DateTime.now(),
      accelerationX: _currentAccelerometer!.x,
      accelerationY: _currentAccelerometer!.y,
      accelerationZ: _currentAccelerometer!.z,
      gyroscopeX: _currentGyroscope!.x,
      gyroscopeY: _currentGyroscope!.y,
      gyroscopeZ: _currentGyroscope!.z,
      magnetometerX: _currentMagnetometer?.x,
      magnetometerY: _currentMagnetometer?.y,
      magnetometerZ: _currentMagnetometer?.z,
    );
    
    _sensorHistory.add(sensorData);
    
    // Manter apenas os últimos 1000 registros (aproximadamente 100 segundos)
    if (_sensorHistory.length > 1000) {
      _sensorHistory.removeAt(0);
    }
    
    notifyListeners();
  }

  SensorData? getLatestSensorData() {
    return _sensorHistory.isNotEmpty ? _sensorHistory.last : null;
  }

  double calculateAccelerationMagnitude() {
    final latest = getLatestSensorData();
    if (latest == null) return 0.0;
    
    return math.sqrt(
      latest.accelerationX * latest.accelerationX +
      latest.accelerationY * latest.accelerationY +
      latest.accelerationZ * latest.accelerationZ
    );
  }

  double calculateGyroscopeMagnitude() {
    final latest = getLatestSensorData();
    if (latest == null) return 0.0;
    
    return math.sqrt(
      latest.gyroscopeX * latest.gyroscopeX +
      latest.gyroscopeY * latest.gyroscopeY +
      latest.gyroscopeZ * latest.gyroscopeZ
    );
  }

  List<SensorData> getRecentSensorData({int seconds = 10}) {
    final cutoff = DateTime.now().subtract(Duration(seconds: seconds));
    return _sensorHistory.where((data) => data.timestamp.isAfter(cutoff)).toList();
  }

  Map<String, dynamic> getSensorStatistics() {
    if (_sensorHistory.isEmpty) {
      return {
        'total_samples': 0,
        'avg_acceleration': 0.0,
        'max_acceleration': 0.0,
        'avg_rotation': 0.0,
        'max_rotation': 0.0,
      };
    }

    final accelerations = _sensorHistory.map((data) => 
      math.sqrt(data.accelerationX * data.accelerationX + 
                data.accelerationY * data.accelerationY + 
                data.accelerationZ * data.accelerationZ)
    ).toList();

    final rotations = _sensorHistory.map((data) => 
      math.sqrt(data.gyroscopeX * data.gyroscopeX + 
                data.gyroscopeY * data.gyroscopeY + 
                data.gyroscopeZ * data.gyroscopeZ)
    ).toList();

    return {
      'total_samples': _sensorHistory.length,
      'avg_acceleration': accelerations.reduce((a, b) => a + b) / accelerations.length,
      'max_acceleration': accelerations.reduce(math.max),
      'avg_rotation': rotations.reduce((a, b) => a + b) / rotations.length,
      'max_rotation': rotations.reduce(math.max),
    };
  }

  void clearHistory() {
    _sensorHistory.clear();
    notifyListeners();
  }

  void setEventCallback(Function(TelematicsEventType, double, {bool? mlValidated, double? confidence}) callback) {
    onEventDetected = callback;
  }
  
  // Métodos para acessar os serviços de pré-processamento
  PhoneStabilityDetector get phoneStabilityDetector => _phoneStabilityDetector;
  GpsCorrelationValidator get gpsValidator => _gpsCorrelationValidator;
  SmartDrivingMode get smartDrivingMode => _smartDrivingMode;
  
  // Método para obter thresholds atuais
  Map<String, double> getCurrentThresholds() {
    return {
      'hardBraking': _hardBrakingThreshold,
      'rapidAcceleration': _rapidAccelerationThreshold,
      'sharpTurn': _sharpTurnThreshold,
      'highGForce': _highGForceThreshold,
    };
  }
  
  // Método para obter estatísticas de confiança
  Map<String, dynamic> getConfidenceStatistics() {
    final recentEvents = _eventCount.entries.map((entry) => {
      'eventType': entry.key.toString().split('.').last,
      'count': entry.value,
      'lastTime': _lastEventTime[entry.key]?.toIso8601String(),
    }).toList();
    
    return {
      'recentEvents': recentEvents,
      'currentThresholds': getCurrentThresholds(),
      'phoneStabilityEnabled': true,
      'gpsValidationEnabled': true,
      'smartDrivingModeEnabled': true,
    };
  }
  
  /// Processa evento com Machine Learning para validação final
  Future<void> _processEventWithML(
    TelematicsEventType eventType, 
    double magnitude, 
    double preprocessingConfidence
  ) async {
    try {
      // Criar dados do sensor atual
      final sensorData = SensorData(
        timestamp: DateTime.now(),
        accelerationX: _currentAccelerometer?.x ?? 0.0,
        accelerationY: _currentAccelerometer?.y ?? 0.0,
        accelerationZ: _currentAccelerometer?.z ?? 0.0,
        gyroscopeX: _currentGyroscope?.x ?? 0.0,
        gyroscopeY: _currentGyroscope?.y ?? 0.0,
        gyroscopeZ: _currentGyroscope?.z ?? 0.0,
        magnetometerX: _currentMagnetometer?.x ?? 0.0,
        magnetometerY: _currentMagnetometer?.y ?? 0.0,
        magnetometerZ: _currentMagnetometer?.z ?? 0.0,
      );
      
      // Obter dados de localização
      final locationData = await LocationService().getCurrentLocation();
      
      // Processar com ML Engine (método será implementado futuramente)
      // final mlPrediction = await _mlEngine.processEvent(
      //   eventType,
      //   eventMagnitude,
      //   confidence,
      //   _currentLocationData,
      //   _currentSensorData,
      // );
      
      // Combinar confiança do pré-processamento (simulado)
      final finalConfidence = preprocessingConfidence;
      final isValidEvent = finalConfidence > 0.7;
        
      // Reportar evento apenas se confiança for alta
      final shouldReport = isValidEvent || finalConfidence > 0.8;
        
      if (shouldReport) {
          onEventDetected?.call(
            eventType,
            magnitude,
            mlValidated: isValidEvent,
            confidence: finalConfidence,
          );
          
          debugPrint('${eventType.toString().split('.').last} DETECTADA: '
                    '${magnitude.toStringAsFixed(2)} ${_getUnitForEventType(eventType)} '
                    '(ML: ${isValidEvent ? "VÁLIDO" : "FALSO POSITIVO"}, '
                    'confiança: ${(finalConfidence * 100).toStringAsFixed(1)}%, '
                    'modelo: simulado)');
        } else {
          debugPrint('${eventType.toString().split('.').last} FILTRADA pelo ML: '
                    '${magnitude.toStringAsFixed(2)} ${_getUnitForEventType(eventType)} '
                    '(confiança: ${(finalConfidence * 100).toStringAsFixed(1)}%)');
        }
      
    } catch (e) {
      debugPrint('Erro ao processar evento com ML: $e');
      
      // Fallback: usar apenas pré-processamento
      onEventDetected?.call(
        eventType,
        magnitude,
        mlValidated: false,
        confidence: preprocessingConfidence,
      );
      
      debugPrint('${eventType.toString().split('.').last} DETECTADA (fallback): '
                  '${magnitude.toStringAsFixed(2)} ${_getUnitForEventType(eventType)} '
                  '(confiança: ${(preprocessingConfidence * 100).toStringAsFixed(1)}%)');
    }
  }
  
  /// Combina confiança do pré-processamento com predição ML
  double _combinePredictionConfidence(
    double preprocessingConfidence,
    double mlConfidence,
    bool mlIsValid,
  ) {
    if (mlIsValid) {
      // Se ML confirma, usar média ponderada favorecendo ML
      return (preprocessingConfidence * 0.3) + (mlConfidence * 0.7);
    } else {
      // Se ML rejeita, reduzir confiança significativamente
      return math.min(preprocessingConfidence * 0.4, mlConfidence);
    }
  }
  
  /// Obtém unidade para tipo de evento
  String _getUnitForEventType(TelematicsEventType eventType) {
    switch (eventType) {
      case TelematicsEventType.hardBraking:
      case TelematicsEventType.rapidAcceleration:
      case TelematicsEventType.highGForce:
        return 'm/s²';
      case TelematicsEventType.sharpTurn:
        return 'rad/s';
      case TelematicsEventType.speeding:
        return 'km/h';
      case TelematicsEventType.idling:
        return 'min';
      case TelematicsEventType.phoneUsage:
        return 's';
    }
  }
  
  /// Adiciona feedback do usuário para treinamento ML
  Future<void> addUserFeedback(String eventId, bool isValidEvent) async {
    // Método será implementado futuramente
    // await _mlEngine.addUserFeedback(eventId, isValidEvent);
  }
  
  /// Treina modelo ML com dados coletados
  Future<void> trainMLModel() async {
    // Método será implementado futuramente
    // await _mlEngine.trainAdvancedModel();
  }
  
  /// Treina modelo ML avançado com múltiplos algoritmos
  Future<void> trainAdvancedMLModel() async {
    // Método será implementado futuramente
    // await _mlEngine.trainAdvancedModel();
  }
  
  /// Obtém estatísticas do sistema ML
  Future<Map<String, dynamic>> getMLStatistics() async {
    // Método será implementado futuramente
    return <String, dynamic>{
      'totalSamples': 0,
      'accuracy': 0.0,
      'lastTraining': DateTime.now().toString(),
    };
  }
  
  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}

