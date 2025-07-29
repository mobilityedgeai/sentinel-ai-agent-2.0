import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/telematics_event.dart';
import 'sensor_service.dart';
import 'location_service.dart';

/// Serviço de detecção de veículo parado ligado (idling)
/// 
/// Algoritmo que detecta quando o veículo está parado mas com motor ligado
/// baseado em:
/// - Velocidade baixa/zero (GPS)
/// - Vibrações do motor (acelerômetro)
/// - Posição estática (GPS)
/// - Duração do evento
class IdlingDetectionService extends ChangeNotifier {
  static final IdlingDetectionService _instance = IdlingDetectionService._internal();
  factory IdlingDetectionService() => _instance;
  IdlingDetectionService._internal();

  // Serviços auxiliares
  final SensorService _sensorService = SensorService();
  final LocationService _locationService = LocationService();

  // Estado do serviço
  bool _isDetecting = false;
  bool _isCurrentlyIdling = false;
  DateTime? _idlingStartTime;
  Position? _idlingPosition;
  
  // Configurações do algoritmo
  static const double _maxIdlingSpeed = 2.0; // km/h - velocidade máxima para considerar parado
  static const double _minIdlingDuration = 30.0; // segundos - tempo mínimo para considerar idling
  static const double _maxPositionVariation = 10.0; // metros - variação máxima de posição
  static const double _minEngineVibration = 0.5; // m/s² - vibração mínima do motor
  static const double _maxEngineVibration = 3.0; // m/s² - vibração máxima do motor
  
  // Histórico de dados para análise
  final List<double> _recentSpeeds = [];
  final List<Position> _recentPositions = [];
  final List<double> _recentVibrations = [];
  final int _maxHistorySize = 20; // 20 amostras (aprox. 1 minuto com amostragem de 3s)
  
  // Callback para eventos detectados
  Function(TelematicsEvent)? onIdlingDetected;
  
  // Timers
  Timer? _analysisTimer;
  Timer? _idlingTimer;

  // Getters
  bool get isDetecting => _isDetecting;
  bool get isCurrentlyIdling => _isCurrentlyIdling;
  Duration? get currentIdlingDuration {
    if (_idlingStartTime == null) return null;
    return DateTime.now().difference(_idlingStartTime!);
  }

  /// Inicia a detecção de idling
  Future<void> startDetection() async {
    if (_isDetecting) return;
    
    try {
      _isDetecting = true;
      _clearHistory();
      
      // Iniciar análise periódica a cada 3 segundos
      _analysisTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _analyzeIdlingConditions();
      });
      
      debugPrint('🚗 Detecção de idling iniciada');
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao iniciar detecção de idling: $e');
      _isDetecting = false;
    }
  }

  /// Para a detecção de idling
  Future<void> stopDetection() async {
    _isDetecting = false;
    _analysisTimer?.cancel();
    _idlingTimer?.cancel();
    
    // Se estava em idling, finalizar o evento
    if (_isCurrentlyIdling) {
      await _endIdlingEvent();
    }
    
    _clearHistory();
    debugPrint('🚗 Detecção de idling parada');
    notifyListeners();
  }

  /// Algoritmo principal de análise de condições de idling
  void _analyzeIdlingConditions() async {
    if (!_isDetecting) return;

    try {
      // Coletar dados atuais
      final currentPosition = await _getCurrentPosition();
      final currentSpeed = _getCurrentSpeed();
      final currentVibration = _getCurrentVibration();
      
      if (currentPosition == null) return;
      
      // Adicionar ao histórico
      _addToHistory(currentPosition, currentSpeed, currentVibration);
      
      // Verificar se há dados suficientes para análise
      if (_recentSpeeds.length < 5) return;
      
      // Aplicar algoritmo de detecção
      final isIdlingCondition = _checkIdlingConditions();
      
      if (isIdlingCondition && !_isCurrentlyIdling) {
        // Iniciar evento de idling
        await _startIdlingEvent(currentPosition);
      } else if (!isIdlingCondition && _isCurrentlyIdling) {
        // Finalizar evento de idling
        await _endIdlingEvent();
      }
      
    } catch (e) {
      debugPrint('Erro na análise de idling: $e');
    }
  }

  /// Algoritmo de verificação das condições de idling
  bool _checkIdlingConditions() {
    // 1. Verificar velocidade baixa/zero
    final avgSpeed = _calculateAverageSpeed();
    if (avgSpeed > _maxIdlingSpeed) {
      return false;
    }
    
    // 2. Verificar posição estática
    if (!_isPositionStatic()) {
      return false;
    }
    
    // 3. Verificar vibrações do motor
    if (!_hasEngineVibrations()) {
      return false;
    }
    
    return true;
  }

  /// Calcula velocidade média das amostras recentes
  double _calculateAverageSpeed() {
    if (_recentSpeeds.isEmpty) return 0.0;
    
    final sum = _recentSpeeds.reduce((a, b) => a + b);
    return sum / _recentSpeeds.length;
  }

  /// Verifica se a posição está estática
  bool _isPositionStatic() {
    if (_recentPositions.length < 3) return false;
    
    final firstPosition = _recentPositions.first;
    
    for (final position in _recentPositions) {
      final distance = Geolocator.distanceBetween(
        firstPosition.latitude,
        firstPosition.longitude,
        position.latitude,
        position.longitude,
      );
      
      if (distance > _maxPositionVariation) {
        return false;
      }
    }
    
    return true;
  }

  /// Verifica se há vibrações características do motor
  bool _hasEngineVibrations() {
    if (_recentVibrations.isEmpty) return false;
    
    // Calcular média e desvio padrão das vibrações
    final avgVibration = _recentVibrations.reduce((a, b) => a + b) / _recentVibrations.length;
    
    // Verificar se está na faixa de vibrações do motor
    if (avgVibration < _minEngineVibration || avgVibration > _maxEngineVibration) {
      return false;
    }
    
    // Verificar consistência das vibrações (motor ligado tem padrão regular)
    final variance = _calculateVariance(_recentVibrations, avgVibration);
    final standardDeviation = math.sqrt(variance);
    
    // Motor ligado tem vibrações mais consistentes
    return standardDeviation < 1.0;
  }

  /// Calcula variância das vibrações
  double _calculateVariance(List<double> values, double mean) {
    if (values.isEmpty) return 0.0;
    
    double sum = 0.0;
    for (final value in values) {
      sum += math.pow(value - mean, 2);
    }
    
    return sum / values.length;
  }

  /// Inicia um evento de idling
  Future<void> _startIdlingEvent(Position position) async {
    _isCurrentlyIdling = true;
    _idlingStartTime = DateTime.now();
    _idlingPosition = position;
    
    // Configurar timer para verificar duração mínima
    _idlingTimer = Timer(Duration(seconds: _minIdlingDuration.toInt()), () {
      if (_isCurrentlyIdling) {
        _reportIdlingEvent();
      }
    });
    
    debugPrint('🚗 Idling iniciado em ${position.latitude}, ${position.longitude}');
    notifyListeners();
  }

  /// Finaliza um evento de idling
  Future<void> _endIdlingEvent() async {
    if (!_isCurrentlyIdling || _idlingStartTime == null) return;
    
    final duration = DateTime.now().difference(_idlingStartTime!);
    
    // Só reportar se durou tempo suficiente
    if (duration.inSeconds >= _minIdlingDuration) {
      _reportIdlingEvent();
    }
    
    _isCurrentlyIdling = false;
    _idlingStartTime = null;
    _idlingPosition = null;
    _idlingTimer?.cancel();
    
    debugPrint('🚗 Idling finalizado após ${duration.inSeconds} segundos');
    notifyListeners();
  }

  /// Reporta evento de idling detectado
  void _reportIdlingEvent() {
    if (_idlingStartTime == null || _idlingPosition == null) return;
    
    final duration = DateTime.now().difference(_idlingStartTime!);
    
    final event = TelematicsEvent(
      tripId: 1, // TODO: Obter trip ID atual
      userId: 1, // TODO: Obter user ID atual
      eventType: TelematicsEventType.idling,
      timestamp: _idlingStartTime!,
      latitude: _idlingPosition!.latitude,
      longitude: _idlingPosition!.longitude,
      severity: duration.inSeconds.toDouble(),
      metadata: {
        'duration_seconds': duration.inSeconds,
        'avg_speed': _calculateAverageSpeed(),
        'avg_vibration': _recentVibrations.isNotEmpty 
            ? _recentVibrations.reduce((a, b) => a + b) / _recentVibrations.length 
            : 0.0,
      },
    );
    
    onIdlingDetected?.call(event);
    debugPrint('🚗 Evento de idling reportado: ${duration.inSeconds}s');
  }

  /// Obtém posição atual
  Future<Position?> _getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition();
    } catch (e) {
      debugPrint('Erro ao obter posição para idling: $e');
      return null;
    }
  }

  /// Obtém velocidade atual
  double _getCurrentSpeed() {
    // Usar velocidade da última posição obtida se disponível
    if (_recentPositions.isNotEmpty) {
      final lastPosition = _recentPositions.last;
      return (lastPosition.speed * 3.6); // Converter m/s para km/h
    }
    return 0.0;
  }

  /// Obtém vibração atual do motor
  double _getCurrentVibration() {
    // Usar magnitude do acelerômetro como indicador de vibração
    return _sensorService.calculateAccelerationMagnitude();
  }

  /// Adiciona dados ao histórico
  void _addToHistory(Position position, double speed, double vibration) {
    _recentPositions.add(position);
    _recentSpeeds.add(speed);
    _recentVibrations.add(vibration);
    
    // Manter tamanho do histórico
    if (_recentPositions.length > _maxHistorySize) {
      _recentPositions.removeAt(0);
      _recentSpeeds.removeAt(0);
      _recentVibrations.removeAt(0);
    }
  }

  /// Limpa histórico de dados
  void _clearHistory() {
    _recentPositions.clear();
    _recentSpeeds.clear();
    _recentVibrations.clear();
  }

  /// Obtém estatísticas do algoritmo
  Map<String, dynamic> getStatistics() {
    return {
      'is_detecting': _isDetecting,
      'is_currently_idling': _isCurrentlyIdling,
      'current_idling_duration_seconds': currentIdlingDuration?.inSeconds ?? 0,
      'avg_speed_kmh': _recentSpeeds.isNotEmpty 
          ? _recentSpeeds.reduce((a, b) => a + b) / _recentSpeeds.length 
          : 0.0,
      'avg_vibration_ms2': _recentVibrations.isNotEmpty 
          ? _recentVibrations.reduce((a, b) => a + b) / _recentVibrations.length 
          : 0.0,
      'position_samples': _recentPositions.length,
      'algorithm_config': {
        'max_idling_speed_kmh': _maxIdlingSpeed,
        'min_idling_duration_seconds': _minIdlingDuration,
        'max_position_variation_meters': _maxPositionVariation,
        'min_engine_vibration_ms2': _minEngineVibration,
        'max_engine_vibration_ms2': _maxEngineVibration,
      },
    };
  }

  @override
  void dispose() {
    stopDetection();
    super.dispose();
  }
}

