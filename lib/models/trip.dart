class Trip {
  final int? id;
  final int userId;
  final DateTime startTime;
  final DateTime? endTime;
  final double? startLatitude;
  final double? startLongitude;
  final double? endLatitude;
  final double? endLongitude;
  final double? distance;
  final double? maxSpeed;
  final double? avgSpeed;
  final int? duration; // em segundos
  final double? safetyScore;
  final int hardBrakingCount;
  final int rapidAccelerationCount;
  final int speedingCount;
  final String? startAddress;
  final String? endAddress;
  final bool isActive;

  Trip({
    this.id,
    required this.userId,
    required this.startTime,
    this.endTime,
    this.startLatitude,
    this.startLongitude,
    this.endLatitude,
    this.endLongitude,
    this.distance,
    this.maxSpeed,
    this.avgSpeed,
    this.duration,
    this.safetyScore,
    this.hardBrakingCount = 0,
    this.rapidAccelerationCount = 0,
    this.speedingCount = 0,
    this.startAddress,
    this.endAddress,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'startLatitude': startLatitude,
      'startLongitude': startLongitude,
      'endLatitude': endLatitude,
      'endLongitude': endLongitude,
      'distance': distance,
      'maxSpeed': maxSpeed,
      'avgSpeed': avgSpeed,
      'duration': duration,
      'safetyScore': safetyScore,
      'hardBrakingCount': hardBrakingCount,
      'rapidAccelerationCount': rapidAccelerationCount,
      'speedingCount': speedingCount,
      'startAddress': startAddress,
      'endAddress': endAddress,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id']?.toInt(),
      userId: map['userId']?.toInt() ?? 0,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime']),
      endTime: map['endTime'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['endTime'])
          : null,
      startLatitude: map['startLatitude']?.toDouble(),
      startLongitude: map['startLongitude']?.toDouble(),
      endLatitude: map['endLatitude']?.toDouble(),
      endLongitude: map['endLongitude']?.toDouble(),
      distance: map['distance']?.toDouble(),
      maxSpeed: map['maxSpeed']?.toDouble(),
      avgSpeed: map['avgSpeed']?.toDouble(),
      duration: map['duration']?.toInt(),
      safetyScore: map['safetyScore']?.toDouble(),
      hardBrakingCount: map['hardBrakingCount']?.toInt() ?? 0,
      rapidAccelerationCount: map['rapidAccelerationCount']?.toInt() ?? 0,
      speedingCount: map['speedingCount']?.toInt() ?? 0,
      startAddress: map['startAddress'],
      endAddress: map['endAddress'],
      isActive: map['isActive'] == 1,
    );
  }

  Trip copyWith({
    int? id,
    int? userId,
    DateTime? startTime,
    DateTime? endTime,
    double? startLatitude,
    double? startLongitude,
    double? endLatitude,
    double? endLongitude,
    double? distance,
    double? maxSpeed,
    double? avgSpeed,
    int? duration,
    double? safetyScore,
    int? hardBrakingCount,
    int? rapidAccelerationCount,
    int? speedingCount,
    String? startAddress,
    String? endAddress,
    bool? isActive,
  }) {
    return Trip(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      endLatitude: endLatitude ?? this.endLatitude,
      endLongitude: endLongitude ?? this.endLongitude,
      distance: distance ?? this.distance,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      avgSpeed: avgSpeed ?? this.avgSpeed,
      duration: duration ?? this.duration,
      safetyScore: safetyScore ?? this.safetyScore,
      hardBrakingCount: hardBrakingCount ?? this.hardBrakingCount,
      rapidAccelerationCount: rapidAccelerationCount ?? this.rapidAccelerationCount,
      speedingCount: speedingCount ?? this.speedingCount,
      startAddress: startAddress ?? this.startAddress,
      endAddress: endAddress ?? this.endAddress,
      isActive: isActive ?? this.isActive,
    );
  }
}

