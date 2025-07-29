import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../feature_engineer.dart';

/// Resultado de predição de um modelo individual
class ModelPrediction {
  final String modelName;
  final double score;
  final bool isValid;
  final double confidence;
  final Map<String, dynamic> metadata;
  
  ModelPrediction({
    required this.modelName,
    required this.score,
    required this.isValid,
    required this.confidence,
    this.metadata = const {},
  });
}

/// Resultado de predição do ensemble
class EnsemblePrediction {
  final double finalScore;
  final bool isValid;
  final double confidence;
  final List<ModelPrediction> individualPredictions;
  final Map<String, double> modelWeights;
  final String strategy;
  
  EnsemblePrediction({
    required this.finalScore,
    required this.isValid,
    required this.confidence,
    required this.individualPredictions,
    required this.modelWeights,
    required this.strategy,
  });
}

/// Estratégias de combinação de modelos
enum EnsembleStrategy {
  voting,           // Votação majoritária
  weightedAverage,  // Média ponderada
  stacking,         // Meta-modelo
  adaptive,         // Adaptativo baseado em confiança
}

/// Modelo ensemble que combina múltiplos algoritmos de ML
class EnsembleModel {
  final Map<String, Map<String, dynamic>> _models = {};
  final Map<String, double> _modelWeights = {};
  final Map<String, double> _modelAccuracies = {};
  EnsembleStrategy _strategy = EnsembleStrategy.adaptive;
  
  /// Adiciona um modelo ao ensemble
  void addModel(
    String name,
    Map<String, dynamic> modelData,
    double accuracy, {
    double? weight,
  }) {
    _models[name] = modelData;
    _modelAccuracies[name] = accuracy;
    _modelWeights[name] = weight ?? accuracy; // Peso padrão baseado na acurácia
    
    debugPrint('EnsembleModel: Modelo $name adicionado (acurácia: ${(accuracy * 100).toStringAsFixed(1)}%)');
  }
  
  /// Remove um modelo do ensemble
  void removeModel(String name) {
    _models.remove(name);
    _modelAccuracies.remove(name);
    _modelWeights.remove(name);
    
    debugPrint('EnsembleModel: Modelo $name removido');
  }
  
  /// Define estratégia de combinação
  void setStrategy(EnsembleStrategy strategy) {
    _strategy = strategy;
    debugPrint('EnsembleModel: Estratégia alterada para ${strategy.toString().split('.').last}');
  }
  
  /// Faz predição usando ensemble
  EnsemblePrediction predict(List<double> features) {
    if (_models.isEmpty) {
      throw Exception('Nenhum modelo no ensemble');
    }
    
    // Obter predições individuais
    final individualPredictions = <ModelPrediction>[];
    
    for (final entry in _models.entries) {
      final modelName = entry.key;
      final modelData = entry.value;
      
      try {
        final prediction = _predictWithModel(modelName, modelData, features);
        individualPredictions.add(prediction);
      } catch (e) {
        debugPrint('Erro ao fazer predição com modelo $modelName: $e');
      }
    }
    
    if (individualPredictions.isEmpty) {
      throw Exception('Nenhuma predição válida obtida');
    }
    
    // Combinar predições baseado na estratégia
    return _combinepredictions(individualPredictions);
  }
  
  /// Faz predição com um modelo específico
  ModelPrediction _predictWithModel(
    String modelName,
    Map<String, dynamic> modelData,
    List<double> features,
  ) {
    final algorithm = modelData['algorithm'] as String;
    
    switch (algorithm) {
      case 'logistic_regression':
        return _predictLogisticRegression(modelName, modelData, features);
      case 'naive_bayes':
        return _predictNaiveBayes(modelName, modelData, features);
      case 'decision_tree':
        return _predictDecisionTree(modelName, modelData, features);
      case 'svm':
        return _predictSVM(modelName, modelData, features);
      default:
        throw Exception('Algoritmo não suportado: $algorithm');
    }
  }
  
  /// Predição com regressão logística
  ModelPrediction _predictLogisticRegression(
    String modelName,
    Map<String, dynamic> modelData,
    List<double> features,
  ) {
    final weights = List<double>.from(modelData['weights']);
    final bias = modelData['bias'] as double;
    
    if (weights.length != features.length) {
      throw Exception('Incompatibilidade de características');
    }
    
    double linearScore = bias;
    for (int i = 0; i < features.length; i++) {
      linearScore += weights[i] * features[i];
    }
    
    final probability = 1.0 / (1.0 + math.exp(-linearScore));
    final isValid = probability > 0.5;
    final confidence = isValid ? probability : (1.0 - probability);
    
    return ModelPrediction(
      modelName: modelName,
      score: probability,
      isValid: isValid,
      confidence: confidence,
      metadata: {'algorithm': 'logistic_regression', 'linearScore': linearScore},
    );
  }
  
  /// Predição com Naive Bayes
  ModelPrediction _predictNaiveBayes(
    String modelName,
    Map<String, dynamic> modelData,
    List<double> features,
  ) {
    final classPriors = Map<String, double>.from(modelData['classPriors']);
    final featureMeans = Map<String, List<double>>.from(
      modelData['featureMeans'].map((k, v) => MapEntry(k, List<double>.from(v)))
    );
    final featureStds = Map<String, List<double>>.from(
      modelData['featureStds'].map((k, v) => MapEntry(k, List<double>.from(v)))
    );
    
    double logProbValid = math.log(classPriors['valid'] ?? 0.5);
    double logProbInvalid = math.log(classPriors['invalid'] ?? 0.5);
    
    // Calcular log-probabilidades para cada característica
    for (int i = 0; i < features.length; i++) {
      final feature = features[i];
      
      // Classe válida
      final meanValid = featureMeans['valid']![i];
      final stdValid = featureStds['valid']![i];
      logProbValid += _logGaussianProbability(feature, meanValid, stdValid);
      
      // Classe inválida
      final meanInvalid = featureMeans['invalid']![i];
      final stdInvalid = featureStds['invalid']![i];
      logProbInvalid += _logGaussianProbability(feature, meanInvalid, stdInvalid);
    }
    
    // Normalizar probabilidades
    final maxLogProb = math.max(logProbValid, logProbInvalid);
    final probValid = math.exp(logProbValid - maxLogProb);
    final probInvalid = math.exp(logProbInvalid - maxLogProb);
    final totalProb = probValid + probInvalid;
    
    final finalProbValid = probValid / totalProb;
    final isValid = finalProbValid > 0.5;
    final confidence = isValid ? finalProbValid : (1.0 - finalProbValid);
    
    return ModelPrediction(
      modelName: modelName,
      score: finalProbValid,
      isValid: isValid,
      confidence: confidence,
      metadata: {'algorithm': 'naive_bayes'},
    );
  }
  
  /// Predição com árvore de decisão (implementação simplificada)
  ModelPrediction _predictDecisionTree(
    String modelName,
    Map<String, dynamic> modelData,
    List<double> features,
  ) {
    final tree = modelData['tree'] as Map<String, dynamic>;
    
    // Navegar pela árvore
    Map<String, dynamic> currentNode = tree;
    
    while (currentNode.containsKey('featureIndex')) {
      final featureIndex = currentNode['featureIndex'] as int;
      final threshold = currentNode['threshold'] as double;
      final featureValue = features[featureIndex];
      
      if (featureValue <= threshold) {
        currentNode = currentNode['left'] as Map<String, dynamic>;
      } else {
        currentNode = currentNode['right'] as Map<String, dynamic>;
      }
    }
    
    // Nó folha
    final prediction = currentNode['prediction'] as double;
    final confidence = currentNode['confidence'] as double;
    final isValid = prediction > 0.5;
    
    return ModelPrediction(
      modelName: modelName,
      score: prediction,
      isValid: isValid,
      confidence: confidence,
      metadata: {'algorithm': 'decision_tree'},
    );
  }
  
  /// Predição com SVM (implementação simplificada)
  ModelPrediction _predictSVM(
    String modelName,
    Map<String, dynamic> modelData,
    List<double> features,
  ) {
    final supportVectors = List<List<double>>.from(
      modelData['supportVectors'].map((sv) => List<double>.from(sv))
    );
    final alphas = List<double>.from(modelData['alphas']);
    final labels = List<double>.from(modelData['labels']);
    final bias = modelData['bias'] as double;
    final gamma = modelData['gamma'] as double;
    
    double decision = bias;
    
    for (int i = 0; i < supportVectors.length; i++) {
      final sv = supportVectors[i];
      final alpha = alphas[i];
      final label = labels[i];
      
      // Kernel RBF
      double distance = 0.0;
      for (int j = 0; j < features.length; j++) {
        distance += math.pow(features[j] - sv[j], 2);
      }
      final kernelValue = math.exp(-gamma * distance);
      
      decision += alpha * label * kernelValue;
    }
    
    // Converter para probabilidade usando função sigmoid
    final probability = 1.0 / (1.0 + math.exp(-decision));
    final isValid = probability > 0.5;
    final confidence = isValid ? probability : (1.0 - probability);
    
    return ModelPrediction(
      modelName: modelName,
      score: probability,
      isValid: isValid,
      confidence: confidence,
      metadata: {'algorithm': 'svm', 'decision': decision},
    );
  }
  
  /// Calcula log-probabilidade gaussiana
  double _logGaussianProbability(double x, double mean, double std) {
    if (std <= 0) return -double.infinity;
    
    final variance = std * std;
    final logCoeff = -0.5 * math.log(2 * math.pi * variance);
    final logExp = -0.5 * math.pow(x - mean, 2) / variance;
    
    return logCoeff + logExp;
  }
  
  /// Combina predições baseado na estratégia
  EnsemblePrediction _combinepredictions(List<ModelPrediction> predictions) {
    switch (_strategy) {
      case EnsembleStrategy.voting:
        return _combineByVoting(predictions);
      case EnsembleStrategy.weightedAverage:
        return _combineByWeightedAverage(predictions);
      case EnsembleStrategy.stacking:
        return _combineByStacking(predictions);
      case EnsembleStrategy.adaptive:
        return _combineAdaptive(predictions);
    }
  }
  
  /// Combinação por votação majoritária
  EnsemblePrediction _combineByVoting(List<ModelPrediction> predictions) {
    int validVotes = 0;
    int invalidVotes = 0;
    double totalConfidence = 0.0;
    
    for (final prediction in predictions) {
      if (prediction.isValid) {
        validVotes++;
      } else {
        invalidVotes++;
      }
      totalConfidence += prediction.confidence;
    }
    
    final isValid = validVotes > invalidVotes;
    final finalScore = validVotes / predictions.length;
    final confidence = totalConfidence / predictions.length;
    
    return EnsemblePrediction(
      finalScore: finalScore,
      isValid: isValid,
      confidence: confidence,
      individualPredictions: predictions,
      modelWeights: _modelWeights,
      strategy: 'voting',
    );
  }
  
  /// Combinação por média ponderada
  EnsemblePrediction _combineByWeightedAverage(List<ModelPrediction> predictions) {
    double weightedSum = 0.0;
    double totalWeight = 0.0;
    double weightedConfidence = 0.0;
    
    for (final prediction in predictions) {
      final weight = _modelWeights[prediction.modelName] ?? 1.0;
      weightedSum += prediction.score * weight;
      weightedConfidence += prediction.confidence * weight;
      totalWeight += weight;
    }
    
    final finalScore = totalWeight > 0 ? weightedSum / totalWeight : 0.5;
    final confidence = totalWeight > 0 ? weightedConfidence / totalWeight : 0.5;
    final isValid = finalScore > 0.5;
    
    return EnsemblePrediction(
      finalScore: finalScore,
      isValid: isValid,
      confidence: confidence,
      individualPredictions: predictions,
      modelWeights: _modelWeights,
      strategy: 'weighted_average',
    );
  }
  
  /// Combinação por stacking (meta-modelo simples)
  EnsemblePrediction _combineByStacking(List<ModelPrediction> predictions) {
    // Implementação simplificada: média ponderada pela acurácia
    double weightedSum = 0.0;
    double totalWeight = 0.0;
    double weightedConfidence = 0.0;
    
    for (final prediction in predictions) {
      final accuracy = _modelAccuracies[prediction.modelName] ?? 0.5;
      final weight = accuracy * accuracy; // Peso quadrático pela acurácia
      
      weightedSum += prediction.score * weight;
      weightedConfidence += prediction.confidence * weight;
      totalWeight += weight;
    }
    
    final finalScore = totalWeight > 0 ? weightedSum / totalWeight : 0.5;
    final confidence = totalWeight > 0 ? weightedConfidence / totalWeight : 0.5;
    final isValid = finalScore > 0.5;
    
    return EnsemblePrediction(
      finalScore: finalScore,
      isValid: isValid,
      confidence: confidence,
      individualPredictions: predictions,
      modelWeights: _modelWeights,
      strategy: 'stacking',
    );
  }
  
  /// Combinação adaptativa baseada em confiança
  EnsemblePrediction _combineAdaptive(List<ModelPrediction> predictions) {
    // Filtrar predições de alta confiança
    final highConfidencePredictions = predictions
        .where((p) => p.confidence > 0.7)
        .toList();
    
    // Se temos predições de alta confiança, usar apenas elas
    final finalPredictions = highConfidencePredictions.isNotEmpty 
        ? highConfidencePredictions 
        : predictions;
    
    // Usar média ponderada pela confiança
    double weightedSum = 0.0;
    double totalWeight = 0.0;
    double weightedConfidence = 0.0;
    
    for (final prediction in finalPredictions) {
      final weight = prediction.confidence * prediction.confidence; // Peso quadrático
      
      weightedSum += prediction.score * weight;
      weightedConfidence += prediction.confidence * weight;
      totalWeight += weight;
    }
    
    final finalScore = totalWeight > 0 ? weightedSum / totalWeight : 0.5;
    final confidence = totalWeight > 0 ? weightedConfidence / totalWeight : 0.5;
    final isValid = finalScore > 0.5;
    
    return EnsemblePrediction(
      finalScore: finalScore,
      isValid: isValid,
      confidence: confidence,
      individualPredictions: predictions,
      modelWeights: _modelWeights,
      strategy: 'adaptive',
    );
  }
  
  /// Obtém informações do ensemble
  Map<String, dynamic> getEnsembleInfo() {
    return {
      'modelCount': _models.length,
      'models': _models.keys.toList(),
      'accuracies': _modelAccuracies,
      'weights': _modelWeights,
      'strategy': _strategy.toString().split('.').last,
      'averageAccuracy': _modelAccuracies.isNotEmpty 
        ? _modelAccuracies.values.reduce((a, b) => a + b) / _modelAccuracies.length
        : 0.0,
    };
  }
  
  /// Atualiza pesos dos modelos baseado em performance
  void updateWeights(Map<String, double> newAccuracies) {
    for (final entry in newAccuracies.entries) {
      final modelName = entry.key;
      final accuracy = entry.value;
      
      if (_models.containsKey(modelName)) {
        _modelAccuracies[modelName] = accuracy;
        _modelWeights[modelName] = accuracy;
      }
    }
    
    debugPrint('EnsembleModel: Pesos atualizados');
  }
  
  /// Converte para Map para persistência
  Map<String, dynamic> toMap() {
    return {
      'models': _models,
      'weights': _modelWeights,
      'accuracies': _modelAccuracies,
      'strategy': _strategy.toString().split('.').last,
    };
  }
  
  /// Carrega de Map
  void fromMap(Map<String, dynamic> map) {
    _models.clear();
    _modelWeights.clear();
    _modelAccuracies.clear();
    
    _models.addAll(Map<String, Map<String, dynamic>>.from(map['models'] ?? {}));
    _modelWeights.addAll(Map<String, double>.from(map['weights'] ?? {}));
    _modelAccuracies.addAll(Map<String, double>.from(map['accuracies'] ?? {}));
    
    final strategyString = map['strategy'] as String? ?? 'adaptive';
    _strategy = EnsembleStrategy.values.firstWhere(
      (s) => s.toString().split('.').last == strategyString,
      orElse: () => EnsembleStrategy.adaptive,
    );
    
    debugPrint('EnsembleModel: Carregado com ${_models.length} modelos');
  }
}

