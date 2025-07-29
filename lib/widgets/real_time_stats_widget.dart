import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../services/real_data_service.dart';
import '../services/real_time_notifier.dart';

class RealTimeStatsWidget extends StatefulWidget {
  @override
  _RealTimeStatsWidgetState createState() => _RealTimeStatsWidgetState();
}

class _RealTimeStatsWidgetState extends State<RealTimeStatsWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer2<RealDataService, RealTimeNotifier>(
      builder: (context, realDataService, realTimeNotifier, child) {
        final stats = realDataService.getGeneralStats();
        final currentLocation = realDataService.getCurrentLocation();
        final isCollecting = realDataService.isCollecting;
        
        return Card(
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header com status
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Icon(
                          isCollecting ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: isCollecting 
                              ? AppColors.success.withOpacity(0.5 + _pulseController.value * 0.5)
                              : AppColors.textSecondary,
                          size: 20,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Dados em Tempo Real',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCollecting ? AppColors.success : AppColors.textSecondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isCollecting ? 'ATIVO' : 'INATIVO',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Velocidade atual
                if (currentLocation != null && isCollecting) ...[
                  Row(
                    children: [
                      Icon(Icons.speed, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Velocidade: ${(currentLocation.speed ?? 0.0).toStringAsFixed(1)} km/h',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Grid de estatísticas
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    _buildStatItem(
                      'Viagens',
                      stats['totalTrips']?.toString() ?? '0',
                      Icons.trip_origin,
                      AppColors.primary,
                    ),
                    _buildStatItem(
                      'Distância',
                      '${(stats['totalDistance'] ?? 0.0).toStringAsFixed(1)} km',
                      Icons.straighten,
                      AppColors.accent,
                    ),
                    _buildStatItem(
                      'Eventos',
                      stats['totalEvents']?.toString() ?? '0',
                      Icons.warning,
                      AppColors.warning,
                    ),
                    _buildStatItem(
                      'Score',
                      (stats['averageScore'] ?? 100.0).toStringAsFixed(0),
                      Icons.star,
                      AppColors.success,
                    ),
                  ],
                ),
                
                // Última atualização
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.update, color: AppColors.textSecondary, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Atualizado: ${_formatTime(DateTime.now())}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}

