import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../constants/app_colors.dart';
import '../services/real_data_service.dart';
import '../services/real_time_notifier.dart';
import '../widgets/location_card.dart';
import '../widgets/user_avatar.dart';
import '../models/user.dart';
import '../models/location_data.dart';
import '../services/location_service.dart';
import '../services/activity_recognition_service.dart' as activity;
import '../services/telematics_analyzer.dart';
import '../services/database_service.dart';
import '../services/real_data_service.dart';

class HomeScreen extends StatefulWidget {
  final LocationService locationService;
  final activity.ActivityRecognitionService activityService;
  final TelematicsAnalyzer telematicsAnalyzer;
  final DatabaseService databaseService;

  const HomeScreen({
    super.key,
    required this.locationService,
    required this.activityService,
    required this.telematicsAnalyzer,
    required this.databaseService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RealDataService _realDataService = RealDataService();
  LocationData? _currentPosition;
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String _trackingStatus = 'Inativo';

  @override
  void initState() {
    super.initState();
    _initializeRealData();
    _setupListeners();
  }

  /// Inicializa coleta de dados reais
  Future<void> _initializeRealData() async {
    try {
      debugPrint('🚀 Inicializando coleta de dados reais...');
      
      // Iniciar coleta de dados reais
      await _realDataService.startDataCollection();
      
      // Obter dados iniciais
      _updateStats();
      
      setState(() {
        _isLoading = false;
        _trackingStatus = _realDataService.isCollecting ? 'Ativo' : 'Inativo';
      });
      
      debugPrint('✅ Dados reais inicializados');
    } catch (e) {
      debugPrint('❌ Erro ao inicializar dados reais: $e');
      setState(() {
        _isLoading = false;
        _trackingStatus = 'Erro';
      });
    }
  }

  /// Atualiza estatísticas
  void _updateStats() {
    _stats = _realDataService.getGeneralStats();
    _currentPosition = _realDataService.getCurrentLocation();
    
    setState(() {
      _trackingStatus = _realDataService.isCollecting ? 'Ativo' : 'Inativo';
    });
  }

  /// Configura listeners para atualizações em tempo real
  void _setupListeners() {
    // Listener para mudanças no serviço de dados reais
    _realDataService.addListener(_updateStats);
  }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<RealDataService, RealTimeNotifier>(
      builder: (context, realDataService, realTimeNotifier, child) {
        // Atualizar dados sempre que houver mudanças
        _stats = realDataService.getGeneralStats();
        _currentPosition = realDataService.getCurrentLocation();
        _trackingStatus = realDataService.isCollecting ? 'Ativo' : 'Inativo';
        
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _initializeRealData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildTrackingStatusCard(),
            const SizedBox(height: 24),
            _buildSafetyScoreCard(),
            const SizedBox(height: 24),
            _buildStatsGrid(),
            const SizedBox(height: 24),
            _buildLocationCard(),
            const SizedBox(height: 24),
            _buildTelematicsEventsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const UserAvatar(
          name: 'Usuário',
          imageUrl: null,
          size: 48,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Olá, Usuário!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                _getGreetingMessage(),
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            // TODO: Implementar notificações
          },
          icon: const Icon(
            Icons.notifications_outlined,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTrackingStatusCard() {
    Color statusColor = _trackingStatus == 'Ativo' ? Colors.green : 
                       _trackingStatus == 'Erro' ? Colors.red : Colors.orange;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            color: statusColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Status do Rastreamento',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentPosition != null 
                    ? 'Detectando localização...'
                    : 'Aguardando GPS...',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _trackingStatus,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyScoreCard() {
    double score = _stats['averageScore']?.toDouble() ?? 100.0;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Score de Segurança',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _getScoreColor(score),
                width: 8,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${score.round()}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(score),
                    ),
                  ),
                  const Text(
                    'SCORE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _getScoreLabel(score),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _getScoreColor(score),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.directions_car,
            title: 'Viagens',
            value: '${_stats['totalTrips'] ?? 0}',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            icon: Icons.straighten,
            title: 'Distância',
            value: '${(_stats['totalDistance'] ?? 0.0).toStringAsFixed(1)} km',
            color: Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
          SafetyScoreWidget(
            score: _safetyScore.round(),
            size: 120,
          ),
          const SizedBox(height: 16),
          Text(
            _getScoreDescription(_safetyScore),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status Atual',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getActivityColor(),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getActivityDisplayName(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (_currentActivity != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getConfidenceText(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _getConfidenceColor(),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    if (_currentPosition == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Column(
          children: [
            Icon(
              Icons.location_searching,
              size: 48,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 12),
            Text(
              'Obtendo localização...',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final user = User(
      id: 1,
      name: 'Usuário Atual',
      email: 'usuario@exemplo.com',
      phoneNumber: '+55 11 99999-9999',
      profileImageUrl: null,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final locationData = LocationData(
      id: null,
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      accuracy: _currentPosition!.accuracy,
      speed: _currentPosition!.speed,
      timestamp: _currentPosition!.timestamp,
    );

    return LocationCard(
      user: user,
      location: locationData,
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ações Rápidas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.play_arrow,
                label: 'Iniciar Viagem',
                onTap: () async {
                  // Método startTrip será implementado futuramente
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Viagem iniciada!')),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.analytics,
                label: 'Ver Análises',
                onTap: () {
                  // Navegar para aba de análises
                  // TODO: Implementar navegação
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: AppColors.primary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia!';
    if (hour < 18) return 'Boa tarde!';
    return 'Boa noite!';
  }

  String _getScoreDescription(double score) {
    if (score >= 90) return 'Excelente condução! Continue assim.';
    if (score >= 70) return 'Boa condução, mas há espaço para melhorias.';
    if (score >= 50) return 'Condução moderada. Pratique direção defensiva.';
    return 'Atenção! Revise seus hábitos de condução.';
  }

  String _getActivityDisplayName() {
    if (_currentActivity == null) return 'Detectando...';
    
    switch (_currentActivity!.type) {
      case activity.ActivityType.unknown:
        return 'Desconhecido';
      case activity.ActivityType.still:
        return 'Parado';
      case activity.ActivityType.walking:
        return 'Caminhando';
      case activity.ActivityType.running:
        return 'Correndo';
      case activity.ActivityType.cycling:
        return 'Ciclismo';
      case activity.ActivityType.driving:
        return 'Dirigindo';
      case activity.ActivityType.unknown:
        return 'Desconhecido';
      default:
        return 'Desconhecido';
    }
  }

  Color _getActivityColor() {
    if (_currentActivity == null) return AppColors.textSecondary;
    
    switch (_currentActivity!.type) {
      case activity.ActivityType.driving:
        return Colors.green;
      case activity.ActivityType.walking:
        return Colors.blue;
      case activity.ActivityType.running:
        return Colors.orange;
      case activity.ActivityType.cycling:
        return Colors.purple;
      case activity.ActivityType.still:
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _getConfidenceColor() {
    if (_currentActivity == null) return AppColors.textSecondary;
    
    switch (_currentActivity!.confidence) {
      case activity.ActivityConfidence.high:
        return Colors.green;
      case activity.ActivityConfidence.medium:
        return Colors.orange;
      case activity.ActivityConfidence.low:
        return Colors.red;
    }
  }

  String _getConfidenceText() {
    if (_currentActivity == null) return '';
    
    switch (_currentActivity!.confidence) {
      case activity.ActivityConfidence.high:
        return 'Alta';
      case activity.ActivityConfidence.medium:
        return 'Média';
      case activity.ActivityConfidence.low:
        return 'Baixa';
    }
  }
}


  Widget _buildLocationCard() {
    if (_currentPosition == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Column(
          children: [
            Icon(
              Icons.location_off,
              color: AppColors.textSecondary,
              size: 48,
            ),
            SizedBox(height: 12),
            Text(
              'Localização não disponível',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Aguardando sinal GPS...',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Localização Atual',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Latitude: ${_currentPosition!.latitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Longitude: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_currentPosition!.speed.toStringAsFixed(1)} km/h',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const Text(
                    'Velocidade',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Precisão: ${_currentPosition!.accuracy.toStringAsFixed(1)}m',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelematicsEventsCard() {
    int eventCount = _stats['totalEvents'] ?? 0;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Eventos de Telemática',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Total de eventos detectados: $eventCount',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildEventIndicator('Frenagem Brusca', Colors.red, 0),
              const SizedBox(width: 16),
              _buildEventIndicator('Aceleração Rápida', Colors.orange, 0),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildEventIndicator('Curva Acentuada', Colors.yellow, 0),
              const SizedBox(width: 16),
              _buildEventIndicator('Excesso de Velocidade', Colors.purple, 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventIndicator(String label, Color color, int count) {
    return Expanded(
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
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getScoreLabel(double score) {
    if (score >= 80) return 'Excelente';
    if (score >= 60) return 'Bom';
    if (score >= 40) return 'Regular';
    return 'Ruim';
  }

  String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia! Dirija com segurança.';
    if (hour < 18) return 'Boa tarde! Mantenha-se seguro.';
    return 'Boa noite! Cuidado nas estradas.';
  }

        );
      },
    );
  }

  @override
  void dispose() {
    _realDataService.removeListener(_updateStats);
    super.dispose();
  }
}

