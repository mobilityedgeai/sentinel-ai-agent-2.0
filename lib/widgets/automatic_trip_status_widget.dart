import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../services/real_data_service.dart';
import '../services/real_time_notifier.dart';
import '../services/hybrid_trip_detection_service.dart';

class AutomaticTripStatusWidget extends StatefulWidget {
  @override
  _AutomaticTripStatusWidgetState createState() => _AutomaticTripStatusWidgetState();
}

class _AutomaticTripStatusWidgetState extends State<AutomaticTripStatusWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer3<RealDataService, RealTimeNotifier, HybridTripDetectionService>(
      builder: (context, realDataService, realTimeNotifier, hybridService, child) {
        final isCollecting = realDataService.isCollecting;
        final currentTrip = realDataService.currentTrip;
        final currentLocation = realDataService.getCurrentLocation();
        final hybridState = hybridService.state;
        final isHybridActive = hybridService.isInitialized;
        
        return Card(
          margin: const EdgeInsets.all(16),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCollecting 
                    ? [AppColors.primary, AppColors.primary.withOpacity(0.7)]
                    : [Colors.grey[600]!, Colors.grey[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Header com status
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _rotationController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: isCollecting ? _rotationController.value * 2 * 3.14159 : 0,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isCollecting ? Icons.gps_fixed : Icons.gps_off,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sistema de Detecção Automática',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isHybridActive && isCollecting
                                ? 'Sistema Híbrido: ${_getStateDescription(hybridState)}'
                                : isCollecting 
                                    ? 'Monitorando movimento...'
                                    : 'Aguardando movimento...',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isCollecting 
                                ? Colors.green.withOpacity(0.8 + _pulseController.value * 0.2)
                                : Colors.orange,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(
                                    isCollecting ? 0.8 + _pulseController.value * 0.2 : 1.0
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isCollecting ? 'ATIVO' : 'STANDBY',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Informações de detecção
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.white.withOpacity(0.8),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Detecção Automática de Viagens',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDetectionRule(
                        'Início da Viagem',
                        'Sistema Híbrido: 6 algoritmos + IA',
                        Icons.play_arrow,
                      ),
                      const SizedBox(height: 8),
                      _buildDetectionRule(
                        'Fim da Viagem',
                        'Análise inteligente multi-dimensional',
                        Icons.stop,
                      ),
                      if (currentLocation != null) ...[
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Velocidade Atual:',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${(currentLocation.speed ?? 0.0).toStringAsFixed(1)} km/h',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildDetectionRule(String title, String description, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.7),
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  String _getStateDescription(TripDetectionState state) {
    switch (state) {
      case TripDetectionState.idle:
        return 'Aguardando';
      case TripDetectionState.analyzing:
        return 'Analisando...';
      case TripDetectionState.tripActive:
        return 'Viagem Ativa';
      case TripDetectionState.endAnalyzing:
        return 'Finalizando...';
      default:
        return 'Desconhecido';
    }
  }
}

