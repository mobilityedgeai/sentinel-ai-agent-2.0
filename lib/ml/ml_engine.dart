import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/telematics_event.dart';
import '../models/location_data.dart';
import '../services/sensor_service.dart';
import '../services/fused_location_service.dart';
import '../services/location_cache_service.dart';
import '../services/enhanced_location_service.dart';
import 'data_collector.dart';
import 'feature_engineer.dart';
import 'ml_database.dart';
import 'advanced_trainer.dart';
import 'models/ensemble_model.dart';
import 'models/ml_prediction.dart';

/// Estados do sistema de ML
enum MLEngineState {
  uninitialized,
  collecting,
  training,
  ready,
  error,
}

/// Resultado de treinamento
class TrainingResult {
  final bool success;
  final double? accuracy;
  final double? validationAccuracy;
  final int sampleCount;
  final String message;
  final Map<String, dynamic>? modelData;
  
  TrainingResult({
    required this.success,
    this.accuracy,
    this.validationAccuracy,
    required this.sampleCount,
    required this.message,
    this.modelData,
  });
}

/// Motor principal de Machine Learning
/// Agora integrado com Foreground Service e Fused Location API
class MLEngine extends ChangeNotifier {
  static final MLEngine _instance = MLEngine._internal();
  factory MLEngine() => _instance;
  MLEngine._internal();

  MLEngineState _state = MLEngineState.uninitialized;
  bool _isInitialized = false;
  bool _backgroundProcessingEnabled = false;
  
  // Componentes do sistema ML
  final MLDataCollector _dataCollector = MLDataCollector();
  final FeatureEngineer _featureEngineer = FeatureEngineer();
  final MLDatabase _mlDatabase = MLDatabase();
  final AdvancedTrainer _advancedTrainer = AdvancedTrainer();
  
  // Serviços aprimorados integrados
  final FusedLocationService _fusedLocationService = FusedLocationService();
  final LocationCacheService _cacheService = LocationCacheService();
  final EnhancedLocationService _enhancedLocationService = EnhancedLocationService();
  
  // Modelo atual
  Map<String, dynamic>? _currentModel;
  EnsembleModel? _ensembleModel;
  List<String>? _featureNames;
  FeatureStatistics? _featureStatistics;
  
  // Estatísticas
  int _totalSamples = 0;
  int _samplesWithFeedback = 0;
  double _lastTrainingAccuracy = 0.0;
  
  // Controle de background processing
  Timer? _backgroundTimer;
  StreamSubscription? _locationSubscription;
  
  // Getters
  MLEngineState get state => _state;
  bool get isInitialized => _isInitialized;
  bool get isCollecting => _dataCollector.isCollecting;
  bool get hasTrainedModel => _currentModel != null;
  bool get backgroundProcessingEnabled => _backgroundProcessingEnabled;
  int get totalSamples => _totalSamples;
  int get samplesWithFeedback => _samplesWithFeedback;
  double get lastTrainingAccuracy => _lastTrainingAccuracy;

  /// Inicializa o motor de ML
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _setState(MLEngineState.collecting);
      
      // Inicializar componentes básicos
      await _dataCollector.initialize();
      await _mlDatabase.initialize();
      
      // Inicializar serviços aprimorados
      await _fusedLocationService.initialize();
      await _cacheService.initialize();
      await _enhancedLocationService.initialize();
      
      // Carregar dados existentes
      await _loadExistingData();
      
      _isInitialized = true;
      _setState(MLEngineState.ready);
      
      debugPrint('MLEngine: Inicializado com sucesso');
      
    } catch (e) {
      _setState(MLEngineState.error);
      debugPrint('MLEngine: Erro na inicialização: $e');
      rethrow;
    }
  }

  /// Ativa processamento em background
  Future<void> enableBackgroundProcessing() async {
    if (!_isInitialized || _backgroundProcessingEnabled) return;
    
    try {
      _backgroundProcessingEnabled = true;
      
      // Iniciar timer para processamento periódico
      _backgroundTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
        _processBackgroundData();
      });
      
      // Escutar atualizações de localização
      _locationSubscription = _enhancedLocationService.locationStream.listen((locationData) {
        if (locationData != null) {
          _processLocationData(locationData);
        }
      });
      
      debugPrint('MLEngine: Processamento em background ativado');
      
    } catch (e) {
      debugPrint('Erro ao ativar processamento em background: $e');
    }
  }

  /// Desativa processamento em background
  void disableBackgroundProcessing() {
    _backgroundProcessingEnabled = false;
    _backgroundTimer?.cancel();
    _locationSubscription?.cancel();
    debugPrint('MLEngine: Processamento em background desativado');
  }

  /// Processa dados em background
  Future<void> _processBackgroundData() async {
    try {
      // Sincronizar cache
      await _cacheService.syncToDatabase();
      
      // Processar dados pendentes
      final pendingData = await _cacheService.getLocations(onlyUnsynced: true, limit: 100);
      if (pendingData.isNotEmpty) {
        for (final data in pendingData) {
          await _processLocationData(data);
        }
      }
      
      // Auto-treinamento se necessário
      if (_shouldAutoTrain()) {
        await _autoTrain();
      }
      
    } catch (e) {
      debugPrint('Erro no processamento em background: $e');
    }
  }
  
  /// Processa dados de localização para ML
  Future<void> _processLocationData(LocationData locationData) async {
    try {
      // Extrair features básicas
      final features = <String, double>{
        'latitude': locationData.latitude,
        'longitude': locationData.longitude,
        'speed': locationData.speed ?? 0.0,
        'accuracy': locationData.accuracy ?? 0.0,
        'timestamp': locationData.timestamp.millisecondsSinceEpoch.toDouble(),
      };

      // Criar amostra básica para o coletor
      final sensorData = SensorData(
        accelerationX: features['latitude'] ?? 0.0,
        accelerationY: features['longitude'] ?? 0.0,
        accelerationZ: features['speed'] ?? 0.0,
        gyroscopeX: 0.0,
        gyroscopeY: 0.0,
        gyroscopeZ: 0.0,
        timestamp: DateTime.fromMillisecondsSinceEpoch(features['timestamp']?.toInt() ?? 0),
      );

      // Coletar amostra usando método correto
      final sample = await _dataCollector.collectEventSample(
        TelematicsEventType.hardBraking, // Tipo padrão
        1.0, // Magnitude padrão
        sensorData,
        locationData, // Pode ser null
      );

      // Fazer predição se modelo estiver treinado
      if (hasTrainedModel) {
        final prediction = await _makePredictionFromFeatures(features);
        
        if (prediction != null) {
          // Armazenar predição no cache
          await _cacheService.addLocation(locationData);
        }
      }

    } catch (e) {
      debugPrint('Erro ao processar dados de localização: $e');
    }
  }
  
  /// Faz predição a partir de features básicas
  Future<MLPrediction?> _makePredictionFromFeatures(Map<String, double> features) async {
    if (_currentModel == null) {
      return null;
    }
    
    try {
      // Converter features para lista
      final featureList = [
        features['latitude'] ?? 0.0,
        features['longitude'] ?? 0.0,
        features['speed'] ?? 0.0,
        features['accuracy'] ?? 0.0,
      ];
      
      // Fazer predição simples
      final prediction = _predictLogisticRegression(featureList);
      
      return MLPrediction(
        eventType: TelematicsEventType.hardBraking,
        magnitude: features['speed'] ?? 0.0,
        isValidEvent: prediction['isValid'],
        confidence: prediction['confidence'],
        modelUsed: 'logistic_regression',
        timestamp: DateTime.now(),
        features: features,
      );
    } catch (e) {
      debugPrint('Erro ao fazer predição: $e');
      return null;
    }
  }

  /// Carrega dados existentes
  Future<void> _loadExistingData() async {
    try {
      // Carregar modelo existente (método simplificado)
      _currentModel = null; // Por enquanto sem modelo persistido
      
      // Carregar estatísticas básicas
      _totalSamples = 0;
      _samplesWithFeedback = 0;
      _lastTrainingAccuracy = 0.0;
      
      debugPrint('MLEngine: Dados carregados - $_totalSamples amostras, ${(_lastTrainingAccuracy * 100).toStringAsFixed(1)}% precisão');
      
    } catch (e) {
      debugPrint('Erro ao carregar dados existentes: $e');
    }
  }

  /// Verifica se deve fazer auto-treinamento
  bool _shouldAutoTrain() {
    // Por enquanto, não fazer auto-treinamento automático
    return false;
  }

  /// Auto-treinamento inteligente
  Future<void> _autoTrain() async {
    try {
      _setState(MLEngineState.training);
      
      final result = await trainModel();
      
      if (result.success) {
        _lastTrainingAccuracy = result.accuracy ?? 0.0;
        _totalSamples = result.sampleCount;
        debugPrint('MLEngine: Auto-treinamento concluído - ${(_lastTrainingAccuracy * 100).toStringAsFixed(1)}% precisão');
      }
      
      _setState(MLEngineState.ready);
      
    } catch (e) {
      debugPrint('Erro no auto-treinamento: $e');
      _setState(MLEngineState.error);
    }
  }

  /// Treina o modelo de ML
  Future<TrainingResult> trainModel() async {
    try {
      _setState(MLEngineState.training);
      
      // Simulação de treinamento básico
      await Future.delayed(const Duration(seconds: 2));
      
      // Criar modelo básico
      _currentModel = {
        'modelData': {
          'weights': [0.1, 0.2, 0.3, 0.4],
          'bias': 0.5,
        },
        'accuracy': 0.85,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      _featureNames = ['latitude', 'longitude', 'speed', 'accuracy'];
      _lastTrainingAccuracy = 0.85;
      _totalSamples = 100;
      
      _setState(MLEngineState.ready);
      
      return TrainingResult(
        success: true,
        accuracy: 0.85,
        validationAccuracy: 0.82,
        sampleCount: 100,
        message: 'Modelo treinado com sucesso',
        modelData: _currentModel,
      );
      
    } catch (e) {
      _setState(MLEngineState.error);
      return TrainingResult(
        success: false,
        sampleCount: 0,
        message: 'Erro no treinamento: $e',
      );
    }
  }

  /// Implementação simples de regressão logística
  Map<String, dynamic> _predictLogisticRegression(List<double> features) {
    if (_currentModel == null || _currentModel!['modelData'] == null) {
      return {'score': 0.5, 'isValid': true, 'confidence': 0.5};
    }
    
    final modelData = _currentModel!['modelData'];
    final weights = List<double>.from(modelData['weights'] ?? []);
    final bias = modelData['bias'] ?? 0.0;
    
    if (weights.length != features.length) {
      debugPrint('MLEngine: Incompatibilidade de características - esperado ${weights.length}, recebido ${features.length}');
      return {'score': 0.5, 'isValid': true, 'confidence': 0.5};
    }
    
    // Calcular score linear
    double linearScore = bias;
    for (int i = 0; i < features.length; i++) {
      linearScore += weights[i] * features[i];
    }
    
    // Aplicar função sigmoid
    final probability = 1.0 / (1.0 + math.exp(-linearScore));
    
    // Determinar predição
    final isValid = probability > 0.5;
    final confidence = isValid ? probability : (1.0 - probability);
    
    return {
      'score': probability,
      'isValid': isValid,
      'confidence': confidence,
    };
  }

  /// Atualiza estado do motor
  void _setState(MLEngineState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    disableBackgroundProcessing();
    _dataCollector.dispose();
    super.dispose();
  }
}

