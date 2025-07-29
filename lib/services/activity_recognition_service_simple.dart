import 'dart:async';

enum DrivingState {
  notDriving,
  startingDrive,
  driving,
  stoppingDrive,
}

class ActivityRecognitionService {
  static final ActivityRecognitionService _instance = ActivityRecognitionService._internal();
  factory ActivityRecognitionService() => _instance;
  ActivityRecognitionService._internal();

  DrivingState _currentState = DrivingState.notDriving;
  DateTime? _drivingStartTime;
  
  // Configurações
  static const int _drivingStartDelay = 30; // Segundos para confirmar início da direção
  static const int _drivingStopDelay = 120; // Segundos para confirmar fim da direção
  
  // Callbacks
  Function(DateTime startTime)? onDrivingStarted;
  Function(DateTime endTime, Duration duration)? onDrivingStopped;
  Function(DrivingState state)? onStateChanged;

  DrivingState get currentState => _currentState;
  bool get isDriving => _currentState == DrivingState.driving;
  DateTime? get drivingStartTime => _drivingStartTime;

  Future<bool> initialize() async {
    // Versão simplificada - sempre retorna true
    return true;
  }

  Future<void> startMonitoring() async {
    // Versão simplificada - não faz monitoramento real
    print('Monitoramento de atividades iniciado (modo simplificado)');
  }

  Future<void> stopMonitoring() async {
    // Se estava dirigindo, finalizar a viagem
    if (_currentState == DrivingState.driving) {
      _stopDriving();
    }
    
    print('Monitoramento de atividades parado');
  }

  Timer? _startDrivingTimer;
  Timer? _stopDrivingTimer;

  void _scheduleStartDriving() {
    _cancelStartDriving();
    _startDrivingTimer = Timer(Duration(seconds: _drivingStartDelay), () {
      if (_currentState == DrivingState.startingDrive) {
        _startDriving();
      }
    });
  }

  void _scheduleStopDriving() {
    _cancelStopDriving();
    _stopDrivingTimer = Timer(Duration(seconds: _drivingStopDelay), () {
      if (_currentState == DrivingState.stoppingDrive) {
        _stopDriving();
      }
    });
  }

  void _cancelStartDriving() {
    _startDrivingTimer?.cancel();
    _startDrivingTimer = null;
  }

  void _cancelStopDriving() {
    _stopDrivingTimer?.cancel();
    _stopDrivingTimer = null;
  }

  void _startDriving() {
    final now = DateTime.now();
    _drivingStartTime = now;
    _setState(DrivingState.driving);
    
    print('Início de direção detectado: $now');
    onDrivingStarted?.call(now);
  }

  void _stopDriving() {
    final now = DateTime.now();
    final startTime = _drivingStartTime;
    
    if (startTime != null) {
      final duration = now.difference(startTime);
      print('Fim de direção detectado: $now (duração: ${duration.inMinutes} min)');
      onDrivingStopped?.call(now, duration);
    }
    
    _drivingStartTime = null;
    _setState(DrivingState.notDriving);
  }

  void _setState(DrivingState newState) {
    if (_currentState != newState) {
      final oldState = _currentState;
      _currentState = newState;
      print('Estado mudou de $oldState para $newState');
      onStateChanged?.call(newState);
    }
  }

  // Método para forçar início de viagem (para testes ou uso manual)
  void forceStartDriving() {
    if (_currentState == DrivingState.notDriving) {
      _setState(DrivingState.startingDrive);
      _scheduleStartDriving();
    }
  }

  // Método para forçar fim de viagem
  void forceStopDriving() {
    if (_currentState == DrivingState.driving) {
      _setState(DrivingState.stoppingDrive);
      _scheduleStopDriving();
    }
  }

  // Verificar se deve coletar dados de telemática
  bool shouldCollectTelematicsData() {
    return _currentState == DrivingState.driving;
  }

  // Obter estatísticas do serviço
  Map<String, dynamic> getServiceStats() {
    return {
      'currentState': _currentState.toString(),
      'isDriving': isDriving,
      'drivingStartTime': _drivingStartTime?.toIso8601String(),
      'isMonitoring': true, // Sempre true na versão simplificada
      'mode': 'simplified',
    };
  }

  void dispose() {
    stopMonitoring();
    _cancelStartDriving();
    _cancelStopDriving();
  }
}

