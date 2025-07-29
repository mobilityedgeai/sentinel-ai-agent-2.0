import 'dart:async';
import 'dart:math';

enum DrivingState {
  notDriving,
  startingDrive,
  driving,
  stoppingDrive,
}

enum ActivityType {
  still,
  walking,
  running,
  driving,
  cycling,
  unknown,
}

enum ActivityConfidence {
  low,
  medium,
  high,
}

class ActivityResult {
  final ActivityType type;
  final ActivityConfidence confidence;
  final DateTime timestamp;

  ActivityResult({
    required this.type,
    required this.confidence,
    required this.timestamp,
  });
}

class ActivityRecognitionService {
  static final ActivityRecognitionService _instance = ActivityRecognitionService._internal();
  factory ActivityRecognitionService() => _instance;
  ActivityRecognitionService._internal();

  StreamSubscription<ActivityResult>? _activitySubscription;
  final StreamController<ActivityResult> _activityController = StreamController<ActivityResult>.broadcast();
  
  DrivingState _currentState = DrivingState.notDriving;
  Function(DrivingState)? onStateChanged;
  Timer? _simulationTimer;
  final Random _random = Random();

  Stream<ActivityResult> get activityStream => _activityController.stream;
  DrivingState get currentState => _currentState;

  Future<bool> initialize() async {
    // Simular inicialização bem-sucedida
    return true;
  }

  Future<void> startRecognition() async {
    // Simular reconhecimento de atividade com dados realistas
    _simulationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final activities = [
        ActivityType.still,
        ActivityType.walking,
        ActivityType.driving,
        ActivityType.unknown,
      ];
      
      final confidences = [
        ActivityConfidence.low,
        ActivityConfidence.medium,
        ActivityConfidence.high,
      ];

      final activity = ActivityResult(
        type: activities[_random.nextInt(activities.length)],
        confidence: confidences[_random.nextInt(confidences.length)],
        timestamp: DateTime.now(),
      );

      _activityController.add(activity);
      _updateDrivingState(activity);
    });
  }

  void _updateDrivingState(ActivityResult activity) {
    DrivingState newState = _currentState;

    if (activity.type == ActivityType.driving && activity.confidence == ActivityConfidence.high) {
      if (_currentState == DrivingState.notDriving) {
        newState = DrivingState.startingDrive;
      } else if (_currentState == DrivingState.startingDrive) {
        newState = DrivingState.driving;
      }
    } else if (activity.type != ActivityType.driving) {
      if (_currentState == DrivingState.driving) {
        newState = DrivingState.stoppingDrive;
      } else if (_currentState == DrivingState.stoppingDrive) {
        newState = DrivingState.notDriving;
      }
    }

    if (newState != _currentState) {
      _currentState = newState;
      onStateChanged?.call(_currentState);
    }
  }

  Future<void> stopRecognition() async {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  void dispose() {
    _simulationTimer?.cancel();
    _activitySubscription?.cancel();
    _activityController.close();
  }
}

