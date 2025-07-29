import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'feature_engineer.dart';
import 'models/ensemble_model.dart';

/// Resultado de treinamento de um algoritmo específico
class AlgorithmTrainingResult {
  final String algorithmName;
  final bool success;
  final double trainAccuracy;
  final double validationAccuracy;
  final Map<String, dynamic> modelData;
  final String message;
  final Duration trainingTime;
  
  AlgorithmTrainingResult({
    required this.algorithmName,
    required this.success,
    required this.trainAccuracy,
    required this.validationAccuracy,
    required this.modelData,
    required this.message,
    required this.trainingTime,
  });
}

/// Resultado de treinamento completo
class AdvancedTrainingResult {
  final bool success;
  final List<AlgorithmTrainingResult> algorithmResults;
  final EnsembleModel? ensembleModel;
  final double bestAccuracy;
  final String bestAlgorithm;
  final String message;
  final Duration totalTime;
  
  AdvancedTrainingResult({
    required this.success,
    required this.algorithmResults,
    this.ensembleModel,
    required this.bestAccuracy,
    required this.bestAlgorithm,
    required this.message,
    required this.totalTime,
  });
}

/// Sistema de treinamento avançado com múltiplos algoritmos
class AdvancedTrainer {
  static final AdvancedTrainer _instance = AdvancedTrainer._internal();
  factory AdvancedTrainer() => _instance;
  AdvancedTrainer._internal();

  /// Treina múltiplos algoritmos e cria ensemble
  Future<AdvancedTrainingResult> trainMultipleAlgorithms(
    List<ProcessedFeatures> trainSamples,
    List<ProcessedFeatures> validationSamples, {
    List<String>? algorithms,
    bool createEnsemble = true,
    Map<String, dynamic>? hyperparameters,
  }) async {
    final startTime = DateTime.now();
    final algorithmResults = <AlgorithmTrainingResult>[];
    
    // Algoritmos padrão se não especificados
    final algorithmsToTrain = algorithms ?? [
      'logistic_regression',
      'naive_bayes',
      'decision_tree',
      'svm',
    ];
    
    debugPrint('AdvancedTrainer: Iniciando treinamento de ${algorithmsToTrain.length} algoritmos');
    
    // Treinar cada algoritmo
    for (final algorithm in algorithmsToTrain) {
      try {
        final result = await _trainSingleAlgorithm(
          algorithm,
          trainSamples,
          validationSamples,
          hyperparameters?[algorithm] ?? {},
        );
        algorithmResults.add(result);
        
        debugPrint('AdvancedTrainer: $algorithm - Acurácia: ${(result.validationAccuracy * 100).toStringAsFixed(1)}%');
        
      } catch (e) {
        debugPrint('Erro ao treinar $algorithm: $e');
        algorithmResults.add(AlgorithmTrainingResult(
          algorithmName: algorithm,
          success: false,
          trainAccuracy: 0.0,
          validationAccuracy: 0.0,
          modelData: {},
          message: 'Erro: $e',
          trainingTime: Duration.zero,
        ));
      }
    }
    
    // Encontrar melhor algoritmo
    final successfulResults = algorithmResults.where((r) => r.success).toList();
    
    if (successfulResults.isEmpty) {
      return AdvancedTrainingResult(
        success: false,
        algorithmResults: algorithmResults,
        bestAccuracy: 0.0,
        bestAlgorithm: 'none',
        message: 'Nenhum algoritmo foi treinado com sucesso',
        totalTime: DateTime.now().difference(startTime),
      );
    }
    
    // Ordenar por acurácia de validação
    successfulResults.sort((a, b) => b.validationAccuracy.compareTo(a.validationAccuracy));
    final bestResult = successfulResults.first;
    
    // Criar ensemble se solicitado
    EnsembleModel? ensembleModel;
    if (createEnsemble && successfulResults.length > 1) {
      ensembleModel = _createEnsemble(successfulResults);
    }
    
    final totalTime = DateTime.now().difference(startTime);
    
    return AdvancedTrainingResult(
      success: true,
      algorithmResults: algorithmResults,
      ensembleModel: ensembleModel,
      bestAccuracy: bestResult.validationAccuracy,
      bestAlgorithm: bestResult.algorithmName,
      message: 'Treinamento concluído com sucesso',
      totalTime: totalTime,
    );
  }

  /// Treina um algoritmo específico
  Future<AlgorithmTrainingResult> _trainSingleAlgorithm(
    String algorithm,
    List<ProcessedFeatures> trainSamples,
    List<ProcessedFeatures> validationSamples,
    Map<String, dynamic> hyperparameters,
  ) async {
    final startTime = DateTime.now();
    
    Map<String, dynamic> modelData;
    
    switch (algorithm) {
      case 'logistic_regression':
        modelData = await _trainLogisticRegression(trainSamples, hyperparameters);
        break;
      case 'naive_bayes':
        modelData = await _trainNaiveBayes(trainSamples, hyperparameters);
        break;
      case 'decision_tree':
        modelData = await _trainDecisionTree(trainSamples, hyperparameters);
        break;
      case 'svm':
        modelData = await _trainSVM(trainSamples, hyperparameters);
        break;
      default:
        throw Exception('Algoritmo não suportado: $algorithm');
    }
    
    // Avaliar modelo
    final trainAccuracy = _evaluateModel(trainSamples, modelData);
    final validationAccuracy = validationSamples.isNotEmpty 
      ? _evaluateModel(validationSamples, modelData)
      : trainAccuracy;
    
    final trainingTime = DateTime.now().difference(startTime);
    
    return AlgorithmTrainingResult(
      algorithmName: algorithm,
      success: true,
      trainAccuracy: trainAccuracy,
      validationAccuracy: validationAccuracy,
      modelData: modelData,
      message: 'Treinamento bem-sucedido',
      trainingTime: trainingTime,
    );
  }

  /// Treina regressão logística com regularização
  Future<Map<String, dynamic>> _trainLogisticRegression(
    List<ProcessedFeatures> samples,
    Map<String, dynamic> hyperparameters,
  ) async {
    if (samples.isEmpty) throw Exception('Nenhuma amostra para treinamento');
    
    final featureCount = samples.first.features.length;
    final sampleCount = samples.length;
    
    // Hiperparâmetros
    final learningRate = hyperparameters['learningRate'] ?? 0.01;
    final epochs = hyperparameters['epochs'] ?? 1000;
    final regularization = hyperparameters['regularization'] ?? 0.01;
    final tolerance = hyperparameters['tolerance'] ?? 1e-6;
    
    // Inicializar pesos
    final random = math.Random(42);
    final weights = List.generate(featureCount, (_) => (random.nextDouble() - 0.5) * 0.1);
    double bias = 0.0;
    
    // Treinamento com regularização L2
    for (int epoch = 0; epoch < epochs; epoch++) {
      double totalLoss = 0.0;
      final weightGradients = List.filled(featureCount, 0.0);
      double biasGradient = 0.0;
      
      // Calcular gradientes
      for (final sample in samples) {
        double linearScore = bias;
        for (int i = 0; i < featureCount; i++) {
          linearScore += weights[i] * sample.features[i];
        }
        
        final prediction = 1.0 / (1.0 + math.exp(-linearScore));
        final error = prediction - sample.target;
        
        totalLoss += sample.target * math.log(math.max(1e-15, prediction)) +
                    (1 - sample.target) * math.log(math.max(1e-15, 1 - prediction));
        
        biasGradient += error;
        for (int i = 0; i < featureCount; i++) {
          weightGradients[i] += error * sample.features[i];
        }
      }
      
      // Adicionar regularização L2
      double regularizationTerm = 0.0;
      for (int i = 0; i < featureCount; i++) {
        regularizationTerm += weights[i] * weights[i];
        weightGradients[i] += regularization * weights[i];
      }
      totalLoss -= 0.5 * regularization * regularizationTerm;
      
      // Atualizar pesos
      bias -= learningRate * biasGradient / sampleCount;
      for (int i = 0; i < featureCount; i++) {
        weights[i] -= learningRate * weightGradients[i] / sampleCount;
      }
      
      // Verificar convergência
      if (epoch > 0 && (totalLoss / sampleCount).abs() < tolerance) {
        break;
      }
    }
    
    return {
      'algorithm': 'logistic_regression',
      'weights': weights,
      'bias': bias,
      'featureCount': featureCount,
      'hyperparameters': hyperparameters,
    };
  }

  /// Treina Naive Bayes Gaussiano
  Future<Map<String, dynamic>> _trainNaiveBayes(
    List<ProcessedFeatures> samples,
    Map<String, dynamic> hyperparameters,
  ) async {
    if (samples.isEmpty) throw Exception('Nenhuma amostra para treinamento');
    
    final featureCount = samples.first.features.length;
    
    // Separar amostras por classe
    final validSamples = samples.where((s) => s.target > 0.5).toList();
    final invalidSamples = samples.where((s) => s.target <= 0.5).toList();
    
    // Calcular priors
    final classPriors = {
      'valid': validSamples.length / samples.length,
      'invalid': invalidSamples.length / samples.length,
    };
    
    // Calcular médias e desvios padrão para cada classe
    final featureMeans = <String, List<double>>{
      'valid': List.filled(featureCount, 0.0),
      'invalid': List.filled(featureCount, 0.0),
    };
    
    final featureStds = <String, List<double>>{
      'valid': List.filled(featureCount, 1.0),
      'invalid': List.filled(featureCount, 1.0),
    };
    
    // Calcular médias
    for (int i = 0; i < featureCount; i++) {
      if (validSamples.isNotEmpty) {
        featureMeans['valid']![i] = validSamples
            .map((s) => s.features[i])
            .reduce((a, b) => a + b) / validSamples.length;
      }
      
      if (invalidSamples.isNotEmpty) {
        featureMeans['invalid']![i] = invalidSamples
            .map((s) => s.features[i])
            .reduce((a, b) => a + b) / invalidSamples.length;
      }
    }
    
    // Calcular desvios padrão
    for (int i = 0; i < featureCount; i++) {
      if (validSamples.length > 1) {
        final mean = featureMeans['valid']![i];
        final variance = validSamples
            .map((s) => math.pow(s.features[i] - mean, 2))
            .reduce((a, b) => a + b) / (validSamples.length - 1);
        featureStds['valid']![i] = math.sqrt(variance + 1e-9); // Evitar divisão por zero
      }
      
      if (invalidSamples.length > 1) {
        final mean = featureMeans['invalid']![i];
        final variance = invalidSamples
            .map((s) => math.pow(s.features[i] - mean, 2))
            .reduce((a, b) => a + b) / (invalidSamples.length - 1);
        featureStds['invalid']![i] = math.sqrt(variance + 1e-9);
      }
    }
    
    return {
      'algorithm': 'naive_bayes',
      'classPriors': classPriors,
      'featureMeans': featureMeans,
      'featureStds': featureStds,
      'featureCount': featureCount,
      'hyperparameters': hyperparameters,
    };
  }

  /// Treina árvore de decisão (implementação simplificada)
  Future<Map<String, dynamic>> _trainDecisionTree(
    List<ProcessedFeatures> samples,
    Map<String, dynamic> hyperparameters,
  ) async {
    if (samples.isEmpty) throw Exception('Nenhuma amostra para treinamento');
    
    final maxDepth = hyperparameters['maxDepth'] ?? 10;
    final minSamplesLeaf = hyperparameters['minSamplesLeaf'] ?? 5;
    
    final tree = _buildDecisionTree(samples, 0, maxDepth, minSamplesLeaf);
    
    return {
      'algorithm': 'decision_tree',
      'tree': tree,
      'hyperparameters': hyperparameters,
    };
  }

  /// Constrói árvore de decisão recursivamente
  Map<String, dynamic> _buildDecisionTree(
    List<ProcessedFeatures> samples,
    int depth,
    int maxDepth,
    int minSamplesLeaf,
  ) {
    // Condições de parada
    if (samples.length < minSamplesLeaf || 
        depth >= maxDepth || 
        _isHomogeneous(samples)) {
      return _createLeafNode(samples);
    }
    
    // Encontrar melhor divisão
    final bestSplit = _findBestSplit(samples);
    
    if (bestSplit == null) {
      return _createLeafNode(samples);
    }
    
    // Dividir amostras
    final leftSamples = samples
        .where((s) => s.features[bestSplit['featureIndex']] <= bestSplit['threshold'])
        .toList();
    final rightSamples = samples
        .where((s) => s.features[bestSplit['featureIndex']] > bestSplit['threshold'])
        .toList();
    
    if (leftSamples.isEmpty || rightSamples.isEmpty) {
      return _createLeafNode(samples);
    }
    
    // Construir subárvores
    final leftTree = _buildDecisionTree(leftSamples, depth + 1, maxDepth, minSamplesLeaf);
    final rightTree = _buildDecisionTree(rightSamples, depth + 1, maxDepth, minSamplesLeaf);
    
    return {
      'featureIndex': bestSplit['featureIndex'],
      'threshold': bestSplit['threshold'],
      'left': leftTree,
      'right': rightTree,
    };
  }

  /// Verifica se amostras são homogêneas
  bool _isHomogeneous(List<ProcessedFeatures> samples) {
    if (samples.isEmpty) return true;
    
    final firstTarget = samples.first.target;
    return samples.every((s) => (s.target - firstTarget).abs() < 0.1);
  }

  /// Cria nó folha
  Map<String, dynamic> _createLeafNode(List<ProcessedFeatures> samples) {
    if (samples.isEmpty) {
      return {'prediction': 0.5, 'confidence': 0.0};
    }
    
    final validCount = samples.where((s) => s.target > 0.5).length;
    final prediction = validCount / samples.length;
    final confidence = math.max(prediction, 1.0 - prediction);
    
    return {
      'prediction': prediction,
      'confidence': confidence,
    };
  }

  /// Encontra melhor divisão para árvore de decisão
  Map<String, dynamic>? _findBestSplit(List<ProcessedFeatures> samples) {
    if (samples.isEmpty) return null;
    
    final featureCount = samples.first.features.length;
    double bestGini = double.infinity;
    Map<String, dynamic>? bestSplit;
    
    for (int featureIndex = 0; featureIndex < featureCount; featureIndex++) {
      final values = samples.map((s) => s.features[featureIndex]).toSet().toList()..sort();
      
      for (int i = 0; i < values.length - 1; i++) {
        final threshold = (values[i] + values[i + 1]) / 2;
        
        final leftSamples = samples
            .where((s) => s.features[featureIndex] <= threshold)
            .toList();
        final rightSamples = samples
            .where((s) => s.features[featureIndex] > threshold)
            .toList();
        
        if (leftSamples.isEmpty || rightSamples.isEmpty) continue;
        
        final gini = _calculateWeightedGini(leftSamples, rightSamples);
        
        if (gini < bestGini) {
          bestGini = gini;
          bestSplit = {
            'featureIndex': featureIndex,
            'threshold': threshold,
            'gini': gini,
          };
        }
      }
    }
    
    return bestSplit;
  }

  /// Calcula Gini impurity ponderado
  double _calculateWeightedGini(
    List<ProcessedFeatures> leftSamples,
    List<ProcessedFeatures> rightSamples,
  ) {
    final totalSamples = leftSamples.length + rightSamples.length;
    
    final leftWeight = leftSamples.length / totalSamples;
    final rightWeight = rightSamples.length / totalSamples;
    
    final leftGini = _calculateGini(leftSamples);
    final rightGini = _calculateGini(rightSamples);
    
    return leftWeight * leftGini + rightWeight * rightGini;
  }

  /// Calcula Gini impurity
  double _calculateGini(List<ProcessedFeatures> samples) {
    if (samples.isEmpty) return 0.0;
    
    final validCount = samples.where((s) => s.target > 0.5).length;
    final validRatio = validCount / samples.length;
    final invalidRatio = 1.0 - validRatio;
    
    return 1.0 - (validRatio * validRatio + invalidRatio * invalidRatio);
  }

  /// Treina SVM (implementação simplificada)
  Future<Map<String, dynamic>> _trainSVM(
    List<ProcessedFeatures> samples,
    Map<String, dynamic> hyperparameters,
  ) async {
    if (samples.isEmpty) throw Exception('Nenhuma amostra para treinamento');
    
    // Implementação simplificada usando subset de amostras como support vectors
    final c = hyperparameters['C'] ?? 1.0;
    final gamma = hyperparameters['gamma'] ?? 0.1;
    final maxSupportVectors = hyperparameters['maxSupportVectors'] ?? 100;
    
    // Selecionar subset de amostras como support vectors
    final shuffledSamples = List<ProcessedFeatures>.from(samples)..shuffle();
    final supportVectorCount = math.min<int>(maxSupportVectors, samples.length);
    final supportVectorSamples = shuffledSamples.take(supportVectorCount).toList();
    
    // Extrair dados dos support vectors
    final supportVectors = supportVectorSamples.map((s) => s.features).toList();
    final labels = supportVectorSamples.map((s) => s.target > 0.5 ? 1.0 : -1.0).toList();
    
    // Alphas simplificados (todos iguais)
    final alphas = List.filled(supportVectorCount, 1.0 / supportVectorCount);
    
    // Bias calculado como média das predições
    double bias = 0.0;
    for (final sample in samples.take(50)) { // Usar subset para calcular bias
      double decision = 0.0;
      for (int i = 0; i < supportVectors.length; i++) {
        final sv = supportVectors[i];
        final alpha = alphas[i];
        final label = labels[i];
        
        double distance = 0.0;
        for (int j = 0; j < sample.features.length; j++) {
          distance += math.pow(sample.features[j] - sv[j], 2);
        }
        final kernelValue = math.exp(-gamma * distance);
        
        decision += alpha * label * kernelValue;
      }
      
      final target = sample.target > 0.5 ? 1.0 : -1.0;
      bias += target - decision;
    }
    bias /= math.min(50, samples.length);
    
    return {
      'algorithm': 'svm',
      'supportVectors': supportVectors,
      'alphas': alphas,
      'labels': labels,
      'bias': bias,
      'gamma': gamma,
      'hyperparameters': hyperparameters,
    };
  }

  /// Cria ensemble com modelos treinados
  EnsembleModel _createEnsemble(List<AlgorithmTrainingResult> results) {
    final ensemble = EnsembleModel();
    
    for (final result in results) {
      ensemble.addModel(
        result.algorithmName,
        result.modelData,
        result.validationAccuracy,
      );
    }
    
    // Usar estratégia adaptativa por padrão
    ensemble.setStrategy(EnsembleStrategy.adaptive);
    
    debugPrint('AdvancedTrainer: Ensemble criado com ${results.length} modelos');
    
    return ensemble;
  }

  /// Avalia modelo
  double _evaluateModel(List<ProcessedFeatures> samples, Map<String, dynamic> modelData) {
    if (samples.isEmpty) return 0.0;
    
    int correctPredictions = 0;
    
    for (final sample in samples) {
      final prediction = _predictWithModel(sample.features, modelData);
      final predictedClass = prediction > 0.5 ? 1.0 : 0.0;
      
      if ((predictedClass - sample.target).abs() < 0.5) {
        correctPredictions++;
      }
    }
    
    return correctPredictions / samples.length;
  }

  /// Faz predição com modelo específico
  double _predictWithModel(List<double> features, Map<String, dynamic> modelData) {
    final algorithm = modelData['algorithm'] as String;
    
    switch (algorithm) {
      case 'logistic_regression':
        return _predictLogisticRegression(features, modelData);
      case 'naive_bayes':
        return _predictNaiveBayes(features, modelData);
      case 'decision_tree':
        return _predictDecisionTree(features, modelData);
      case 'svm':
        return _predictSVM(features, modelData);
      default:
        return 0.5;
    }
  }

  double _predictLogisticRegression(List<double> features, Map<String, dynamic> modelData) {
    final weights = List<double>.from(modelData['weights']);
    final bias = modelData['bias'] as double;
    
    double linearScore = bias;
    for (int i = 0; i < features.length; i++) {
      linearScore += weights[i] * features[i];
    }
    
    return 1.0 / (1.0 + math.exp(-linearScore));
  }

  double _predictNaiveBayes(List<double> features, Map<String, dynamic> modelData) {
    final classPriors = Map<String, double>.from(modelData['classPriors']);
    final featureMeans = Map<String, List<double>>.from(
      modelData['featureMeans'].map((k, v) => MapEntry(k, List<double>.from(v)))
    );
    final featureStds = Map<String, List<double>>.from(
      modelData['featureStds'].map((k, v) => MapEntry(k, List<double>.from(v)))
    );
    
    double logProbValid = math.log(classPriors['valid'] ?? 0.5);
    double logProbInvalid = math.log(classPriors['invalid'] ?? 0.5);
    
    for (int i = 0; i < features.length; i++) {
      final feature = features[i];
      
      final meanValid = featureMeans['valid']![i];
      final stdValid = featureStds['valid']![i];
      logProbValid += _logGaussianProbability(feature, meanValid, stdValid);
      
      final meanInvalid = featureMeans['invalid']![i];
      final stdInvalid = featureStds['invalid']![i];
      logProbInvalid += _logGaussianProbability(feature, meanInvalid, stdInvalid);
    }
    
    final maxLogProb = math.max(logProbValid, logProbInvalid);
    final probValid = math.exp(logProbValid - maxLogProb);
    final probInvalid = math.exp(logProbInvalid - maxLogProb);
    
    return probValid / (probValid + probInvalid);
  }

  double _predictDecisionTree(List<double> features, Map<String, dynamic> modelData) {
    final tree = modelData['tree'] as Map<String, dynamic>;
    
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
    
    return currentNode['prediction'] as double;
  }

  double _predictSVM(List<double> features, Map<String, dynamic> modelData) {
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
      
      double distance = 0.0;
      for (int j = 0; j < features.length; j++) {
        distance += math.pow(features[j] - sv[j], 2);
      }
      final kernelValue = math.exp(-gamma * distance);
      
      decision += alpha * label * kernelValue;
    }
    
    return 1.0 / (1.0 + math.exp(-decision));
  }

  double _logGaussianProbability(double x, double mean, double std) {
    if (std <= 0) return -double.infinity;
    
    final variance = std * std;
    final logCoeff = -0.5 * math.log(2 * math.pi * variance);
    final logExp = -0.5 * math.pow(x - mean, 2) / variance;
    
    return logCoeff + logExp;
  }
}

