import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/permission_manager.dart';
import '../services/location_service.dart';
import '../services/activity_detection_service.dart' as activity;
import '../services/telematics_analyzer.dart';

class SettingsScreen extends StatefulWidget {
  final PermissionManager permissionManager;
  final LocationService locationService;
  final activity.ActivityDetectionService activityService;
  final TelematicsAnalyzer telematicsAnalyzer;

  const SettingsScreen({
    super.key,
    required this.permissionManager,
    required this.locationService,
    required this.activityService,
    required this.telematicsAnalyzer,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Configurações'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.settings,
              size: 64,
              color: AppColors.primary,
            ),
            SizedBox(height: 16),
            Text(
              'Tela de Configurações',
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

