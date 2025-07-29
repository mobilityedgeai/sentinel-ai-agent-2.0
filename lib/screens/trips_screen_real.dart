import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../database/database_helper.dart';
import '../models/trip.dart';
import '../services/real_data_service.dart';
import '../services/geocoding_service.dart';
import '../widgets/automatic_trip_status_widget.dart';

class TripsScreenReal extends StatefulWidget {
  const TripsScreenReal({Key? key}) : super(key: key);

  @override
  State<TripsScreenReal> createState() => _TripsScreenRealState();
}

class _TripsScreenRealState extends State<TripsScreenReal> {
  final DatabaseHelper _db = DatabaseHelper();
  final RealDataService _realDataService = RealDataService();
  final GeocodingService _geocodingService = GeocodingService();
  
  List<Trip> _trips = [];
  bool _isLoading = true;
  Trip? _currentTrip;

  @override
  void initState() {
    super.initState();
    _loadTrips();
    _setupListeners();
  }

  void _setupListeners() {
    _realDataService.addListener(_updateCurrentTrip);
  }

  void _updateCurrentTrip() {
    if (mounted) {
      setState(() {
        _currentTrip = _realDataService.currentTrip;
      });
    }
  }

  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final trips = await _db.getTrips();
      
      setState(() {
        _trips = trips;
        _currentTrip = _realDataService.currentTrip;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar viagens: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Viagens'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadTrips,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingState() : _buildContent(),
      // Removido floatingActionButton - agora é 100% automático
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadTrips,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Widget de status automático sempre visível
            AutomaticTripStatusWidget(),
            
            // Card de viagem atual (se existir)
            if (_currentTrip != null) _buildCurrentTripCard(),
            
            // Lista de viagens ou estado vazio
            _trips.isEmpty ? _buildEmptyState() : _buildTripsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTripCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _realDataService.getGeneralStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {};
        final duration = stats['tripDuration'] as int? ?? 0;
        final distance = stats['currentTripDistance'] as double? ?? 0.0;
        final currentSpeed = stats['currentSpeed'] as double? ?? 0.0;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.directions_car,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Viagem Detectada Automaticamente',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'AUTO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTripStat(
                  'Duração',
                  _formatDuration(duration),
                  Icons.access_time,
                ),
              ),
              Expanded(
                child: _buildTripStat(
                  'Distância',
                  '${distance.toStringAsFixed(1)} km',
                  Icons.straighten,
                ),
              ),
              Expanded(
                child: _buildTripStat(
                  'Velocidade',
                  '${currentSpeed.toStringAsFixed(0)} km/h',
                  Icons.speed,
                ),
              ),
            ],
          ),
          if (_currentTrip?.startAddress != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Iniciada em: ${_currentTrip!.startAddress}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
      },
    );
  }

  Widget _buildTripStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car,
            size: 80,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nenhuma viagem registrada',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'As viagens são detectadas automaticamente\nquando você começar a se mover',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _trips.length,
      itemBuilder: (context, index) {
        final trip = _trips[index];
        return _buildTripCard(trip);
      },
    );
  }

  Widget _buildTripCard(Trip trip) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showTripDetails(trip),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${(trip.distance ?? 0.0).toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          DateFormat('dd/MM/yyyy às HH:mm').format(trip.startTime),
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
                      color: _getScoreColor(trip.safetyScore?.toDouble() ?? 100.0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Score: ${trip.safetyScore?.round() ?? 100}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTripInfo(
                      'Duração',
                      _formatDuration(trip.duration ?? 0),
                      Icons.access_time,
                    ),
                  ),
                  Expanded(
                    child: _buildTripInfo(
                      'Vel. Máx.',
                      '${(trip.maxSpeed ?? 0.0).toStringAsFixed(0)} km/h',
                      Icons.speed,
                    ),
                  ),
                ],
              ),
              if (trip.startAddress != null || trip.endAddress != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                if (trip.startAddress != null)
                  _buildAddressRow(
                    'Origem',
                    trip.startAddress!,
                    Icons.location_on,
                    Colors.green,
                  ),
                if (trip.startAddress != null && trip.endAddress != null)
                  const SizedBox(height: 8),
                if (trip.endAddress != null)
                  _buildAddressRow(
                    'Destino',
                    trip.endAddress!,
                    Icons.flag,
                    Colors.red,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripInfo(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAddressRow(String label, String address, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showTripDetails(Trip trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildTripDetailsModal(trip),
    );
  }

  Widget _buildTripDetailsModal(Trip trip) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detalhes da Viagem',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildDetailRow('Data', DateFormat('dd/MM/yyyy').format(trip.startTime)),
                  _buildDetailRow('Horário de Início', DateFormat('HH:mm').format(trip.startTime)),
                  if (trip.endTime != null)
                    _buildDetailRow('Horário de Fim', DateFormat('HH:mm').format(trip.endTime!)),
                  _buildDetailRow('Duração', _formatDuration(trip.duration ?? 0)),
                  _buildDetailRow('Distância', '${(trip.distance ?? 0.0).toStringAsFixed(2)} km'),
                  _buildDetailRow('Velocidade Máxima', '${(trip.maxSpeed ?? 0.0).toStringAsFixed(1)} km/h'),
                  _buildDetailRow('Score de Segurança', '${trip.safetyScore?.round() ?? 100}'),
                  if (trip.startAddress != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Endereços',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow('Origem', trip.startAddress!),
                    if (trip.endAddress != null)
                      _buildDetailRow('Destino', trip.endAddress!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '${minutes}min';
    } else {
      int hours = minutes ~/ 60;
      int remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}min';
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    _realDataService.removeListener(_updateCurrentTrip);
    super.dispose();
  }
}

