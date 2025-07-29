import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../services/database_service.dart';
import '../models/trip.dart';
import '../models/telematics_event.dart';

class AnalyticsScreenReal extends StatefulWidget {
  @override
  _AnalyticsScreenRealState createState() => _AnalyticsScreenRealState();
}

class _AnalyticsScreenRealState extends State<AnalyticsScreenReal> {
  bool _isLoading = true;
  List<Trip> _trips = [];
  List<TelematicsEvent> _events = [];
  
  // Estatísticas
  int _totalTrips = 0;
  double _totalDistance = 0.0;
  int _totalDuration = 0;
  double _averageScore = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      
      // Carregar dados REAIS do banco de dados
      _trips = await databaseService.getAllTrips();
      _events = await databaseService.getAllTelematicsEvents();
      
      // Calcular estatísticas reais baseadas nos dados do banco
      _totalTrips = _trips.length;
      _totalDistance = _trips.fold(0.0, (sum, trip) => sum + (trip.distance ?? 0.0));
      _totalDuration = _trips.fold(0, (sum, trip) => sum + (trip.duration ?? 0));
      
      if (_trips.isNotEmpty) {
        _averageScore = _trips.fold(0.0, (sum, trip) => sum + (trip.safetyScore ?? 0.0)) / _trips.length;
      } else {
        _averageScore = 0.0;
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar análises: $e');
      setState(() {
        _isLoading = false;
        // Manter valores zerados se não há dados
        _totalTrips = 0;
        _totalDistance = 0.0;
        _totalDuration = 0;
        _averageScore = 0.0;
      });
    }
  }

  Color _getEventColor(TelematicsEventType eventType) {
    switch (eventType) {
      case TelematicsEventType.hardBraking:
        return Colors.red;
      case TelematicsEventType.rapidAcceleration:
        return Colors.orange;
      case TelematicsEventType.sharpTurn:
        return Colors.yellow;
      case TelematicsEventType.speeding:
        return Colors.purple;
      case TelematicsEventType.highGForce:
        return Colors.red.shade800;
      default:
        return Colors.grey;
    }
  }

  String _getEventName(TelematicsEventType eventType) {
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
      default:
        return 'Evento Desconhecido';
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(title, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildEventRow(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
          Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Análises',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estatísticas Gerais
                  Text(
                    'Estatísticas Gerais',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildStatCard(
                        'Viagens',
                        '$_totalTrips',
                        Icons.directions_car,
                        AppColors.primary,
                      ),
                      _buildStatCard(
                        'Distância',
                        '${_totalDistance.toStringAsFixed(1)} km',
                        Icons.straighten,
                        Colors.blue,
                      ),
                      _buildStatCard(
                        'Tempo',
                        '${(_totalDuration / 3600).toStringAsFixed(1)}h',
                        Icons.access_time,
                        Colors.green,
                      ),
                      _buildStatCard(
                        'Score Médio',
                        '${_averageScore.toStringAsFixed(0)}',
                        Icons.star,
                        Colors.amber,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Eventos de Telemática
                  Text(
                    'Eventos de Condução',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildEventRow(
                            'Frenagem Brusca',
                            _events.where((e) => e.eventType == TelematicsEventType.hardBraking).length,
                            Colors.red,
                          ),
                          _buildEventRow(
                            'Aceleração Rápida',
                            _events.where((e) => e.eventType == TelematicsEventType.rapidAcceleration).length,
                            Colors.orange,
                          ),
                          _buildEventRow(
                            'Curva Acentuada',
                            _events.where((e) => e.eventType == TelematicsEventType.sharpTurn).length,
                            Colors.yellow,
                          ),
                          _buildEventRow(
                            'Excesso de Velocidade',
                            _events.where((e) => e.eventType == TelematicsEventType.speeding).length,
                            Colors.purple,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Histórico de Viagens
                  Text(
                    'Histórico de Viagens',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _trips.length,
                    itemBuilder: (context, index) {
                      final trip = _trips[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getScoreColor(trip.safetyScore?.toInt() ?? 0),
                            child: Text(
                              '${trip.safetyScore?.toInt() ?? 0}',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            '${trip.distance?.toStringAsFixed(1) ?? '0.0'} km',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${(trip.duration ?? 0) ~/ 60} min',
                          ),
                          trailing: Text(
                            '${trip.startTime?.day ?? 0}/${trip.startTime?.month ?? 0}',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

