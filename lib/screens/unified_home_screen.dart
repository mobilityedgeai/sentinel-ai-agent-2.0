import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../constants/app_colors.dart';
import '../services/real_data_service.dart';
import '../services/real_time_notifier.dart';
import '../services/hybrid_trip_detection_service.dart';
import '../widgets/location_card.dart';
import '../widgets/user_avatar.dart';
import '../widgets/safety_score_widget.dart';
import '../widgets/automatic_trip_status_widget.dart';
import '../models/user.dart';
import '../models/location_data.dart';
import '../models/trip.dart';
import '../models/telematics_event.dart';
import '../database/database_helper.dart';

class UnifiedHomeScreen extends StatefulWidget {
  const UnifiedHomeScreen({super.key});

  @override
  State<UnifiedHomeScreen> createState() => _UnifiedHomeScreenState();
}

class _UnifiedHomeScreenState extends State<UnifiedHomeScreen> {
  final RealDataService _realDataService = RealDataService();
  final DatabaseHelper _db = DatabaseHelper();
  final HybridTripDetectionService _hybridService = HybridTripDetectionService();
  
  LocationData? _currentPosition;
  Map<String, dynamic> _stats = {};
  List<Trip> _recentTrips = [];
  List<TelematicsEvent> _recentEvents = [];
  bool _isLoading = true;
  String _trackingStatus = 'Inativo';
  Timer? _refreshTimer;
  
  // Variáveis para debug do sistema híbrido
  String _hybridStatus = 'Aguardando';
  double _hybridConfidence = 0.0;
  Map<String, double> _algorithmScores = {};
  String _lastAnalysisReasoning = 'Nenhuma análise ainda';
  DateTime? _lastAnalysisTime;
  List<TelematicsEvent> _recentTelematicsEvents = [];

  @override
  void initState() {
    super.initState();
    _initializeRealData();
    _setupListeners();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Inicializa coleta de dados reais
  Future<void> _initializeRealData() async {
    try {
      debugPrint('🚀 Inicializando sistema híbrido unificado...');
      
      // Iniciar sistema híbrido de detecção
      await _hybridService.initialize();
      
      // Iniciar coleta de dados reais
      await _realDataService.startDataCollection();
      
      // Carregar dados iniciais
      await _loadAllData();
      
      setState(() {
        _isLoading = false;
        _trackingStatus = _realDataService.isCollecting ? 'Ativo' : 'Inativo';
      });
      
      debugPrint('✅ Sistema híbrido unificado inicializado');
    } catch (e) {
      debugPrint('❌ Erro ao inicializar sistema híbrido: $e');
      setState(() {
        _isLoading = false;
        _trackingStatus = 'Erro';
      });
    }
  }

  /// Carrega todos os dados necessários
  Future<void> _loadAllData() async {
    try {
      // Obter estatísticas reais do banco SQLite
      _stats = await _realDataService.getGeneralStats();
      _currentPosition = _realDataService.getCurrentLocation();
      
      // Carregar viagens recentes do banco
      final trips = await _db.getTrips(limit: 10);
      _recentTrips = trips.take(5).toList();
      
      // Carregar eventos recentes do banco
      final events = await _db.getTelematicsEvents(limit: 10);
      _recentEvents = events.take(10).toList();
      
      // Atualizar estatísticas com dados do banco
      if (trips.isNotEmpty) {
        double totalTime = trips.fold(0.0, (sum, trip) => sum + (trip.duration ?? 0.0));
        double maxSpeed = trips.fold(0.0, (max, trip) => (trip.maxSpeed ?? 0.0) > max ? (trip.maxSpeed ?? 0.0) : max);
        
        _stats['totalTime'] = totalTime;
        _stats['maxSpeed'] = maxSpeed;
        _stats['totalTripsFromDB'] = trips.length;
        _stats['totalEventsFromDB'] = events.length;
      }
      
      debugPrint('📊 Dados carregados: ${_stats.length} estatísticas, ${_recentTrips.length} viagens, ${_recentEvents.length} eventos');
    } catch (e) {
      debugPrint('❌ Erro ao carregar dados: $e');
    }
  }

  /// Configura listeners para atualizações em tempo real
  void _setupListeners() {
    // Listener para mudanças no serviço de dados reais
    _realDataService.addListener(_updateStats);
    
    // Listener para detecção híbrida de viagens
    _hybridService.onTripStarted = (Trip? trip) {
      debugPrint('🚗 Viagem iniciada automaticamente pelo sistema híbrido');
      setState(() {
        _hybridStatus = 'Viagem Ativa';
      });
      _updateStats();
    };
    
    _hybridService.onTripEnded = (Trip? trip) {
      debugPrint('🛑 Viagem finalizada automaticamente pelo sistema híbrido');
      setState(() {
        _hybridStatus = 'Aguardando';
      });
      _loadAllData(); // Recarregar dados após fim da viagem
    };
    
    // Listener para análises do sistema híbrido
    _hybridService.onAnalysisUpdate = (result) {
      if (mounted) {
        setState(() {
          _hybridStatus = _hybridService.isTripActive ? 'Viagem Ativa' : 
                         (_hybridService.state == TripDetectionState.analyzing ? 'Analisando' : 'Aguardando');
          _hybridConfidence = result.confidence;
          _algorithmScores = result.algorithmScores;
          _lastAnalysisReasoning = result.reasoning;
          _lastAnalysisTime = DateTime.now();
        });
      }
    };
  }

  /// Inicia refresh automático
  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _updateStats();
      }
    });
  }

  /// Atualiza estatísticas em tempo real
  void _updateStats() async {
    if (!mounted) return;
    
    try {
      final newStats = await _realDataService.getGeneralStats();
      final newPosition = await _realDataService.forceLocationUpdate();
      final newStatus = _realDataService.isCollecting ? 'Ativo' : 'Inativo';
      
      // Carregar eventos telemáticos dos últimos 5 minutos
      final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
      final recentEvents = await _db.getTelematicsEventsSince(fiveMinutesAgo);
      
      if (mounted) {
        setState(() {
          _stats = newStats;
          _currentPosition = newPosition;
          _trackingStatus = newStatus;
          _recentTelematicsEvents = recentEvents;
        });
      }
    } catch (e) {
      debugPrint('❌ Erro ao atualizar estatísticas: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<RealDataService, RealTimeNotifier>(
      builder: (context, realDataService, realTimeNotifier, child) {
        // Atualizar apenas dados síncronos no build
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
      },
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadAllData();
        await _realDataService.forceLocationUpdate();
      },
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
            _buildAutomaticTripStatus(),
            const SizedBox(height: 24),
            _buildHybridSystemDebugCard(),
            const SizedBox(height: 24),
            _buildTelematicsEventsRealTimeCard(),
            const SizedBox(height: 24),
            _buildSafetyScoreCard(),
            const SizedBox(height: 24),
            _buildStatsGrid(),
            const SizedBox(height: 24),
            _buildLocationCard(),
            const SizedBox(height: 24),
            _buildTelematicsEventsCard(),
            const SizedBox(height: 24),
            _buildRecentTripsSection(),
            const SizedBox(height: 24),
            _buildRecentEventsSection(),
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
                    ? 'GPS: ${(_currentPosition!.speed ?? 0.0).toStringAsFixed(1)} km/h'
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

  Widget _buildAutomaticTripStatus() {
    return AutomaticTripStatusWidget();
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
          SafetyScoreWidget(
            score: score.round(),
            size: 120,
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
          const SizedBox(height: 8),
          Text(
            'Baseado em ${_stats['totalTrips'] ?? 0} viagens',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Estatísticas Gerais',
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
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.access_time,
                title: 'Tempo',
                value: '${((_stats['totalTime'] ?? 0.0) / 60).toStringAsFixed(1)}h',
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                icon: Icons.speed,
                title: 'Vel. Máx',
                value: '${(_stats['maxSpeed'] ?? 0.0).toStringAsFixed(0)} km/h',
                color: Colors.orange,
              ),
            ),
          ],
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

  Widget _buildTelematicsEventsCard() {
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
            'Eventos de Condução',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildEventRow('Frenagem Brusca', _stats['hardBrakingCount'] ?? 0, Colors.red),
          const Divider(height: 16),
          _buildEventRow('Aceleração Rápida', _stats['rapidAccelerationCount'] ?? 0, Colors.orange),
          const Divider(height: 16),
          _buildEventRow('Curva Acentuada', _stats['sharpTurnCount'] ?? 0, Colors.yellow),
          const Divider(height: 16),
          _buildEventRow('Excesso de Velocidade', _stats['speedingCount'] ?? 0, Colors.purple),
        ],
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

  Widget _buildRecentTripsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Viagens Recentes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                // TODO: Navegar para tela de viagens completa
              },
              child: const Text('Ver todas'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_recentTrips.isEmpty)
          Container(
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
            child: const Center(
              child: Text(
                'Nenhuma viagem encontrada\nInicie dirigindo para coletar dados',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...(_recentTrips.map((trip) => _buildTripCard(trip))),
      ],
    );
  }

  Widget _buildTripCard(Trip trip) {
    final duration = Duration(seconds: (trip.duration ?? 0).round());
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getScoreColor(trip.safetyScore ?? 100.0).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.directions_car,
              color: _getScoreColor(trip.safetyScore ?? 100.0),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${(trip.distance ?? 0.0).toStringAsFixed(1)} km • ${hours > 0 ? '${hours}h ' : ''}${minutes}min',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateTime(trip.startTime),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getScoreColor(trip.safetyScore ?? 100.0).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${(trip.safetyScore ?? 100.0).round()}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _getScoreColor(trip.safetyScore ?? 100.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Eventos Recentes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (_recentEvents.isEmpty)
          Container(
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
            child: const Center(
              child: Text(
                'Nenhum evento detectado\nDirija para gerar eventos telemáticos',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...(_recentEvents.take(3).map((event) => _buildEventCard(event))),
      ],
    );
  }

  Widget _buildEventCard(TelematicsEvent event) {
    IconData icon;
    Color color;
    
    switch (event.eventType) {
      case TelematicsEventType.hardBraking:
        icon = Icons.warning;
        color = Colors.red;
        break;
      case TelematicsEventType.rapidAcceleration:
        icon = Icons.speed;
        color = Colors.orange;
        break;
      case TelematicsEventType.sharpTurn:
        icon = Icons.turn_right;
        color = Colors.yellow;
        break;
      case TelematicsEventType.speeding:
        icon = Icons.speed;
        color = Colors.purple;
        break;
      default:
        icon = Icons.info;
        color = Colors.blue;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getEventDisplayName(event.eventType),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            _formatDateTime(event.timestamp),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // Métodos auxiliar  }

  /// Card de debug do sistema híbrido em tempo real
  Widget _buildHybridSystemDebugCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.psychology,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Sistema Híbrido - DEBUG',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Status atual
            _buildDebugRow('Status:', _hybridStatus, _getStatusColor(_hybridStatus)),
            const SizedBox(height: 8),
            
            // Confiança atual
            _buildDebugRow('Confiança:', '${(_hybridConfidence * 100).toStringAsFixed(1)}%', 
                          _getConfidenceColor(_hybridConfidence)),
            const SizedBox(height: 8),
            
            // Inicializado
            _buildDebugRow('Inicializado:', _hybridService.isInitialized ? 'Sim' : 'Não', 
                          _hybridService.isInitialized ? Colors.green : Colors.red),
            const SizedBox(height: 16),
            
            // Scores dos algoritmos
            const Text(
              'Scores dos Algoritmos:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            
            ..._algorithmScores.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      _getAlgorithmName(entry.key),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: LinearProgressIndicator(
                      value: entry.value,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getConfidenceColor(entry.value),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(entry.value * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            )).toList(),
            
            const SizedBox(height: 16),
            
            // Última análise
            const Text(
              'Última Análise:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _lastAnalysisReasoning,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            if (_lastAnalysisTime != null) ...[
              const SizedBox(height: 4),
              Text(
                'Há ${_formatDateTime(_lastAnalysisTime!)}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Card de eventos telemáticos em tempo real
  Widget _buildTelematicsEventsRealTimeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Eventos Telemáticos - TEMPO REAL',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Contador de eventos
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildEventCounter('Total', _recentTelematicsEvents.length, Colors.blue),
                _buildEventCounter('Frenagem', 
                  _recentTelematicsEvents.where((e) => e.type == TelematicsEventType.hardBraking).length, 
                  Colors.red),
                _buildEventCounter('Aceleração', 
                  _recentTelematicsEvents.where((e) => e.type == TelematicsEventType.rapidAcceleration).length, 
                  Colors.orange),
                _buildEventCounter('Curvas', 
                  _recentTelematicsEvents.where((e) => e.type == TelematicsEventType.sharpTurn).length, 
                  Colors.purple),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Lista de eventos recentes
            const Text(
              'Últimos 5 minutos:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            
            if (_recentTelematicsEvents.isEmpty)
              const Text(
                'Nenhum evento detectado',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              )
            else
              ...(_recentTelematicsEvents.take(5).map((event) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      _getEventIcon(event.type),
                      size: 16,
                      color: _getEventColor(event.type),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getEventDisplayName(event.type),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      _formatDateTime(event.timestamp),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugRow(String label, String value, Color color) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEventCounter(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Viagem Ativa':
        return Colors.green;
      case 'Analisando':
        return Colors.orange;
      case 'Aguardando':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    if (confidence >= 0.4) return Colors.yellow[700]!;
    return Colors.red;
  }

  String _getAlgorithmName(String key) {
    switch (key) {
      case 'speed':
        return 'Velocidade';
      case 'activity':
        return 'Atividade';
      case 'stability':
        return 'Estabilidade';
      case 'telematics':
        return 'Telemática';
      case 'context':
        return 'Contexto';
      case 'ml':
        return 'ML';
      default:
        return key;
    }
  }

  IconData _getEventIcon(TelematicsEventType type) {
    switch (type) {
      case TelematicsEventType.hardBraking:
        return Icons.warning;
      case TelematicsEventType.rapidAcceleration:
        return Icons.speed;
      case TelematicsEventType.sharpTurn:
        return Icons.turn_right;
      case TelematicsEventType.speeding:
        return Icons.speed;
      default:
        return Icons.info;
    }
  }

  Color _getEventColor(TelematicsEventType type) {
    switch (type) {
      case TelematicsEventType.hardBraking:
        return Colors.red;
      case TelematicsEventType.rapidAcceleration:
        return Colors.orange;
      case TelematicsEventType.sharpTurn:
        return Colors.purple;
      case TelematicsEventType.speeding:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getGreetingMessage() {   final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia! Dirija com segurança.';
    if (hour < 18) return 'Boa tarde! Tenha uma boa viagem.';
    return 'Boa noite! Cuidado nas estradas.';
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getScoreLabel(double score) {
    if (score >= 90) return 'Excelente';
    if (score >= 80) return 'Bom';
    if (score >= 70) return 'Regular';
    if (score >= 60) return 'Ruim';
    return 'Muito Ruim';
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

  String _getEventDisplayName(TelematicsEventType type) {
    switch (type) {
      case TelematicsEventType.hardBraking:
        return 'Frenagem Brusca';
      case TelematicsEventType.rapidAcceleration:
        return 'Aceleração Rápida';
      case TelematicsEventType.sharpTurn:
        return 'Curva Acentuada';
      case TelematicsEventType.speeding:
        return 'Excesso de Velocidade';
      default:
        return 'Evento Desconhecido';
    }
  }
}

