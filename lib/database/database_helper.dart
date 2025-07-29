import 'dart:async';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/location_data.dart';
import '../models/trip.dart';
import '../models/telematics_event.dart';
import '../models/location_point.dart';
import '../models/driving_event.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'sentinel_ai.db');
    
    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabela de usuários
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        phone_number TEXT,
        profile_image_url TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Tabela de viagens
    await db.execute('''
      CREATE TABLE trips (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        distance REAL DEFAULT 0,
        duration INTEGER DEFAULT 0,
        avg_speed REAL DEFAULT 0,
        max_speed REAL DEFAULT 0,
        safety_score REAL DEFAULT 100,
        start_latitude REAL,
        start_longitude REAL,
        end_latitude REAL,
        end_longitude REAL,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // Tabela de dados de localização
    await db.execute('''
      CREATE TABLE location_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude REAL,
        accuracy REAL,
        speed REAL,
        heading REAL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (trip_id) REFERENCES trips (id)
      )
    ''');

    // Tabela de eventos de telemática
    await db.execute('''
      CREATE TABLE telematics_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        event_type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        severity REAL DEFAULT 0,
        FOREIGN KEY (trip_id) REFERENCES trips (id),
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // Tabela de cache de endereços
    await db.execute('''
      CREATE TABLE address_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        formatted_address TEXT NOT NULL,
        street TEXT,
        house_number TEXT,
        neighbourhood TEXT,
        city TEXT,
        state TEXT,
        country TEXT,
        postcode TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    // Tabela de pontos de localização das viagens
    await db.execute('''
      CREATE TABLE location_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        speed REAL,
        accuracy REAL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');

    // Tabela de eventos de direção
    await db.execute('''
      CREATE TABLE driving_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER NOT NULL,
        event_type TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        intensity REAL NOT NULL,
        timestamp TEXT NOT NULL,
        metadata TEXT,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');

    // Índices para melhor performance
    await db.execute('CREATE INDEX idx_trips_user_id ON trips (user_id)');
    await db.execute('CREATE INDEX idx_trips_start_time ON trips (start_time)');
    await db.execute('CREATE INDEX idx_location_trip_id ON location_data (trip_id)');
    await db.execute('CREATE INDEX idx_location_timestamp ON location_data (timestamp)');
    await db.execute('CREATE INDEX idx_events_trip_id ON telematics_events (trip_id)');
    await db.execute('CREATE INDEX idx_events_timestamp ON telematics_events (timestamp)');
    await db.execute('CREATE INDEX idx_address_cache_coords ON address_cache (latitude, longitude)');
    await db.execute('CREATE INDEX idx_location_points_trip_id ON location_points (trip_id)');
    await db.execute('CREATE INDEX idx_location_points_timestamp ON location_points (timestamp)');
    await db.execute('CREATE INDEX idx_driving_events_trip_id ON driving_events (trip_id)');
    await db.execute('CREATE INDEX idx_driving_events_timestamp ON driving_events (timestamp)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Adicionar tabela de cache de endereços na versão 2
      await db.execute('''
        CREATE TABLE address_cache (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          formatted_address TEXT NOT NULL,
          street TEXT,
          house_number TEXT,
          neighbourhood TEXT,
          city TEXT,
          state TEXT,
          country TEXT,
          postcode TEXT,
          created_at INTEGER NOT NULL
        )
      ''');
      
      await db.execute('CREATE INDEX idx_address_cache_coords ON address_cache (latitude, longitude)');
    }
    
    if (oldVersion < 3) {
      // Adicionar tabelas de detalhes da viagem na versão 3
      await db.execute('''
        CREATE TABLE location_points (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          trip_id INTEGER NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          speed REAL,
          accuracy REAL,
          timestamp TEXT NOT NULL,
          FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE driving_events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          trip_id INTEGER NOT NULL,
          event_type TEXT NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          intensity REAL NOT NULL,
          timestamp TEXT NOT NULL,
          metadata TEXT,
          FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
        )
      ''');
      
      await db.execute('CREATE INDEX idx_location_points_trip_id ON location_points (trip_id)');
      await db.execute('CREATE INDEX idx_location_points_timestamp ON location_points (timestamp)');
      await db.execute('CREATE INDEX idx_driving_events_trip_id ON driving_events (trip_id)');
      await db.execute('CREATE INDEX idx_driving_events_timestamp ON driving_events (timestamp)');
    }
  }

  // Métodos para usuários
  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert('users', {
      'name': user.name,
      'email': user.email,
      'phone_number': user.phoneNumber,
      'profile_image_url': user.profileImageUrl,
      'created_at': user.createdAt.toIso8601String(),
      'updated_at': user.updatedAt.toIso8601String(),
    });
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users');
    
    return List.generate(maps.length, (i) {
      return User(
        id: maps[i]['id'],
        name: maps[i]['name'],
        email: maps[i]['email'],
        phoneNumber: maps[i]['phone_number'],
        profileImageUrl: maps[i]['profile_image_url'],
        createdAt: DateTime.parse(maps[i]['created_at']),
        updatedAt: DateTime.parse(maps[i]['updated_at']),
      );
    });
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    return await db.update(
      'users',
      {
        'name': user.name,
        'email': user.email,
        'phone_number': user.phoneNumber,
        'profile_image_url': user.profileImageUrl,
        'updated_at': user.updatedAt.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<User?> getCurrentUser() async {
    final users = await getAllUsers();
    return users.isNotEmpty ? users.first : null;
  }

  // Métodos para dados de localização
  Future<int> insertLocationData(LocationData locationData, {int? tripId}) async {
    final db = await database;
    return await db.insert('location_data', {
      'trip_id': tripId,
      'latitude': locationData.latitude,
      'longitude': locationData.longitude,
      'altitude': locationData.altitude,
      'accuracy': locationData.accuracy,
      'speed': locationData.speed,
      'heading': locationData.heading,
      'timestamp': locationData.timestamp.toIso8601String(),
    });
  }

  Future<int> insertLocation(LocationData locationData) async {
    return await insertLocationData(locationData);
  }

  Future<List<LocationData>> getLocationData({int? limit}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'location_data',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    
    return List.generate(maps.length, (i) {
      return LocationData(
        latitude: maps[i]['latitude'],
        longitude: maps[i]['longitude'],
        altitude: maps[i]['altitude'],
        accuracy: maps[i]['accuracy'],
        speed: maps[i]['speed'],
        heading: maps[i]['heading'],
        timestamp: DateTime.parse(maps[i]['timestamp']),
      );
    });
  }

  Future<List<LocationData>> getLocationsByTrip(int tripId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'location_data',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'timestamp ASC',
    );
    
    return List.generate(maps.length, (i) {
      return LocationData(
        latitude: maps[i]['latitude'],
        longitude: maps[i]['longitude'],
        altitude: maps[i]['altitude'],
        accuracy: maps[i]['accuracy'],
        speed: maps[i]['speed'],
        heading: maps[i]['heading'],
        timestamp: DateTime.parse(maps[i]['timestamp']),
      );
    });
  }

  // Métodos para viagens
  Future<int> insertTrip(Trip trip) async {
    final db = await database;
    return await db.insert('trips', {
      'user_id': trip.userId,
      'start_time': trip.startTime.toIso8601String(),
      'end_time': trip.endTime?.toIso8601String(),
      'distance': trip.distance,
      'duration': trip.duration,
      'avg_speed': trip.avgSpeed,
      'max_speed': trip.maxSpeed,
      'safety_score': trip.safetyScore,
      'start_latitude': trip.startLatitude,
      'start_longitude': trip.startLongitude,
      'end_latitude': trip.endLatitude,
      'end_longitude': trip.endLongitude,
    });
  }

  Future<List<Trip>> getTrips({int? userId, int? limit, int? offset}) async {
    final db = await database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (userId != null) {
      whereClause = 'user_id = ?';
      whereArgs.add(userId);
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'trips',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'start_time DESC',
      limit: limit,
      offset: offset,
    );
    
    return List.generate(maps.length, (i) {
      return Trip(
        id: maps[i]['id'],
        userId: maps[i]['user_id'],
        startTime: DateTime.parse(maps[i]['start_time']),
        endTime: maps[i]['end_time'] != null ? DateTime.parse(maps[i]['end_time']) : null,
        distance: maps[i]['distance']?.toDouble(),
        duration: maps[i]['duration'],
        avgSpeed: maps[i]['avg_speed']?.toDouble(),
        maxSpeed: maps[i]['max_speed']?.toDouble(),
        safetyScore: maps[i]['safety_score']?.toDouble(),
        startLatitude: maps[i]['start_latitude']?.toDouble(),
        startLongitude: maps[i]['start_longitude']?.toDouble(),
        endLatitude: maps[i]['end_latitude']?.toDouble(),
        endLongitude: maps[i]['end_longitude']?.toDouble(),
      );
    });
  }

  Future<int> updateTrip(Trip trip) async {
    final db = await database;
    return await db.update(
      'trips',
      {
        'end_time': trip.endTime?.toIso8601String(),
        'distance': trip.distance,
        'duration': trip.duration,
        'avg_speed': trip.avgSpeed,
        'max_speed': trip.maxSpeed,
        'safety_score': trip.safetyScore,
        'end_latitude': trip.endLatitude,
        'end_longitude': trip.endLongitude,
      },
      where: 'id = ?',
      whereArgs: [trip.id],
    );
  }

  Future<void> deleteTrip(int tripId) async {
    final db = await database;
    await db.delete('trips', where: 'id = ?', whereArgs: [tripId]);
  }

  Future<Trip?> getActiveTrip() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'trips',
      where: 'end_time IS NULL',
      orderBy: 'start_time DESC',
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    
    final map = maps.first;
    return Trip(
      id: map['id'],
      userId: map['user_id'],
      startTime: DateTime.parse(map['start_time']),
      endTime: null,
      distance: map['distance']?.toDouble(),
      duration: map['duration'],
      avgSpeed: map['avg_speed']?.toDouble(),
      maxSpeed: map['max_speed']?.toDouble(),
      safetyScore: map['safety_score']?.toDouble(),
      startLatitude: map['start_latitude']?.toDouble(),
      startLongitude: map['start_longitude']?.toDouble(),
      endLatitude: map['end_latitude']?.toDouble(),
      endLongitude: map['end_longitude']?.toDouble(),
    );
  }

  Future<Map<String, dynamic>> getTripStatistics() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_trips,
        AVG(distance) as avg_distance,
        AVG(safety_score) as avg_safety_score,
        SUM(distance) as total_distance
      FROM trips
      WHERE end_time IS NOT NULL
    ''');
    
    if (result.isEmpty) {
      return {
        'total_trips': 0,
        'avg_distance': 0.0,
        'avg_safety_score': 100.0,
        'total_distance': 0.0,
      };
    }
    
    return result.first;
  }

  // Métodos para eventos de telemática
  Future<int> insertTelematicsEvent(TelematicsEvent event) async {
    final db = await database;
    return await db.insert('telematics_events', {
      'trip_id': event.tripId,
      'user_id': event.userId,
      'event_type': event.eventType.toString(),
      'timestamp': event.timestamp.toIso8601String(),
      'latitude': event.latitude,
      'longitude': event.longitude,
      'severity': event.severity,
    });
  }

  Future<List<TelematicsEvent>> getTelematicsEvents({int? tripId, int? limit}) async {
    final db = await database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (tripId != null) {
      whereClause = 'trip_id = ?';
      whereArgs.add(tripId);
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'telematics_events',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    
    return List.generate(maps.length, (i) {
      return TelematicsEvent(
        id: maps[i]['id'],
        tripId: maps[i]['trip_id'],
        userId: maps[i]['user_id'],
        eventType: _stringToEventType(maps[i]['event_type']),
        timestamp: DateTime.parse(maps[i]['timestamp']),
        latitude: maps[i]['latitude']?.toDouble(),
        longitude: maps[i]['longitude']?.toDouble(),
        severity: maps[i]['severity']?.toDouble(),
      );
    });
  }

  Future<List<TelematicsEvent>> getTelematicsEventsByTrip(int tripId) async {
    return await getTelematicsEvents(tripId: tripId);
  }

  Future<Map<String, int>> getTelematicsEventCounts() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT event_type, COUNT(*) as count
      FROM telematics_events
      GROUP BY event_type
    ''');
    
    Map<String, int> counts = {};
    for (var row in result) {
      final type = row['event_type'].toString().split('.').last;
      counts[type] = row['count'];
    }
    
    return counts;
  }

  // Métodos de limpeza e estatísticas
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('telematics_events');
    await db.delete('location_data');
    await db.delete('trips');
    await db.delete('users');
  }

  Future<String> exportData() async {
    final users = await getAllUsers();
    final trips = await getTrips();
    final events = await getTelematicsEvents();
    
    return "Dados exportados com sucesso - ${users.length} usuários, ${trips.length} viagens, ${events.length} eventos";
  }

  Future<List<Map<String, dynamic>>> getDailyStatistics(DateTime startDate, DateTime endDate) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT 
        DATE(start_time) as date,
        COUNT(*) as trip_count,
        AVG(safety_score) as avg_safety_score
      FROM trips
      WHERE start_time >= ? AND start_time <= ? AND end_time IS NOT NULL
      GROUP BY DATE(start_time)
      ORDER BY date
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);
    
    return result;
  }

  Future<void> deleteOldData(DateTime cutoffDate) async {
    final db = await database;
    await db.delete(
      'telematics_events',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  // Métodos para detalhes da viagem
  Future<List<LocationPoint>> getTripLocationPoints(int tripId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'location_points',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (i) {
      return LocationPoint.fromMap(maps[i]);
    });
  }

  Future<List<DrivingEvent>> getTripDrivingEvents(int tripId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'driving_events',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (i) {
      return DrivingEvent.fromMap(maps[i]);
    });
  }

  Future<List<Trip>> getAllTrips() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'trips',
      orderBy: 'start_time DESC',
    );

    return List.generate(maps.length, (i) {
      return Trip.fromMap(maps[i]);
    });
  }

  Future<List<TelematicsEvent>> getAllTelematicsEvents() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'telematics_events',
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) {
      return TelematicsEvent.fromMap(maps[i]);
    });
  }

  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  TelematicsEventType _stringToEventType(String eventTypeString) {
    switch (eventTypeString) {
      case 'TelematicsEventType.hardBraking':
        return TelematicsEventType.hardBraking;
      case 'TelematicsEventType.rapidAcceleration':
        return TelematicsEventType.rapidAcceleration;
      case 'TelematicsEventType.sharpTurn':
        return TelematicsEventType.sharpTurn;
      case 'TelematicsEventType.speeding':
        return TelematicsEventType.speeding;
      case 'TelematicsEventType.highGForce':
        return TelematicsEventType.highGForce;
      case 'TelematicsEventType.idling':
        return TelematicsEventType.idling;
      case 'TelematicsEventType.phoneUsage':
        return TelematicsEventType.phoneUsage;
      default:
        return TelematicsEventType.hardBraking;
    }
  }
}

