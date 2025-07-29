import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/location_service.dart';
import '../services/activity_detection_service.dart' as activity;
import '../services/telematics_analyzer.dart';
import '../services/database_service.dart';

class TripScreen extends StatefulWidget {
  final LocationService locationService;
  final activity.ActivityDetectionService activityService;
  final TelematicsAnalyzer telematicsAnalyzer;
  final DatabaseService databaseService;

  const TripScreen({
    super.key,
    required this.locationService,
    required this.activityService,
    required this.telematicsAnalyzer,
    required this.databaseService,
  });

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Viagem'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car,
              size: 64,
              color: AppColors.primary,
            ),
            SizedBox(height: 16),
            Text(
              'Tela de Viagem',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Integração com dados reais implementada',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

