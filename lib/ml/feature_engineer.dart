import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/telematics_event.dart';
import 'data_collector.dart';

/// Características processadas para ML
class ProcessedFeatures {
  final List<double> features;
  final List<String> featureNames;
  final double target; // 0.0 = falso positivo, 1.0 = evento válido
  final Map<String, dynamic> metadata;
  
  ProcessedFeatures({
    required this.features,
    required this.featureNames,
    required this.target,
    required this.metadata,
  });
}

/// Estatísticas para normalização
class FeatureStatistics {
  final Map<String, double> means;
  final Map<String, double> standardDeviations;
  final Map<String, double> minimums;
  final Map<String, double> maximums;
  
  FeatureStatistics({
    required this.means,
    required this.standardDeviations,
    required this.minimums,
    required this.maximums,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'means': means,
      'standardDeviations': standardDeviations,
      'minimums': minimums,
      'maximums': maximums,
    };
  }
  
  factory FeatureStatistics.fromMap(Map<String, dynamic> map) {
    return FeatureStatistics(
      means: Map<String, double>.from(map['means']),
      standardDeviations: Map<String, double>.from(map['standardDeviations']),
      minimums: Map<String, double>.from(map['minimums']),
      maximums: Map<String, double>.from(map['maximums']),
    );
  }
}

/// Sistema de engenharia de características para Machine Learning
class FeatureEngineer {
  static final FeatureEngineer _instance = FeatureEngineer._internal();
  factory FeatureEngineer() => _instance;
  FeatureEngineer._internal();

  FeatureStatistics? _statistics;
  List<String>? _featureNames;
  
  /// Processa amostras brutas em características para ML
  List<ProcessedFeatures> processRawSamples(List<MLDataSample> samples) {
    if (samples.isEmpty) return [];
    
    debugPrint('FeatureEngineer: Processando ${samples.length} amostras');
    
    // Extrair todas as características
    final allFeatures = <Map<String, double>>[];
    final targets = <double>[];
    final metadata = <Map<String, dynamic>>[];
    
    for (final sample in samples) {
      final combinedFeatures = <String, double>{};
      
      // Combinar todas as características
      combinedFeatures.addAll(sample.sensorFeatures);
      combinedFeatures.addAll(sample.contextFeatures);
      combinedFeatures.addAll(sample.preprocessingFeatures);
      
      // Adicionar características derivadas
      combinedFeatures.addAll(_extractDerivedFeatures(sample));
      
      allFeatures.add(combinedFeatures);
      targets.add(sample.userFeedback ?? (sample.isValidEvent ? 1.0 : 0.0));
      metadata.add({
        'id': sample.id,
        'timestamp': sample.timestamp.millisecondsSinceEpoch,
        'eventType': sample.eventType.toString().split('.').last,
        'magnitude': sample.magnitude,
      });
    }
    
    // Calcular estatísticas se não existirem
    if (_statistics == null) {
      _statistics = _calculateStatistics(allFeatures);
    }
    
    // Obter nomes das características
    if (_featureNames == null && allFeatures.isNotEmpty) {
      _featureNames = allFeatures.first.keys.toList()..sort();
    }
    
    // Normalizar características
    final processedSamples = <ProcessedFeatures>[];
    for (int i = 0; i < allFeatures.length; i++) {
      final normalizedFeatures = _normalizeFeatures(allFeatures[i]);
      
      processedSamples.add(ProcessedFeatures(
        features: normalizedFeatures,
        featureNames: _featureNames!,
        target: targets[i],
        metadata: metadata[i],
      ));
    }
    
    debugPrint('FeatureEngineer: ${processedSamples.length} amostras processadas com ${_featureNames!.length} características');
    
    return processedSamples;
  }
  
  /// Extrai características derivadas de uma amostra
  Map<String, double> _extractDerivedFeatures(MLDataSample sample) {
    final derived = <String, double>{};
    
    // Características temporais
    final hour = sample.timestamp.hour.toDouble();
    derived['hour_of_day'] = hour;
    derived['is_rush_hour'] = (hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19) ? 1.0 : 0.0;
    derived['is_night'] = (hour >= 22 || hour <= 6) ? 1.0 : 0.0;
    
    // Características de magnitude
    derived['magnitude_squared'] = sample.magnitude * sample.magnitude;
    derived['magnitude_log'] = math.log(math.max(0.1, sample.magnitude));
    
    // Características de tipo de evento
    derived['is_braking_event'] = sample.eventType == TelematicsEventType.hardBraking ? 1.0 : 0.0;
    derived['is_acceleration_event'] = sample.eventType == TelematicsEventType.rapidAcceleration ? 1.0 : 0.0;
    derived['is_turn_event'] = sample.eventType == TelematicsEventType.sharpTurn ? 1.0 : 0.0;
    derived['is_speed_event'] = sample.eventType == TelematicsEventType.speeding ? 1.0 : 0.0;
    derived['is_gforce_event'] = sample.eventType == TelematicsEventType.highGForce ? 1.0 : 0.0;
    
    // Características de interação entre sensores
    final accelMag = sample.sensorFeatures['accel_magnitude'] ?? 0.0;
    final gyroMag = sample.sensorFeatures['gyro_magnitude'] ?? 0.0;
    final magMag = sample.sensorFeatures['mag_magnitude'] ?? 0.0;
    
    derived['accel_gyro_ratio'] = gyroMag > 0 ? accelMag / gyroMag : 0.0;
    derived['accel_mag_ratio'] = magMag > 0 ? accelMag / magMag : 0.0;
    derived['sensor_consistency'] = _calculateSensorConsistency(sample.sensorFeatures);
    
    // Características de contexto GPS
    final speed = sample.contextFeatures['speed'] ?? 0.0;
    final accuracy = sample.contextFeatures['accuracy'] ?? 100.0;
    
    derived['speed_squared'] = speed * speed;
    derived['speed_log'] = math.log(math.max(0.1, speed));
    derived['gps_quality'] = math.max(0.0, 1.0 - (accuracy / 100.0));
    derived['is_moving'] = speed > 5.0 ? 1.0 : 0.0; // Acima de 5 km/h
    derived['is_high_speed'] = speed > 80.0 ? 1.0 : 0.0; // Acima de 80 km/h
    
    // Características de pré-processamento
    final stabilityScore = sample.preprocessingFeatures['phone_stability_score'] ?? 0.5;
    final gpsConfidence = sample.preprocessingFeatures['gps_validation_confidence'] ?? 0.5;
    
    derived['stability_confidence_product'] = stabilityScore * gpsConfidence;
    derived['preprocessing_agreement'] = _calculatePreprocessingAgreement(sample.preprocessingFeatures);
    
    return derived;
  }
  
  /// Calcula consistência entre sensores
  double _calculateSensorConsistency(Map<String, double> sensorFeatures) {
    final accelMag = sensorFeatures['accel_magnitude'] ?? 0.0;
    final gyroMag = sensorFeatures['gyro_magnitude'] ?? 0.0;
    final totalMag = sensorFeatures['total_magnitude'] ?? 0.0;
    
    // Verificar se as magnitudes são consistentes
    final expectedTotal = math.sqrt(accelMag * accelMag + gyroMag * gyroMag);
    final consistency = totalMag > 0 ? math.min(1.0, expectedTotal / totalMag) : 0.0;
    
    return consistency;
  }
  
  /// Calcula concordância entre algoritmos de pré-processamento
  double _calculatePreprocessingAgreement(Map<String, double> preprocessingFeatures) {
    final phoneStable = (preprocessingFeatures['phone_is_mounted'] ?? 0.0) > 0.5;
    final gpsValid = (preprocessingFeatures['gps_is_valid'] ?? 0.0) > 0.5;
    final hasGps = (preprocessingFeatures['gps_has_data'] ?? 0.0) > 0.5;
    
    // Calcular score de concordância
    double agreement = 0.0;
    int factors = 0;
    
    if (phoneStable) {
      agreement += 1.0;
      factors++;
    }
    
    if (hasGps) {
      if (gpsValid) {
        agreement += 1.0;
      }
      factors++;
    }
    
    return factors > 0 ? agreement / factors : 0.5;
  }
  
  /// Calcula estatísticas das características
  FeatureStatistics _calculateStatistics(List<Map<String, double>> allFeatures) {
    if (allFeatures.isEmpty) {
      return FeatureStatistics(
        means: {},
        standardDeviations: {},
        minimums: {},
        maximums: {},
      );
    }
    
    final featureNames = allFeatures.first.keys.toList();
    final means = <String, double>{};
    final standardDeviations = <String, double>{};
    final minimums = <String, double>{};
    final maximums = <String, double>{};
    
    for (final featureName in featureNames) {
      final values = allFeatures.map((f) => f[featureName] ?? 0.0).toList();
      
      // Calcular estatísticas
      final mean = values.reduce((a, b) => a + b) / values.length;
      final variance = values.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
      final stdDev = math.sqrt(variance);
      final min = values.reduce(math.min);
      final max = values.reduce(math.max);
      
      means[featureName] = mean;
      standardDeviations[featureName] = stdDev;
      minimums[featureName] = min;
      maximums[featureName] = max;
    }
    
    debugPrint('FeatureEngineer: Estatísticas calculadas para ${featureNames.length} características');
    
    return FeatureStatistics(
      means: means,
      standardDeviations: standardDeviations,
      minimums: minimums,
      maximums: maximums,
    );
  }
  
  /// Normaliza características usando Z-score
  List<double> _normalizeFeatures(Map<String, double> features) {
    if (_statistics == null || _featureNames == null) {
      throw Exception('Estatísticas não calculadas');
    }
    
    final normalized = <double>[];
    
    for (final featureName in _featureNames!) {
      final value = features[featureName] ?? 0.0;
      final mean = _statistics!.means[featureName] ?? 0.0;
      final stdDev = _statistics!.standardDeviations[featureName] ?? 1.0;
      
      // Z-score normalization
      final normalizedValue = stdDev > 0 ? (value - mean) / stdDev : 0.0;
      
      // Clamp para evitar valores extremos
      final clampedValue = math.max(-5.0, math.min(5.0, normalizedValue));
      
      normalized.add(clampedValue);
    }
    
    return normalized;
  }
  
  /// Normaliza uma única amostra usando estatísticas existentes
  List<double>? normalizeSingleSample(MLDataSample sample) {
    if (_statistics == null || _featureNames == null) {
      return null;
    }
    
    final combinedFeatures = <String, double>{};
    combinedFeatures.addAll(sample.sensorFeatures);
    combinedFeatures.addAll(sample.contextFeatures);
    combinedFeatures.addAll(sample.preprocessingFeatures);
    combinedFeatures.addAll(_extractDerivedFeatures(sample));
    
    return _normalizeFeatures(combinedFeatures);
  }
  
  /// Divide dados em treino e teste
  Map<String, List<ProcessedFeatures>> splitTrainTest(
    List<ProcessedFeatures> samples, {
    double trainRatio = 0.8,
    int? randomSeed,
  }) {
    final random = randomSeed != null ? math.Random(randomSeed) : math.Random();
    final shuffled = List<ProcessedFeatures>.from(samples)..shuffle(random);
    
    final trainSize = (samples.length * trainRatio).round();
    final trainSamples = shuffled.take(trainSize).toList();
    final testSamples = shuffled.skip(trainSize).toList();
    
    debugPrint('FeatureEngineer: Divisão treino/teste: ${trainSamples.length}/${testSamples.length}');
    
    return {
      'train': trainSamples,
      'test': testSamples,
    };
  }
  
  /// Balanceia dataset para ter proporção igual de classes
  List<ProcessedFeatures> balanceDataset(List<ProcessedFeatures> samples) {
    final positives = samples.where((s) => s.target > 0.5).toList();
    final negatives = samples.where((s) => s.target <= 0.5).toList();
    
    final minSize = math.min(positives.length, negatives.length);
    
    if (minSize == 0) {
      debugPrint('FeatureEngineer: Não é possível balancear - uma classe está vazia');
      return samples;
    }
    
    // Embaralhar e pegar amostras iguais de cada classe
    positives.shuffle();
    negatives.shuffle();
    
    final balanced = <ProcessedFeatures>[];
    balanced.addAll(positives.take(minSize));
    balanced.addAll(negatives.take(minSize));
    
    // Embaralhar resultado final
    balanced.shuffle();
    
    debugPrint('FeatureEngineer: Dataset balanceado: ${balanced.length} amostras (${minSize} de cada classe)');
    
    return balanced;
  }
  
  /// Obtém estatísticas das características
  FeatureStatistics? get statistics => _statistics;
  
  /// Obtém nomes das características
  List<String>? get featureNames => _featureNames;
  
  /// Define estatísticas manualmente (para carregar modelo treinado)
  void setStatistics(FeatureStatistics statistics) {
    _statistics = statistics;
    _featureNames = statistics.means.keys.toList()..sort();
    debugPrint('FeatureEngineer: Estatísticas carregadas com ${_featureNames!.length} características');
  }
  
  /// Obtém informações sobre as características
  Map<String, dynamic> getFeatureInfo() {
    return {
      'hasStatistics': _statistics != null,
      'featureCount': _featureNames?.length ?? 0,
      'featureNames': _featureNames,
      'statistics': _statistics?.toMap(),
    };
  }
}

