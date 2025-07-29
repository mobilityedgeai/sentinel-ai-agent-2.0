import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/telematics_analyzer.dart';
import '../services/database_service.dart';

class AnalyticsScreen extends StatefulWidget {
  final TelematicsAnalyzer telematicsAnalyzer;
  final DatabaseService databaseService;

  const AnalyticsScreen({
    super.key,
    required this.telematicsAnalyzer,
    required this.databaseService,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Análises'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics,
              size: 64,
              color: AppColors.primary,
            ),
            SizedBox(height: 16),
            Text(
              'Tela de Análises',
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

