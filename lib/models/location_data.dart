class LocationData {
  final int? id;
  final int? tripId;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? speed;
  final double? speedAccuracy;
  final double? heading;
  final double? accuracy;
  final DateTime timestamp;
  final String? provider;

  LocationData({
    this.id,
    this.tripId,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    this.speedAccuracy,
    this.heading,
    this.accuracy,
    required this.timestamp,
    this.provider,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'speed': speed,
      'speedAccuracy': speedAccuracy,
      'heading': heading,
      'accuracy': accuracy,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'provider': provider,
    };
  }

  factory LocationData.fromMap(Map<String, dynamic> map) {
    return LocationData(
      id: map['id']?.toInt(),
      tripId: map['tripId']?.toInt(),
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      altitude: map['altitude']?.toDouble(),
      speed: map['speed']?.toDouble(),
      speedAccuracy: map['speedAccuracy']?.toDouble(),
      heading: map['heading']?.toDouble(),
      accuracy: map['accuracy']?.toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      provider: map['provider'] as String?,
    );
  }

  LocationData copyWith({
    int? id,
    int? tripId,
    double? latitude,
    double? longitude,
    double? altitude,
    double? speed,
    double? speedAccuracy,
    double? heading,
    double? accuracy,
    DateTime? timestamp,
    String? provider,
  }) {
    return LocationData(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      speedAccuracy: speedAccuracy ?? this.speedAccuracy,
      heading: heading ?? this.heading,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
      provider: provider ?? this.provider,
    );
  }
}

