import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../constants/app_colors.dart';
import '../models/component_health.dart';
import '../models/maintenance_prediction.dart';
import '../services/predictive_maintenance_real_service.dart';
import '../services/real_time_notifier.dart';

class PredictiveMaintenanceScreen extends StatefulWidget {
  @override
  _PredictiveMaintenanceScreenState createState() => _PredictiveMaintenanceScreenState();
}

class _PredictiveMaintenanceScreenState extends State<PredictiveMaintenanceScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    
    // Controladores de animação
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
    
    // Inicializar serviço
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = Provider.of<PredictiveMaintenanceRealService>(context, listen: false);
      service.initialize();
    });
    
    // Timer para refresh automático
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationController.value * 2 * 3.14159,
                  child: Icon(Icons.settings, color: AppColors.primary),
                );
              },
            ),
            const SizedBox(width: 8),
            const Text(
              'Manutenção Preditiva',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          Consumer<PredictiveMaintenanceRealService>(
            builder: (context, service, child) {
              return AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: service.isActive 
                          ? AppColors.success.withOpacity(0.5 + _pulseController.value * 0.5)
                          : AppColors.danger,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          service.isActive ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          service.isActive ? 'ATIVO' : 'INATIVO',
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
              );
            },
          ),
        ],
      ),
      body: Consumer2<PredictiveMaintenanceRealService, RealTimeNotifier>(
        builder: (context, maintenanceService, realTimeNotifier, child) {
          final realTimeData = maintenanceService.getRealTimeData();
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHealthScoreCard(realTimeData),
                const SizedBox(height: 16),
                _buildRealTimeDataCard(realTimeData),
                const SizedBox(height: 16),
                _buildActiveAlertsCard(maintenanceService),
                const SizedBox(height: 16),
                _buildComponentsGrid(maintenanceService),
                const SizedBox(height: 16),
                _buildPredictionsCard(maintenanceService),
                const SizedBox(height: 16),
                _buildActiveAlgorithmsCard(realTimeData),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHealthScoreCard(Map<String, dynamic> realTimeData) {
    final healthScore = realTimeData['overallHealthScore'] ?? 100.0;
    final isActive = realTimeData['isActive'] ?? false;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [AppColors.success.withOpacity(0.1), AppColors.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety, color: AppColors.success, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Health Score Geral',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: healthScore / 100,
                    strokeWidth: 8,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      healthScore >= 80 ? AppColors.success :
                      healthScore >= 60 ? Colors.orange :
                      AppColors.danger,
                    ),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${healthScore.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: healthScore >= 80 ? AppColors.success :
                               healthScore >= 60 ? Colors.orange :
                               AppColors.danger,
                      ),
                    ),
                    Text(
                      healthScore >= 80 ? 'Excelente' :
                      healthScore >= 60 ? 'Bom' :
                      healthScore >= 40 ? 'Regular' : 'Crítico',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildScoreIndicator(
                  'Críticos',
                  realTimeData['criticalAlerts'] ?? 0,
                  AppColors.danger,
                  Icons.warning,
                ),
                _buildScoreIndicator(
                  'Altos',
                  realTimeData['highAlerts'] ?? 0,
                  Colors.orange,
                  Icons.error_outline,
                ),
                _buildScoreIndicator(
                  'Componentes',
                  8,
                  AppColors.primary,
                  Icons.build,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreIndicator(String label, int value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildRealTimeDataCard(Map<String, dynamic> realTimeData) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Dados em Tempo Real',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildRealTimeMetric(
                    'Quilometragem',
                    '${(realTimeData['totalKilometers'] ?? 0.0).toStringAsFixed(1)} km',
                    Icons.speed,
                    AppColors.primary,
                  ),
                ),
                Expanded(
                  child: _buildRealTimeMetric(
                    'Horas de Uso',
                    '${(realTimeData['totalOperatingHours'] ?? 0.0).toStringAsFixed(1)}h',
                    Icons.access_time,
                    AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildRealTimeMetric(
                    'Viagens',
                    '${realTimeData['totalTrips'] ?? 0}',
                    Icons.trip_origin,
                    AppColors.primary,
                  ),
                ),
                Expanded(
                  child: _buildRealTimeMetric(
                    'Última Atualização',
                    _formatLastUpdate(realTimeData['lastUpdate']),
                    Icons.refresh,
                    AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealTimeMetric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveAlertsCard(PredictiveMaintenanceRealService service) {
    final alerts = service.alerts;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active, color: Colors.orange, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Alertas Ativos',
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
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    alerts.length.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (alerts.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success),
                    const SizedBox(width: 12),
                    const Text(
                      'Nenhum alerta ativo',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...alerts.take(3).map((alert) => _buildAlertItem(alert)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertItem(MaintenanceAlert alert) {
    Color alertColor = alert.severity == AlertSeverity.critical ? AppColors.danger :
                      alert.severity == AlertSeverity.high ? Colors.orange :
                      Colors.yellow[700]!;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alertColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: alertColor, width: 4)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: alertColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              alert.message,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentsGrid(PredictiveMaintenanceRealService service) {
    final components = service.componentHealth;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build_circle, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Componentes do Veículo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemCount: components.length,
              itemBuilder: (context, index) {
                final component = components.values.elementAt(index);
                return _buildComponentCard(component);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComponentCard(ComponentHealth component) {
    Color healthColor = component.healthScore >= 80 ? AppColors.success :
                       component.healthScore >= 60 ? Colors.orange :
                       AppColors.danger;
    
    IconData componentIcon = _getComponentIcon(component.type);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: healthColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: healthColor.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(componentIcon, color: healthColor, size: 32),
          const SizedBox(height: 8),
          Text(
            _getComponentName(component.type),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${component.healthScore.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: healthColor,
            ),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: component.healthScore / 100,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(healthColor),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionsCard(PredictiveMaintenanceRealService service) {
    final predictions = service.predictions;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Predições IA',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (predictions.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success),
                    const SizedBox(width: 12),
                    const Text(
                      'Nenhuma manutenção prevista',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...predictions.take(5).map((prediction) => _buildPredictionItem(prediction)),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionItem(MaintenancePrediction prediction) {
    final daysUntil = prediction.predictedDate.difference(DateTime.now()).inDays;
    final urgencyColor = prediction.urgency >= 0.8 ? AppColors.danger :
                        prediction.urgency >= 0.5 ? Colors.orange :
                        AppColors.success;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: urgencyColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: urgencyColor, width: 4)),
      ),
      child: Row(
        children: [
          Icon(_getComponentIcon(prediction.componentType), color: urgencyColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getComponentName(prediction.componentType),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Em $daysUntil dias • R\$ ${prediction.estimatedCost.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: urgencyColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              prediction.urgency >= 0.8 ? 'Alta' :
              prediction.urgency >= 0.5 ? 'Média' : 'Baixa',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveAlgorithmsCard(Map<String, dynamic> realTimeData) {
    final algorithms = realTimeData['algorithms'] ?? {};
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.functions, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Algoritmos Ativos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildAlgorithmItem(
              'Desgaste por Quilometragem',
              'Calcula desgaste baseado na distância percorrida',
              Icons.speed,
              algorithms['wearByKilometers'] ?? false,
            ),
            _buildAlgorithmItem(
              'Desgaste por Tempo',
              'Monitora degradação temporal dos componentes',
              Icons.access_time,
              algorithms['wearByTime'] ?? false,
            ),
            _buildAlgorithmItem(
              'Análise de Eventos',
              'Detecta impacto de frenagens, acelerações e curvas',
              Icons.analytics,
              algorithms['eventAnalysis'] ?? false,
            ),
            _buildAlgorithmItem(
              'Machine Learning',
              'Predições baseadas em padrões de uso',
              Icons.psychology,
              algorithms['machineLearning'] ?? false,
            ),
            _buildAlgorithmItem(
              'Algoritmos Híbridos',
              'Combinação inteligente de múltiplos fatores',
              Icons.hub,
              algorithms['hybridAlgorithms'] ?? false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlgorithmItem(String title, String description, IconData icon, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? AppColors.success.withOpacity(0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppColors.success : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isActive ? AppColors.success : Colors.grey[500],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isActive ? AppColors.success : Colors.grey[400],
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastUpdate(String? lastUpdate) {
    if (lastUpdate == null) return 'Nunca';
    
    try {
      final updateTime = DateTime.parse(lastUpdate);
      final now = DateTime.now();
      final difference = now.difference(updateTime);
      
      if (difference.inSeconds < 60) {
        return 'Agora mesmo';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}min atrás';
      } else {
        return '${difference.inHours}h atrás';
      }
    } catch (e) {
      return 'Erro';
    }
  }

  IconData _getComponentIcon(ComponentType type) {
    switch (type) {
      case ComponentType.brakes:
        return Icons.disc_full;
      case ComponentType.engine:
        return Icons.settings;
      case ComponentType.tires:
        return Icons.circle;
      case ComponentType.suspension:
        return Icons.vertical_align_center;
      case ComponentType.transmission:
        return Icons.tune;
      case ComponentType.battery:
        return Icons.battery_full;
      case ComponentType.airFilter:
        return Icons.air;
      case ComponentType.oilFilter:
        return Icons.opacity;
    }
  }

  String _getComponentName(ComponentType type) {
    switch (type) {
      case ComponentType.brakes:
        return 'Freios';
      case ComponentType.engine:
        return 'Motor';
      case ComponentType.tires:
        return 'Pneus';
      case ComponentType.suspension:
        return 'Suspensão';
      case ComponentType.transmission:
        return 'Transmissão';
      case ComponentType.battery:
        return 'Bateria';
      case ComponentType.airFilter:
        return 'Filtro de Ar';
      case ComponentType.oilFilter:
        return 'Filtro de Óleo';
    }
  }
}

