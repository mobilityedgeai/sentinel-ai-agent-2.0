import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/user.dart';
import '../models/location_data.dart';
import '../models/trip.dart';
import '../models/telematics_event.dart';
import '../models/location_point.dart';
import '../models/driving_event.dart';

class DatabaseService extends ChangeNotifier {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  User? _currentUser;
  Trip? _activeTrip;
  Map<String, dynamic> _statistics = {};

  User? get currentUser => _currentUser;
  Trip? get activeTrip => _activeTrip;
  Map<String, dynamic> get statistics => _statistics;

  Future<void> initialize() async {
    try {
      // Inicializar dados básicos
      _currentUser = await _dbHelper.getCurrentUser();
      _activeTrip = await _dbHelper.getActiveTrip();
      _statistics = await _dbHelper.getTripStatistics();
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao inicializar DatabaseService: $e');
    }
  }

  // Métodos para usuários
  Future<int> insertUser(User user) async {
    try {
      final id = await _dbHelper.insertUser(user);
      if (_currentUser == null) {
        _currentUser = user.copyWith(id: id);
        notifyListeners();
      }
      return id;
    } catch (e) {
      debugPrint('Erro ao inserir usuário: $e');
      rethrow;
    }
  }

  Future<List<User>> getAllUsers() async {
    try {
      return await _dbHelper.getAllUsers();
    } catch (e) {
      debugPrint('Erro ao obter usuários: $e');
      return [];
    }
  }

  Future<void> updateUser(User user) async {
    try {
      await _dbHelper.updateUser(user);
      if (_currentUser?.id == user.id) {
        _currentUser = user;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Erro ao atualizar usuário: $e');
      rethrow;
    }
  }

  // Métodos para viagens
  Future<List<Trip>> getTrips({
    int? userId,
    int? limit,
    int? offset,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      return await _dbHelper.getTrips(
        userId: _currentUser?.id,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      debugPrint('Erro ao obter viagens: $e');
      rethrow;
    }
  }

  Future<int> insertTrip(Trip trip) async {
    try {
      final id = await _dbHelper.insertTrip(trip);
      _activeTrip = trip.copyWith(id: id);
      notifyListeners();
      return id;
    } catch (e) {
      debugPrint('Erro ao inserir viagem: $e');
      rethrow;
    }
  }

  Future<void> updateTrip(Trip trip) async {
    try {
      await _dbHelper.updateTrip(trip);
      if (_activeTrip?.id == trip.id) {
        _activeTrip = trip;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Erro ao atualizar viagem: $e');
      rethrow;
    }
  }

  Future<void> deleteTrip(int tripId) async {
    try {
      await _dbHelper.deleteTrip(tripId);
      if (_activeTrip?.id == tripId) {
        _activeTrip = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Erro ao deletar viagem: $e');
      rethrow;
    }
  }

  // Métodos para dados de localização
  Future<int> insertLocationData(LocationData locationData) async {
    try {
      return await _dbHelper.insertLocationData(locationData);
    } catch (e) {
      debugPrint('Erro ao inserir dados de localização: $e');
      rethrow;
    }
  }

  Future<List<LocationData>> getLocationsByTrip(int tripId) async {
    try {
      return await _dbHelper.getLocationsByTrip(tripId);
    } catch (e) {
      debugPrint('Erro ao obter localizações da viagem: $e');
      return [];
    }
  }

  Future<List<LocationData>> getLocationData({int? limit}) async {
    try {
      return await _dbHelper.getLocationData(limit: limit);
    } catch (e) {
      debugPrint('Erro ao obter dados de localização: $e');
      return [];
    }
  }

  // Métodos para eventos de telemática
  Future<int> insertTelematicsEvent(TelematicsEvent event) async {
    try {
      return await _dbHelper.insertTelematicsEvent(event);
    } catch (e) {
      debugPrint('Erro ao inserir evento de telemática: $e');
      rethrow;
    }
  }

  Future<List<TelematicsEvent>> getTelematicsEventsByTrip(int tripId) async {
    try {
      return await _dbHelper.getTelematicsEventsByTrip(tripId);
    } catch (e) {
      debugPrint('Erro ao obter eventos de telemática da viagem: $e');
      return [];
    }
  }

  Future<List<TelematicsEvent>> getTelematicsEvents({int? limit}) async {
    try {
      return await _dbHelper.getTelematicsEvents(limit: limit);
    } catch (e) {
      debugPrint('Erro ao obter eventos de telemática: $e');
      return [];
    }
  }

  // Métodos de estatísticas
  Future<Map<String, int>> getTelematicsEventCounts() async {
    try {
      return await _dbHelper.getTelematicsEventCounts();
    } catch (e) {
      debugPrint('Erro ao obter contagem de eventos: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getTripStatistics() async {
    try {
      _statistics = await _dbHelper.getTripStatistics();
      notifyListeners();
      return _statistics;
    } catch (e) {
      debugPrint('Erro ao obter estatísticas: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getDailyStatistics(DateTime start, DateTime end) async {
    try {
      return await _dbHelper.getDailyStatistics(start, end);
    } catch (e) {
      debugPrint('Erro ao obter estatísticas diárias: $e');
      return [];
    }
  }

  // Métodos de limpeza
  Future<void> cleanOldData(DateTime cutoffDate) async {
    try {
      await _dbHelper.deleteOldData(cutoffDate);
    } catch (e) {
      debugPrint('Erro ao limpar dados antigos: $e');
      rethrow;
    }
  }

  Future<void> clearAllData() async {
    try {
      await _dbHelper.clearAllData();
      _currentUser = null;
      _activeTrip = null;
      _statistics = {};
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao limpar todos os dados: $e');
      rethrow;
    }
  }

  Future<bool> exportData() async {
    try {
      final result = await _dbHelper.exportData();
      debugPrint('Dados exportados: $result');
      return true;
    } catch (e) {
      debugPrint('Erro ao exportar dados: $e');
      return false;
    }
  }

  // Métodos auxiliares
  Future<List<Trip>> getAllTrips() async {
    return await getTrips();
  }

  Future<List<Trip>> getTripsByUser(int userId) async {
    return await getTrips(userId: userId);
  }

  Future<List<TelematicsEvent>> getAllTelematicsEvents() async {
    return await getTelematicsEvents();
  }

  // Métodos para detalhes da viagem
  Future<List<LocationPoint>> getTripLocationPoints(int tripId) async {
    try {
      return await _dbHelper.getTripLocationPoints(tripId);
    } catch (e) {
      debugPrint('Erro ao buscar pontos de localização da viagem: $e');
      return [];
    }
  }

  Future<List<DrivingEvent>> getTripDrivingEvents(int tripId) async {
    try {
      return await _dbHelper.getTripDrivingEvents(tripId);
    } catch (e) {
      debugPrint('Erro ao buscar eventos de direção da viagem: $e');
      return [];
    }
  }

  Future<void> optimizeDatabase() async {
    try {
      await _dbHelper.vacuum();
    } catch (e) {
      debugPrint('Erro ao otimizar banco: $e');
    }
  }
}

