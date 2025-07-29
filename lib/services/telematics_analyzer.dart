import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/telematics_event.dart';
import '../models/location_data.dart';
import 'sensor_service.dart';
import 'database_service.dart';

class TelematicsAnalyzer extends ChangeNotifier {
  static final TelematicsAnalyzer _instance = TelematicsAnalyzer._internal();
  factory TelematicsAnalyzer() => _instance;
  TelematicsAnalyzer._internal();

  bool _isAnalyzing = false;
  final List<LocationData> _locationHistory = [];
  final StreamController<TelematicsEvent> _eventController = StreamController<TelematicsEvent>.broadcast();
  
  // Integração com serviços reais
  final SensorService _sensorService = SensorService();
  final DatabaseService _databaseService = DatabaseService();
  
  // Estatísticas de eventos
  final Map<TelematicsEventType, int> _eventCounts = {};
  final List<TelematicsEvent> _recentEvents = [];

  bool get isAnalyzing => _isAnalyzing;
  Stream<TelematicsEvent> get eventStream => _eventController.stream;
  Map<TelematicsEventType, int> get eventCounts => Map.unmodifiable(_eventCounts);
  List<TelematicsEvent> get recentEvents => List.unmodifiable(_recentEvents);

  Future<void> startAnalysis() async {
    if (_isAnalyzing) return;
    
    _isAnalyzing = true;
    
    // Configurar callback para eventos do SensorService
    _sensorService.setEventCallback(_onSensorEventDetected);
    
    // Iniciar sensores se não estiverem rodando
    if (!_sensorService.isListening) {
      await _sensorService.startListening();
    }
    
    debugPrint('TelematicsAnalyzer: Análise iniciada com sensores reais');
  }

  Future<void> stopAnalysis() async {
    _isAnalyzing = false;
    await _sensorService.stopListening();
    debugPrint('TelematicsAnalyzer: Análise parada');
  }

  // Callback para eventos detectados pelos sensores
  void _onSensorEventDetected(
    TelematicsEventType eventType, 
    double magnitude, {
    bool? mlValidated, 
    double? confidence
  }) async {
    if (!_isAnalyzing) return;
    
    try {
      // Obter localização atual (se disponível)
      LocationData? currentLocation;
      if (_locationHistory.isNotEmpty) {
        currentLocation = _locationHistory.last;
      }
      
      // Criar evento de telemática
      final event = TelematicsEvent(
        id: DateTime.now().millisecondsSinceEpoch,
        tripId: 1, // TODO: Obter trip ID atual
        userId: 1, // TODO: Obter user ID atual
        eventType: eventType,
        timestamp: DateTime.now(),
        latitude: currentLocation?.latitude ?? 0.0,
        longitude: currentLocation?.longitude ?? 0.0,
        severity: _calculateSeverity(eventType, magnitude),
        magnitude: magnitude,
        confidence: confidence,
        mlValidated: mlValidated ?? false,
      );
      
      // Salvar no banco de dados
      await _databaseService.insertTelematicsEvent(event);
      
      // Atualizar estatísticas
      _eventCounts[eventType] = (_eventCounts[eventType] ?? 0) + 1;
      _recentEvents.add(event);
      
      // Manter apenas os últimos 50 eventos
      if (_recentEvents.length > 50) {
        _recentEvents.removeAt(0);
      }
      
      // Emitir evento
      _eventController.add(event);
      
      debugPrint('Evento real detectado: ${eventType.toString().split('.').last} '
                'magnitude: ${magnitude.toStringAsFixed(2)} '
                'confiança: ${((confidence ?? 0.0) * 100).toStringAsFixed(1)}% '
                'ML: ${mlValidated ?? false}');
      
      notifyListeners();
      
    } catch (e) {
      debugPrint('Erro ao processar evento de telemática: $e');
    }
  }

  Future<void> processLocationData(LocationData locationData) async {
    if (!_isAnalyzing) return;

    _locationHistory.add(locationData);
    if (_locationHistory.length > 100) {
      _locationHistory.removeAt(0);
    }

    // Analisar dados de localização para eventos específicos
    _analyzeLocationForEvents(locationData);
  }
  
  void _analyzeLocationForEvents(LocationData currentLocation) {
    if (_locationHistory.length < 2) return;
    
    final previousLocation = _locationHistory[_locationHistory.length - 2];
    final timeDiff = currentLocation.timestamp.difference(previousLocation.timestamp).inSeconds;
    
    if (timeDiff <= 0) return;
    
    // Detectar excesso de velocidade
    final speedKmh = (currentLocation.speed ?? 0.0) * 3.6; // m/s para km/h
    if (speedKmh > 80.0) { // Limite de 80 km/h
      _onSensorEventDetected(
        TelematicsEventType.speeding, 
        speedKmh,
        confidence: 0.9,
        mlValidated: false
      );
    }
  }
  
  double _calculateSeverity(TelematicsEventType eventType, double magnitude) {
    switch (eventType) {
      case TelematicsEventType.hardBraking:
        // Severidade baseada na magnitude da desaceleração
        return math.min(10.0, magnitude / 2.0); // 0-10 scale
        
      case TelematicsEventType.rapidAcceleration:
        // Severidade baseada na magnitude da aceleração
        return math.min(10.0, magnitude / 1.5); // 0-10 scale
        
      case TelematicsEventType.sharpTurn:
        // Severidade baseada na velocidade angular
        return math.min(10.0, magnitude * 2.0); // 0-10 scale
        
      case TelematicsEventType.highGForce:
        // Severidade baseada na força G
        return math.min(10.0, magnitude / 1.5); // 0-10 scale
        
      case TelematicsEventType.speeding:
        // Severidade baseada no excesso de velocidade
        return math.min(10.0, (magnitude - 80.0) / 10.0); // 0-10 scale
        
      case TelematicsEventType.idling:
      case TelematicsEventType.phoneUsage:
        return 5.0; // Severidade média para estes eventos
    }
  }

  String _getEventDescription(TelematicsEventType type) {
    switch (type) {
      case TelematicsEventType.hardBraking:
        return 'Frenagem brusca detectada';
      case TelematicsEventType.rapidAcceleration:
        return 'Aceleração rápida detectada';
      case TelematicsEventType.sharpTurn:
        return 'Curva acentuada detectada';
      case TelematicsEventType.speeding:
        return 'Excesso de velocidade detectado';
      case TelematicsEventType.highGForce:
        return 'Força G alta detectada';
      case TelematicsEventType.idling:
        return 'Veículo parado com motor ligado detectado';
      case TelematicsEventType.phoneUsage:
        return 'Uso do telefone durante condução detectado';
    }
  }

  double calculateSafetyScore() {
    if (_recentEvents.isEmpty) return 100.0;
    
    // Calcular score baseado em eventos reais dos últimos 7 dias
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    
    final recentWeekEvents = _recentEvents.where(
      (event) => event.timestamp.isAfter(weekAgo)
    ).toList();
    
    if (recentWeekEvents.isEmpty) return 100.0;
    
    // Calcular penalidades baseadas na severidade e tipo de evento
    double totalPenalty = 0.0;
    
    for (final event in recentWeekEvents) {
      double eventPenalty = (event.severity ?? 5.0);
      
      // Multiplicadores por tipo de evento
      switch (event.eventType) {
        case TelematicsEventType.hardBraking:
          eventPenalty *= 1.5; // Penalidade alta
          break;
        case TelematicsEventType.rapidAcceleration:
          eventPenalty *= 1.3;
          break;
        case TelematicsEventType.sharpTurn:
          eventPenalty *= 1.2;
          break;
        case TelematicsEventType.highGForce:
          eventPenalty *= 2.0; // Penalidade muito alta
          break;
        case TelematicsEventType.speeding:
          eventPenalty *= 1.8;
          break;
        case TelematicsEventType.idling:
          eventPenalty *= 0.5; // Penalidade baixa
          break;
        case TelematicsEventType.phoneUsage:
          eventPenalty *= 2.5; // Penalidade muito alta
          break;
      }
      
      // Reduzir penalidade se evento foi validado por ML com alta confiança
      if (event.mlValidated == true && (event.confidence ?? 0.0) > 0.8) {
        eventPenalty *= 1.0; // Manter penalidade total
      } else if ((event.confidence ?? 1.0) < 0.6) {
        eventPenalty *= 0.5; // Reduzir penalidade para eventos de baixa confiança
      }
      
      totalPenalty += eventPenalty;
    }
    
    // Calcular score final (100 - penalidades, mínimo 0)
    final safetyScore = math.max(0.0, 100.0 - totalPenalty);
    
    return safetyScore;
  }
  
  // Método para obter estatísticas detalhadas
  Map<String, dynamic> getDetailedStatistics() {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final monthAgo = now.subtract(const Duration(days: 30));
    
    final weekEvents = _recentEvents.where(
      (event) => event.timestamp.isAfter(weekAgo)
    ).toList();
    
    final monthEvents = _recentEvents.where(
      (event) => event.timestamp.isAfter(monthAgo)
    ).toList();
    
    return {
      'totalEvents': _recentEvents.length,
      'weekEvents': weekEvents.length,
      'monthEvents': monthEvents.length,
      'safetyScore': calculateSafetyScore(),
      'eventsByType': _eventCounts,
      'averageConfidence': _recentEvents.isNotEmpty 
        ? _recentEvents.map((e) => e.confidence ?? 0.5).reduce((a, b) => a + b) / _recentEvents.length
        : 0.0,
      'mlValidatedEvents': _recentEvents.where((e) => e.mlValidated == true).length,
      'highConfidenceEvents': _recentEvents.where((e) => (e.confidence ?? 0.0) > 0.8).length,
      'sensorServiceStats': _sensorService.getConfidenceStatistics(),
    };
  }
  
  // Método para limpar histórico
  void clearHistory() {
    _recentEvents.clear();
    _eventCounts.clear();
    notifyListeners();
  }

  void dispose() {
    _eventController.close();
    super.dispose();
  }
}

