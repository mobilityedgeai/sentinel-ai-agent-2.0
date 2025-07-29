import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import '../models/trip.dart';
import '../models/location_data.dart' as models;
import '../services/database_service.dart';
import '../services/telematics_analyzer.dart';

class TripManager {
  static final TripManager _instance = TripManager._internal();
  factory TripManager() => _instance;
  TripManager._internal();

  final DatabaseService _databaseService = DatabaseService();
  final TelematicsAnalyzer _telematicsAnalyzer = TelematicsAnalyzer();
  
  Trip? _currentTrip;
  List<models.LocationData> _currentTripLocations = [];
  StreamController<Trip?> _tripController = StreamController<Trip?>.broadcast();
  
  Stream<Trip?> get tripStream => _tripController.stream;
  Trip? get currentTrip => _currentTrip;
  bool get isInTrip => _currentTrip != null;

  Future<void> startTrip(int userId) async {
    if (_currentTrip != null) {
      print('Viagem já está em andamento');
      return;
    }

    try {
      final now = DateTime.now();
      _currentTrip = Trip(
        id: now.millisecondsSinceEpoch,
        userId: userId,
        startTime: now,
        endTime: null,
        distance: 0.0,
        duration: 0,
        avgSpeed: 0.0,
        maxSpeed: 0.0,
        safetyScore: 100.0,
      );

      await _databaseService.insertTrip(_currentTrip!);
      _currentTripLocations.clear();
      _tripController.add(_currentTrip);
      
      print('Viagem iniciada: ${_currentTrip!.id}');
    } catch (e) {
      print('Erro ao iniciar viagem: $e');
    }
  }

  Future<void> endTrip() async {
    if (_currentTrip == null) {
      print('Nenhuma viagem em andamento');
      return;
    }

    try {
      final endTime = DateTime.now();
      final duration = endTime.difference(_currentTrip!.startTime).inMinutes;
      
      // Calcular estatísticas da viagem
      double totalDistance = _calculateTotalDistance();
      double averageSpeed = _calculateAverageSpeed();
      double maxSpeed = _calculateMaxSpeed();
      int safetyScore = _calculateSafetyScore();

      final completedTrip = _currentTrip!.copyWith(
        endTime: endTime,
        distance: totalDistance,
        duration: duration,
        avgSpeed: averageSpeed,
        maxSpeed: maxSpeed,
        safetyScore: safetyScore.toDouble(),
      );

      await _databaseService.updateTrip(completedTrip);
      
      _currentTrip = null;
      _currentTripLocations.clear();
      _tripController.add(null);
      
      print('Viagem finalizada: ${completedTrip.id}');
    } catch (e) {
      print('Erro ao finalizar viagem: $e');
    }
  }

  Future<void> addLocationPoint(Position position) async {
    if (_currentTrip == null) return;

    try {
      final locationData = models.LocationData(
        id: DateTime.now().millisecondsSinceEpoch,
        tripId: _currentTrip!.id!,
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        heading: position.heading,
        accuracy: position.accuracy,
        timestamp: DateTime.now(),
      );

      await _databaseService.insertLocationData(locationData);
      _currentTripLocations.add(locationData);

      print('Ponto de localização adicionado: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('Erro ao adicionar ponto de localização: $e');
    }
  }

  double _calculateTotalDistance() {
    if (_currentTripLocations.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 1; i < _currentTripLocations.length; i++) {
      final prev = _currentTripLocations[i - 1];
      final current = _currentTripLocations[i];
      
      totalDistance += Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        current.latitude,
        current.longitude,
      ) / 1000.0; // Converter para km
    }
    
    return totalDistance;
  }

  double _calculateAverageSpeed() {
    if (_currentTripLocations.isEmpty) return 0.0;

    // Como LocationData não tem campo speed, usar velocidade baseada na distância
    if (_currentTripLocations.length < 2) return 0.0;

    double totalDistance = _calculateTotalDistance();
    if (totalDistance == 0.0) return 0.0;

    final startTime = _currentTripLocations.first.timestamp;
    final endTime = _currentTripLocations.last.timestamp;
    final durationHours = endTime.difference(startTime).inMinutes / 60.0;

    return durationHours > 0 ? totalDistance / durationHours : 0.0;
  }

  double _calculateMaxSpeed() {
    // Como não temos dados de velocidade, retornar uma estimativa baseada na velocidade média
    double avgSpeed = _calculateAverageSpeed();
    return avgSpeed * 1.5; // Estimativa: velocidade máxima é 50% maior que a média
  }

  int _calculateSafetyScore() {
    // Implementação simplificada do cálculo de score
    // Em uma implementação real, isso seria baseado nos eventos de telemática
    int baseScore = 100;
    
    // Reduzir score baseado na velocidade máxima
    double maxSpeed = _calculateMaxSpeed();
    if (maxSpeed > 120) {
      baseScore -= 20;
    } else if (maxSpeed > 100) {
      baseScore -= 10;
    } else if (maxSpeed > 80) {
      baseScore -= 5;
    }

    return math.max(0, baseScore);
  }

  void dispose() {
    _tripController.close();
  }
}

