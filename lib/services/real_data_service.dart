import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/location_data.dart';
import '../models/trip.dart';
import '../models/telematics_event.dart';
import 'location_service.dart';
import 'database_service.dart';
import 'geocoding_service.dart';
import 'telematics_analyzer.dart';
import 'advanced_telematics_analyzer.dart';
import 'real_time_notifier.dart';
import 'hybrid_trip_detection_service.dart';

/// Serviço responsável por coletar e processar dados reais do dispositivo
/// Agora integrado com sistema híbrido inteligente de detecção de viagens
class RealDataService extends ChangeNotifier {
  static final RealDataService _instance = RealDataService._internal();
  factory RealDataService() => _instance;
  
  RealDataService._internal() {
    // Iniciar coleta de dados automaticamente quando o serviço é criado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      startDataCollection();
    });
  }

  // Serviços auxiliares
  final LocationService _locationService = LocationService();
  final DatabaseService _databaseService = DatabaseService();
  final GeocodingService _geocodingService = GeocodingService();
  final TelematicsAnalyzer _telematicsAnalyzer = TelematicsAnalyzer();
  final AdvancedTelematicsAnalyzer _advancedTelematicsAnalyzer = AdvancedTelematicsAnalyzer();
  final RealTimeNotifier _realTimeNotifier = RealTimeNotifier();
  final HybridTripDetectionService _hybridDetection = HybridTripDetectionService();

  // Estado atual
  bool _isCollecting = false;
  LocationData? _lastLocation;
  Trip? _currentTrip;
  DateTime? _tripStartTime;
  
  // Dados acumulados
  double _totalDistance = 0.0;
  double _maxSpeed = 0.0;
  int _eventCount = 0;
  List<LocationData> _tripLocations = [];
  List<TelematicsEvent> _events = [];
  
  // Subscriptions
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<LocationData>? _locationSubscription;
  
  // Dados de aceleração para detectar eventos
  List<double> _accelerationHistory = [];
  
  // Thresholds para detecção de eventos
  static const double _hardBrakingThreshold = -4.0; // m/s²
  static const double _rapidAccelerationThreshold = 3.0; // m/s²
  static const double _sharpTurnThreshold = 2.5; // rad/s
  static const double _speedingThreshold = 80.0; // km/h (ajustar conforme necessário)
  
  // Getters
  bool get isCollecting => _isCollecting;
  Trip? get currentTrip => _currentTrip;
  double get totalDistance => _totalDistance;
  double get maxSpeed => _maxSpeed;
  int get eventCount => _eventCount;
  int get tripCount => _tripCount;
  
  int _tripCount = 0;
  double _averageScore = 100.0;

  /// Inicia a coleta de dados reais com sistema híbrido
  Future<void> startDataCollection() async {
    if (_isCollecting) return;
    
    try {
      debugPrint('🚀 Iniciando coleta de dados reais com sistema híbrido...');
      
      // Inicializar serviço de localização
      await _locationService.initialize();
      await _locationService.startTracking();
      
      // Inicializar sistema híbrido
      await _hybridDetection.initialize();
      
      // Configurar callbacks do sistema híbrido
      _setupHybridCallbacks();
      
      // Iniciar notificador em tempo real
      _realTimeNotifier.start();
      
      _isCollecting = true;
      
      // Configurar listeners de sensores
      _setupSensorListeners();
      
      // Configurar listener de localização
      _setupLocationListener();
      
      debugPrint('✅ Coleta de dados reais iniciada com sistema híbrido');
      notifyListeners();
      
    } catch (e) {
      debugPrint('❌ Erro ao iniciar coleta de dados: $e');
    }
  }

  /// Configura callbacks do sistema híbrido
  void _setupHybridCallbacks() {
    _hybridDetection.onTripStarted = (trip) {
      _handleHybridTripStart(trip);
    };
    
    _hybridDetection.onTripEnded = (trip) {
      _handleHybridTripEnd(trip);
    };
    
    _hybridDetection.onAnalysisUpdate = (result) {
      debugPrint('🧠 Análise híbrida: ${result.reasoning}');
    };
  }

  /// Para a coleta de dados
  Future<void> stopDataCollection() async {
    if (!_isCollecting) return;
    
    debugPrint('🛑 Parando coleta de dados...');
    
    // Finalizar viagem atual se existir
    if (_currentTrip != null) {
      await _endCurrentTrip();
    }
    
    // Cancelar subscriptions
    await _accelerometerSubscription?.cancel();
    await _gyroscopeSubscription?.cancel();
    await _locationSubscription?.cancel();
    
    // Parar serviços
    await _locationService.stopTracking();
    _realTimeNotifier.stop();
    
    _isCollecting = false;
    
    debugPrint('✅ Coleta de dados parada');
    notifyListeners();
  }

  /// Configura listeners de sensores
  void _setupSensorListeners() {
    // Listener do acelerômetro
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      _processAccelerometerData(event);
    });

    // Listener do giroscópio
    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      _processGyroscopeData(event);
    });
  }

  /// Configura listener de localização
  void _setupLocationListener() {
    _locationSubscription = _locationService.locationStream.listen((LocationData location) {
      _processLocationData(location);
    });
  }

  /// Processa dados do acelerômetro
  void _processAccelerometerData(AccelerometerEvent event) {
    if (!_isCollecting) return;
    
    // Calcular magnitude da aceleração
    double magnitude = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    
    _accelerationHistory.add(magnitude);
    if (_accelerationHistory.length > 20) {
      _accelerationHistory.removeAt(0);
    }
    
    // Detectar frenagem brusca (desaceleração súbita)
    if (_accelerationHistory.length >= 2) {
      double acceleration = _accelerationHistory.last - _accelerationHistory[_accelerationHistory.length - 2];
      
      if (acceleration < _hardBrakingThreshold) {
        _recordEvent(TelematicsEventType.hardBraking, acceleration.abs());
      } else if (acceleration > _rapidAccelerationThreshold) {
        _recordEvent(TelematicsEventType.rapidAcceleration, acceleration);
      }
    }
  }

  /// Processa dados do giroscópio
  void _processGyroscopeData(GyroscopeEvent event) {
    if (!_isCollecting) return;
    
    // Calcular magnitude da rotação
    double rotationMagnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z
    );
    
    // Detectar curvas acentuadas
    if (rotationMagnitude > _sharpTurnThreshold) {
      _recordEvent(TelematicsEventType.sharpTurn, rotationMagnitude);
    }
  }

  /// Processa dados de localização com sistema híbrido
  void _processLocationData(LocationData location) {
    if (!_isCollecting) return;
    
    debugPrint('📍 Nova localização: ${location.latitude}, ${location.longitude}, velocidade: ${(location.speed ?? 0.0).toStringAsFixed(1)} km/h');
    
    // Alimentar sistema híbrido com nova localização
    _hybridDetection.addLocationData(location);
    
    // Alimentar analisadores
    _advancedTelematicsAnalyzer.addLocationData(location);
    
    // Se há viagem ativa, processar dados
    if (_currentTrip != null) {
      _updateTripData(location);
    }
    
    _lastLocation = location;
    
    // NOTIFICAR SEMPRE para atualização em tempo real
    notifyListeners();
    
    // Notificar especificamente sobre localização
    _realTimeNotifier.notifyLocationUpdate();
  }

  /// Manipula início de viagem detectado pelo sistema híbrido
  void _handleHybridTripStart(Trip trip) async {
    if (_currentTrip != null) return; // Já há viagem ativa
    
    debugPrint('🚗 VIAGEM INICIADA PELO SISTEMA HÍBRIDO');
    
    _tripStartTime = DateTime.now();
    _totalDistance = 0.0;
    _maxSpeed = 0.0;
    _eventCount = 0;
    _tripLocations = [];
    _events = [];
    
    // Resetar analisadores
    _advancedTelematicsAnalyzer.reset();
    
    if (_lastLocation != null) {
      _tripLocations.add(_lastLocation!);
      
      // Obter endereço de início da viagem
      String startAddress = 'Obtendo endereço...';
      try {
        startAddress = await _geocodingService.getSimpleAddress(
          _lastLocation!.latitude, 
          _lastLocation!.longitude
        );
      } catch (e) {
        debugPrint('❌ Erro ao obter endereço de início: $e');
      }
      
      _currentTrip = Trip(
        id: DateTime.now().millisecondsSinceEpoch,
        userId: 1,
        startTime: _tripStartTime!,
        startLatitude: _lastLocation!.latitude,
        startLongitude: _lastLocation!.longitude,
        endTime: null,
        endLatitude: null,
        endLongitude: null,
        distance: 0.0,
        duration: 0,
        maxSpeed: 0.0,
        safetyScore: 100,
        startAddress: startAddress,
        endAddress: null,
      );
      
      debugPrint('✅ Viagem iniciada: ${_currentTrip!.id} em $startAddress');
    }
    
    notifyListeners();
  }

  /// Manipula fim de viagem detectado pelo sistema híbrido
  void _handleHybridTripEnd(Trip trip) async {
    if (_currentTrip == null) return; // Não há viagem ativa
    
    debugPrint('🏁 VIAGEM FINALIZADA PELO SISTEMA HÍBRIDO');
    
    await _endCurrentTrip();
  }

  /// Atualiza dados da viagem atual
  void _updateTripData(LocationData location) {
    if (_currentTrip == null || _tripLocations.isEmpty) return;
    
    LocationData lastLocation = _tripLocations.last;
    
    // Calcular distância incremental
    double distance = _calculateDistance(
      lastLocation.latitude, lastLocation.longitude,
      location.latitude, location.longitude
    );
    
    // Filtrar movimentos muito pequenos (ruído GPS)
    if (distance > 0.01) { // Mínimo 10 metros
      _totalDistance += distance;
      _tripLocations.add(location);
      
      // Atualizar velocidade máxima
      if ((location.speed ?? 0.0) > _maxSpeed) {
        _maxSpeed = location.speed ?? 0.0;
      }
    }
    
    // NOTIFICAR SEMPRE para atualização em tempo real
    notifyListeners();
    
    // Notificar especificamente sobre viagem
    _realTimeNotifier.notifyTripUpdate();
  }

  /// Finaliza a viagem atual
  Future<void> _endCurrentTrip() async {
    if (_currentTrip == null || _lastLocation == null) return;
    
    debugPrint('🏁 Finalizando viagem...');
    
    DateTime endTime = DateTime.now();
    int duration = endTime.difference(_currentTrip!.startTime).inMinutes;
    
    // Calcular score de segurança usando analisador avançado
    double safetyScore = _advancedTelematicsAnalyzer.calculateSafetyScore(
      distance: _totalDistance,
      durationMinutes: duration,
    );
    
    // Obter endereço de fim da viagem
    String endAddress = 'Obtendo endereço...';
    try {
      endAddress = await _geocodingService.getSimpleAddress(
        _lastLocation!.latitude, 
        _lastLocation!.longitude
      );
    } catch (e) {
      debugPrint('❌ Erro ao obter endereço de fim: $e');
    }
    
    // Atualizar viagem
    _currentTrip = Trip(
      id: _currentTrip!.id,
      userId: _currentTrip!.userId,
      startTime: _currentTrip!.startTime,
      startLatitude: _currentTrip!.startLatitude,
      startLongitude: _currentTrip!.startLongitude,
      endTime: endTime,
      endLatitude: _lastLocation!.latitude,
      endLongitude: _lastLocation!.longitude,
      distance: _totalDistance,
      duration: duration,
      maxSpeed: _maxSpeed,
      safetyScore: safetyScore.round().toDouble(),
      startAddress: _currentTrip!.startAddress,
      endAddress: endAddress,
    );
    
    // Salvar no banco de dados
    try {
      await _databaseService.insertTrip(_currentTrip!);
      _tripCount++;
      
      // Atualizar score médio
      _updateAverageScore(safetyScore);
      
      debugPrint('✅ Viagem salva: ${_totalDistance.toStringAsFixed(2)} km, Score: ${safetyScore.round()}');
      debugPrint('📍 De: ${_currentTrip!.startAddress} → Para: $endAddress');
    } catch (e) {
      debugPrint('❌ Erro ao salvar viagem: $e');
    }
    
    _currentTrip = null;
    notifyListeners();
  }

  /// Registra um evento telemático
  void _recordEvent(TelematicsEventType type, double value) {
    if (_currentTrip == null || _lastLocation == null) return;
    
    TelematicsEvent event = TelematicsEvent(
      id: DateTime.now().millisecondsSinceEpoch,
      tripId: _currentTrip!.id!,
      userId: _currentTrip!.userId,
      eventType: type,
      timestamp: DateTime.now(),
      latitude: _lastLocation!.latitude,
      longitude: _lastLocation!.longitude,
      severity: value,
    );
    
    _events.add(event);
    _eventCount++;
    
    debugPrint('⚠️ Evento detectado: ${type.toString()}, valor: ${value.toStringAsFixed(2)}');
    
    // NOTIFICAR SEMPRE
    notifyListeners();
  }

  /// Calcula distância entre dois pontos usando fórmula de Haversine
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Raio da Terra em km
    
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);
    
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  /// Converte graus para radianos
  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Atualiza score médio
  void _updateAverageScore(double newScore) {
    _averageScore = ((_averageScore * (_tripCount - 1)) + newScore) / _tripCount;
  }

  /// Obtém estatísticas gerais (dados do banco + tempo real)
  Future<Map<String, dynamic>> getGeneralStats() async {
    try {
      // Obter estatísticas do banco SQLite
      final dbStats = await _databaseService.getTripStatistics();
      final eventCounts = await _databaseService.getTelematicsEventCounts();
      final allTrips = await _databaseService.getTrips();
      
      // Calcular velocidade máxima de todas as viagens
      double maxSpeedFromDB = 0.0;
      double totalTimeFromDB = 0.0;
      
      for (final trip in allTrips) {
        if ((trip.maxSpeed ?? 0.0) > maxSpeedFromDB) {
          maxSpeedFromDB = trip.maxSpeed ?? 0.0;
        }
        totalTimeFromDB += (trip.duration ?? 0.0);
      }
      
      return {
        // Dados persistentes do banco SQLite
        'totalTrips': dbStats['total_trips'] ?? 0,
        'totalDistance': dbStats['total_distance'] ?? 0.0,
        'averageScore': dbStats['avg_safety_score'] ?? 100.0,
        'totalEvents': eventCounts.values.fold(0, (sum, count) => sum + count),
        'maxSpeed': maxSpeedFromDB,
        'totalTime': totalTimeFromDB,
        
        // Contadores de eventos específicos
        'hardBrakingCount': eventCounts['hardBraking'] ?? 0,
        'rapidAccelerationCount': eventCounts['rapidAcceleration'] ?? 0,
        'sharpTurnCount': eventCounts['sharpTurn'] ?? 0,
        'speedingCount': eventCounts['speeding'] ?? 0,
        
        // Estado atual em tempo real
        'isCollecting': _isCollecting,
        'currentTrip': _currentTrip,
        'hybridDetectionActive': _hybridDetection.isInitialized,
        'hybridState': _hybridDetection.state.toString(),
        
        // Dados da sessão atual (para viagem em andamento)
        'sessionDistance': _totalDistance,
        'sessionMaxSpeed': _maxSpeed,
        'sessionEventCount': _eventCount,
      };
    } catch (e) {
      debugPrint('❌ Erro ao obter estatísticas: $e');
      // Fallback para dados em memória
      return {
        'totalTrips': _tripCount,
        'totalDistance': _totalDistance,
        'averageScore': _averageScore,
        'totalEvents': _eventCount,
        'maxSpeed': _maxSpeed,
        'totalTime': 0.0,
        'hardBrakingCount': 0,
        'rapidAccelerationCount': 0,
        'sharpTurnCount': 0,
        'speedingCount': 0,
        'isCollecting': _isCollecting,
        'currentTrip': _currentTrip,
        'hybridDetectionActive': _hybridDetection.isInitialized,
        'hybridState': _hybridDetection.state.toString(),
        'sessionDistance': _totalDistance,
        'sessionMaxSpeed': _maxSpeed,
        'sessionEventCount': _eventCount,
      };
    }
  }

  /// Obtém localização atual (GPS em tempo real)
  LocationData? getCurrentLocation() {
    // Se estamos coletando dados, retornar a última localização
    if (_isCollecting && _lastLocation != null) {
      return _lastLocation;
    }
    
    // Se não estamos coletando, tentar obter localização atual
    if (!_isCollecting) {
      _requestCurrentLocation();
    }
    
    return _lastLocation;
  }
  
  /// Solicita localização atual do GPS
  Future<void> _requestCurrentLocation() async {
    try {
      final location = await _locationService.getCurrentLocation();
      if (location != null) {
        _lastLocation = location;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Erro ao obter localização atual: $e');
    }
  }
  
  /// Força atualização da localização atual
  Future<LocationData?> forceLocationUpdate() async {
    try {
      final location = await _locationService.getCurrentLocation();
      if (location != null) {
        _lastLocation = location;
        notifyListeners();
        return location;
      }
    } catch (e) {
      debugPrint('❌ Erro ao forçar atualização de localização: $e');
    }
    return _lastLocation;
  }
}

