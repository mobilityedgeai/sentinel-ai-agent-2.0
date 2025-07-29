class DrivingEvent {
  final int id;
  final int tripId;
  final String eventType;
  final double latitude;
  final double longitude;
  final double intensity;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  DrivingEvent({
    required this.id,
    required this.tripId,
    required this.eventType,
    required this.latitude,
    required this.longitude,
    required this.intensity,
    required this.timestamp,
    this.metadata,
  });

  factory DrivingEvent.fromMap(Map<String, dynamic> map) {
    return DrivingEvent(
      id: map['id'] ?? 0,
      tripId: map['trip_id'] ?? 0,
      eventType: map['event_type'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      intensity: (map['intensity'] ?? 0.0).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      metadata: map['metadata'] != null ? Map<String, dynamic>.from(map['metadata']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'event_type': eventType,
      'latitude': latitude,
      'longitude': longitude,
      'intensity': intensity,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  DrivingEvent copyWith({
    int? id,
    int? tripId,
    String? eventType,
    double? latitude,
    double? longitude,
    double? intensity,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return DrivingEvent(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      eventType: eventType ?? this.eventType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      intensity: intensity ?? this.intensity,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'DrivingEvent(id: $id, tripId: $tripId, type: $eventType, lat: $latitude, lng: $longitude, intensity: $intensity, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DrivingEvent &&
        other.id == id &&
        other.tripId == tripId &&
        other.eventType == eventType &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.intensity == intensity &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      tripId,
      eventType,
      latitude,
      longitude,
      intensity,
      timestamp,
    );
  }
}

