import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
// import '../models/vehicle.dart'; // Arquivo não existe
import '../models/component_health.dart';
import '../models/location_data.dart';
import '../models/telematics_event.dart';
import 'fused_location_service.dart';
import 'location_cache_service.dart';
import 'enhanced_location_service.dart';
import 'telematics_analyzer.dart';
import 'database_service.dart';
import '../trip_manager.dart';

/// Tipos de alertas de manutenção
enum MaintenanceAlertType {
  info,
  warning,
  critical,
  urgent,
}

/// Alerta de manutenção
class MaintenanceAlert {
  final String id;
  final String vehicleId;
  final String componentId;
  final MaintenanceAlertType type;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime? estimatedDate;
  final double? estimatedKm;
  final double confidence;
  final Map<String, dynamic> metadata;

  MaintenanceAlert({
    required this.id,
    required this.vehicleId,
    required this.componentId,
    required this.type,
    required this.title,
    required this.description,
    required this.createdAt,
    this.estimatedDate,
    this.estimatedKm,
    required this.confidence,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicleId': vehicleId,
    'componentId': componentId,
    'type': type.toString().split('.').last,
    'title': title,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'estimatedDate': estimatedDate?.toIso8601String(),
    'estimatedKm': estimatedKm,
    'confidence': confidence,
    'metadata': metadata,
  };

  factory MaintenanceAlert.fromJson(Map<String, dynamic> json) => MaintenanceAlert(
    id: json['id'],
    vehicleId: json['vehicleId'],
    componentId: json['componentId'],
    type: MaintenanceAlertType.values.firstWhere(
      (e) => e.toString().split('.').last == json['type'],
    ),
    title: json['title'],
    description: json['description'],
    createdAt: DateTime.parse(json['createdAt']),
    estimatedDate: json['estimatedDate'] != null ? DateTime.parse(json['estimatedDate']) : null,
    estimatedKm: json['estimatedKm']?.toDouble(),
    confidence: json['confidence']?.toDouble() ?? 0.0,
    metadata: json['metadata'] ?? {},
  );
}

/// Serviço de manutenção preditiva otimizado com dados em tempo real
class PredictiveMaintenanceService {
  static final PredictiveMaintenanceService _instance = PredictiveMaintenanceService._internal();
  factory PredictiveMaintenanceService() => _instance;
  PredictiveMaintenanceService._internal();

  bool _isInitialized = false;
  bool _realTimeProcessingEnabled = false;

  // Serviços integrados
  final FusedLocationService _fusedLocationService = FusedLocationService();
  final LocationCacheService _cacheService = LocationCacheService();
  final EnhancedLocationService _enhancedLocationService = EnhancedLocationService();
  final TelematicsAnalyzer _telematicsAnalyzer = TelematicsAnalyzer();
  final DatabaseService _databaseService = DatabaseService();
  final TripManager _tripManager = TripManager();

  // Controle de processamento em tempo real
  Timer? _realTimeTimer;
  StreamSubscription? _locationSubscription;
  StreamSubscription? _telematicsSubscription;

  // Cache de dados
  final Map<String, Vehicle> _vehicleCache = {};
  final Map<String, List<VehicleComponent>> _componentCache = {};
  final Map<String, List<MaintenanceAlert>> _alertCache = {};

  // Estatísticas
  int _totalPredictions = 0;
  int _accuratePredictions = 0;
  DateTime? _lastProcessingTime;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get realTimeProcessingEnabled => _realTimeProcessingEnabled;
  int get totalPredictions => _totalPredictions;
  double get predictionAccuracy => _totalPredictions > 0 ? _accuratePredictions / _totalPredictions : 0.0;
  DateTime? get lastProcessingTime => _lastProcessingTime;

  /// Inicializa o serviço de manutenção preditiva
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Inicializar serviços dependentes
      await _fusedLocationService.initialize();
      await _cacheService.initialize();
      await _enhancedLocationService.initialize();
      await _telematicsAnalyzer.initialize();
      await _databaseService.initialize();
      await _tripManager.initialize();

      // Carregar dados do cache
      await _loadCachedData();

      // Configurar processamento em tempo real
      await _setupRealTimeProcessing();

      _isInitialized = true;
      debugPrint('PredictiveMaintenanceService: Inicializado com dados em tempo real');

    } catch (e) {
      debugPrint('Erro ao inicializar PredictiveMaintenanceService: $e');
      rethrow;
    }
  }

  /// Configura processamento em tempo real
  Future<void> _setupRealTimeProcessing() async {
    try {
      // Timer para processamento periódico
      _realTimeTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
        if (_realTimeProcessingEnabled) {
          _processRealTimeData();
        }
      });

      // Listener de localização em tempo real
      _locationSubscription = _enhancedLocationService.locationStream.listen(
        (locationData) {
          if (_realTimeProcessingEnabled && locationData != null) {
            _processLocationUpdate(locationData);
          }
        },
        onError: (error) {
          debugPrint('Erro no stream de localização: $error');
        },
      );

      // Listener de eventos telemáticos
      _telematicsSubscription = _telematicsAnalyzer.eventStream.listen(
        (event) {
          if (_realTimeProcessingEnabled) {
            _processTelematicsEvent(event);
          }
        },
        onError: (error) {
          debugPrint('Erro no stream de telemática: $error');
        },
      );

      debugPrint('PredictiveMaintenanceService: Processamento em tempo real configurado');

    } catch (e) {
      debugPrint('Erro ao configurar processamento em tempo real: $e');
    }
  }

  /// Carrega dados do cache
  Future<void> _loadCachedData() async {
    try {
      // Carregar veículos
      final vehicles = await _databaseService.getAllVehicles();
      for (final vehicle in vehicles) {
        _vehicleCache[vehicle.id] = vehicle;
      }

      // Carregar componentes
      for (final vehicleId in _vehicleCache.keys) {
        final components = await _databaseService.getVehicleComponents(vehicleId);
        _componentCache[vehicleId] = components;
      }

      // Carregar alertas ativos
      for (final vehicleId in _vehicleCache.keys) {
        final alerts = await _databaseService.getActiveAlerts(vehicleId);
        _alertCache[vehicleId] = alerts;
      }

      debugPrint('PredictiveMaintenanceService: Dados carregados do cache');

    } catch (e) {
      debugPrint('Erro ao carregar dados do cache: $e');
    }
  }

  /// Processa dados em tempo real
  Future<void> _processRealTimeData() async {
    try {
      _lastProcessingTime = DateTime.now();

      // Processar cada veículo
      for (final vehicle in _vehicleCache.values) {
        await _processVehicleRealTime(vehicle);
      }

      // Sincronizar com cache
      await _cacheService.syncToDatabase();

      debugPrint('PredictiveMaintenanceService: Processamento em tempo real concluído');

    } catch (e) {
      debugPrint('Erro no processamento em tempo real: $e');
    }
  }

  /// Processa veículo em tempo real
  Future<void> _processVehicleRealTime(Vehicle vehicle) async {
    try {
      // Obter dados atuais do veículo
      final currentLocation = await _fusedLocationService.getCurrentLocation();
      final tripStats = await _tripManager.getManagerStats();
      final telematicsEvents = await _telematicsAnalyzer.getRecentEvents(
        hours: 24,
        vehicleId: vehicle.id,
      );

      // Atualizar quilometragem
      final totalKm = tripStats['totalDistance'] ?? 0.0;
      if (totalKm > vehicle.currentMileage) {
        vehicle.currentMileage = totalKm;
        await _databaseService.updateVehicle(vehicle);
      }

      // Processar componentes
      final components = _componentCache[vehicle.id] ?? [];
      for (final component in components) {
        await _processComponentRealTime(vehicle, component, telematicsEvents);
      }

    } catch (e) {
      debugPrint('Erro ao processar veículo ${vehicle.id}: $e');
    }
  }

  /// Processa componente em tempo real
  Future<void> _processComponentRealTime(
    Vehicle vehicle,
    VehicleComponent component,
    List<TelematicsEvent> events,
  ) async {
    try {
      // Calcular desgaste baseado em quilometragem
      final kmWear = _calculateKilometerWear(vehicle, component);

      // Calcular desgaste baseado em eventos
      final eventWear = _calculateEventWear(component, events);

      // Calcular desgaste baseado no tempo
      final timeWear = _calculateTimeWear(component);

      // Combinar desgastes com pesos otimizados
      final totalWear = (kmWear * 0.5) + (eventWear * 0.3) + (timeWear * 0.2);

      // Atualizar saúde do componente
      final newHealth = math.max(0.0, component.currentHealth - totalWear);
      if ((component.currentHealth - newHealth).abs() > 0.01) {
        component.currentHealth = newHealth;
        component.lastUpdated = DateTime.now();
        await _databaseService.updateVehicleComponent(component);
      }

      // Verificar se precisa gerar alerta
      await _checkMaintenanceAlert(vehicle, component);

    } catch (e) {
      debugPrint('Erro ao processar componente ${component.id}: $e');
    }
  }

  /// Calcula desgaste baseado em quilometragem
  double _calculateKilometerWear(Vehicle vehicle, VehicleComponent component) {
    final kmSinceLastUpdate = vehicle.currentMileage - component.lastKnownMileage;
    if (kmSinceLastUpdate <= 0) return 0.0;

    // Taxa de desgaste por km baseada no tipo de componente
    double wearRatePerKm;
    switch (component.type) {
      case ComponentType.brakes:
        wearRatePerKm = 0.001; // 0.1% por 100km
        break;
      case ComponentType.tires:
        wearRatePerKm = 0.0008; // 0.08% por 100km
        break;
      case ComponentType.engine:
        wearRatePerKm = 0.0002; // 0.02% por 100km
        break;
      case ComponentType.transmission:
        wearRatePerKm = 0.0001; // 0.01% por 100km
        break;
      case ComponentType.suspension:
        wearRatePerKm = 0.0003; // 0.03% por 100km
        break;
      case ComponentType.battery:
        wearRatePerKm = 0.0001; // 0.01% por 100km
        break;
      case ComponentType.filters:
        wearRatePerKm = 0.002; // 0.2% por 100km
        break;
      case ComponentType.fluids:
        wearRatePerKm = 0.0015; // 0.15% por 100km
        break;
    }

    final wear = kmSinceLastUpdate * wearRatePerKm;
    component.lastKnownMileage = vehicle.currentMileage;

    return math.min(wear, 0.1); // Máximo 10% por atualização
  }

  /// Calcula desgaste baseado em eventos telemáticos
  double _calculateEventWear(VehicleComponent component, List<TelematicsEvent> events) {
    if (events.isEmpty) return 0.0;

    double totalWear = 0.0;

    for (final event in events) {
      double eventWear = 0.0;

      switch (component.type) {
        case ComponentType.brakes:
          if (event.type == TelematicsEventType.hardBraking) {
            eventWear = 0.005 * event.severity; // 0.5% por evento severo
          }
          break;
        case ComponentType.tires:
          if (event.type == TelematicsEventType.sharpTurn ||
              event.type == TelematicsEventType.hardBraking ||
              event.type == TelematicsEventType.rapidAcceleration) {
            eventWear = 0.003 * event.severity; // 0.3% por evento severo
          }
          break;
        case ComponentType.engine:
          if (event.type == TelematicsEventType.rapidAcceleration ||
              event.type == TelematicsEventType.highGForce) {
            eventWear = 0.002 * event.severity; // 0.2% por evento severo
          }
          break;
        case ComponentType.transmission:
          if (event.type == TelematicsEventType.rapidAcceleration) {
            eventWear = 0.001 * event.severity; // 0.1% por evento severo
          }
          break;
        case ComponentType.suspension:
          if (event.type == TelematicsEventType.highGForce ||
              event.type == TelematicsEventType.sharpTurn) {
            eventWear = 0.004 * event.severity; // 0.4% por evento severo
          }
          break;
        default:
          eventWear = 0.001 * event.severity; // Desgaste genérico
      }

      totalWear += eventWear;
    }

    return math.min(totalWear, 0.05); // Máximo 5% por atualização
  }

  /// Calcula desgaste baseado no tempo
  double _calculateTimeWear(VehicleComponent component) {
    final daysSinceLastUpdate = DateTime.now().difference(component.lastUpdated).inDays;
    if (daysSinceLastUpdate <= 0) return 0.0;

    // Taxa de desgaste por dia baseada no tipo de componente
    double wearRatePerDay;
    switch (component.type) {
      case ComponentType.battery:
        wearRatePerDay = 0.0003; // 0.03% por dia
        break;
      case ComponentType.fluids:
        wearRatePerDay = 0.0002; // 0.02% por dia
        break;
      case ComponentType.filters:
        wearRatePerDay = 0.0001; // 0.01% por dia
        break;
      default:
        wearRatePerDay = 0.00005; // 0.005% por dia para outros componentes
    }

    final wear = daysSinceLastUpdate * wearRatePerDay;
    return math.min(wear, 0.02); // Máximo 2% por atualização
  }

  /// Verifica se precisa gerar alerta de manutenção
  Future<void> _checkMaintenanceAlert(Vehicle vehicle, VehicleComponent component) async {
    try {
      MaintenanceAlertType? alertType;
      String? title;
      String? description;
      double? estimatedKm;
      DateTime? estimatedDate;

      // Determinar tipo de alerta baseado na saúde
      if (component.currentHealth <= 0.1) {
        alertType = MaintenanceAlertType.urgent;
        title = 'Manutenção URGENTE - ${component.name}';
        description = 'Componente em estado crítico. Manutenção imediata necessária.';
      } else if (component.currentHealth <= 0.2) {
        alertType = MaintenanceAlertType.critical;
        title = 'Manutenção CRÍTICA - ${component.name}';
        description = 'Componente próximo ao fim da vida útil. Agende manutenção em breve.';
      } else if (component.currentHealth <= 0.4) {
        alertType = MaintenanceAlertType.warning;
        title = 'Atenção - ${component.name}';
        description = 'Componente apresentando desgaste. Monitore de perto.';
      } else if (component.currentHealth <= 0.6) {
        alertType = MaintenanceAlertType.info;
        title = 'Informação - ${component.name}';
        description = 'Componente em desgaste normal. Planeje manutenção futura.';
      }

      // Calcular estimativas se alerta for necessário
      if (alertType != null) {
        final predictions = await _calculateMaintenancePredictions(vehicle, component);
        estimatedKm = predictions['estimatedKm'];
        estimatedDate = predictions['estimatedDate'];

        // Verificar se já existe alerta similar
        final existingAlerts = _alertCache[vehicle.id] ?? [];
        final hasExistingAlert = existingAlerts.any(
          (alert) => alert.componentId == component.id && alert.type == alertType,
        );

        if (!hasExistingAlert) {
          // Criar novo alerta
          final alert = MaintenanceAlert(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            vehicleId: vehicle.id,
            componentId: component.id,
            type: alertType,
            title: title!,
            description: description!,
            createdAt: DateTime.now(),
            estimatedDate: estimatedDate,
            estimatedKm: estimatedKm,
            confidence: _calculatePredictionConfidence(component),
            metadata: {
              'currentHealth': component.currentHealth,
              'componentType': component.type.toString(),
              'lastMileage': component.lastKnownMileage,
            },
          );

          // Salvar alerta
          await _databaseService.saveMaintenanceAlert(alert);

          // Atualizar cache
          if (_alertCache[vehicle.id] == null) {
            _alertCache[vehicle.id] = [];
          }
          _alertCache[vehicle.id]!.add(alert);

          debugPrint('Alerta de manutenção criado: ${alert.title}');
        }
      }

    } catch (e) {
      debugPrint('Erro ao verificar alerta de manutenção: $e');
    }
  }

  /// Calcula predições de manutenção
  Future<Map<String, dynamic>> _calculateMaintenancePredictions(
    Vehicle vehicle,
    VehicleComponent component,
  ) async {
    try {
      // Obter estatísticas de uso
      final tripStats = await _tripManager.getManagerStats();
      final avgKmPerDay = (tripStats['averageDailyDistance'] ?? 50.0) as double;

      // Calcular quilometragem restante até manutenção
      final healthRemaining = component.currentHealth;
      final kmToMaintenance = _estimateKmToMaintenance(component, healthRemaining);

      // Calcular data estimada
      final daysToMaintenance = (kmToMaintenance / avgKmPerDay).ceil();
      final estimatedDate = DateTime.now().add(Duration(days: daysToMaintenance));

      // Quilometragem estimada
      final estimatedKm = vehicle.currentMileage + kmToMaintenance;

      return {
        'estimatedKm': estimatedKm,
        'estimatedDate': estimatedDate,
        'daysRemaining': daysToMaintenance,
        'kmRemaining': kmToMaintenance,
      };

    } catch (e) {
      debugPrint('Erro ao calcular predições: $e');
      return {};
    }
  }

  /// Estima quilometragem até manutenção
  double _estimateKmToMaintenance(VehicleComponent component, double healthRemaining) {
    // Taxa de desgaste por km baseada no histórico
    double wearRatePerKm;
    switch (component.type) {
      case ComponentType.brakes:
        wearRatePerKm = 0.001;
        break;
      case ComponentType.tires:
        wearRatePerKm = 0.0008;
        break;
      case ComponentType.engine:
        wearRatePerKm = 0.0002;
        break;
      case ComponentType.transmission:
        wearRatePerKm = 0.0001;
        break;
      case ComponentType.suspension:
        wearRatePerKm = 0.0003;
        break;
      case ComponentType.battery:
        wearRatePerKm = 0.0001;
        break;
      case ComponentType.filters:
        wearRatePerKm = 0.002;
        break;
      case ComponentType.fluids:
        wearRatePerKm = 0.0015;
        break;
    }

    // Calcular km restantes (deixar 10% de margem de segurança)
    final targetHealth = 0.1;
    final healthToConsume = healthRemaining - targetHealth;
    final kmRemaining = healthToConsume / wearRatePerKm;

    return math.max(0.0, kmRemaining);
  }

  /// Calcula confiança da predição
  double _calculatePredictionConfidence(VehicleComponent component) {
    // Fatores que afetam a confiança
    final dataAge = DateTime.now().difference(component.lastUpdated).inDays;
    final healthLevel = component.currentHealth;

    // Confiança base
    double confidence = 0.8;

    // Reduzir confiança se dados são antigos
    if (dataAge > 7) {
      confidence -= 0.1;
    }
    if (dataAge > 30) {
      confidence -= 0.2;
    }

    // Ajustar confiança baseada na saúde
    if (healthLevel < 0.2) {
      confidence += 0.1; // Mais confiança em componentes críticos
    } else if (healthLevel > 0.8) {
      confidence -= 0.1; // Menos confiança em componentes novos
    }

    return math.max(0.1, math.min(1.0, confidence));
  }

  /// Processa atualização de localização
  Future<void> _processLocationUpdate(LocationData locationData) async {
    try {
      // Atualizar estatísticas de uso em tempo real
      // Implementação futura se necessário
    } catch (e) {
      debugPrint('Erro ao processar atualização de localização: $e');
    }
  }

  /// Processa evento telemático
  Future<void> _processTelematicsEvent(TelematicsEvent event) async {
    try {
      // Processar evento em tempo real para ajuste de desgaste
      // Implementação futura se necessário
    } catch (e) {
      debugPrint('Erro ao processar evento telemático: $e');
    }
  }

  /// Habilita/desabilita processamento em tempo real
  void setRealTimeProcessing(bool enabled) {
    _realTimeProcessingEnabled = enabled;
    debugPrint('PredictiveMaintenanceService: Processamento em tempo real ${enabled ? "habilitado" : "desabilitado"}');
  }

  /// Obtém saúde de todos os componentes de um veículo
  Future<List<VehicleComponent>> getVehicleComponentHealth(String vehicleId) async {
    if (!_isInitialized) await initialize();

    try {
      // Verificar cache primeiro
      if (_componentCache.containsKey(vehicleId)) {
        return _componentCache[vehicleId]!;
      }

      // Carregar do banco se não estiver no cache
      final components = await _databaseService.getVehicleComponents(vehicleId);
      _componentCache[vehicleId] = components;
      return components;

    } catch (e) {
      debugPrint('Erro ao obter saúde dos componentes: $e');
      return [];
    }
  }

  /// Obtém alertas ativos de um veículo
  Future<List<MaintenanceAlert>> getActiveAlerts(String vehicleId) async {
    if (!_isInitialized) await initialize();

    try {
      // Verificar cache primeiro
      if (_alertCache.containsKey(vehicleId)) {
        return _alertCache[vehicleId]!;
      }

      // Carregar do banco se não estiver no cache
      final alerts = await _databaseService.getActiveAlerts(vehicleId);
      _alertCache[vehicleId] = alerts;
      return alerts;

    } catch (e) {
      debugPrint('Erro ao obter alertas ativos: $e');
      return [];
    }
  }

  /// Obtém estatísticas do serviço
  Map<String, dynamic> getServiceStatistics() {
    return {
      'isInitialized': _isInitialized,
      'realTimeProcessingEnabled': _realTimeProcessingEnabled,
      'totalPredictions': _totalPredictions,
      'predictionAccuracy': predictionAccuracy,
      'lastProcessingTime': _lastProcessingTime?.toIso8601String(),
      'vehiclesMonitored': _vehicleCache.length,
      'componentsMonitored': _componentCache.values.fold(0, (sum, list) => sum + list.length),
      'activeAlerts': _alertCache.values.fold(0, (sum, list) => sum + list.length),
    };
  }

  /// Limpa cache
  void clearCache() {
    _vehicleCache.clear();
    _componentCache.clear();
    _alertCache.clear();
    debugPrint('PredictiveMaintenanceService: Cache limpo');
  }

  /// Dispose
  void dispose() {
    _realTimeTimer?.cancel();
    _locationSubscription?.cancel();
    _telematicsSubscription?.cancel();
    clearCache();
    _isInitialized = false;
  }
}

