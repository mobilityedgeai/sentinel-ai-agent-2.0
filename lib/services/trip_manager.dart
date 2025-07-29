import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/trip.dart';
import '../models/location_data.dart';
import '../services/location_service.dart';
import '../services/telematics_analyzer.dart';
import '../services/database_service.dart';

class TripManager extends ChangeNotifier {
  static final TripManager _instance = TripManager._internal();
  factory TripManager() => _instance;
  TripManager._internal();

  final DatabaseService _databaseService = DatabaseService();
  final LocationService _locationService = LocationService();
  final TelematicsAnalyzer _telematicsAnalyzer = TelematicsAnalyzer();

  // Estado atual
  Trip? _currentTrip;
  final List<LocationData> _currentTripLocations = [];
  StreamSubscription<LocationData>? _locationSubscription;
  int? _currentUserId;
  List<Trip> _allTrips = [];

  // Callbacks
  Function(Trip)? _onTripStarted;
  Function(Trip)? _onTripEnded;
  Function(LocationData)? _onLocationUpdate;
  Function(dynamic)? _onTelematicsEvent;

  // Setters para callbacks
  set onTripStarted(Function(Trip)? callback) => _onTripStarted = callback;
  set onTripEnded(Function(Trip)? callback) => _onTripEnded = callback;
  set onLocationUpdate(Function(LocationData)? callback) => _onLocationUpdate = callback;
  set onTelematicsEvent(Function(dynamic)? callback) => _onTelematicsEvent = callback;

  // Getters
  Trip? get currentTrip => _currentTrip;
  List<LocationData> get currentTripLocations => List.unmodifiable(_currentTripLocations);
  bool get isOnTrip => _currentTrip != null;
  bool get _isOnTrip => _currentTrip != null;

  // Iniciar viagem
  Future<void> startTrip() async {
    if (_currentTrip != null) return;

    try {
      final location = await _locationService.getCurrentPosition();
      
      _currentTrip = Trip(
        id: DateTime.now().millisecondsSinceEpoch,
        userId: 1,
        startTime: DateTime.now(),
        startLatitude: location?.latitude ?? 0.0,
        startLongitude: location?.longitude ?? 0.0,
        endTime: null,
        endLatitude: null,
        endLongitude: null,
        distance: 0.0,
        duration: 0,
        maxSpeed: 0.0,
        safetyScore: 100,
      );

      // Salvar no banco
      await _databaseService.insertTrip(_currentTrip!);

      // Iniciar rastreamento de localização
      // _locationSubscription = _locationService.positionStream.listen(_handleLocationUpdate);
      // Temporariamente desabilitado até implementar stream público

      // Iniciar análise de telemática
      await _telematicsAnalyzer.startAnalysis();

      notifyListeners();
      print('Viagem iniciada: ${_currentTrip!.id}');
    } catch (e) {
      print('Erro ao iniciar viagem: $e');
    }
  }

  // Finalizar viagem
  Future<void> endTrip() async {
    if (_currentTrip == null) return;

    try {
      final location = await _locationService.getCurrentPosition();
      final endTime = DateTime.now();
      final duration = endTime.difference(_currentTrip!.startTime).inMinutes;

      // Calcular distância total
      double totalDistance = 0.0;
      for (int i = 1; i < _currentTripLocations.length; i++) {
        totalDistance += _calculateDistance(
          _currentTripLocations[i - 1],
          _currentTripLocations[i],
        );
      }

      // Calcular velocidade máxima
      double maxSpeed = 0.0;
      for (final loc in _currentTripLocations) {
        if (loc.speed != null && loc.speed! > maxSpeed) {
          maxSpeed = loc.speed!;
        }
      }

      // Atualizar viagem
      final updatedTrip = _currentTrip!.copyWith(
        endTime: endTime,
        endLatitude: location?.latitude ?? 0.0,
        endLongitude: location?.longitude ?? 0.0,
        distance: totalDistance,
        duration: duration,
        maxSpeed: maxSpeed,
        safetyScore: _telematicsAnalyzer.calculateSafetyScore().toDouble(),
      );

      // Salvar no banco
      await _databaseService.updateTrip(updatedTrip);

      // Parar análise de telemática
      await _telematicsAnalyzer.stopAnalysis();

      // Cancelar subscription
      await _locationSubscription?.cancel();
      _locationSubscription = null;

      // Limpar estado
      _currentTrip = null;
      _currentTripLocations.clear();

      notifyListeners();
      print('Viagem finalizada: ${updatedTrip.id}');
    } catch (e) {
      print('Erro ao finalizar viagem: $e');
    }
  }

  // Processar atualização de localização
  void _handleLocationUpdate(LocationData location) {
    if (_currentTrip == null) return;

    // Adicionar à lista de localizações
    _currentTripLocations.add(location);

    // Salvar no banco
    _databaseService.insertLocationData(location);

    // Processar na análise de telemática
    _telematicsAnalyzer.processLocationData(location);

    notifyListeners();
  }

  // Calcular distância entre dois pontos (fórmula de Haversine)
  double _calculateDistance(LocationData point1, LocationData point2) {
    const double earthRadius = 6371000; // metros

    final lat1Rad = point1.latitude * (pi / 180);
    final lat2Rad = point2.latitude * (pi / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);

    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final c = 2 * sqrt(a) * asin(sqrt(a));

    return earthRadius * c / 1000; // retorna em quilômetros
  }

  // Obter estatísticas da viagem atual
  Map<String, dynamic> getCurrentTripStats() {
    if (_currentTrip == null) {
      return {
        'isOnTrip': false,
        'duration': 0,
        'distance': 0.0,
        'locations': 0,
        'safetyScore': 100,
      };
    }

    final duration = DateTime.now().difference(_currentTrip!.startTime).inMinutes;
    double distance = 0.0;
    
    for (int i = 1; i < _currentTripLocations.length; i++) {
      distance += _calculateDistance(
        _currentTripLocations[i - 1],
        _currentTripLocations[i],
      );
    }

    return {
      'isOnTrip': true,
      'tripId': _currentTrip!.id,
      'duration': duration,
      'distance': distance,
      'locations': _currentTripLocations.length,
      'safetyScore': _telematicsAnalyzer.calculateSafetyScore(),
    };
  }

  /// Obter estatísticas do gerenciador de viagens
  Map<String, dynamic> getManagerStats() {
    return {
      'totalTrips': _allTrips.length,
      'currentTrip': _currentTrip?.id ?? 0,
      'isOnTrip': _isOnTrip,
      'totalDistance': _allTrips.fold(0.0, (sum, trip) => sum + (trip.distance ?? 0.0)),
      'averageScore': _allTrips.isEmpty ? 100.0 : 
        _allTrips.fold(0.0, (sum, trip) => sum + (trip.safetyScore ?? 100.0)) / _allTrips.length,
    };
  }

  /// Inicializar o gerenciador de viagens
  Future<bool> initialize(int userId) async {
    try {
      _currentUserId = userId;
      // Carregar viagens existentes do banco
      _allTrips = await _databaseService.getTripsByUser(userId);
      notifyListeners();
      return true;
    } catch (e) {
      print('Erro ao inicializar TripManager: $e');
      return false;
    }
  }

  /// Forçar início de viagem manualmente
  Future<void> forceStartTrip() async {
    if (_currentTrip == null) {
      await startTrip();
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _telematicsAnalyzer.dispose();
    super.dispose();
  }
}

