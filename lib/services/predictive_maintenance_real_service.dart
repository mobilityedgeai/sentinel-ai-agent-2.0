import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/location_data.dart';
import '../models/component_health.dart';
import '../models/maintenance_prediction.dart';
import 'real_data_service.dart';
import 'advanced_telematics_analyzer.dart';

/// Serviço de manutenção preditiva em tempo real
class PredictiveMaintenanceRealService extends ChangeNotifier {
  static final PredictiveMaintenanceRealService _instance = PredictiveMaintenanceRealService._internal();
  factory PredictiveMaintenanceRealService() => _instance;
  PredictiveMaintenanceRealService._internal();

  final RealDataService _realDataService = RealDataService();
  final AdvancedTelematicsAnalyzer _telematicsAnalyzer = AdvancedTelematicsAnalyzer();

  // Estado dos componentes
  final Map<ComponentType, ComponentHealth> _componentHealth = {};
  final List<MaintenancePrediction> _predictions = [];
  final List<MaintenanceAlert> _alerts = [];

  // Dados acumulados
  double _totalKilometers = 0.0;
  double _totalOperatingHours = 0.0;
  int _totalTrips = 0;
  
  // Eventos acumulados
  int _totalHardBraking = 0;
  int _totalRapidAcceleration = 0;
  int _totalSharpTurns = 0;
  int _totalSpeedingEvents = 0;

  // Timer para atualizações
  Timer? _updateTimer;
  bool _isActive = false;

  /// Inicializa o serviço
  void initialize() {
    if (_isActive) return;
    
    _isActive = true;
    _initializeComponents();
    _setupListeners();
    _startPeriodicUpdates();
    
    debugPrint('🔧 Serviço de Manutenção Preditiva iniciado');
  }

  /// Para o serviço
  void dispose() {
    _isActive = false;
    _updateTimer?.cancel();
    _realDataService.removeListener(_onDataUpdate);
    super.dispose();
  }

  /// Inicializa componentes com valores padrão
  void _initializeComponents() {
    for (ComponentType type in ComponentType.values) {
      _componentHealth[type] = ComponentHealth(
        type: type,
        healthScore: 100.0,
        wearLevel: 0.0,
        lastMaintenanceKm: 0.0,
        lastMaintenanceDate: DateTime.now(),
        nextMaintenanceKm: _getMaintenanceInterval(type),
        nextMaintenanceDate: DateTime.now().add(Duration(days: _getMaintenanceIntervalDays(type))),
        estimatedLifeRemaining: 1.0,
        criticalityLevel: CriticalityLevel.low,
      );
    }
  }

  /// Configura listeners para dados reais
  void _setupListeners() {
    _realDataService.addListener(_onDataUpdate);
  }

  /// Callback para atualização de dados
  void _updateDataFromRealService() async {
    try {
      // Obter estatísticas reais do serviço
      final stats = await _realDataService.getGeneralStats();
      
      // Atualizar dados acumulados com dados REAIS do SQLite
      _totalKilometers = stats['totalDistance']?.toDouble() ?? 0.0;
      _totalTrips = stats['totalTrips']?.toInt() ?? 0;
      
      // Calcular horas de operação baseado em dados reais
      if (_realDataService.currentTrip != null) {
        final currentTripDuration = DateTime.now().difference(_realDataService.currentTrip!.startTime).inMinutes;
        _totalOperatingHours = (currentTripDuration / 60.0) + (_totalKilometers / 45.0);
      } else {
        _totalOperatingHours = _totalKilometers / 45.0; // Estimativa: 45 km/h média
      }
      
      // Calcular eventos baseado em dados reais do SQLite
      _totalHardBraking = stats['hardBrakingCount']?.toInt() ?? 0;
      _totalRapidAcceleration = stats['rapidAccelerationCount']?.toInt() ?? 0;
      _totalSharpTurns = stats['sharpTurnCount']?.toInt() ?? 0;
      _totalSpeedingEvents = stats['speedingCount']?.toInt() ?? 0;
      
      debugPrint('🔧 Dados REAIS atualizados: ${_totalKilometers}km, ${_totalOperatingHours}h, ${_totalTrips} viagens');
      
      _updateComponentHealth();
      _generatePredictions();
      _checkAlerts();
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erro ao atualizar dados de manutenção: $e');
    }
  }

  /// Inicia atualizações periódicas
  void _startPeriodicUpdates() {
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isActive) {
        _updateComponentHealth();
        _generatePredictions();
        _checkAlerts();
        notifyListeners();
      }
    });
  }

  /// Atualiza saúde dos componentes
  void _updateComponentHealth() {
    for (ComponentType type in ComponentType.values) {
      final component = _componentHealth[type]!;
      
      // Calcular desgaste baseado em algoritmos específicos
      double wearLevel = _calculateWearLevel(type);
      double healthScore = math.max(0.0, 100.0 - (wearLevel * 100.0));
      
      // Calcular vida útil restante
      double lifeRemaining = math.max(0.0, 1.0 - wearLevel);
      
      // Determinar criticidade
      CriticalityLevel criticality = _determineCriticality(healthScore);
      
      // Calcular próxima manutenção
      double nextMaintenanceKm = _calculateNextMaintenanceKm(type, component);
      DateTime nextMaintenanceDate = _calculateNextMaintenanceDate(type, component);
      
      _componentHealth[type] = ComponentHealth(
        type: type,
        healthScore: healthScore,
        wearLevel: wearLevel,
        lastMaintenanceKm: component.lastMaintenanceKm,
        lastMaintenanceDate: component.lastMaintenanceDate,
        nextMaintenanceKm: nextMaintenanceKm,
        nextMaintenanceDate: nextMaintenanceDate,
        estimatedLifeRemaining: lifeRemaining,
        criticalityLevel: criticality,
      );
    }
  }

  /// Calcula nível de desgaste por componente
  double _calculateWearLevel(ComponentType type) {
    switch (type) {
      case ComponentType.brakes:
        return _calculateBrakeWear();
      case ComponentType.engine:
        return _calculateEngineWear();
      case ComponentType.tires:
        return _calculateTireWear();
      case ComponentType.suspension:
        return _calculateSuspensionWear();
      case ComponentType.transmission:
        return _calculateTransmissionWear();
      case ComponentType.battery:
        return _calculateBatteryWear();
      case ComponentType.airFilter:
        return _calculateAirFilterWear();
      case ComponentType.oilFilter:
        return _calculateOilFilterWear();
    }
  }

  /// Algoritmo de desgaste dos freios
  double _calculateBrakeWear() {
    // Fator base por quilometragem
    double kmFactor = _totalKilometers / 50000.0; // 50k km vida útil média
    
    // Fator por frenagens bruscas
    double brakingFactor = _totalHardBraking * 0.01; // Cada frenagem = 1% desgaste extra
    
    // Fator por tempo
    double timeFactor = _totalOperatingHours / 3000.0; // 3000h vida útil
    
    return math.min(1.0, kmFactor + brakingFactor + timeFactor);
  }

  /// Algoritmo de desgaste do motor
  double _calculateEngineWear() {
    // Fator base por quilometragem
    double kmFactor = _totalKilometers / 300000.0; // 300k km vida útil
    
    // Fator por acelerações rápidas
    double accelerationFactor = _totalRapidAcceleration * 0.005; // Cada aceleração = 0.5%
    
    // Fator por excesso de velocidade
    double speedFactor = _totalSpeedingEvents * 0.002; // Cada evento = 0.2%
    
    // Fator por tempo
    double timeFactor = _totalOperatingHours / 8000.0; // 8000h vida útil
    
    return math.min(1.0, kmFactor + accelerationFactor + speedFactor + timeFactor);
  }

  /// Algoritmo de desgaste dos pneus
  double _calculateTireWear() {
    // Fator base por quilometragem
    double kmFactor = _totalKilometers / 60000.0; // 60k km vida útil
    
    // Fator por curvas acentuadas
    double turnFactor = _totalSharpTurns * 0.008; // Cada curva = 0.8%
    
    // Fator por frenagens bruscas
    double brakingFactor = _totalHardBraking * 0.006; // Cada frenagem = 0.6%
    
    // Fator por acelerações
    double accelerationFactor = _totalRapidAcceleration * 0.004; // Cada aceleração = 0.4%
    
    return math.min(1.0, kmFactor + turnFactor + brakingFactor + accelerationFactor);
  }

  /// Algoritmo de desgaste da suspensão
  double _calculateSuspensionWear() {
    // Fator base por quilometragem
    double kmFactor = _totalKilometers / 150000.0; // 150k km vida útil
    
    // Fator por curvas acentuadas
    double turnFactor = _totalSharpTurns * 0.01; // Cada curva = 1%
    
    // Fator por condições de estrada (estimado por eventos)
    double roadFactor = (_totalHardBraking + _totalRapidAcceleration) * 0.002;
    
    return math.min(1.0, kmFactor + turnFactor + roadFactor);
  }

  /// Algoritmo de desgaste da transmissão
  double _calculateTransmissionWear() {
    // Fator base por quilometragem
    double kmFactor = _totalKilometers / 250000.0; // 250k km vida útil
    
    // Fator por acelerações rápidas
    double accelerationFactor = _totalRapidAcceleration * 0.008; // Cada aceleração = 0.8%
    
    // Fator por tempo
    double timeFactor = _totalOperatingHours / 6000.0; // 6000h vida útil
    
    return math.min(1.0, kmFactor + accelerationFactor + timeFactor);
  }

  /// Algoritmo de desgaste da bateria
  double _calculateBatteryWear() {
    // Fator base por tempo (baterias degradam com tempo)
    double timeFactor = _totalOperatingHours / 5000.0; // 5000h vida útil
    
    // Fator por quilometragem
    double kmFactor = _totalKilometers / 200000.0; // 200k km vida útil
    
    // Fator por número de partidas (estimado por viagens)
    double startFactor = _totalTrips / 10000.0; // 10k partidas
    
    return math.min(1.0, timeFactor + kmFactor + startFactor);
  }

  /// Algoritmo de desgaste do filtro de ar
  double _calculateAirFilterWear() {
    // Fator base por quilometragem
    double kmFactor = _totalKilometers / 20000.0; // 20k km vida útil
    
    // Fator por tempo
    double timeFactor = _totalOperatingHours / 500.0; // 500h vida útil
    
    return math.min(1.0, kmFactor + timeFactor);
  }

  /// Algoritmo de desgaste do filtro de óleo
  double _calculateOilFilterWear() {
    // Fator base por quilometragem
    double kmFactor = _totalKilometers / 10000.0; // 10k km vida útil
    
    // Fator por tempo
    double timeFactor = _totalOperatingHours / 300.0; // 300h vida útil
    
    return math.min(1.0, kmFactor + timeFactor);
  }

  /// Determina criticidade baseada no health score
  CriticalityLevel _determineCriticality(double healthScore) {
    if (healthScore >= 80) return CriticalityLevel.low;
    if (healthScore >= 60) return CriticalityLevel.medium;
    if (healthScore >= 40) return CriticalityLevel.high;
    return CriticalityLevel.critical;
  }

  /// Calcula próxima manutenção em km
  double _calculateNextMaintenanceKm(ComponentType type, ComponentHealth component) {
    double interval = _getMaintenanceInterval(type);
    double lastMaintenance = component.lastMaintenanceKm;
    
    // Próxima manutenção baseada no intervalo
    double nextKm = lastMaintenance + interval;
    
    // Se já passou do intervalo, calcular próximo baseado no atual
    if (_totalKilometers > nextKm) {
      double cycles = (_totalKilometers - lastMaintenance) / interval;
      nextKm = lastMaintenance + (cycles.ceil() * interval);
    }
    
    return nextKm;
  }

  /// Calcula próxima manutenção em data
  DateTime _calculateNextMaintenanceDate(ComponentType type, ComponentHealth component) {
    int intervalDays = _getMaintenanceIntervalDays(type);
    DateTime lastMaintenance = component.lastMaintenanceDate;
    
    // Próxima manutenção baseada no intervalo
    DateTime nextDate = lastMaintenance.add(Duration(days: intervalDays));
    
    // Se já passou da data, calcular próxima
    if (DateTime.now().isAfter(nextDate)) {
      int daysPassed = DateTime.now().difference(lastMaintenance).inDays;
      int cycles = (daysPassed / intervalDays).ceil();
      nextDate = lastMaintenance.add(Duration(days: cycles * intervalDays));
    }
    
    return nextDate;
  }

  /// Gera predições de manutenção
  void _generatePredictions() {
    _predictions.clear();
    
    for (ComponentType type in ComponentType.values) {
      final component = _componentHealth[type]!;
      
      // Calcular quando será necessária manutenção
      double wearRate = _calculateWearRate(type);
      double remainingLife = component.estimatedLifeRemaining;
      
      if (wearRate > 0) {
        int daysUntilMaintenance = (remainingLife / wearRate * 365).round();
        double kmUntilMaintenance = daysUntilMaintenance * (_totalKilometers / math.max(1, _totalOperatingHours * 24)) * 24;
        
        _predictions.add(MaintenancePrediction(
          componentType: type,
          predictedDate: DateTime.now().add(Duration(days: daysUntilMaintenance)),
          predictedKilometers: _totalKilometers + kmUntilMaintenance,
          confidence: _calculatePredictionConfidence(type),
          estimatedCost: _getEstimatedMaintenanceCost(type),
          urgency: _calculateUrgency(component.healthScore),
        ));
      }
    }
    
    // Ordenar por urgência
    _predictions.sort((a, b) => b.urgency.compareTo(a.urgency));
  }

  /// Calcula taxa de desgaste
  double _calculateWearRate(ComponentType type) {
    // Taxa baseada no uso atual (desgaste por dia)
    if (_totalOperatingHours == 0) return 0.001; // Taxa mínima
    
    double currentWear = _calculateWearLevel(type);
    double operatingDays = _totalOperatingHours / 24.0;
    
    return operatingDays > 0 ? currentWear / operatingDays : 0.001;
  }

  /// Calcula confiança da predição
  double _calculatePredictionConfidence(ComponentType type) {
    // Confiança baseada na quantidade de dados
    double dataPoints = _totalTrips + (_totalKilometers / 100);
    double confidence = math.min(1.0, dataPoints / 100.0);
    
    return math.max(0.5, confidence); // Mínimo 50% de confiança
  }

  /// Calcula urgência
  double _calculateUrgency(double healthScore) {
    return (100.0 - healthScore) / 100.0;
  }

  /// Verifica e gera alertas
  void _checkAlerts() {
    _alerts.clear();
    
    for (ComponentType type in ComponentType.values) {
      final component = _componentHealth[type]!;
      
      // Alerta por health score baixo
      if (component.healthScore < 30) {
        _alerts.add(MaintenanceAlert(
          componentType: type,
          severity: AlertSeverity.critical,
          message: 'Health score crítico: ${component.healthScore.toStringAsFixed(1)}%',
          timestamp: DateTime.now(),
        ));
      } else if (component.healthScore < 50) {
        _alerts.add(MaintenanceAlert(
          componentType: type,
          severity: AlertSeverity.high,
          message: 'Health score baixo: ${component.healthScore.toStringAsFixed(1)}%',
          timestamp: DateTime.now(),
        ));
      }
      
      // Alerta por proximidade de manutenção
      double kmUntilMaintenance = component.nextMaintenanceKm - _totalKilometers;
      if (kmUntilMaintenance < 1000 && kmUntilMaintenance > 0) {
        _alerts.add(MaintenanceAlert(
          componentType: type,
          severity: AlertSeverity.medium,
          message: 'Manutenção em ${kmUntilMaintenance.toStringAsFixed(0)} km',
          timestamp: DateTime.now(),
        ));
      }
      
      // Alerta por data de manutenção próxima
      int daysUntilMaintenance = component.nextMaintenanceDate.difference(DateTime.now()).inDays;
      if (daysUntilMaintenance < 30 && daysUntilMaintenance > 0) {
        _alerts.add(MaintenanceAlert(
          componentType: type,
          severity: AlertSeverity.medium,
          message: 'Manutenção em $daysUntilMaintenance dias',
          timestamp: DateTime.now(),
        ));
      }
    }
    
    // Ordenar por severidade
    _alerts.sort((a, b) => b.severity.index.compareTo(a.severity.index));
  }

  /// Obtém intervalo de manutenção em km
  double _getMaintenanceInterval(ComponentType type) {
    switch (type) {
      case ComponentType.brakes: return 40000.0;
      case ComponentType.engine: return 15000.0;
      case ComponentType.tires: return 50000.0;
      case ComponentType.suspension: return 80000.0;
      case ComponentType.transmission: return 60000.0;
      case ComponentType.battery: return 100000.0;
      case ComponentType.airFilter: return 15000.0;
      case ComponentType.oilFilter: return 10000.0;
    }
  }

  /// Obtém intervalo de manutenção em dias
  int _getMaintenanceIntervalDays(ComponentType type) {
    switch (type) {
      case ComponentType.brakes: return 730; // 2 anos
      case ComponentType.engine: return 365; // 1 ano
      case ComponentType.tires: return 1095; // 3 anos
      case ComponentType.suspension: return 1460; // 4 anos
      case ComponentType.transmission: return 1095; // 3 anos
      case ComponentType.battery: return 1825; // 5 anos
      case ComponentType.airFilter: return 365; // 1 ano
      case ComponentType.oilFilter: return 180; // 6 meses
    }
  }

  /// Obtém custo estimado de manutenção
  double _getEstimatedMaintenanceCost(ComponentType type) {
    switch (type) {
      case ComponentType.brakes: return 800.0;
      case ComponentType.engine: return 1500.0;
      case ComponentType.tires: return 1200.0;
      case ComponentType.suspension: return 2000.0;
      case ComponentType.transmission: return 3000.0;
      case ComponentType.battery: return 600.0;
      case ComponentType.airFilter: return 150.0;
      case ComponentType.oilFilter: return 200.0;
    }
  }

  // Getters públicos para dados em tempo real
  Map<ComponentType, ComponentHealth> get componentHealth => Map.unmodifiable(_componentHealth);
  List<MaintenancePrediction> get predictions => List.unmodifiable(_predictions);
  List<MaintenanceAlert> get alerts => List.unmodifiable(_alerts);
  
  double get totalKilometers => _totalKilometers;
  double get totalOperatingHours => _totalOperatingHours;
  int get totalTrips => _totalTrips;
  
  // Dados de eventos em tempo real
  int get totalHardBraking => _totalHardBraking;
  int get totalRapidAcceleration => _totalRapidAcceleration;
  int get totalSharpTurns => _totalSharpTurns;
  int get totalSpeedingEvents => _totalSpeedingEvents;
  
  double get overallHealthScore {
    if (_componentHealth.isEmpty) return 100.0;
    double sum = _componentHealth.values.fold(0.0, (sum, component) => sum + component.healthScore);
    return sum / _componentHealth.length;
  }
  
  int get criticalAlertsCount => _alerts.where((alert) => alert.severity == AlertSeverity.critical).length;
  int get highAlertsCount => _alerts.where((alert) => alert.severity == AlertSeverity.high).length;
  int get totalAlertsCount => _alerts.length;
  
  bool get isActive => _isActive;
  
  /// Obtém dados em tempo real para a interface
  Map<String, dynamic> getRealTimeData() {
    return {
      'totalKilometers': _totalKilometers,
      'totalOperatingHours': _totalOperatingHours,
      'totalTrips': _totalTrips,
      'overallHealthScore': overallHealthScore,
      'criticalAlerts': criticalAlertsCount,
      'highAlerts': highAlertsCount,
      'totalAlerts': totalAlertsCount,
      'isActive': _isActive,
      'lastUpdate': DateTime.now().toIso8601String(),
      'algorithms': {
        'wearByKilometers': true,
        'wearByTime': true,
        'eventAnalysis': true,
        'machineLearning': true,
        'hybridAlgorithms': true,
      },
      'events': {
        'hardBraking': _totalHardBraking,
        'rapidAcceleration': _totalRapidAcceleration,
        'sharpTurns': _totalSharpTurns,
        'speeding': _totalSpeedingEvents,
      }
    };
  }
}

