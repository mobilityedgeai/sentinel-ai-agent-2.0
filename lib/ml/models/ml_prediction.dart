import '../../models/telematics_event.dart';

/// Resultado de uma predição de Machine Learning
class MLPrediction {
  final TelematicsEventType eventType;
  final double magnitude;
  final bool isValidEvent;
  final double confidence;
  final String modelUsed;
  final DateTime timestamp;
  final Map<String, double> features;
  final Map<String, dynamic>? metadata;
  
  MLPrediction({
    required this.eventType,
    required this.magnitude,
    required this.isValidEvent,
    required this.confidence,
    required this.modelUsed,
    required this.timestamp,
    required this.features,
    this.metadata,
  });
  
  /// Converte para Map
  Map<String, dynamic> toMap() {
    return {
      'eventType': eventType.toString().split('.').last,
      'magnitude': magnitude,
      'isValidEvent': isValidEvent,
      'confidence': confidence,
      'modelUsed': modelUsed,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'features': features,
      'metadata': metadata,
    };
  }
  
  /// Cria a partir de Map
  factory MLPrediction.fromMap(Map<String, dynamic> map) {
    return MLPrediction(
      eventType: TelematicsEventType.values.firstWhere(
        (e) => e.toString().split('.').last == map['eventType'],
        orElse: () => TelematicsEventType.hardBraking,
      ),
      magnitude: map['magnitude']?.toDouble() ?? 0.0,
      isValidEvent: map['isValidEvent'] ?? true,
      confidence: map['confidence']?.toDouble() ?? 0.5,
      modelUsed: map['modelUsed'] ?? 'unknown',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      features: Map<String, double>.from(map['features'] ?? {}),
      metadata: map['metadata'],
    );
  }
  
  /// Cria cópia com modificações
  MLPrediction copyWith({
    TelematicsEventType? eventType,
    double? magnitude,
    bool? isValidEvent,
    double? confidence,
    String? modelUsed,
    DateTime? timestamp,
    Map<String, double>? features,
    Map<String, dynamic>? metadata,
  }) {
    return MLPrediction(
      eventType: eventType ?? this.eventType,
      magnitude: magnitude ?? this.magnitude,
      isValidEvent: isValidEvent ?? this.isValidEvent,
      confidence: confidence ?? this.confidence,
      modelUsed: modelUsed ?? this.modelUsed,
      timestamp: timestamp ?? this.timestamp,
      features: features ?? this.features,
      metadata: metadata ?? this.metadata,
    );
  }
  
  /// Obtém descrição da predição
  String get description {
    final eventName = _getEventName(eventType);
    final confidencePercent = (confidence * 100).toStringAsFixed(1);
    final validityText = isValidEvent ? 'válido' : 'falso positivo';
    
    return '$eventName - $validityText (${confidencePercent}% confiança)';
  }
  
  /// Obtém cor baseada na confiança
  String get confidenceColor {
    if (confidence >= 0.8) return '#4CAF50'; // Verde
    if (confidence >= 0.6) return '#FF9800'; // Laranja
    return '#F44336'; // Vermelho
  }
  
  /// Verifica se é uma predição de alta confiança
  bool get isHighConfidence => confidence >= 0.8;
  
  /// Verifica se é uma predição de baixa confiança
  bool get isLowConfidence => confidence < 0.6;
  
  String _getEventName(TelematicsEventType type) {
    switch (type) {
      case TelematicsEventType.hardBraking:
        return 'Frenagem Brusca';
      case TelematicsEventType.rapidAcceleration:
        return 'Aceleração Rápida';
      case TelematicsEventType.sharpTurn:
        return 'Curva Acentuada';
      case TelematicsEventType.speeding:
        return 'Excesso de Velocidade';
      case TelematicsEventType.highGForce:
        return 'G-Force Elevada';
      case TelematicsEventType.idling:
        return 'Veículo Parado Ligado';
      case TelematicsEventType.phoneUsage:
        return 'Uso do Telefone';
    }
  }
  
  @override
  String toString() {
    return 'MLPrediction(${eventType.toString().split('.').last}, '
           'magnitude: ${magnitude.toStringAsFixed(2)}, '
           'valid: $isValidEvent, '
           'confidence: ${(confidence * 100).toStringAsFixed(1)}%, '
           'model: $modelUsed)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MLPrediction &&
        other.eventType == eventType &&
        other.magnitude == magnitude &&
        other.isValidEvent == isValidEvent &&
        other.confidence == confidence &&
        other.modelUsed == modelUsed &&
        other.timestamp == timestamp;
  }
  
  @override
  int get hashCode {
    return eventType.hashCode ^
        magnitude.hashCode ^
        isValidEvent.hashCode ^
        confidence.hashCode ^
        modelUsed.hashCode ^
        timestamp.hashCode;
  }
}

