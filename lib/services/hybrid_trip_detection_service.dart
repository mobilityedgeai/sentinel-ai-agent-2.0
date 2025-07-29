import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/location_data.dart';
import '../models/trip.dart';
import '../models/telematics_event.dart';
import 'advanced_telematics_analyzer.dart';
import 'smart_driving_mode.dart';
import 'phone_stability_detector.dart';
import 'activity_recognition_service.dart';
import 'sensor_service.dart';
import '../ml/ml_engine.dart';

/// Estados de detecção de viagem
enum TripDetectionState {
  idle,           // Não dirigindo
  analyzing,      // Analisando dados para possível início
  tripActive,     // Viagem ativa
  endAnalyzing,   // Analisando para possível fim
}

/// Resultado da análise híbrida
class HybridAnalysisResult {
  final bool shouldStartTrip;
  final bool shouldEndTrip;
  final double confidence;
  final Map<String, double> algorithmScores;
  final String reasoning;
  
  HybridAnalysisResult({
    required this.shouldStartTrip,
    required this.shouldEndTrip,
    required this.confidence,
    required this.algorithmScores,
    required this.reasoning,
  });
}

/// Serviço híbrido inteligente que combina todos os algoritmos avançados
/// para detecção ultra-precisa de início e fim de viagens
class HybridTripDetectionService extends ChangeNotifier {
  static final HybridTripDetectionService _instance = HybridTripDetectionService._internal();
  factory HybridTripDetectionService() => _instance;
  HybridTripDetectionService._internal();

  // Estado atual
  TripDetectionState _state = TripDetectionState.idle;
  bool _isInitialized = false;
  
  // Algoritmos integrados
  final AdvancedTelematicsAnalyzer _telematicsAnalyzer = AdvancedTelematicsAnalyzer();
  final SmartDrivingMode _smartDrivingMode = SmartDrivingMode();
  final PhoneStabilityDetector _stabilityDetector = PhoneStabilityDetector();
  final ActivityRecognitionService _activityRecognition = ActivityRecognitionService();
  final MLEngine _mlEngine = MLEngine();
  final SensorService _sensorService = SensorService();
  
  // Histórico de dados para análise
  final List<LocationData> _locationHistory = [];
  final List<SensorData> _sensorHistory = [];
  final List<ActivityResult> _activityHistory = [];
  final List<double> _stabilityHistory = [];
  
  // Configurações de análise
  static const int _maxHistorySize = 50;
  static const int _minDataPointsForAnalysis = 10;
  static const double _confidenceThreshold = 0.6;
  
  // Timers para análise contínua
  Timer? _analysisTimer;
  Timer? _tripEndTimer;
  DateTime? _potentialTripEndTime;
  
  // Callbacks
  Function(Trip)? onTripStarted;
  Function(Trip)? onTripEnded;
  Function(HybridAnalysisResult)? onAnalysisUpdate;
  
  // Getters
  TripDetectionState get state => _state;
  bool get isInitialized => _isInitialized;
  bool get isTripActive => _state == TripDetectionState.tripActive;
  
  /// Inicializa todos os algoritmos
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('🧠 Inicializando sistema híbrido de detecção de viagens...');
      
      // Inicializar todos os algoritmos
      await _telematicsAnalyzer.initialize();
      await _smartDrivingMode.initialize();
      await _stabilityDetector.initialize();
      await _activityRecognition.initialize();
      await _mlEngine.initialize();
      // _sensorService não tem initialize
      
      // Configurar listeners
      _setupListeners();
      
      // Iniciar análise contínua
      _startContinuousAnalysis();
      
      _isInitialized = true;
      debugPrint('✅ Sistema híbrido inicializado com sucesso');
      
    } catch (e) {
      debugPrint('❌ Erro ao inicializar sistema híbrido: $e');
    }
  }
  
  /// Configura listeners para todos os serviços
  void _setupListeners() {
    // Listener de atividade
    _activityRecognition.activityStream.listen((activity) {
      _activityHistory.add(activity);
      if (_activityHistory.length > _maxHistorySize) {
        _activityHistory.removeAt(0);
      }
      _triggerAnalysis();
    });
    
    // Listener de sensores - comentado pois SensorService não tem sensorStream
    // _sensorService.sensorStream.listen((sensorData) {
    //   _sensorHistory.add(sensorData);
    //   if (_sensorHistory.length > _maxHistorySize) {
    //     _sensorHistory.removeAt(0);
    //   }
    // });
  }
  
  /// Inicia análise contínua
  void _startContinuousAnalysis() {
    _analysisTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _triggerAnalysis();
    });
  }
  
  /// Adiciona nova localização para análise
  void addLocationData(LocationData location) {
    if (!_isInitialized) return;
    
    _locationHistory.add(location);
    if (_locationHistory.length > _maxHistorySize) {
      _locationHistory.removeAt(0);
    }
    
    // Alimentar algoritmos individuais
    _telematicsAnalyzer.addLocationData(location);
    
    // Triggerar análise
    _triggerAnalysis();
  }
  
  /// Executa análise híbrida completa
  void _triggerAnalysis() async {
    if (_locationHistory.length < _minDataPointsForAnalysis) return;
    
    try {
      // Executar análise híbrida
      final result = await _performHybridAnalysis();
      
      // Notificar listeners
      onAnalysisUpdate?.call(result);
      
      // Tomar decisões baseadas no resultado
      await _processAnalysisResult(result);
      
    } catch (e) {
      debugPrint('❌ Erro na análise híbrida: $e');
    }
  }
  
  /// Executa análise híbrida combinando todos os algoritmos
  Future<HybridAnalysisResult> _performHybridAnalysis() async {
    final Map<String, double> scores = {};
    final List<String> reasoning = [];
    
    // 1. ANÁLISE DE VELOCIDADE E MOVIMENTO
    final speedScore = _analyzeSpeedPatterns();
    scores['speed'] = speedScore;
    reasoning.add('Velocidade: ${(speedScore * 100).toStringAsFixed(1)}%');
    
    // 2. ANÁLISE DE ATIVIDADE
    final activityScore = _analyzeActivityPatterns();
    scores['activity'] = activityScore;
    reasoning.add('Atividade: ${(activityScore * 100).toStringAsFixed(1)}%');
    
    // 3. ANÁLISE DE ESTABILIDADE DO TELEFONE
    final stabilityScore = await _analyzePhoneStability();
    scores['stability'] = stabilityScore;
    reasoning.add('Estabilidade: ${(stabilityScore * 100).toStringAsFixed(1)}%');
    
    // 4. ANÁLISE TELEMÁTICA AVANÇADA
    final telematicsScore = _analyzeTelematicsPatterns();
    scores['telematics'] = telematicsScore;
    reasoning.add('Telemática: ${(telematicsScore * 100).toStringAsFixed(1)}%');
    
    // 5. CONTEXTO DE DIREÇÃO INTELIGENTE
    final contextScore = await _analyzeSmartContext();
    scores['context'] = contextScore;
    reasoning.add('Contexto: ${(contextScore * 100).toStringAsFixed(1)}%');
    
    // 6. PREDIÇÃO DE MACHINE LEARNING
    final mlScore = await _analyzeMLPrediction();
    scores['ml'] = mlScore;
    reasoning.add('ML: ${(mlScore * 100).toStringAsFixed(1)}%');
    
    // COMBINAR SCORES COM PESOS OTIMIZADOS
    final finalScore = _combineScores(scores);
    
    // DETERMINAR AÇÕES
    bool shouldStartTrip = false;
    bool shouldEndTrip = false;
    
    if (_state == TripDetectionState.idle || _state == TripDetectionState.analyzing) {
      shouldStartTrip = finalScore > 0.6; // Reduzido de 0.8 para 0.6
    } else if (_state == TripDetectionState.tripActive || _state == TripDetectionState.endAnalyzing) {
      shouldEndTrip = finalScore < 0.4; // Aumentado de 0.3 para 0.4
    }
    
    return HybridAnalysisResult(
      shouldStartTrip: shouldStartTrip,
      shouldEndTrip: shouldEndTrip,
      confidence: finalScore,
      algorithmScores: scores,
      reasoning: reasoning.join(', '),
    );
  }
  
  /// Analisa padrões de velocidade
  double _analyzeSpeedPatterns() {
    if (_locationHistory.length < 5) return 0.5;
    
    final speeds = _locationHistory.map((l) => l.speed ?? 0.0).toList();
    final avgSpeed = speeds.reduce((a, b) => a + b) / speeds.length;
    final maxSpeed = speeds.reduce(math.max);
    
    debugPrint('🚗 Análise de velocidade: Média=${avgSpeed.toStringAsFixed(1)} km/h, Máxima=${maxSpeed.toStringAsFixed(1)} km/h');
    
    // Score baseado em velocidade média e máxima - AJUSTADO PARA CONDIÇÕES URBANAS
    if (avgSpeed > 12.0 && maxSpeed > 20.0) {
      return 0.9; // Claramente dirigindo em estrada
    } else if (avgSpeed > 8.0 && maxSpeed > 15.0) {
      return 0.8; // Dirigindo em cidade
    } else if (avgSpeed > 5.0 && maxSpeed > 12.0) {
      return 0.7; // Dirigindo devagar ou trânsito
    } else if (avgSpeed > 3.0 && maxSpeed > 8.0) {
      return 0.4; // Possivelmente caminhando/ciclismo
    } else if (avgSpeed > 1.0 && maxSpeed > 5.0) {
      return 0.2; // Movimento muito lento
    } else {
      return 0.1; // Parado ou GPS impreciso
    }
  }
  
  /// Analisa padrões de atividade
  double _analyzeActivityPatterns() {
    if (_activityHistory.isEmpty) {
      debugPrint('🎯 Análise de atividade: Sem dados - usando fallback baseado em velocidade');
      // Fallback: usar velocidade como proxy para atividade
      if (_locationHistory.isNotEmpty) {
        final avgSpeed = _locationHistory.map((l) => l.speed ?? 0.0).reduce((a, b) => a + b) / _locationHistory.length;
        if (avgSpeed > 8.0) return 0.7; // Provavelmente dirigindo
        if (avgSpeed > 3.0) return 0.3; // Possivelmente caminhando
        return 0.1; // Parado
      }
      return 0.5; // Score neutro quando não há dados
    }
    
    final recentActivities = _activityHistory.take(10).toList();
    int drivingCount = 0;
    int walkingCount = 0;
    int stillCount = 0;
    
    for (final activity in recentActivities) {
      switch (activity.type) {
        case ActivityType.driving:
          drivingCount++;
          break;
        case ActivityType.walking:
          walkingCount++;
          break;
        case ActivityType.still:
          stillCount++;
          break;
        default:
          break;
      }
    }
    
    final total = recentActivities.length;
    if (total == 0) return 0.5;
    
    final drivingRatio = drivingCount / total;
    final walkingRatio = walkingCount / total;
    final stillRatio = stillCount / total;
    
    debugPrint('🎯 Análise de atividade: Dirigindo=${(drivingRatio*100).toStringAsFixed(0)}%, Caminhando=${(walkingRatio*100).toStringAsFixed(0)}%, Parado=${(stillRatio*100).toStringAsFixed(0)}%');
    
    if (drivingRatio > 0.6) {
      return 0.9; // Maioria dirigindo
    } else if (drivingRatio > 0.3) {
      return 0.7; // Parcialmente dirigindo
    } else if (walkingRatio > 0.6) {
      return 0.2; // Maioria caminhando
    } else if (stillRatio > 0.6) {
      return 0.1; // Maioria parado
    } else {
      return 0.5; // Misto
    }
  }
  
  /// Analisa estabilidade do telefone
  Future<double> _analyzePhoneStability() async {
    if (_sensorHistory.isEmpty) {
      debugPrint('📱 Análise de estabilidade: Sem dados de sensor - usando fallback');
      // Fallback: assumir estabilidade média baseada em velocidade
      if (_locationHistory.isNotEmpty) {
        final avgSpeed = _locationHistory.map((l) => l.speed ?? 0.0).reduce((a, b) => a + b) / _locationHistory.length;
        if (avgSpeed > 10.0) return 0.8; // Velocidade alta = provavelmente estável no carro
        if (avgSpeed > 3.0) return 0.4; // Velocidade baixa = possivelmente instável
        return 0.2; // Parado = instável
      }
      return 0.5; // Score neutro quando não há dados
    }
    
    final recentSensor = _sensorHistory.last;
    final stabilityScore = await _stabilityDetector.calculateStabilityScore(recentSensor);
    
    _stabilityHistory.add(stabilityScore);
    if (_stabilityHistory.length > 20) {
      _stabilityHistory.removeAt(0);
    }
    
    // Média dos últimos scores
    final avgStability = _stabilityHistory.reduce((a, b) => a + b) / _stabilityHistory.length;
    
    debugPrint('📱 Análise de estabilidade: Score=${(avgStability*100).toStringAsFixed(1)}%');
    
    return avgStability;
  }
  
  /// Analisa padrões telemáticos
  double _analyzeTelematicsPatterns() {
    // Obter dados do analisador telemático
    final eventCount = _telematicsAnalyzer.getTotalEventCount();
    final safetyScore = _telematicsAnalyzer.calculateSafetyScore();
    
    debugPrint('🚨 Análise telemática: Eventos=${eventCount}, Segurança=${safetyScore.toStringAsFixed(1)}%');
    
    // Score baseado em eventos e segurança
    if (eventCount > 5) {
      return 0.9; // Muitos eventos = definitivamente dirigindo
    } else if (eventCount > 2) {
      return 0.8; // Alguns eventos = provavelmente dirigindo
    } else if (eventCount > 0) {
      return 0.7; // Poucos eventos = possivelmente dirigindo
    } else if (safetyScore < 100 && safetyScore > 80) {
      return 0.6; // Score não perfeito = alguma atividade
    } else if (safetyScore == 100 && eventCount == 0) {
      return 0.3; // Nenhum evento = possivelmente não dirigindo
    } else {
      return 0.5; // Situação intermediária
    }
  }
  
  /// Analisa contexto inteligente
  Future<double> _analyzeSmartContext() async {
    try {
      final context = await _smartDrivingMode.getCurrentContext();
      
      debugPrint('🧠 Análise de contexto: ${context.toString()}');
      
      switch (context) {
        case DrivingContext.ideal:
        case DrivingContext.good:
          return 0.9; // Condições ideais para direção
        case DrivingContext.moderate:
          return 0.7;
        case DrivingContext.challenging:
          return 0.5;
        case DrivingContext.difficult:
          return 0.3;
        case DrivingContext.poor:
          return 0.1; // Condições ruins = provavelmente não dirigindo
        default:
          return 0.5;
      }
    } catch (e) {
      debugPrint('🧠 Análise de contexto: Erro - usando fallback baseado em horário');
      // Fallback: análise baseada em horário
      final hour = DateTime.now().hour;
      if (hour >= 6 && hour <= 9 || hour >= 17 && hour <= 20) {
        return 0.7; // Horário de pico = mais provável estar dirigindo
      } else if (hour >= 10 && hour <= 16) {
        return 0.6; // Horário comercial
      } else if (hour >= 21 && hour <= 23) {
        return 0.5; // Noite
      } else {
        return 0.3; // Madrugada = menos provável
      }
    }
  }
  
  /// Analisa predição de ML
  Future<double> _analyzeMLPrediction() async {
    // MLEngine não tem método predict implementado ainda
    return 0.5; // Score neutro por enquanto
    
    // TODO: Implementar quando MLEngine tiver método predict
    // if (!_mlEngine.hasTrainedModel) return 0.5;
    // 
    // try {
    //   final features = _prepareMLFeatures();
    //   final prediction = await _mlEngine.predict(features);
    //   return prediction.confidence;
    // } catch (e) {
    //   debugPrint('❌ Erro na predição ML: $e');
    //   return 0.5;
    // }
  }
  
  /// Prepara features para ML
  Map<String, double> _prepareMLFeatures() {
    final features = <String, double>{};
    
    if (_locationHistory.isNotEmpty) {
      final speeds = _locationHistory.map((l) => l.speed ?? 0.0).toList();
      features['avg_speed'] = speeds.reduce((a, b) => a + b) / speeds.length;
      features['max_speed'] = speeds.reduce(math.max);
      features['speed_variance'] = _calculateVariance(speeds);
    }
    
    if (_stabilityHistory.isNotEmpty) {
      features['avg_stability'] = _stabilityHistory.reduce((a, b) => a + b) / _stabilityHistory.length;
    }
    
    if (_activityHistory.isNotEmpty) {
      final drivingCount = _activityHistory.where((a) => a.type == ActivityType.driving).length;
      features['driving_ratio'] = drivingCount / _activityHistory.length;
    }
    
    return features;
  }
  
  /// Combina scores com pesos otimizados
  double _combineScores(Map<String, double> scores) {
    final weights = {
      'speed': 0.30,      // Velocidade é mais fundamental
      'activity': 0.20,   // Reconhecimento de atividade é importante
      'stability': 0.15,  // Estabilidade do telefone
      'telematics': 0.15, // Eventos telemáticos
      'context': 0.15,    // Contexto inteligente
      'ml': 0.05,         // ML como complemento menor
    };
    
    double finalScore = 0.0;
    double totalWeight = 0.0;
    
    for (final entry in scores.entries) {
      final weight = weights[entry.key] ?? 0.0;
      finalScore += entry.value * weight;
      totalWeight += weight;
    }
    
    final result = totalWeight > 0 ? finalScore / totalWeight : 0.5;
    
    debugPrint('🔄 Combinação de scores: Final=${(result*100).toStringAsFixed(1)}% | ${scores.entries.map((e) => '${e.key}=${(e.value*100).toStringAsFixed(0)}%').join(', ')}');
    
    return result;
  }
  
  /// Processa resultado da análise
  Future<void> _processAnalysisResult(HybridAnalysisResult result) async {
    debugPrint('🧠 Análise híbrida: ${result.reasoning} | Confiança: ${(result.confidence * 100).toStringAsFixed(1)}%');
    
    if (result.shouldStartTrip && result.confidence > _confidenceThreshold) {
      await _handleTripStart(result);
    } else if (result.shouldEndTrip && result.confidence < (1.0 - _confidenceThreshold)) {
      await _handleTripEnd(result);
    }
  }
  
  /// Manipula início de viagem
  Future<void> _handleTripStart(HybridAnalysisResult result) async {
    if (_state == TripDetectionState.tripActive) return;
    
    _state = TripDetectionState.tripActive;
    debugPrint('🚗 VIAGEM INICIADA PELO SISTEMA HÍBRIDO - Confiança: ${(result.confidence * 100).toStringAsFixed(1)}%');
    
    // Criar trip com dados da localização atual
    if (_locationHistory.isNotEmpty) {
      final startLocation = _locationHistory.last;
      final trip = Trip(
        id: DateTime.now().millisecondsSinceEpoch,
        userId: 1,
        startTime: DateTime.now(),
        startLatitude: startLocation.latitude,
        startLongitude: startLocation.longitude,
        distance: 0.0,
        duration: 0,
        maxSpeed: 0.0,
        safetyScore: 100,
      );
      
      onTripStarted?.call(trip);
    }
    
    notifyListeners();
  }
  
  /// Manipula fim de viagem
  Future<void> _handleTripEnd(HybridAnalysisResult result) async {
    if (_state != TripDetectionState.tripActive) return;
    
    // Iniciar timer de confirmação
    if (_potentialTripEndTime == null) {
      _potentialTripEndTime = DateTime.now();
      _state = TripDetectionState.endAnalyzing;
      
      debugPrint('⏳ Possível fim de viagem detectado - Iniciando confirmação...');
      
      // Timer de 60 segundos para confirmar fim
      _tripEndTimer = Timer(const Duration(seconds: 60), () {
        _confirmTripEnd(result);
      });
      
    } else {
      // Verificar se já passou tempo suficiente
      final elapsed = DateTime.now().difference(_potentialTripEndTime!);
      if (elapsed.inSeconds >= 60) {
        _confirmTripEnd(result);
      }
    }
    
    notifyListeners();
  }
  
  /// Confirma fim de viagem
  void _confirmTripEnd(HybridAnalysisResult result) {
    _state = TripDetectionState.idle;
    _potentialTripEndTime = null;
    _tripEndTimer?.cancel();
    
    debugPrint('🏁 VIAGEM FINALIZADA PELO SISTEMA HÍBRIDO - Confiança: ${((1.0 - result.confidence) * 100).toStringAsFixed(1)}%');
    
    // Criar trip finalizada
    if (_locationHistory.isNotEmpty) {
      final endLocation = _locationHistory.last;
      final trip = Trip(
        id: DateTime.now().millisecondsSinceEpoch,
        userId: 1,
        startTime: DateTime.now().subtract(const Duration(minutes: 10)), // Placeholder
        endTime: DateTime.now(),
        endLatitude: endLocation.latitude,
        endLongitude: endLocation.longitude,
        distance: 0.0,
        duration: 10,
        maxSpeed: 0.0,
        safetyScore: 100,
      );
      
      onTripEnded?.call(trip);
    }
    
    notifyListeners();
  }
  
  /// Calcula variância de uma lista de valores
  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values
        .map((x) => math.pow(x - mean, 2))
        .reduce((a, b) => a + b) / values.length;
    
    return variance.toDouble();
  }
  
  /// Para o serviço
  void dispose() {
    _analysisTimer?.cancel();
    _tripEndTimer?.cancel();
    super.dispose();
  }
}

