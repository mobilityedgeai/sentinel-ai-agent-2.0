import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/telematics_event.dart';
import 'data_collector.dart';
import 'feature_engineer.dart';

/// Sistema de persistência de dados de Machine Learning
class MLDatabase {
  static final MLDatabase _instance = MLDatabase._internal();
  factory MLDatabase() => _instance;
  MLDatabase._internal();

  Database? _database;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _database = await DatabaseHelper().database;
    await _createMLTables();
    _isInitialized = true;
    
    debugPrint('MLDatabase: Inicializado');
  }

  /// Cria tabelas específicas para ML
  Future<void> _createMLTables() async {
    if (_database == null) return;
    
    // Tabela de amostras de treinamento
    await _database!.execute('''
      CREATE TABLE IF NOT EXISTS ml_training_samples (
        id TEXT PRIMARY KEY,
        timestamp INTEGER NOT NULL,
        event_type TEXT NOT NULL,
        magnitude REAL NOT NULL,
        sensor_features TEXT NOT NULL,
        context_features TEXT NOT NULL,
        preprocessing_features TEXT NOT NULL,
        is_valid_event INTEGER NOT NULL,
        user_feedback REAL,
        created_at INTEGER NOT NULL
      )
    ''');
    
    // Tabela de estatísticas de características
    await _database!.execute('''
      CREATE TABLE IF NOT EXISTS ml_feature_statistics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        feature_name TEXT NOT NULL,
        mean_value REAL NOT NULL,
        std_deviation REAL NOT NULL,
        min_value REAL NOT NULL,
        max_value REAL NOT NULL,
        created_at INTEGER NOT NULL,
        UNIQUE(feature_name)
      )
    ''');
    
    // Tabela de modelos treinados
    await _database!.execute('''
      CREATE TABLE IF NOT EXISTS ml_trained_models (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        model_name TEXT NOT NULL,
        model_type TEXT NOT NULL,
        model_data TEXT NOT NULL,
        feature_names TEXT NOT NULL,
        training_accuracy REAL,
        validation_accuracy REAL,
        sample_count INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        is_active INTEGER DEFAULT 0
      )
    ''');
    
    // Tabela de predições
    await _database!.execute('''
      CREATE TABLE IF NOT EXISTS ml_predictions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sample_id TEXT NOT NULL,
        model_id INTEGER NOT NULL,
        prediction_score REAL NOT NULL,
        is_valid_prediction INTEGER NOT NULL,
        confidence REAL NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (model_id) REFERENCES ml_trained_models (id)
      )
    ''');
    
    // Índices para performance
    await _database!.execute('CREATE INDEX IF NOT EXISTS idx_ml_samples_timestamp ON ml_training_samples(timestamp)');
    await _database!.execute('CREATE INDEX IF NOT EXISTS idx_ml_samples_event_type ON ml_training_samples(event_type)');
    await _database!.execute('CREATE INDEX IF NOT EXISTS idx_ml_predictions_sample ON ml_predictions(sample_id)');
    
    debugPrint('MLDatabase: Tabelas ML criadas');
  }

  /// Salva amostras de treinamento
  Future<void> saveTrainingSamples(List<MLDataSample> samples) async {
    if (_database == null || samples.isEmpty) return;
    
    final batch = _database!.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    for (final sample in samples) {
      batch.insert(
        'ml_training_samples',
        {
          'id': sample.id,
          'timestamp': sample.timestamp.millisecondsSinceEpoch,
          'event_type': sample.eventType.toString().split('.').last,
          'magnitude': sample.magnitude,
          'sensor_features': jsonEncode(sample.sensorFeatures),
          'context_features': jsonEncode(sample.contextFeatures),
          'preprocessing_features': jsonEncode(sample.preprocessingFeatures),
          'is_valid_event': sample.isValidEvent ? 1 : 0,
          'user_feedback': sample.userFeedback,
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
    debugPrint('MLDatabase: ${samples.length} amostras de treinamento salvas');
  }

  /// Carrega amostras de treinamento
  Future<List<MLDataSample>> loadTrainingSamples({
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
    String? eventType,
    bool? hasUserFeedback,
  }) async {
    if (_database == null) return [];
    
    String query = 'SELECT * FROM ml_training_samples WHERE 1=1';
    final args = <dynamic>[];
    
    if (startDate != null) {
      query += ' AND timestamp >= ?';
      args.add(startDate.millisecondsSinceEpoch);
    }
    
    if (endDate != null) {
      query += ' AND timestamp <= ?';
      args.add(endDate.millisecondsSinceEpoch);
    }
    
    if (eventType != null) {
      query += ' AND event_type = ?';
      args.add(eventType);
    }
    
    if (hasUserFeedback != null) {
      if (hasUserFeedback) {
        query += ' AND user_feedback IS NOT NULL';
      } else {
        query += ' AND user_feedback IS NULL';
      }
    }
    
    query += ' ORDER BY timestamp DESC';
    
    if (limit != null) {
      query += ' LIMIT ?';
      args.add(limit);
    }
    
    final results = await _database!.rawQuery(query, args);
    
    final samples = results.map((row) {
      return MLDataSample(
        id: row['id'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
        eventType: _stringToEventType(row['event_type'] as String),
        magnitude: row['magnitude'] as double,
        sensorFeatures: Map<String, double>.from(jsonDecode(row['sensor_features'] as String)),
        contextFeatures: Map<String, double>.from(jsonDecode(row['context_features'] as String)),
        preprocessingFeatures: Map<String, double>.from(jsonDecode(row['preprocessing_features'] as String)),
        isValidEvent: (row['is_valid_event'] as int) == 1,
        userFeedback: row['user_feedback'] as double?,
      );
    }).toList();
    
    debugPrint('MLDatabase: ${samples.length} amostras carregadas');
    return samples;
  }

  /// Salva estatísticas de características
  Future<void> saveFeatureStatistics(FeatureStatistics statistics) async {
    if (_database == null) return;
    
    final batch = _database!.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Limpar estatísticas antigas
    batch.delete('ml_feature_statistics');
    
    // Inserir novas estatísticas
    for (final featureName in statistics.means.keys) {
      batch.insert('ml_feature_statistics', {
        'feature_name': featureName,
        'mean_value': statistics.means[featureName]!,
        'std_deviation': statistics.standardDeviations[featureName]!,
        'min_value': statistics.minimums[featureName]!,
        'max_value': statistics.maximums[featureName]!,
        'created_at': now,
      });
    }
    
    await batch.commit(noResult: true);
    debugPrint('MLDatabase: Estatísticas de ${statistics.means.length} características salvas');
  }

  /// Carrega estatísticas de características
  Future<FeatureStatistics?> loadFeatureStatistics() async {
    if (_database == null) return null;
    
    final results = await _database!.query('ml_feature_statistics');
    
    if (results.isEmpty) return null;
    
    final means = <String, double>{};
    final standardDeviations = <String, double>{};
    final minimums = <String, double>{};
    final maximums = <String, double>{};
    
    for (final row in results) {
      final featureName = row['feature_name'] as String;
      means[featureName] = row['mean_value'] as double;
      standardDeviations[featureName] = row['std_deviation'] as double;
      minimums[featureName] = row['min_value'] as double;
      maximums[featureName] = row['max_value'] as double;
    }
    
    debugPrint('MLDatabase: Estatísticas de ${means.length} características carregadas');
    
    return FeatureStatistics(
      means: means,
      standardDeviations: standardDeviations,
      minimums: minimums,
      maximums: maximums,
    );
  }

  /// Salva modelo treinado
  Future<int> saveTrainedModel({
    required String modelName,
    required String modelType,
    required Map<String, dynamic> modelData,
    required List<String> featureNames,
    double? trainingAccuracy,
    double? validationAccuracy,
    required int sampleCount,
    bool setAsActive = false,
  }) async {
    if (_database == null) return -1;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Se definir como ativo, desativar outros modelos
    if (setAsActive) {
      await _database!.update(
        'ml_trained_models',
        {'is_active': 0},
        where: 'model_type = ?',
        whereArgs: [modelType],
      );
    }
    
    final modelId = await _database!.insert('ml_trained_models', {
      'model_name': modelName,
      'model_type': modelType,
      'model_data': jsonEncode(modelData),
      'feature_names': jsonEncode(featureNames),
      'training_accuracy': trainingAccuracy,
      'validation_accuracy': validationAccuracy,
      'sample_count': sampleCount,
      'created_at': now,
      'is_active': setAsActive ? 1 : 0,
    });
    
    debugPrint('MLDatabase: Modelo $modelName salvo com ID $modelId');
    return modelId;
  }

  /// Carrega modelo ativo
  Future<Map<String, dynamic>?> loadActiveModel(String modelType) async {
    if (_database == null) return null;
    
    final results = await _database!.query(
      'ml_trained_models',
      where: 'model_type = ? AND is_active = 1',
      whereArgs: [modelType],
      limit: 1,
    );
    
    if (results.isEmpty) return null;
    
    final row = results.first;
    
    return {
      'id': row['id'],
      'modelName': row['model_name'],
      'modelType': row['model_type'],
      'modelData': jsonDecode(row['model_data'] as String),
      'featureNames': List<String>.from(jsonDecode(row['feature_names'] as String)),
      'trainingAccuracy': row['training_accuracy'],
      'validationAccuracy': row['validation_accuracy'],
      'sampleCount': row['sample_count'],
      'createdAt': DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    };
  }

  /// Lista todos os modelos
  Future<List<Map<String, dynamic>>> listModels() async {
    if (_database == null) return [];
    
    final results = await _database!.query(
      'ml_trained_models',
      orderBy: 'created_at DESC',
    );
    
    return results.map((row) => {
      'id': row['id'],
      'modelName': row['model_name'],
      'modelType': row['model_type'],
      'trainingAccuracy': row['training_accuracy'],
      'validationAccuracy': row['validation_accuracy'],
      'sampleCount': row['sample_count'],
      'createdAt': DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      'isActive': (row['is_active'] as int) == 1,
    }).toList();
  }

  /// Salva predição
  Future<void> savePrediction({
    required String sampleId,
    required int modelId,
    required double predictionScore,
    required bool isValidPrediction,
    required double confidence,
  }) async {
    if (_database == null) return;
    
    await _database!.insert('ml_predictions', {
      'sample_id': sampleId,
      'model_id': modelId,
      'prediction_score': predictionScore,
      'is_valid_prediction': isValidPrediction ? 1 : 0,
      'confidence': confidence,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Atualiza feedback do usuário
  Future<void> updateUserFeedback(String sampleId, bool isValidEvent) async {
    if (_database == null) return;
    
    await _database!.update(
      'ml_training_samples',
      {
        'user_feedback': isValidEvent ? 1.0 : 0.0,
        'is_valid_event': isValidEvent ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [sampleId],
    );
    
    debugPrint('MLDatabase: Feedback atualizado para amostra $sampleId');
  }

  /// Obtém estatísticas do banco ML
  Future<Map<String, dynamic>> getMLStatistics() async {
    if (_database == null) return {};
    
    final sampleCount = Sqflite.firstIntValue(
      await _database!.rawQuery('SELECT COUNT(*) FROM ml_training_samples')
    ) ?? 0;
    
    final feedbackCount = Sqflite.firstIntValue(
      await _database!.rawQuery('SELECT COUNT(*) FROM ml_training_samples WHERE user_feedback IS NOT NULL')
    ) ?? 0;
    
    final modelCount = Sqflite.firstIntValue(
      await _database!.rawQuery('SELECT COUNT(*) FROM ml_trained_models')
    ) ?? 0;
    
    final predictionCount = Sqflite.firstIntValue(
      await _database!.rawQuery('SELECT COUNT(*) FROM ml_predictions')
    ) ?? 0;
    
    // Estatísticas por tipo de evento
    final eventStats = await _database!.rawQuery('''
      SELECT event_type, COUNT(*) as count, 
             SUM(CASE WHEN user_feedback = 1.0 THEN 1 ELSE 0 END) as valid_count
      FROM ml_training_samples 
      GROUP BY event_type
    ''');
    
    return {
      'totalSamples': sampleCount,
      'samplesWithFeedback': feedbackCount,
      'totalModels': modelCount,
      'totalPredictions': predictionCount,
      'eventStatistics': eventStats,
      'feedbackRatio': sampleCount > 0 ? feedbackCount / sampleCount : 0.0,
    };
  }

  /// Limpa dados antigos
  Future<void> cleanupOldData({int keepDays = 30}) async {
    if (_database == null) return;
    
    final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
    final cutoffTimestamp = cutoffDate.millisecondsSinceEpoch;
    
    // Manter amostras com feedback do usuário
    final deletedSamples = await _database!.delete(
      'ml_training_samples',
      where: 'created_at < ? AND user_feedback IS NULL',
      whereArgs: [cutoffTimestamp],
    );
    
    // Limpar predições antigas
    final deletedPredictions = await _database!.delete(
      'ml_predictions',
      where: 'created_at < ?',
      whereArgs: [cutoffTimestamp],
    );
    
    debugPrint('MLDatabase: Limpeza - $deletedSamples amostras e $deletedPredictions predições removidas');
  }

  TelematicsEventType _stringToEventType(String eventTypeString) {
    switch (eventTypeString) {
      case 'hardBraking':
        return TelematicsEventType.hardBraking;
      case 'rapidAcceleration':
        return TelematicsEventType.rapidAcceleration;
      case 'sharpTurn':
        return TelematicsEventType.sharpTurn;
      case 'speeding':
        return TelematicsEventType.speeding;
      case 'highGForce':
        return TelematicsEventType.highGForce;
      case 'idling':
        return TelematicsEventType.idling;
      case 'phoneUsage':
        return TelematicsEventType.phoneUsage;
      default:
        return TelematicsEventType.hardBraking;
    }
  }
}

