import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../models/location_data.dart';

/// Serviço de cache local para dados de localização
class LocationCacheService {
  static final LocationCacheService _instance = LocationCacheService._internal();
  factory LocationCacheService() => _instance;
  LocationCacheService._internal();

  Database? _database;
  bool _isInitialized = false;
  Timer? _syncTimer;
  Timer? _cleanupTimer;

  // Configurações
  static const int _maxCacheEntries = 10000;
  static const int _syncIntervalMinutes = 5;
  static const int _cleanupIntervalHours = 24;
  static const int _maxCacheAgeDays = 7;

  // Estatísticas
  int _totalEntries = 0;
  int _syncedEntries = 0;
  int _pendingEntries = 0;
  DateTime? _lastSyncTime;
  DateTime? _lastCleanupTime;

  // Getters
  bool get isInitialized => _isInitialized;
  int get totalEntries => _totalEntries;
  int get syncedEntries => _syncedEntries;
  int get pendingEntries => _pendingEntries;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Inicializa o serviço de cache
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _initializeDatabase();
      await _loadStatistics();
      _startPeriodicTasks();
      
      _isInitialized = true;
      debugPrint('LocationCacheService: Inicializado');

    } catch (e) {
      debugPrint('Erro ao inicializar LocationCacheService: $e');
    }
  }

  /// Inicializa o banco de dados
  Future<void> _initializeDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final dbPath = path.join(databasesPath, 'location_cache.db');

      _database = await openDatabase(
        dbPath,
        version: 1,
        onCreate: _createTables,
        onUpgrade: _upgradeTables,
      );

    } catch (e) {
      debugPrint('Erro ao inicializar banco de dados: $e');
      rethrow;
    }
  }

  /// Cria tabelas do banco de dados
  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE location_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        accuracy REAL,
        altitude REAL,
        speed REAL,
        speed_accuracy REAL,
        heading REAL,
        timestamp INTEGER NOT NULL,
        provider TEXT,
        is_synced INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        metadata TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_location_timestamp ON location_cache(timestamp);
    ''');

    await db.execute('''
      CREATE INDEX idx_location_synced ON location_cache(is_synced);
    ''');

    await db.execute('''
      CREATE INDEX idx_location_created ON location_cache(created_at);
    ''');
  }

  /// Atualiza tabelas do banco de dados
  Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
    // Implementar migrações futuras se necessário
  }

  /// Carrega estatísticas do cache
  Future<void> _loadStatistics() async {
    if (_database == null) return;

    try {
      // Total de entradas
      final totalResult = await _database!.rawQuery('SELECT COUNT(*) as count FROM location_cache');
      _totalEntries = totalResult.first['count'] as int;

      // Entradas sincronizadas
      final syncedResult = await _database!.rawQuery('SELECT COUNT(*) as count FROM location_cache WHERE is_synced = 1');
      _syncedEntries = syncedResult.first['count'] as int;

      // Entradas pendentes
      _pendingEntries = _totalEntries - _syncedEntries;

      debugPrint('LocationCacheService: $_totalEntries entradas, $_pendingEntries pendentes');

    } catch (e) {
      debugPrint('Erro ao carregar estatísticas: $e');
    }
  }

  /// Inicia tarefas periódicas
  void _startPeriodicTasks() {
    // Timer de sincronização
    _syncTimer = Timer.periodic(
      Duration(minutes: _syncIntervalMinutes),
      (_) => syncToDatabase(),
    );

    // Timer de limpeza
    _cleanupTimer = Timer.periodic(
      Duration(hours: _cleanupIntervalHours),
      (_) => cleanupOldEntries(),
    );
  }

  /// Adiciona localização ao cache
  Future<void> addLocation(LocationData locationData) async {
    if (_database == null) return;

    try {
      final metadata = {
        'source': 'fused_location',
        'cached_at': DateTime.now().toIso8601String(),
      };

      await _database!.insert('location_cache', {
        'latitude': locationData.latitude,
        'longitude': locationData.longitude,
        'accuracy': locationData.accuracy,
        'altitude': locationData.altitude,
        'speed': locationData.speed,
        'speed_accuracy': locationData.speedAccuracy,
        'heading': locationData.heading,
        'timestamp': locationData.timestamp.millisecondsSinceEpoch,
        'provider': locationData.provider,
        'is_synced': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'metadata': jsonEncode(metadata),
      });

      _totalEntries++;
      _pendingEntries++;

      // Verificar limite de entradas
      if (_totalEntries > _maxCacheEntries) {
        await _removeOldestEntries(1000);
      }

    } catch (e) {
      debugPrint('Erro ao adicionar localização ao cache: $e');
    }
  }

  /// Obtém localizações do cache
  Future<List<LocationData>> getLocations({
    DateTime? startTime,
    DateTime? endTime,
    int? limit,
    bool? onlyUnsynced,
  }) async {
    if (_database == null) return [];

    try {
      String query = 'SELECT * FROM location_cache WHERE 1=1';
      List<dynamic> args = [];

      if (startTime != null) {
        query += ' AND timestamp >= ?';
        args.add(startTime.millisecondsSinceEpoch);
      }

      if (endTime != null) {
        query += ' AND timestamp <= ?';
        args.add(endTime.millisecondsSinceEpoch);
      }

      if (onlyUnsynced == true) {
        query += ' AND is_synced = 0';
      }

      query += ' ORDER BY timestamp DESC';

      if (limit != null) {
        query += ' LIMIT ?';
        args.add(limit);
      }

      final results = await _database!.rawQuery(query, args);
      
      return results.map<LocationData>((row) => LocationData(
        latitude: row['latitude'] as double,
        longitude: row['longitude'] as double,
        accuracy: row['accuracy'] as double?,
        altitude: row['altitude'] as double?,
        speed: row['speed'] as double? ?? 0.0,
        speedAccuracy: row['speed_accuracy'] as double?,
        heading: row['heading'] as double?,
        timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
        provider: row['provider'] as String?,
      )).toList();

    } catch (e) {
      debugPrint('Erro ao obter localizações do cache: $e');
      return [];
    }
  }

  /// Sincroniza dados com o banco principal
  Future<void> syncToDatabase() async {
    if (_database == null) return;

    try {
      // Obter entradas não sincronizadas
      final unsyncedLocations = await getLocations(onlyUnsynced: true, limit: 1000);
      
      if (unsyncedLocations.isEmpty) {
        _lastSyncTime = DateTime.now();
        return;
      }

      // Aqui você integraria com o DatabaseService principal
      // Por enquanto, apenas marcar como sincronizado
      final ids = await _database!.rawQuery(
        'SELECT id FROM location_cache WHERE is_synced = 0 LIMIT 1000'
      );

      if (ids.isNotEmpty) {
        final idList = ids.map((row) => row['id']).join(',');
        await _database!.rawUpdate(
          'UPDATE location_cache SET is_synced = 1 WHERE id IN ($idList)'
        );

        _syncedEntries += ids.length;
        _pendingEntries -= ids.length;
      }

      _lastSyncTime = DateTime.now();
      debugPrint('LocationCacheService: ${ids.length} entradas sincronizadas');

    } catch (e) {
      debugPrint('Erro na sincronização: $e');
    }
  }

  /// Remove entradas antigas
  Future<void> cleanupOldEntries() async {
    if (_database == null) return;

    try {
      final cutoffTime = DateTime.now().subtract(Duration(days: _maxCacheAgeDays));
      
      final deletedCount = await _database!.delete(
        'location_cache',
        where: 'created_at < ? AND is_synced = 1',
        whereArgs: [cutoffTime.millisecondsSinceEpoch],
      );

      _totalEntries -= deletedCount;
      _syncedEntries -= deletedCount;
      _lastCleanupTime = DateTime.now();

      debugPrint('LocationCacheService: $deletedCount entradas antigas removidas');

    } catch (e) {
      debugPrint('Erro na limpeza: $e');
    }
  }

  /// Remove entradas mais antigas
  Future<void> _removeOldestEntries(int count) async {
    if (_database == null) return;

    try {
      await _database!.rawDelete('''
        DELETE FROM location_cache 
        WHERE id IN (
          SELECT id FROM location_cache 
          ORDER BY created_at ASC 
          LIMIT ?
        )
      ''', [count]);

      _totalEntries -= count;
      await _loadStatistics(); // Recarregar estatísticas

    } catch (e) {
      debugPrint('Erro ao remover entradas antigas: $e');
    }
  }

  /// Exporta dados para JSON
  Future<String> exportToJson({
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    try {
      final locations = await getLocations(
        startTime: startTime,
        endTime: endTime,
      );

      final exportData = {
        'export_time': DateTime.now().toIso8601String(),
        'total_entries': locations.length,
        'start_time': startTime?.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'locations': locations.map((loc) => {
          'latitude': loc.latitude,
          'longitude': loc.longitude,
          'accuracy': loc.accuracy,
          'altitude': loc.altitude,
          'speed': loc.speed,
          'speed_accuracy': loc.speedAccuracy,
          'heading': loc.heading,
          'timestamp': loc.timestamp.toIso8601String(),
          'provider': loc.provider,
        }).toList(),
      };

      return jsonEncode(exportData);

    } catch (e) {
      debugPrint('Erro ao exportar dados: $e');
      return '{}';
    }
  }

  /// Obtém estatísticas do cache
  Future<Map<String, dynamic>> getCacheStatistics() async {
    await _loadStatistics();

    return {
      'totalEntries': _totalEntries,
      'syncedEntries': _syncedEntries,
      'pendingEntries': _pendingEntries,
      'lastSyncTime': _lastSyncTime,
      'lastCleanupTime': _lastCleanupTime,
      'maxCacheEntries': _maxCacheEntries,
      'maxCacheAgeDays': _maxCacheAgeDays,
      'syncIntervalMinutes': _syncIntervalMinutes,
      'isInitialized': _isInitialized,
    };
  }

  /// Limpa todo o cache
  Future<void> clearCache() async {
    if (_database == null) return;

    try {
      await _database!.delete('location_cache');
      _totalEntries = 0;
      _syncedEntries = 0;
      _pendingEntries = 0;
      
      debugPrint('LocationCacheService: Cache limpo');

    } catch (e) {
      debugPrint('Erro ao limpar cache: $e');
    }
  }

  /// Força sincronização imediata
  Future<void> forceSyncNow() async {
    await syncToDatabase();
  }

  /// Dispose
  void dispose() {
    _syncTimer?.cancel();
    _cleanupTimer?.cancel();
    _database?.close();
    _isInitialized = false;
  }
}

