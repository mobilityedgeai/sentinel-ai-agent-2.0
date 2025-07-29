import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../constants/app_colors.dart';
import '../models/user.dart';
import '../models/location_data.dart';
import '../services/location_service.dart';
import '../services/activity_detection_service.dart';
import '../services/telematics_analyzer.dart';
import '../services/database_service.dart';
import '../widgets/safety_score_widget.dart';
import '../widgets/location_card.dart';

class HomeScreenReal extends StatefulWidget {
  @override
  _HomeScreenRealState createState() => _HomeScreenRealState();
}

class _HomeScreenRealState extends State<HomeScreenReal> {
  StreamSubscription? _locationSubscription;
  StreamSubscription? _activitySubscription;
  StreamSubscription? _telematicsSubscription;
  
  // Estado atual
  double _currentLatitude = 0.0;
  double _currentLongitude = 0.0;
  double _currentSpeed = 0.0;
  String _currentActivity = 'Detectando...';
  String _activityConfidence = 'low';
  int _safetyScore = 0; // Será calculado dos dados reais
  bool _isTracking = false;
  
  // Estatísticas
  int _totalTrips = 0;
  double _totalDistance = 0.0;
  int _totalEvents = 0;

  @override
  void initState() {
    super.initState();
    _initializeRealTimeData();
    _loadStatistics();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _activitySubscription?.cancel();
    _telematicsSubscription?.cancel();
    super.dispose();
  }

  void _initializeRealTimeData() {
    try {
      final locationService = Provider.of<LocationService>(context, listen: false);
      final activityService = Provider.of<ActivityDetectionService>(context, listen: false);
      final telematicsAnalyzer = Provider.of<TelematicsAnalyzer>(context, listen: false);

      // Listener para localização
      _locationSubscription = locationService.positionStream.listen(
        (position) {
          if (mounted) {
            setState(() {
              _currentLatitude = position.latitude;
              _currentLongitude = position.longitude;
              _currentSpeed = position.speed ?? 0.0;
              _isTracking = true;
            });
          }
        },
        onError: (error) {
          print('Erro na localização: $error');
        },
      );

      // Listener para atividade
      _activitySubscription = activityService.activityStream.listen(
        (activity) {
          if (mounted) {
            setState(() {
              _currentActivity = _getActivityName(activity);
              _activityConfidence = activityService.currentConfidence.name;
            });
          }
        },
        onError: (error) {
          print('Erro na detecção de atividade: $error');
        },
      );

      // Listener para eventos de telemática
      _telematicsSubscription = telematicsAnalyzer.eventStream.listen(
        (event) {
          if (mounted) {
            setState(() {
              _totalEvents++;
              // Atualizar score baseado na severidade do evento
              _safetyScore = (_safetyScore - ((event.severity ?? 0.0) * 10).round()).clamp(0, 100);
            });
          }
        },
        onError: (error) {
          print('Erro na análise de telemática: $error');
        },
      );

    } catch (e) {
      print('Erro ao inicializar dados em tempo real: $e');
    }
  }

  String _getActivityName(ActivityType type) {
    switch (type) {
      case ActivityType.still:
        return 'Parado';
      case ActivityType.walking:
        return 'Caminhando';
      case ActivityType.running:
        return 'Correndo';
      case ActivityType.cycling:
        return 'Ciclismo';
      case ActivityType.driving:
        return 'Dirigindo';
      case ActivityType.unknown:
      default:
        return 'Desconhecido';
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      
      final trips = await databaseService.getAllTrips();
      final events = await databaseService.getAllTelematicsEvents();
      
      double totalDistance = 0.0;
      double totalSafetyScore = 0.0;
      int validTrips = 0;
      
      for (final trip in trips) {
        totalDistance += trip.distance ?? 0.0;
        if (trip.safetyScore != null && trip.safetyScore! > 0) {
          totalSafetyScore += trip.safetyScore!;
          validTrips++;
        }
      }

      // Calcular score médio real ou usar 100 se não há viagens
      int calculatedScore = 100; // Score padrão para usuários novos
      if (validTrips > 0) {
        calculatedScore = (totalSafetyScore / validTrips).round();
      } else if (events.isNotEmpty) {
        // Se há eventos mas não viagens, reduzir score baseado na severidade
        double totalSeverity = 0.0;
        for (final event in events) {
          totalSeverity += event.severity ?? 0.0;
        }
        calculatedScore = (100 - (totalSeverity * 10)).clamp(0, 100).round();
      }

      if (mounted) {
        setState(() {
          _totalTrips = trips.length;
          _totalDistance = totalDistance;
          _totalEvents = events.length;
          _safetyScore = calculatedScore;
        });
      }
    } catch (e) {
      print('Erro ao carregar estatísticas: $e');
      // Em caso de erro, manter valores padrão
      if (mounted) {
        setState(() {
          _safetyScore = 100; // Score padrão em caso de erro
        });
      }
    }
  }

  Color _getActivityColor() {
    switch (_currentActivity) {
      case 'Dirigindo':
        return Colors.red;
      case 'Caminhando':
        return Colors.blue;
      case 'Correndo':
        return Colors.orange;
      case 'Ciclismo':
        return Colors.green;
      case 'Parado':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Sentinel AI',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadStatistics();
        },
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status do Rastreamento
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Status do Rastreamento',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _isTracking ? Colors.green : Colors.red,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _isTracking ? 'Ativo' : 'Inativo',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: _getActivityColor(),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            _currentActivity,
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (_activityConfidence != 'low') ...[
                            const SizedBox(width: 8),
                            Text(
                              '($_activityConfidence)',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_currentSpeed > 0) ...[
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.speed,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Velocidade: ${(_currentSpeed * 3.6).toStringAsFixed(1)} km/h',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 16),
              
              // Score de Segurança
              SafetyScoreWidget(score: _safetyScore),
              
              SizedBox(height: 16),
              
              // Localização Atual
              if (_currentLatitude != 0.0 && _currentLongitude != 0.0)
                LocationCard(
                  user: User(
                    id: 1,
                    name: 'Usuário Atual',
                    email: 'usuario@sentinel.ai',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                  location: LocationData(
                    latitude: _currentLatitude,
                    longitude: _currentLongitude,
                    timestamp: DateTime.now(),
                  ),
                ),
              
              SizedBox(height: 16),
              
              // Estatísticas
              Row(
                children: [
                  Expanded(
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.directions_car,
                              color: AppColors.primary,
                              size: 32,
                            ),
                            SizedBox(height: 8),
                            Text(
                              '$_totalTrips',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Viagens',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.straighten,
                              color: AppColors.accent,
                              size: 32,
                            ),
                            SizedBox(height: 8),
                            Text(
                              '${_totalDistance.toStringAsFixed(1)} km',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Distância',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              
              // Eventos Recentes
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Eventos de Telemática',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total de eventos detectados:',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '$_totalEvents',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

