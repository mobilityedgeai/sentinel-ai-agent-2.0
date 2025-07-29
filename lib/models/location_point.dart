class LocationPoint {
  final int id;
  final int tripId;
  final double latitude;
  final double longitude;
  final double? speed;
  final double? accuracy;
  final DateTime timestamp;

  LocationPoint({
    required this.id,
    required this.tripId,
    required this.latitude,
    required this.longitude,
    this.speed,
    this.accuracy,
    required this.timestamp,
  });

  factory LocationPoint.fromMap(Map<String, dynamic> map) {
    return LocationPoint(
      id: map['id'] ?? 0,
      tripId: map['trip_id'] ?? 0,
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      speed: map['speed']?.toDouble(),
      accuracy: map['accuracy']?.toDouble(),
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  LocationPoint copyWith({
    int? id,
    int? tripId,
    double? latitude,
    double? longitude,
    double? speed,
    double? accuracy,
    DateTime? timestamp,
  }) {
    return LocationPoint(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speed: speed ?? this.speed,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'LocationPoint(id: $id, tripId: $tripId, lat: $latitude, lng: $longitude, speed: $speed, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationPoint &&
        other.id == id &&
        other.tripId == tripId &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.speed == speed &&
        other.accuracy == accuracy &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      tripId,
      latitude,
      longitude,
      speed,
      accuracy,
      timestamp,
    );
  }
}

