import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../database/database_helper.dart';
import '../models/trip.dart';
import '../models/telematics_event.dart';
import '../widgets/safety_score_widget.dart';
import '../services/real_data_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final RealDataService _realDataService = RealDataService();
  
  Map<String, dynamic>? _userStats;
  List<Trip>? _recentTrips;
  List<TelematicsEvent>? _recentEvents;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
    _setupListeners();
  }

  void _setupListeners() {
    _realDataService.addListener(() {
      if (mounted) {
        _loadAnalytics();
      }
    });
  }

  @override
  void dispose() {
    _realDataService.removeListener(() {});
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Obter estatísticas do serviço de dados reais
      final realStats = await _realDataService.getGeneralStats();
      
      // Carregar viagens do banco de dados
      final trips = await _db.getAllTrips();
      final events = await _db.getAllTelematicsEvents();

      // Calcular estatísticas adicionais
      double totalTime = 0.0;
      double maxSpeed = 0.0;
      
      for (var trip in trips) {
        totalTime += (trip.duration ?? 0);
        if ((trip.maxSpeed ?? 0.0) > maxSpeed) {
          maxSpeed = trip.maxSpeed ?? 0.0;
        }
      }

      setState(() {
        _userStats = {
          'totalTrips': realStats['totalTrips'] ?? trips.length,
          'totalDistance': realStats['totalDistance'] ?? _calculateTotalDistance(trips),
          'averageScore': realStats['averageScore'] ?? _calculateAverageScore(trips),
          'totalEvents': realStats['totalEvents'] ?? events.length,
          'totalTime': totalTime,
          'maxSpeed': maxSpeed,
          'isOnTrip': realStats['isOnTrip'] ?? false,
          'currentTripDistance': realStats['currentTripDistance'] ?? 0.0,
        };
        _recentTrips = trips.take(5).toList();
        _recentEvents = events.take(10).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar análises: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  double _calculateTotalDistance(List<Trip> trips) {
    return trips.fold(0.0, (sum, trip) => sum + (trip.distance ?? 0.0));
  }

  double _calculateAverageScore(List<Trip> trips) {
    if (trips.isEmpty) return 100.0;
    return trips.fold(0.0, (sum, trip) => sum + (trip.safetyScore ?? 100.0)) / trips.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Análises de Condução'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                _showClearDataDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Text('Limpar Dados'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : _userStats == null
              ? const Center(
                  child: Text('Nenhum dado disponível'),
                )
              : RefreshIndicator(
                  onRefresh: _loadAnalytics,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOverviewCard(),
                        const SizedBox(height: 16),
                        _buildStatsGrid(),
                        const SizedBox(height: 16),
                        _buildRecentTripsSection(),
                        const SizedBox(height: 16),
                        _buildRecentEventsSection(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildOverviewCard() {
    final avgScore = (_userStats!['averageScore'] as double? ?? 100.0);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumo Geral',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SafetyScoreWidget(
                  score: avgScore.round(),
                  size: 80,
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatRow(
                        'Viagens Realizadas',
                        '${_userStats!['totalTrips']}',
                        Icons.directions_car,
                      ),
                      const SizedBox(height: 8),
                      _buildStatRow(
                        'Distância Total',
                        '${(_userStats!['totalDistance'] as double).toStringAsFixed(1)} km',
                        Icons.straighten,
                      ),
                      const SizedBox(height: 8),
                      _buildStatRow(
                        'Tempo Total',
                        '${(_userStats!['totalTime'] as double / 60).toStringAsFixed(1)}h',
                        Icons.access_time,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Viagens',
            '${_userStats!['totalTrips']}',
            Icons.directions_car,
            AppColors.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Eventos',
            '${_userStats!['totalEvents']}',
            Icons.warning,
            AppColors.warning,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTripsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Viagens Recentes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (_recentTrips == null || _recentTrips!.isEmpty)
              const Text(
                'Nenhuma viagem encontrada',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              ...(_recentTrips!.map((trip) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildTripRow(trip),
              )).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildTripRow(Trip trip) {
    return Row(
      children: [
        Icon(
          Icons.directions_car,
          color: AppColors.primary,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${(trip.distance ?? 0.0).toStringAsFixed(1)} km',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _formatDateTime(trip.startTime),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        SafetyScoreWidget(
          score: (trip.safetyScore ?? 100.0).round(),
          size: 30,
          showLabel: false,
        ),
      ],
    );
  }

  Widget _buildRecentEventsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Eventos Recentes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (_recentEvents == null || _recentEvents!.isEmpty)
              const Text(
                'Nenhum evento encontrado',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              Column(
                children: [
                  _buildEventRow(
                    'Frenagem Brusca',
                    _recentEvents!.where((e) => e.eventType == TelematicsEventType.hardBraking).length,
                    AppColors.danger,
                  ),
                  const SizedBox(height: 8),
                  _buildEventRow(
                    'Aceleração Rápida',
                    _recentEvents!.where((e) => e.eventType == TelematicsEventType.rapidAcceleration).length,
                    AppColors.warning,
                  ),
                  const SizedBox(height: 8),
                  _buildEventRow(
                    'Curva Acentuada',
                    _recentEvents!.where((e) => e.eventType == TelematicsEventType.sharpTurn).length,
                    AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  _buildEventRow(
                    'Excesso de Velocidade',
                    _recentEvents!.where((e) => e.eventType == TelematicsEventType.speeding).length,
                    AppColors.danger,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventRow(String title, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d atrás';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h atrás';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}min atrás';
    } else {
      return 'Agora';
    }
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar Dados'),
        content: const Text(
          'Tem certeza que deseja remover todos os dados de viagens e eventos? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearAllData();
              await _loadAnalytics();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Dados removidos com sucesso!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllData() async {
    try {
      await _db.clearAllData();
    } catch (e) {
      print('Erro ao limpar dados: $e');
    }
  }
}

