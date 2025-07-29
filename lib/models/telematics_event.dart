enum TelematicsEventType {
  hardBraking,
  rapidAcceleration,
  sharpTurn,
  speeding,
  highGForce,
  idling,
  phoneUsage,
}

class TelematicsEvent {
  final int? id;
  final int tripId;
  final int userId;
  final TelematicsEventType eventType;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double? severity;
  final double? magnitude;        // Magnitude do evento (aceleração, rotação, etc.)
  final double? confidence;       // Score de confiança (0.0 a 1.0)
  final bool? mlValidated;        // Se foi validado por ML
  final Map<String, dynamic>? metadata;

  TelematicsEvent({
    this.id,
    required this.tripId,
    required this.userId,
    required this.eventType,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.severity,
    this.magnitude,
    this.confidence,
    this.mlValidated,
    this.metadata,
  });

  // Getters para compatibilidade
  String get eventTypeString {
    switch (eventType) {
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

  String get description {
    switch (eventType) {
      case TelematicsEventType.hardBraking:
        return 'Frenagem detectada com G-force de ${(severity ?? 0.0).toStringAsFixed(2)}g';
      case TelematicsEventType.rapidAcceleration:
        return 'Aceleração rápida detectada';
      case TelematicsEventType.sharpTurn:
        return 'Curva acentuada realizada';
      case TelematicsEventType.speeding:
        return 'Velocidade acima do limite detectada';
      case TelematicsEventType.highGForce:
        return 'G-force elevada detectada - possível acidente';
      case TelematicsEventType.idling:
        return 'Veículo parado com motor ligado por ${(severity ?? 0.0).toStringAsFixed(0)} segundos';
      case TelematicsEventType.phoneUsage:
        return 'Uso do telefone detectado por ${(severity ?? 0.0).toStringAsFixed(0)} segundos';
    }
  }

  // Converter para Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'user_id': userId,
      'event_type': eventType.toString().split('.').last,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'latitude': latitude,
      'longitude': longitude,
      'severity': severity,
      'magnitude': magnitude,
      'confidence': confidence,
      'ml_validated': mlValidated == true ? 1 : 0,
      'metadata': metadata != null ? metadata.toString() : null,
    };
  }

  factory TelematicsEvent.fromMap(Map<String, dynamic> map) {
    return TelematicsEvent(
      id: map['id'],
      tripId: map['trip_id'],
      userId: map['user_id'],
      eventType: TelematicsEventType.values.firstWhere(
        (e) => e.toString().split('.').last == map['event_type'],
        orElse: () => TelematicsEventType.hardBraking,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      latitude: map['latitude'],
      longitude: map['longitude'],
      severity: map['severity'],
      magnitude: map['magnitude'],
      confidence: map['confidence'],
      mlValidated: map['ml_validated'] == 1,
      metadata: map['metadata'] != null ? {'raw': map['metadata']} : null,
    );
  }

  TelematicsEvent copyWith({
    int? id,
    int? tripId,
    int? userId,
    TelematicsEventType? eventType,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    double? severity,
    double? magnitude,
    double? confidence,
    bool? mlValidated,
    Map<String, dynamic>? metadata,
  }) {
    return TelematicsEvent(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      userId: userId ?? this.userId,
      eventType: eventType ?? this.eventType,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      severity: severity ?? this.severity,
      magnitude: magnitude ?? this.magnitude,
      confidence: confidence ?? this.confidence,
      mlValidated: mlValidated ?? this.mlValidated,
      metadata: metadata ?? this.metadata,
    );
  }
}

