import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:activity_recognition_flutter/activity_recognition_flutter.dart' as ar;
import 'sensor_service.dart';
import 'location_service.dart';

enum ActivityType {
  still,
  walking,
  running,
  automotive,
  driving,
  cycling,
  unknown
}

enum ActivityConfidence {
  low,
  medium,
  high
}

class ActivityDetectionService extends ChangeNotifier {
  static final ActivityDetectionService _instance = ActivityDetectionService._internal();
  factory ActivityDetectionService() => _instance;
  ActivityDetectionService._internal();

  bool _isDetecting = false;
  ActivityType _currentActivity = ActivityType.still;
  ActivityConfidence _currentConfidence = ActivityConfidence.medium;
  
  final StreamController<ActivityType> _activityController = StreamController<ActivityType>.broadcast();
  StreamSubscription<ar.ActivityEvent>? _activitySubscription;
  
  // Serviços auxiliares
  final SensorService _sensorService = SensorService();
  final LocationService _locationService = LocationService();
  
  // Histórico de atividades
  final List<ar.ActivityEvent> _activityHistory = [];
  
  // Callback para mudanças de atividade
  Function(ActivityType, ActivityConfidence)? onActivityChanged;

  bool get isDetecting => _isDetecting;
  ActivityType get currentActivity => _currentActivity;
  ActivityConfidence get currentConfidence => _currentConfidence;
  Stream<ActivityType> get activityStream => _activityController.stream;
  List<ar.ActivityEvent> get activityHistory => List.unmodifiable(_activityHistory);

  Future<void> startDetection() async {
    if (_isDetecting) return;
    
    try {
      _isDetecting = true;
      
      // Iniciar detecção usando Google Activity Recognition API
      await _startGoogleActivityRecognition();
      
      // Iniciar detecção auxiliar baseada em sensores e GPS
      await _startAuxiliaryDetection();
      
      debugPrint('ActivityDetectionService: Detecção iniciada com sucesso');
      
    } catch (e) {
      debugPrint('Erro ao iniciar detecção de atividade: $e');
      // Fallback para detecção baseada em sensores
      await _startSensorBasedDetection();
    }
  }

  Future<void> _startGoogleActivityRecognition() async {
    try {
      // Verificar se o Google Play Services está disponível
      debugPrint('Iniciando Google Activity Recognition...');
      
      // Iniciar stream de atividades com tratamento de erro robusto
      _activitySubscription = ar.ActivityRecognition().activityStream(
        runForegroundService: true
      ).listen(
        (ar.ActivityEvent activity) {
          debugPrint('Atividade recebida: ${activity.type} - ${activity.confidence}%');
          _processGoogleActivity(activity);
        },
        onError: (error) {
          debugPrint('Erro no Google Activity Recognition: $error');
          
          // Verificar se é o erro específico de IncompatibleClassChangeError
          if (error.toString().contains('IncompatibleClassChangeError') ||
              error.toString().contains('ActivityRecognitionClient')) {
            debugPrint('Erro de compatibilidade detectado. Usando fallback para sensores.');
            // Fallback imediato para detecção baseada em sensores
            _startSensorBasedDetection();
          } else {
            // Para outros erros, tentar novamente após um delay
            Timer(const Duration(seconds: 5), () {
              if (_isDetecting) {
                _startSensorBasedDetection();
              }
            });
          }
        },
        onDone: () {
          debugPrint('Stream do Google Activity Recognition finalizado');
          if (_isDetecting) {
            _startSensorBasedDetection();
          }
        },
      );
      
      debugPrint('Google Activity Recognition iniciado com sucesso');
      
    } catch (e) {
      debugPrint('Erro ao inicializar Google Activity Recognition: $e');
      
      // Se houver erro na inicialização, usar fallback imediatamente
      if (e.toString().contains('IncompatibleClassChangeError') ||
          e.toString().contains('ActivityRecognitionClient')) {
        debugPrint('Erro de compatibilidade na inicialização. Usando apenas sensores.');
      }
      
      // Sempre usar fallback em caso de erro
      await _startSensorBasedDetection();
    }
  }

  void _processGoogleActivity(ar.ActivityEvent activity) {
    // Adicionar ao histórico
    _activityHistory.add(activity);
    if (_activityHistory.length > 100) {
      _activityHistory.removeAt(0);
    }

    // Converter tipo de atividade
    final activityType = _convertGoogleActivityType(activity.type);
    final confidence = _convertGoogleConfidence(activity.confidence);
    
    // Atualizar estado atual
    if (activityType != _currentActivity || confidence != _currentConfidence) {
      _currentActivity = activityType;
      _currentConfidence = confidence;
      
      _activityController.add(activityType);
      onActivityChanged?.call(activityType, confidence);
      notifyListeners();
      
      debugPrint('Atividade detectada: $activityType (${confidence.name})');
    }
  }

  ActivityType _convertGoogleActivityType(ar.ActivityType googleType) {
    // Mapear tipos da biblioteca para nossos tipos
    switch (googleType) {
      case ar.ActivityType.IN_VEHICLE:
        return ActivityType.automotive;
      case ar.ActivityType.ON_BICYCLE:
        return ActivityType.cycling;
      case ar.ActivityType.ON_FOOT:
      case ar.ActivityType.WALKING:
        return ActivityType.walking;
      case ar.ActivityType.RUNNING:
        return ActivityType.running;
      case ar.ActivityType.STILL:
        return ActivityType.still;
      default:
        return ActivityType.unknown;
    }
  }

  ActivityConfidence _convertGoogleConfidence(int confidence) {
    if (confidence >= 75) {
      return ActivityConfidence.high;
    } else if (confidence >= 50) {
      return ActivityConfidence.medium;
    } else {
      return ActivityConfidence.low;
    }
  }

  Future<void> _startAuxiliaryDetection() async {
    // Timer para análise auxiliar baseada em sensores e GPS
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isDetecting) {
        timer.cancel();
        return;
      }
      
      _performAuxiliaryAnalysis();
    });
  }

  void _performAuxiliaryAnalysis() {
    // Análise baseada em dados de localização
    final locationData = _locationService.lastKnownPosition;
    if (locationData != null) {
      final speed = locationData.speed * 3.6; // Converter m/s para km/h
      
      // Detectar direção baseada na velocidade
      if (speed > 15.0 && _currentActivity != ActivityType.automotive) {
        _updateActivity(ActivityType.automotive, ActivityConfidence.medium);
      } else if (speed > 5.0 && speed <= 15.0 && _currentActivity == ActivityType.still) {
        _updateActivity(ActivityType.cycling, ActivityConfidence.low);
      } else if (speed <= 2.0 && _currentActivity != ActivityType.still) {
        _updateActivity(ActivityType.still, ActivityConfidence.medium);
      }
    }
    
    // Análise baseada em dados de sensores
    final sensorData = _sensorService.getLatestSensorData();
    if (sensorData != null) {
      final accelerationMagnitude = _sensorService.calculateAccelerationMagnitude();
      final gyroscopeMagnitude = _sensorService.calculateGyroscopeMagnitude();
      
      // Detectar movimento baseado em aceleração
      if (accelerationMagnitude > 12.0 && gyroscopeMagnitude > 1.0) {
        // Movimento intenso - possivelmente dirigindo
        if (_currentActivity == ActivityType.still) {
          _updateActivity(ActivityType.automotive, ActivityConfidence.low);
        }
      } else if (accelerationMagnitude > 10.5 && accelerationMagnitude <= 12.0) {
        // Movimento moderado - possivelmente caminhando
        if (_currentActivity == ActivityType.still) {
          _updateActivity(ActivityType.walking, ActivityConfidence.low);
        }
      }
    }
  }

  Future<void> _startSensorBasedDetection() async {
    debugPrint('Iniciando detecção baseada em sensores (fallback)');
    
    // Iniciar sensores se não estiverem ativos
    if (!_sensorService.isListening) {
      await _sensorService.startListening();
    }
    
    // Iniciar GPS se não estiver ativo
    if (!_locationService.isTracking) {
      await _locationService.startTracking();
    }
    
    // Timer para análise baseada apenas em sensores e GPS
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isDetecting) {
        timer.cancel();
        return;
      }
      
      _performSensorBasedAnalysis();
    });
  }

  void _performSensorBasedAnalysis() {
    final locationData = _locationService.lastKnownPosition;
    final sensorData = _sensorService.getLatestSensorData();
    
    if (locationData == null && sensorData == null) return;
    
    ActivityType detectedActivity = ActivityType.unknown;
    ActivityConfidence confidence = ActivityConfidence.low;
    
    // Análise baseada na velocidade GPS
    if (locationData != null) {
      final speed = locationData.speed * 3.6; // km/h
      
      if (speed < 1.0) {
        detectedActivity = ActivityType.still;
        confidence = ActivityConfidence.high;
      } else if (speed >= 1.0 && speed < 8.0) {
        detectedActivity = ActivityType.walking;
        confidence = ActivityConfidence.medium;
      } else if (speed >= 8.0 && speed < 25.0) {
        detectedActivity = ActivityType.cycling;
        confidence = ActivityConfidence.medium;
      } else if (speed >= 25.0) {
        detectedActivity = ActivityType.automotive;
        confidence = ActivityConfidence.high;
      }
    }
    
    // Refinar análise com dados de sensores
    if (sensorData != null) {
      final accelerationMagnitude = _sensorService.calculateAccelerationMagnitude();
      final gyroscopeMagnitude = _sensorService.calculateGyroscopeMagnitude();
      
      // Padrões típicos de direção: aceleração moderada com rotações
      if (accelerationMagnitude > 9.5 && accelerationMagnitude < 11.0 && 
          gyroscopeMagnitude > 0.1 && gyroscopeMagnitude < 2.0) {
        if (detectedActivity == ActivityType.automotive) {
          confidence = ActivityConfidence.high;
        }
      }
      
      // Padrões de caminhada: aceleração rítmica
      if (accelerationMagnitude > 10.0 && accelerationMagnitude < 12.0 &&
          gyroscopeMagnitude < 0.5) {
        if (detectedActivity == ActivityType.walking) {
          confidence = ActivityConfidence.high;
        }
      }
    }
    
    // Atualizar apenas se houver mudança significativa
    if (detectedActivity != _currentActivity && confidence != ActivityConfidence.low) {
      _updateActivity(detectedActivity, confidence);
    }
  }

  void _updateActivity(ActivityType activity, ActivityConfidence confidence) {
    _currentActivity = activity;
    _currentConfidence = confidence;
    
    _activityController.add(activity);
    onActivityChanged?.call(activity, confidence);
    notifyListeners();
    
    debugPrint('Atividade atualizada: $activity (${confidence.name})');
  }

  Future<void> stopDetection() async {
    _isDetecting = false;
    
    await _activitySubscription?.cancel();
    _activitySubscription = null;
    
    notifyListeners();
    debugPrint('ActivityDetectionService: Detecção parada');
  }

  bool isDriving() {
    return _currentActivity == ActivityType.automotive || 
           _currentActivity == ActivityType.driving;
  }

  bool isMoving() {
    return _currentActivity != ActivityType.still && 
           _currentActivity != ActivityType.unknown;
  }

  Map<String, dynamic> getDetectionStatistics() {
    if (_activityHistory.isEmpty) {
      return {
        'total_detections': 0,
        'most_common_activity': 'unknown',
        'avg_confidence': 0.0,
      };
    }

    // Contar atividades
    Map<ActivityType, int> activityCounts = {};
    double totalConfidence = 0;
    
    for (var activity in _activityHistory) {
      final type = _convertGoogleActivityType(activity.type);
      activityCounts[type] = (activityCounts[type] ?? 0) + 1;
      totalConfidence += activity.confidence;
    }

    // Encontrar atividade mais comum
    ActivityType mostCommon = activityCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    return {
      'total_detections': _activityHistory.length,
      'most_common_activity': mostCommon.toString().split('.').last,
      'avg_confidence': totalConfidence / _activityHistory.length,
      'activity_breakdown': activityCounts.map(
        (key, value) => MapEntry(key.toString().split('.').last, value)
      ),
    };
  }

  void setActivityCallback(Function(ActivityType, ActivityConfidence) callback) {
    onActivityChanged = callback;
  }

  @override
  void dispose() {
    stopDetection();
    _activityController.close();
    super.dispose();
  }
}

