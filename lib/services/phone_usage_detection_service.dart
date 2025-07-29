import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/telematics_event.dart';
import 'sensor_service.dart';
import 'activity_detection_service.dart';

/// Serviço de detecção de uso do telefone enquanto dirige
/// 
/// Algoritmo que detecta quando o telefone está sendo usado durante a condução
/// baseado em:
/// - Padrões de movimento do dispositivo (acelerômetro/giroscópio)
/// - Orientação do telefone
/// - Atividade de condução detectada
/// - Análise de gestos característicos
class PhoneUsageDetectionService extends ChangeNotifier {
  static final PhoneUsageDetectionService _instance = PhoneUsageDetectionService._internal();
  factory PhoneUsageDetectionService() => _instance;
  PhoneUsageDetectionService._internal();

  // Serviços auxiliares
  final SensorService _sensorService = SensorService();
  final ActivityDetectionService _activityService = ActivityDetectionService();

  // Estado do serviço
  bool _isDetecting = false;
  bool _isCurrentlyUsingPhone = false;
  bool _isDriving = false;
  DateTime? _phoneUsageStartTime;
  
  // Configurações do algoritmo
  static const double _minDrivingSpeed = 5.0; // km/h - velocidade mínima para considerar dirigindo
  static const double _phoneUsageThreshold = 3.0; // m/s² - threshold para detectar movimento do telefone
  static const double _orientationChangeThreshold = 30.0; // graus - mudança de orientação
  static const double _gestureFrequencyThreshold = 0.5; // Hz - frequência de gestos
  static const double _minUsageDuration = 3.0; // segundos - duração mínima para considerar uso
  static const int _analysisWindowSize = 30; // amostras para análise (aprox. 3 segundos)
  
  // Histórico de dados para análise
  final List<double> _recentAccelMagnitudes = [];
  final List<double> _recentGyroMagnitudes = [];
  final List<double> _recentOrientations = [];
  final List<DateTime> _recentGestures = [];
  
  // Padrões de movimento
  double _baselineAcceleration = 0.0;
  double _baselineRotation = 0.0;
  bool _hasBaseline = false;
  
  // Callback para eventos detectados
  Function(TelematicsEvent)? onPhoneUsageDetected;
  
  // Timers
  Timer? _analysisTimer;
  Timer? _usageTimer;

  // Getters
  bool get isDetecting => _isDetecting;
  bool get isCurrentlyUsingPhone => _isCurrentlyUsingPhone;
  bool get isDriving => _isDriving;
  Duration? get currentUsageDuration {
    if (_phoneUsageStartTime == null) return null;
    return DateTime.now().difference(_phoneUsageStartTime!);
  }

  /// Inicia a detecção de uso do telefone
  Future<void> startDetection() async {
    if (_isDetecting) return;
    
    try {
      _isDetecting = true;
      _clearHistory();
      _hasBaseline = false;
      
      // Iniciar análise periódica a cada 100ms (10 Hz)
      _analysisTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        _analyzePhoneUsage();
      });
      
      // Monitorar atividade de condução
      _activityService.activityStream.listen((activity) {
        final activityString = activity.toString().toLowerCase();
        _isDriving = (activityString.contains('driving') || 
                     activityString.contains('automotive'));
      });
      
      debugPrint('📱 Detecção de uso do telefone iniciada');
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao iniciar detecção de uso do telefone: $e');
      _isDetecting = false;
    }
  }

  /// Para a detecção de uso do telefone
  Future<void> stopDetection() async {
    _isDetecting = false;
    _analysisTimer?.cancel();
    _usageTimer?.cancel();
    
    // Se estava usando telefone, finalizar o evento
    if (_isCurrentlyUsingPhone) {
      await _endPhoneUsageEvent();
    }
    
    _clearHistory();
    debugPrint('📱 Detecção de uso do telefone parada');
    notifyListeners();
  }

  /// Algoritmo principal de análise de uso do telefone
  void _analyzePhoneUsage() async {
    if (!_isDetecting) return;

    try {
      // Coletar dados atuais dos sensores
      final accelMagnitude = _sensorService.calculateAccelerationMagnitude();
      final gyroMagnitude = _sensorService.calculateGyroscopeMagnitude();
      final orientation = _getCurrentOrientation();
      
      // Adicionar ao histórico
      _addToHistory(accelMagnitude, gyroMagnitude, orientation);
      
      // Estabelecer baseline se necessário
      if (!_hasBaseline && _recentAccelMagnitudes.length >= 10) {
        _establishBaseline();
      }
      
      // Verificar se há dados suficientes para análise
      if (_recentAccelMagnitudes.length < _analysisWindowSize) return;
      
      // Aplicar algoritmo de detecção
      final isUsingPhone = _detectPhoneUsage();
      
      if (isUsingPhone && !_isCurrentlyUsingPhone && _isDriving) {
        // Iniciar evento de uso do telefone
        await _startPhoneUsageEvent();
      } else if (!isUsingPhone && _isCurrentlyUsingPhone) {
        // Finalizar evento de uso do telefone
        await _endPhoneUsageEvent();
      }
      
    } catch (e) {
      debugPrint('Erro na análise de uso do telefone: $e');
    }
  }

  /// Algoritmo de detecção de uso do telefone
  bool _detectPhoneUsage() {
    if (!_hasBaseline || !_isDriving) return false;
    
    // 1. Detectar movimentos anômalos do dispositivo
    if (!_hasAnomalousMovement()) return false;
    
    // 2. Detectar mudanças de orientação características
    if (!_hasOrientationChanges()) return false;
    
    // 3. Detectar padrões de gestos
    if (!_hasGesturePatterns()) return false;
    
    // 4. Verificar frequência de interação
    if (!_hasInteractionFrequency()) return false;
    
    return true;
  }

  /// Detecta movimentos anômalos do dispositivo
  bool _hasAnomalousMovement() {
    // Calcular desvio da aceleração em relação ao baseline
    final recentAccel = _recentAccelMagnitudes.take(10).toList();
    final avgAccel = recentAccel.reduce((a, b) => a + b) / recentAccel.length;
    final accelDeviation = (avgAccel - _baselineAcceleration).abs();
    
    // Calcular desvio da rotação em relação ao baseline
    final recentGyro = _recentGyroMagnitudes.take(10).toList();
    final avgGyro = recentGyro.reduce((a, b) => a + b) / recentGyro.length;
    final gyroDeviation = (avgGyro - _baselineRotation).abs();
    
    // Movimento anômalo se há desvio significativo
    return accelDeviation > _phoneUsageThreshold || gyroDeviation > 1.0;
  }

  /// Detecta mudanças de orientação características
  bool _hasOrientationChanges() {
    if (_recentOrientations.length < 10) return false;
    
    final recent = _recentOrientations.take(10).toList();
    double maxChange = 0.0;
    
    for (int i = 1; i < recent.length; i++) {
      final change = (recent[i] - recent[i-1]).abs();
      if (change > maxChange) maxChange = change;
    }
    
    return maxChange > _orientationChangeThreshold;
  }

  /// Detecta padrões de gestos característicos
  bool _hasGesturePatterns() {
    // Detectar picos de aceleração (gestos de toque/swipe)
    final recent = _recentAccelMagnitudes.take(20).toList();
    int gestureCount = 0;
    
    for (int i = 1; i < recent.length - 1; i++) {
      // Detectar pico local
      if (recent[i] > recent[i-1] && recent[i] > recent[i+1] && 
          recent[i] > _baselineAcceleration + 2.0) {
        gestureCount++;
        _recentGestures.add(DateTime.now());
      }
    }
    
    // Limpar gestos antigos (últimos 5 segundos)
    final cutoff = DateTime.now().subtract(const Duration(seconds: 5));
    _recentGestures.removeWhere((time) => time.isBefore(cutoff));
    
    return gestureCount >= 2; // Pelo menos 2 gestos na janela
  }

  /// Verifica frequência de interação
  bool _hasInteractionFrequency() {
    if (_recentGestures.length < 2) return false;
    
    // Calcular frequência de gestos (gestos por segundo)
    final timeSpan = _recentGestures.last.difference(_recentGestures.first);
    if (timeSpan.inMilliseconds == 0) return false;
    
    final frequency = _recentGestures.length / (timeSpan.inMilliseconds / 1000.0);
    return frequency >= _gestureFrequencyThreshold;
  }

  /// Estabelece baseline de movimento normal durante condução
  void _establishBaseline() {
    final accelSum = _recentAccelMagnitudes.take(10).reduce((a, b) => a + b);
    final gyroSum = _recentGyroMagnitudes.take(10).reduce((a, b) => a + b);
    
    _baselineAcceleration = accelSum / 10;
    _baselineRotation = gyroSum / 10;
    _hasBaseline = true;
    
    debugPrint('📱 Baseline estabelecido: accel=${_baselineAcceleration.toStringAsFixed(2)}, gyro=${_baselineRotation.toStringAsFixed(2)}');
  }

  /// Obtém orientação atual do dispositivo
  double _getCurrentOrientation() {
    // Usar dados do giroscópio para estimar orientação
    // Simplificação: usar magnitude como proxy para mudanças de orientação
    return _sensorService.calculateGyroscopeMagnitude() * 57.2958; // rad para graus
  }

  /// Inicia um evento de uso do telefone
  Future<void> _startPhoneUsageEvent() async {
    _isCurrentlyUsingPhone = true;
    _phoneUsageStartTime = DateTime.now();
    
    // Configurar timer para verificar duração mínima
    _usageTimer = Timer(Duration(seconds: _minUsageDuration.toInt()), () {
      if (_isCurrentlyUsingPhone) {
        _reportPhoneUsageEvent();
      }
    });
    
    debugPrint('📱 Uso do telefone iniciado');
    notifyListeners();
  }

  /// Finaliza um evento de uso do telefone
  Future<void> _endPhoneUsageEvent() async {
    if (!_isCurrentlyUsingPhone || _phoneUsageStartTime == null) return;
    
    final duration = DateTime.now().difference(_phoneUsageStartTime!);
    
    // Só reportar se durou tempo suficiente
    if (duration.inSeconds >= _minUsageDuration) {
      _reportPhoneUsageEvent();
    }
    
    _isCurrentlyUsingPhone = false;
    _phoneUsageStartTime = null;
    _usageTimer?.cancel();
    
    debugPrint('📱 Uso do telefone finalizado após ${duration.inSeconds} segundos');
    notifyListeners();
  }

  /// Reporta evento de uso do telefone detectado
  void _reportPhoneUsageEvent() async {
    if (_phoneUsageStartTime == null) return;
    
    final duration = DateTime.now().difference(_phoneUsageStartTime!);
    
    // Obter posição atual
    Position? currentPosition;
    try {
      currentPosition = await Geolocator.getCurrentPosition();
    } catch (e) {
      debugPrint('Erro ao obter posição para evento de telefone: $e');
    }
    
    final event = TelematicsEvent(
      tripId: 1, // TODO: Obter trip ID atual
      userId: 1, // TODO: Obter user ID atual
      eventType: TelematicsEventType.phoneUsage,
      timestamp: _phoneUsageStartTime!,
      latitude: currentPosition?.latitude ?? 0.0,
      longitude: currentPosition?.longitude ?? 0.0,
      severity: duration.inSeconds.toDouble(),
      metadata: {
        'duration_seconds': duration.inSeconds,
        'gesture_count': _recentGestures.length,
        'avg_acceleration_deviation': _calculateAccelerationDeviation(),
        'max_orientation_change': _calculateMaxOrientationChange(),
        'detection_confidence': _calculateDetectionConfidence(),
      },
    );
    
    onPhoneUsageDetected?.call(event);
    debugPrint('📱 Evento de uso do telefone reportado: ${duration.inSeconds}s');
  }

  /// Calcula desvio médio da aceleração
  double _calculateAccelerationDeviation() {
    if (!_hasBaseline || _recentAccelMagnitudes.isEmpty) return 0.0;
    
    final deviations = _recentAccelMagnitudes.map((accel) => 
        (accel - _baselineAcceleration).abs()).toList();
    
    return deviations.reduce((a, b) => a + b) / deviations.length;
  }

  /// Calcula mudança máxima de orientação
  double _calculateMaxOrientationChange() {
    if (_recentOrientations.length < 2) return 0.0;
    
    double maxChange = 0.0;
    for (int i = 1; i < _recentOrientations.length; i++) {
      final change = (_recentOrientations[i] - _recentOrientations[i-1]).abs();
      if (change > maxChange) maxChange = change;
    }
    
    return maxChange;
  }

  /// Calcula confiança da detecção
  double _calculateDetectionConfidence() {
    double confidence = 0.0;
    
    // Confiança baseada em desvio de aceleração
    final accelDeviation = _calculateAccelerationDeviation();
    confidence += math.min(accelDeviation / _phoneUsageThreshold, 1.0) * 0.3;
    
    // Confiança baseada em mudanças de orientação
    final orientationChange = _calculateMaxOrientationChange();
    confidence += math.min(orientationChange / _orientationChangeThreshold, 1.0) * 0.3;
    
    // Confiança baseada em frequência de gestos
    if (_recentGestures.length >= 2) {
      final timeSpan = _recentGestures.last.difference(_recentGestures.first);
      final frequency = _recentGestures.length / (timeSpan.inMilliseconds / 1000.0);
      confidence += math.min(frequency / _gestureFrequencyThreshold, 1.0) * 0.4;
    }
    
    return math.min(confidence, 1.0);
  }

  /// Adiciona dados ao histórico
  void _addToHistory(double accelMagnitude, double gyroMagnitude, double orientation) {
    _recentAccelMagnitudes.add(accelMagnitude);
    _recentGyroMagnitudes.add(gyroMagnitude);
    _recentOrientations.add(orientation);
    
    // Manter tamanho do histórico
    if (_recentAccelMagnitudes.length > _analysisWindowSize) {
      _recentAccelMagnitudes.removeAt(0);
      _recentGyroMagnitudes.removeAt(0);
      _recentOrientations.removeAt(0);
    }
  }

  /// Limpa histórico de dados
  void _clearHistory() {
    _recentAccelMagnitudes.clear();
    _recentGyroMagnitudes.clear();
    _recentOrientations.clear();
    _recentGestures.clear();
  }

  /// Obtém estatísticas do algoritmo
  Map<String, dynamic> getStatistics() {
    return {
      'is_detecting': _isDetecting,
      'is_currently_using_phone': _isCurrentlyUsingPhone,
      'is_driving': _isDriving,
      'current_usage_duration_seconds': currentUsageDuration?.inSeconds ?? 0,
      'has_baseline': _hasBaseline,
      'baseline_acceleration': _baselineAcceleration,
      'baseline_rotation': _baselineRotation,
      'recent_gestures_count': _recentGestures.length,
      'acceleration_samples': _recentAccelMagnitudes.length,
      'detection_confidence': _isCurrentlyUsingPhone ? _calculateDetectionConfidence() : 0.0,
      'algorithm_config': {
        'min_driving_speed_kmh': _minDrivingSpeed,
        'phone_usage_threshold_ms2': _phoneUsageThreshold,
        'orientation_change_threshold_degrees': _orientationChangeThreshold,
        'gesture_frequency_threshold_hz': _gestureFrequencyThreshold,
        'min_usage_duration_seconds': _minUsageDuration,
        'analysis_window_size': _analysisWindowSize,
      },
    };
  }

  @override
  void dispose() {
    stopDetection();
    super.dispose();
  }
}

