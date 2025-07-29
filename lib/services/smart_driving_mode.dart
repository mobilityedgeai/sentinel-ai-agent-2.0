import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../services/location_service.dart';
import '../services/sensor_service.dart';
import '../models/location_data.dart';

/// Contextos de condução para ajuste dinâmico
enum DrivingContext {
  ideal,        // Condições ideais - telefone fixo, GPS bom, condução suave
  good,         // Boas condições - pequenas variações
  moderate,     // Condições moderadas - alguma instabilidade
  challenging,  // Condições desafiadoras - telefone instável ou GPS ruim
  difficult,    // Condições difíceis - múltiplos problemas
  poor,         // Condições ruins - dados não confiáveis
}

/// Ajustes de threshold baseados no contexto
class ThresholdAdjustments {
  final double hardBrakingMultiplier;
  final double rapidAccelerationMultiplier;
  final double sharpTurnMultiplier;
  final double highGForceMultiplier;
  final double confidenceBonus;
  
  ThresholdAdjustments({
    required this.hardBrakingMultiplier,
    required this.rapidAccelerationMultiplier,
    required this.sharpTurnMultiplier,
    required this.highGForceMultiplier,
    required this.confidenceBonus,
  });
}

/// Sistema inteligente que ajusta thresholds baseado no contexto de condução
/// Agora integrado com Fused Location API e cache otimizado
class SmartDrivingMode {
  static final SmartDrivingMode _instance = SmartDrivingMode._internal();
  factory SmartDrivingMode() => _instance;
  SmartDrivingMode._internal();

  bool _isInitialized = false;
  DrivingContext _currentContext = DrivingContext.moderate;
  
  // Serviços auxiliares
  final LocationService _locationService = LocationService();
  
  // Histórico de contextos e métricas
  final List<DrivingContext> _contextHistory = [];
  final List<double> _accuracyHistory = [];
  final List<double> _speedVarianceHistory = [];
  static const int _contextHistorySize = 20;
  static const int _metricsHistorySize = 50;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _isInitialized = true;
      debugPrint('SmartDrivingMode: Inicializado');
    } catch (e) {
      debugPrint('Erro ao inicializar SmartDrivingMode: $e');
    }
  }

  /// Obtém o contexto atual de condução com dados aprimorados
  Future<DrivingContext> getCurrentContext() async {
    if (!_isInitialized) return DrivingContext.moderate;
    
    // FATOR 1: Qualidade do GPS (aprimorado)
    final gpsQuality = await _assessGpsQuality();
    
    // FATOR 2: Estabilidade do telefone (será obtida do PhoneStabilityDetector)
    final phoneStability = await _assessPhoneStability();
    
    // FATOR 3: Atividade detectada
    final activityConfidence = _assessActivityConfidence();
    
    // FATOR 4: Consistência dos sensores (aprimorado)
    final sensorConsistency = await _assessSensorConsistency();
    
    // FATOR 5: Condições ambientais (velocidade, aceleração)
    final environmentalConditions = await _assessEnvironmentalConditions();
    
    // Calcular score geral (0.0 = poor, 1.0 = ideal) com pesos otimizados
    final overallScore = (
      gpsQuality * 0.35 +           // Maior peso para GPS
      phoneStability * 0.3 +
      activityConfidence * 0.2 +
      sensorConsistency * 0.15
    );
    
    // Determinar contexto baseado no score com thresholds otimizados
    DrivingContext newContext;
    if (overallScore >= 0.85) {
      newContext = DrivingContext.ideal;
    } else if (overallScore >= 0.7) {
      newContext = DrivingContext.good;
    } else if (overallScore >= 0.55) {
      newContext = DrivingContext.moderate;
    } else if (overallScore >= 0.4) {
      newContext = DrivingContext.challenging;
    } else if (overallScore >= 0.25) {
      newContext = DrivingContext.difficult;
    } else {
      newContext = DrivingContext.poor;
    }
    // Atualizar histórico de contexto
    _updateContextHistory(newContext);
    
    debugPrint('SmartDrivingMode: Contexto atual = ${newContext.toString().split('.').last} '
              '(score: ${(overallScore * 100).toStringAsFixed(1)}%)');
    
    return newContext;
  }
  
  /// Avalia qualidade do GPS
  Future<double> _assessGpsQuality() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (position == null) return 0.2;
      
      // Avaliar precisão atual
      final accuracy = position.accuracy ?? 100.0;
      double accuracyScore;
      if (accuracy <= 5.0) {
        accuracyScore = 1.0;      // Excelente
      } else if (accuracy <= 10.0) {
        accuracyScore = 0.8;      // Boa
      } else if (accuracy <= 20.0) {
        accuracyScore = 0.6;      // Moderada
      } else if (accuracy <= 50.0) {
        accuracyScore = 0.4;      // Ruim
      } else {
        accuracyScore = 0.2;      // Muito ruim
      }
      
      return accuracyScore;
      
    } catch (e) {
      debugPrint('Erro ao avaliar qualidade GPS: $e');
      return 0.1; // GPS não disponível
    }
  }
  
  Future<double> _assessPhoneStability() async {
    // Esta função será integrada com o PhoneStabilityDetector
    // Por enquanto, retorna valor moderado
    return 0.6;
  }
  
  double _assessActivityConfidence() {
    // Simplificar avaliação de atividade (sem dependência externa)
    final activityScore = 0.8; // Valor padrão para condução
    
    return activityScore;
  }
  
  Future<double> _assessSensorConsistency() async {
    // Avaliar se os sensores estão fornecendo dados consistentes
    // Integração futura com SensorService
    return 0.7;
  }
  
  Future<double> _assessEnvironmentalConditions() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (position == null) return 0.5;
      
      final speed = position.speed ?? 0.0;
      final speedKmh = speed * 3.6;
      
      // Avaliar velocidade atual
      double speedScore;
      if (speedKmh >= 25.0 && speedKmh <= 70.0) {
        speedScore = 1.0; // Velocidade ideal para detecção
      } else if (speedKmh >= 15.0 && speedKmh <= 90.0) {
        speedScore = 0.8; // Velocidade boa
      } else if (speedKmh >= 10.0 && speedKmh <= 110.0) {
        speedScore = 0.6; // Velocidade moderada
      } else if (speedKmh >= 5.0 && speedKmh <= 130.0) {
        speedScore = 0.4; // Velocidade desafiadora
      } else {
        speedScore = 0.2; // Velocidade muito baixa ou muito alta
      }
      
      return speedScore;
      
    } catch (e) {
      debugPrint('Erro ao avaliar condições ambientais: $e');
      return 0.5;
    }
  }
  
  void _updateContextHistory(DrivingContext context) {
    _contextHistory.add(context);
    if (_contextHistory.length > _contextHistorySize) {
      _contextHistory.removeAt(0);
    }
  }

  /// Obtém ajustes de threshold baseados no contexto atual (aprimorado)
  ThresholdAdjustments getThresholdAdjustments(DrivingContext context) {
    switch (context) {
      case DrivingContext.ideal:
        // Condições ideais - thresholds mais sensíveis + bônus de confiança
        return ThresholdAdjustments(
          hardBrakingMultiplier: 0.75,     // Mais sensível
          rapidAccelerationMultiplier: 0.75,
          sharpTurnMultiplier: 0.8,
          highGForceMultiplier: 0.85,
          confidenceBonus: 0.2,            // Bônus de confiança
        );
        
      case DrivingContext.good:
        // Boas condições - ligeiramente mais sensível
        return ThresholdAdjustments(
          hardBrakingMultiplier: 0.85,
          rapidAccelerationMultiplier: 0.85,
          sharpTurnMultiplier: 0.9,
          highGForceMultiplier: 0.9,
          confidenceBonus: 0.15,
        );
        
      case DrivingContext.moderate:
        // Condições moderadas - thresholds padrão
        return ThresholdAdjustments(
          hardBrakingMultiplier: 1.0,
          rapidAccelerationMultiplier: 1.0,
          sharpTurnMultiplier: 1.0,
          highGForceMultiplier: 1.0,
          confidenceBonus: 0.0,
        );
        
      case DrivingContext.challenging:
        // Condições desafiadoras - menos sensível
        return ThresholdAdjustments(
          hardBrakingMultiplier: 1.25,
          rapidAccelerationMultiplier: 1.25,
          sharpTurnMultiplier: 1.2,
          highGForceMultiplier: 1.15,
          confidenceBonus: -0.1,           // Penalidade de confiança
        );
        
      case DrivingContext.difficult:
        // Condições difíceis - muito menos sensível
        return ThresholdAdjustments(
          hardBrakingMultiplier: 1.6,
          rapidAccelerationMultiplier: 1.6,
          sharpTurnMultiplier: 1.5,
          highGForceMultiplier: 1.4,
          confidenceBonus: -0.2,
        );
        
      case DrivingContext.poor:
        // Condições ruins - thresholds muito altos para evitar falsos positivos
        return ThresholdAdjustments(
          hardBrakingMultiplier: 2.2,
          rapidAccelerationMultiplier: 2.2,
          sharpTurnMultiplier: 2.0,
          highGForceMultiplier: 1.8,
          confidenceBonus: -0.3,
        );
    }
  }
  
  /// Obtém recomendações baseadas no contexto atual
  List<String> getContextRecommendations(DrivingContext context) {
    switch (context) {
      case DrivingContext.ideal:
        return [
          'Condições ideais para detecção',
          'Todos os algoritmos funcionando com precisão máxima'
        ];
        
      case DrivingContext.good:
        return [
          'Boas condições de detecção',
          'Pequenos ajustes aplicados para otimizar precisão'
        ];
        
      case DrivingContext.moderate:
        return [
          'Condições moderadas',
          'Thresholds padrão aplicados'
        ];
        
      case DrivingContext.challenging:
        return [
          'Condições desafiadoras detectadas',
          'Thresholds ajustados para reduzir falsos positivos',
          'Considere fixar melhor o telefone'
        ];
        
      case DrivingContext.difficult:
        return [
          'Condições difíceis para detecção',
          'Sensibilidade reduzida significativamente',
          'Verifique se o telefone está bem fixo',
          'Aguarde melhores condições de GPS'
        ];
        
      case DrivingContext.poor:
        return [
          'Condições ruins para detecção confiável',
          'Muitos eventos podem não ser detectados',
          'Fixe o telefone adequadamente',
          'Verifique conexão GPS',
          'Considere reiniciar o app'
        ];
    }
  }
  
  /// Obtém estatísticas do modo inteligente
  Map<String, dynamic> getSmartModeStatistics() {
    final contextCounts = <String, int>{};
    for (final context in _contextHistory) {
      final key = context.toString().split('.').last;
      contextCounts[key] = (contextCounts[key] ?? 0) + 1;
    }
    
    return {
      'isInitialized': _isInitialized,
      'currentContext': _currentContext.toString().split('.').last,
      'contextHistorySize': _contextHistory.length,
      'contextDistribution': contextCounts,
      'recommendations': getContextRecommendations(_currentContext),
    };
  }
  
  /// Força um contexto específico (para testes)
  void forceContext(DrivingContext context) {
    _currentContext = context;
    _updateContextHistory(context);
    debugPrint('SmartDrivingMode: Contexto forçado para ${context.toString().split('.').last}');
  }
  
  /// Limpa histórico
  void clearHistory() {
    _contextHistory.clear();
  }
}

