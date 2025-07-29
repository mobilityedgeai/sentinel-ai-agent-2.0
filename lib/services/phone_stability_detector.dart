import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'sensor_service.dart';
import 'fused_location_service.dart';
import '../models/location_data.dart';

/// Detecta se o telefone está estável (fixo no suporte) ou sendo manipulado
/// Agora integrado com Fused Location API para maior precisão
class PhoneStabilityDetector {
  static final PhoneStabilityDetector _instance = PhoneStabilityDetector._internal();
  factory PhoneStabilityDetector() => _instance;
  PhoneStabilityDetector._internal();

  bool _isInitialized = false;
  final List<double> _orientationHistory = [];
  final List<double> _accelerationVarianceHistory = [];
  final List<double> _gyroscopeVarianceHistory = [];
  final List<double> _locationAccuracyHistory = [];
  final List<double> _speedVarianceHistory = [];
  
  // Serviços integrados
  final FusedLocationService _fusedLocationService = FusedLocationService();
  
  // Configurações de detecção
  static const int _historySize = 30; // 3 segundos a 10Hz
  static const double _stabilityThreshold = 0.6; // Score mínimo para considerar estável
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _fusedLocationService.initialize();
    _isInitialized = true;
    debugPrint('PhoneStabilityDetector: Inicializado com Fused Location API');
  }

  /// Calcula score de estabilidade do telefone (0.0 = instável, 1.0 = muito estável)
  /// Agora usa dados de localização para maior precisão
  Future<double> calculateStabilityScore(SensorData? currentData) async {
    if (!_isInitialized || currentData == null) return 0.5;
    
    // Obter dados de localização atual
    final locationData = await _fusedLocationService.getCurrentLocation();
    
    // ALGORITMO 1: Variância da orientação
    final orientationScore = _calculateOrientationStability(currentData);
    
    // ALGORITMO 2: Variância da aceleração
    final accelerationScore = _calculateAccelerationStability(currentData);
    
    // ALGORITMO 3: Variância do giroscópio
    final gyroscopeScore = _calculateGyroscopeStability(currentData);
    
    // ALGORITMO 4: Padrão de vibração
    final vibrationScore = _calculateVibrationPattern(currentData);
    
    // ALGORITMO 5: Precisão da localização (NOVO)
    final locationScore = _calculateLocationStability(locationData);
    
    // ALGORITMO 6: Variância da velocidade (NOVO)
    final speedScore = _calculateSpeedStability(locationData);
    
    // Combinar scores com pesos otimizados
    final finalScore = (
      orientationScore * 0.25 +
      accelerationScore * 0.25 +
      gyroscopeScore * 0.25 +
      vibrationScore * 0.1 +
      locationScore * 0.1 +
      speedScore * 0.05
    );
    
    return math.max(0.0, math.min(1.0, finalScore));
  }
  
  double _calculateOrientationStability(SensorData data) {
    // Calcular magnitude da orientação atual
    final orientationMagnitude = math.sqrt(
      data.accelerationX * data.accelerationX +
      data.accelerationY * data.accelerationY +
      data.accelerationZ * data.accelerationZ
    );
    
    _orientationHistory.add(orientationMagnitude);
    if (_orientationHistory.length > _historySize) {
      _orientationHistory.removeAt(0);
    }
    
    if (_orientationHistory.length < 10) return 0.5;
    
    // Calcular variância da orientação
    final mean = _orientationHistory.reduce((a, b) => a + b) / _orientationHistory.length;
    final variance = _orientationHistory
        .map((x) => math.pow(x - mean, 2))
        .reduce((a, b) => a + b) / _orientationHistory.length;
    
    // Converter variância em score (menor variância = mais estável)
    final stabilityScore = math.max(0.0, 1.0 - (variance / 10.0));
    return stabilityScore;
  }
  
  double _calculateAccelerationStability(SensorData data) {
    // Calcular variância da aceleração (removendo gravidade)
    final accelMagnitude = math.sqrt(
      data.accelerationX * data.accelerationX +
      data.accelerationY * data.accelerationY +
      (data.accelerationZ - 9.8) * (data.accelerationZ - 9.8)
    );
    
    _accelerationVarianceHistory.add(accelMagnitude);
    if (_accelerationVarianceHistory.length > _historySize) {
      _accelerationVarianceHistory.removeAt(0);
    }
    
    if (_accelerationVarianceHistory.length < 10) return 0.5;
    
    final mean = _accelerationVarianceHistory.reduce((a, b) => a + b) / _accelerationVarianceHistory.length;
    final variance = _accelerationVarianceHistory
        .map((x) => math.pow(x - mean, 2))
        .reduce((a, b) => a + b) / _accelerationVarianceHistory.length;
    
    // Score baseado na variância (telefone fixo tem baixa variância)
    final stabilityScore = math.max(0.0, 1.0 - (variance / 5.0));
    return stabilityScore;
  }
  
  double _calculateGyroscopeStability(SensorData data) {
    // Calcular magnitude da rotação
    final gyroMagnitude = math.sqrt(
      data.gyroscopeX * data.gyroscopeX +
      data.gyroscopeY * data.gyroscopeY +
      data.gyroscopeZ * data.gyroscopeZ
    );
    
    _gyroscopeVarianceHistory.add(gyroMagnitude);
    if (_gyroscopeVarianceHistory.length > _historySize) {
      _gyroscopeVarianceHistory.removeAt(0);
    }
    
    if (_gyroscopeVarianceHistory.length < 10) return 0.5;
    
    final mean = _gyroscopeVarianceHistory.reduce((a, b) => a + b) / _gyroscopeVarianceHistory.length;
    final variance = _gyroscopeVarianceHistory
        .map((x) => math.pow(x - mean, 2))
        .reduce((a, b) => a + b) / _gyroscopeVarianceHistory.length;
    
    // Telefone fixo tem baixa rotação
    final stabilityScore = math.max(0.0, 1.0 - (variance / 2.0));
    return stabilityScore;
  }
  
  double _calculateVibrationPattern(SensorData data) {
    // Detectar padrões de vibração típicos de telefone sendo segurado
    final totalMagnitude = math.sqrt(
      data.accelerationX * data.accelerationX +
      data.accelerationY * data.accelerationY +
      data.accelerationZ * data.accelerationZ +
      data.gyroscopeX * data.gyroscopeX +
      data.gyroscopeY * data.gyroscopeY +
      data.gyroscopeZ * data.gyroscopeZ
    );
    
    // Padrões de vibração humana são tipicamente entre 1-20 Hz
    // Telefone fixo tem vibração mais consistente
    if (totalMagnitude < 2.0) {
      return 0.9; // Muito estável
    } else if (totalMagnitude < 5.0) {
      return 0.7; // Moderadamente estável
    } else if (totalMagnitude < 10.0) {
      return 0.4; // Pouco estável
    } else {
      return 0.1; // Muito instável (sendo manipulado)
    }
  }
  
  /// NOVO: Calcula estabilidade baseada na precisão da localização
  double _calculateLocationStability(LocationData? locationData) {
    if (locationData == null) return 0.5;
    
    // Adicionar precisão ao histórico
    _locationAccuracyHistory.add(locationData.accuracy ?? 0.0);
    if (_locationAccuracyHistory.length > _historySize) {
      _locationAccuracyHistory.removeAt(0);
    }
    
    if (_locationAccuracyHistory.length < 5) return 0.5;
    
    // Telefone estável tem precisão mais consistente
    final averageAccuracy = _locationAccuracyHistory.reduce((a, b) => a + b) / _locationAccuracyHistory.length;
    
    // Melhor precisão = maior estabilidade
    if (averageAccuracy < 5.0) {
      return 0.9; // Muito preciso = muito estável
    } else if (averageAccuracy < 10.0) {
      return 0.7; // Boa precisão = estável
    } else if (averageAccuracy < 20.0) {
      return 0.5; // Precisão moderada
    } else {
      return 0.2; // Baixa precisão = instável
    }
  }
  
  /// NOVO: Calcula estabilidade baseada na variância da velocidade
  double _calculateSpeedStability(LocationData? locationData) {
    if (locationData == null) return 0.5;
    
    // Adicionar velocidade ao histórico
    _speedVarianceHistory.add(locationData.speed ?? 0.0);
    if (_speedVarianceHistory.length > _historySize) {
      _speedVarianceHistory.removeAt(0);
    }
    
    if (_speedVarianceHistory.length < 10) return 0.5;
    
    // Calcular variância da velocidade
    final mean = _speedVarianceHistory.reduce((a, b) => a + b) / _speedVarianceHistory.length;
    final variance = _speedVarianceHistory
        .map((x) => math.pow(x - mean, 2))
        .reduce((a, b) => a + b) / _speedVarianceHistory.length;
    
    // Telefone fixo tem velocidade mais consistente
    final stabilityScore = math.max(0.0, 1.0 - (variance / 25.0));
    return stabilityScore;
  }
  
  /// Verifica se o telefone está provavelmente fixo no suporte
  bool isPhoneMounted(double stabilityScore) {
    return stabilityScore >= _stabilityThreshold;
  }
  
  /// Obtém estatísticas de estabilidade aprimoradas
  Map<String, dynamic> getStabilityStatistics() {
    return {
      'orientationHistorySize': _orientationHistory.length,
      'accelerationHistorySize': _accelerationVarianceHistory.length,
      'gyroscopeHistorySize': _gyroscopeVarianceHistory.length,
      'locationAccuracyHistorySize': _locationAccuracyHistory.length,
      'speedVarianceHistorySize': _speedVarianceHistory.length,
      'isInitialized': _isInitialized,
      'stabilityThreshold': _stabilityThreshold,
      'fusedLocationEnabled': _fusedLocationService.isInitialized,
      'averageLocationAccuracy': _locationAccuracyHistory.isNotEmpty 
          ? _locationAccuracyHistory.reduce((a, b) => a + b) / _locationAccuracyHistory.length 
          : 0.0,
    };
  }
  
  /// Limpa histórico
  void clearHistory() {
    _orientationHistory.clear();
    _accelerationVarianceHistory.clear();
    _gyroscopeVarianceHistory.clear();
    _locationAccuracyHistory.clear();
    _speedVarianceHistory.clear();
  }
}

