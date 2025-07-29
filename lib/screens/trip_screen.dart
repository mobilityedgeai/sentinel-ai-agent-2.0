import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/trip_manager.dart';
import '../services/activity_recognition_service_simple.dart';
import '../models/trip.dart';
import '../models/telematics_event.dart';
import '../constants/app_colors.dart';
import '../widgets/safety_score_widget.dart';

class TripScreen extends StatefulWidget {
  const TripScreen({Key? key}) : super(key: key);

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  final TripManager _tripManager = TripManager();
  final ActivityRecognitionService _activityService = ActivityRecognitionService();
  
  Trip? _currentTrip;
  DrivingState _drivingState = DrivingState.notDriving;
  Duration _tripDuration = Duration.zero;
  double _currentSpeed = 0.0;
  double _maxSpeed = 0.0;
  double _avgSpeed = 0.0;
  double _distance = 0.0;
  int _eventCount = 0;
  double _currentSafetyScore = 100.0;
  
  late Stream<Duration> _durationStream;

  @override
  void initState() {
    super.initState();
    _initializeTripManager();
    _setupDurationStream();
  }

  Future<void> _initializeTripManager() async {
    // Inicializar com usuário ID 1 (em produção, vem do login)
    final initialized = await _tripManager.initialize(1);
    
    if (initialized) {
      // Configurar callbacks
      _tripManager.onTripStarted = _handleTripStarted;
      _tripManager.onTripEnded = _handleTripEnded;
      _tripManager.onLocationUpdate = _handleLocationUpdate;
      _tripManager.onTelematicsEvent = _handleTelematicsEvent;
      
      _activityService.onStateChanged = _handleStateChanged;
      
      // Atualizar estado inicial
      setState(() {
        _currentTrip = _tripManager.currentTrip;
        _drivingState = _activityService.currentState;
      });
    }
  }

  void _setupDurationStream() {
    _durationStream = Stream.periodic(const Duration(seconds: 1), (count) {
      if (_currentTrip != null) {
        return DateTime.now().difference(_currentTrip!.startTime);
      }
      return Duration.zero;
    });
  }

  void _handleTripStarted(Trip trip) {
    setState(() {
      _currentTrip = trip;
      _tripDuration = Duration.zero;
      _currentSpeed = 0.0;
      _maxSpeed = 0.0;
      _avgSpeed = 0.0;
      _distance = 0.0;
      _eventCount = 0;
      _currentSafetyScore = 100.0;
    });
  }

  void _handleTripEnded(Trip trip) {
    setState(() {
      _currentTrip = null;
      _tripDuration = Duration.zero;
      _currentSpeed = 0.0;
    });
    
    _showTripSummary(trip, []);
  }

  void _handleLocationUpdate(location) {
    if (_currentTrip != null) {
      setState(() {
        _currentSpeed = location.speed ?? 0.0;
        if (_currentSpeed > _maxSpeed) {
          _maxSpeed = _currentSpeed;
        }
        // Calcular distância e velocidade média seria feito aqui
      });
    }
  }

  void _handleTelematicsEvent(dynamic event) {
    if (event is TelematicsEvent) {
      setState(() {
        _eventCount++;
        // Recalcular safety score baseado nos eventos
        _currentSafetyScore = math.max(0, _currentSafetyScore - _getEventPenalty(event));
      });
      
      _showEventAlert(event);
    }
  }

  void _handleStateChanged(DrivingState state) {
    setState(() {
      _drivingState = state;
    });
  }

  double _getEventPenalty(TelematicsEvent event) {
    switch (event.eventType) {
      case TelematicsEventType.hardBraking:
        return 5.0;
      case TelematicsEventType.rapidAcceleration:
        return 3.0;
      case TelematicsEventType.speeding:
        return 8.0;
      case TelematicsEventType.sharpTurn:
        return 4.0;
      case TelematicsEventType.hardBraking:
        return 15.0;
      case TelematicsEventType.highGForce:
        return 50.0;
      default:
        return 2.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Monitoramento de Viagem'),
        actions: [
          IconButton(
            onPressed: _showDebugInfo,
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: _currentTrip != null ? _buildActiveTrip() : _buildWaitingState(),
      ),
    );
  }

  Widget _buildWaitingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getStateIcon(),
            size: 80,
            color: _getStateColor(),
          ),
          const SizedBox(height: 16),
          Text(
            _getStateMessage(),
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _getStateDescription(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (_drivingState == DrivingState.notDriving) ...[
            ElevatedButton(
              onPressed: () => _tripManager.forceStartTrip(),
              child: const Text('Iniciar Viagem Manualmente'),
            ),
            const SizedBox(height: 8),
            Text(
              'Para testes apenas',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveTrip() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTripHeader(),
          const SizedBox(height: 16),
          _buildSafetyScoreCard(),
          const SizedBox(height: 16),
          _buildStatsGrid(),
          const SizedBox(height: 16),
          _buildRecentEvents(),
          const SizedBox(height: 80), // Espaço para o FAB
        ],
      ),
    );
  }

  Widget _buildTripHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_car,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Viagem em Andamento',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ATIVO',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<Duration>(
              stream: _durationStream,
              builder: (context, snapshot) {
                final duration = snapshot.data ?? Duration.zero;
                return Text(
                  _formatDuration(duration),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            Text(
              'Iniciada às ${DateFormat('HH:mm').format(_currentTrip!.startTime)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyScoreCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SafetyScoreWidget(
              score: _currentSafetyScore.round(),
              size: 100,
              showLabel: false,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Score de Segurança',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Viagem atual',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_eventCount eventos detectados',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _eventCount > 0 ? AppColors.warning : AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: [
        _buildStatCard(
          'Velocidade Atual',
          '${_currentSpeed.toStringAsFixed(0)} km/h',
          Icons.speed,
          AppColors.primary,
        ),
        _buildStatCard(
          'Velocidade Máxima',
          '${_maxSpeed.toStringAsFixed(0)} km/h',
          Icons.trending_up,
          AppColors.warning,
        ),
        _buildStatCard(
          'Distância',
          '${_distance.toStringAsFixed(1)} km',
          Icons.straighten,
          AppColors.success,
        ),
        _buildStatCard(
          'Vel. Média',
          '${_avgSpeed.toStringAsFixed(0)} km/h',
          Icons.timeline,
          AppColors.mapSecondary,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentEvents() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Eventos Recentes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_eventCount == 0)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nenhum evento detectado',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                    Text(
                      'Continue dirigindo com segurança!',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                '$_eventCount eventos detectados nesta viagem',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getStateIcon() {
    switch (_drivingState) {
      case DrivingState.notDriving:
        return Icons.directions_car_outlined;
      case DrivingState.startingDrive:
        return Icons.play_circle_outline;
      case DrivingState.driving:
        return Icons.directions_car;
      case DrivingState.stoppingDrive:
        return Icons.stop_circle_outlined;
    }
  }

  Color _getStateColor() {
    switch (_drivingState) {
      case DrivingState.notDriving:
        return AppColors.textTertiary;
      case DrivingState.startingDrive:
        return AppColors.warning;
      case DrivingState.driving:
        return AppColors.success;
      case DrivingState.stoppingDrive:
        return AppColors.warning;
    }
  }

  String _getStateMessage() {
    switch (_drivingState) {
      case DrivingState.notDriving:
        return 'Aguardando Viagem';
      case DrivingState.startingDrive:
        return 'Detectando Direção...';
      case DrivingState.driving:
        return 'Dirigindo';
      case DrivingState.stoppingDrive:
        return 'Finalizando Viagem...';
    }
  }

  String _getStateDescription() {
    switch (_drivingState) {
      case DrivingState.notDriving:
        return 'O Sentinel AI detectará automaticamente quando você começar a dirigir';
      case DrivingState.startingDrive:
        return 'Confirmando que você está dirigindo um veículo';
      case DrivingState.driving:
        return 'Monitorando sua condução em tempo real';
      case DrivingState.stoppingDrive:
        return 'Confirmando que você parou de dirigir';
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  void _showEventAlert(TelematicsEvent event) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${event.eventTypeString} detectado'),
        backgroundColor: _getEventColor(event.eventType),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Color _getEventColor(TelematicsEventType eventType) {
    switch (eventType) {
      case TelematicsEventType.hardBraking:
      case TelematicsEventType.highGForce:
        return AppColors.danger;
      case TelematicsEventType.speeding:
      case TelematicsEventType.rapidAcceleration:
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  void _showTripSummary(Trip trip, List<TelematicsEvent> events) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Viagem Finalizada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Duração: ${_formatDuration(Duration(seconds: trip.duration ?? 0))}'),
            Text('Distância: ${(trip.distance ?? 0).toStringAsFixed(1)} km'),
            Text('Velocidade máxima: ${(trip.maxSpeed ?? 0).toStringAsFixed(0)} km/h'),
            Text('Score de segurança: ${(trip.safetyScore ?? 0).toStringAsFixed(1)}'),
            Text('Eventos: ${events.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDebugInfo() {
    final stats = _tripManager.getManagerStats();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Informações de Debug'),
        content: SingleChildScrollView(
          child: Text(stats.toString()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Não dispose do TripManager aqui pois ele é global
    super.dispose();
  }
}

