import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location_data.dart';

class LocationService extends ChangeNotifier {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  bool _isTracking = false;
  final StreamController<LocationData> _locationController = StreamController<LocationData>.broadcast();
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;

  bool get isTracking => _isTracking;
  Stream<LocationData> get locationStream => _locationController.stream;
  Stream<LocationData> get positionStream => _locationController.stream; // Alias para compatibilidade

  Future<void> initialize() async {
    // Verificar se o serviço de localização está habilitado
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Serviço de localização desabilitado');
    }

    // Verificar permissões
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permissão de localização negada');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permissão de localização negada permanentemente');
    }
  }

  Future<LocationData?> getCurrentPosition() async {
    return getCurrentLocation();
  }

  Future<LocationData?> getCurrentLocation() async {
    try {
      await initialize();
      
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      _lastPosition = position;
      
      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        accuracy: position.accuracy,
        speed: position.speed * 3.6, // Converter m/s para km/h
        heading: position.heading,
        timestamp: position.timestamp ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('Erro ao obter localização atual: $e');
      return null;
    }
  }

  Future<void> startTracking() async {
    if (_isTracking) return;
    
    try {
      await initialize();
      
      _isTracking = true;
      
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Atualizar a cada 5 metros
      );
      
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _lastPosition = position;
          
          final locationData = LocationData(
            latitude: position.latitude,
            longitude: position.longitude,
            altitude: position.altitude,
            accuracy: position.accuracy,
            speed: position.speed * 3.6, // Converter m/s para km/h
            heading: position.heading,
            timestamp: position.timestamp ?? DateTime.now(),
          );
          
          _locationController.add(locationData);
          notifyListeners();
        },
        onError: (error) {
          debugPrint('Erro no stream de localização: $error');
        },
      );
      
    } catch (e) {
      debugPrint('Erro ao iniciar rastreamento: $e');
      _isTracking = false;
    }
  }

  Future<void> stopTracking() async {
    _isTracking = false;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    notifyListeners();
  }

  double calculateDistance(double startLatitude, double startLongitude, 
                          double endLatitude, double endLongitude) {
    return Geolocator.distanceBetween(
      startLatitude, startLongitude, 
      endLatitude, endLongitude
    ) / 1000; // Converter metros para quilômetros
  }

  double calculateBearing(double startLatitude, double startLongitude,
                         double endLatitude, double endLongitude) {
    return Geolocator.bearingBetween(
      startLatitude, startLongitude,
      endLatitude, endLongitude
    );
  }

  Position? get lastKnownPosition => _lastPosition;

  void dispose() {
    _positionSubscription?.cancel();
    _locationController.close();
  }
}

