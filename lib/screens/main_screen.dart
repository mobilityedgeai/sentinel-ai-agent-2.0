import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/location_data.dart';
import '../services/auth_service.dart';
import '../services/permission_manager.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/activity_detection_service.dart';
import '../services/telematics_analyzer.dart';
import '../services/notification_service.dart';
import '../services/idling_detection_service.dart';
import '../services/phone_usage_detection_service.dart';
import 'unified_home_screen.dart';
import 'trips_screen_real.dart';
import 'predictive_maintenance_screen.dart';
import 'settings_screen_real.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _servicesInitialized = false;
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupServices();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      final permissionManager = Provider.of<PermissionManager>(context, listen: false);
      final locationService = Provider.of<LocationService>(context, listen: false);
      final activityService = Provider.of<ActivityDetectionService>(context, listen: false);
      final telematicsAnalyzer = Provider.of<TelematicsAnalyzer>(context, listen: false);
      final notificationService = Provider.of<NotificationService>(context, listen: false);
      final idlingService = IdlingDetectionService();
      final phoneUsageService = PhoneUsageDetectionService();

      // Verificar e solicitar permissões
      final hasPermissions = await permissionManager.checkAllPermissions();
      
      if (hasPermissions == false) {
        final granted = await permissionManager.requestAllPermissions();
        if (granted == false) {
          // Mostrar dialog explicando a importância das permissões
          _showPermissionDialog();
          return;
        }
      }

      setState(() {
        _permissionsGranted = true;
      });

      // Inicializar serviços de localização
      await locationService.initialize();
      
      // Inicializar detecção de atividade
      await activityService.startDetection();
      
      // Inicializar detecção de idling
      await idlingService.startDetection();
      
      // Inicializar detecção de uso do telefone
      await phoneUsageService.startDetection();
      
      // Configurar listeners
      locationService.positionStream.listen((position) {
        // Analisar dados de telemática
        final locationData = LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          speed: position.speed,
          heading: position.heading,
          timestamp: DateTime.now(),
        );
        telematicsAnalyzer.processLocationData(locationData);
      });

      activityService.activityStream.listen((activity) {
        print('Atividade detectada: $activity (${activityService.currentConfidence})');
      });
      
      // Configurar listener para eventos de idling
      idlingService.onIdlingDetected = (event) {
        print('🚗 Idling detectado: ${event.description}');
        // TODO: Salvar evento no banco de dados
        // TODO: Mostrar notificação ao usuário
      };

      telematicsAnalyzer.eventStream.listen((event) {
        // Enviar notificação para eventos importantes
        if ((event.severity ?? 0.0) > 0.7) {
          print('Evento detectado: ${event.eventType} - Severidade: ${((event.severity ?? 0.0) * 100).toInt()}%');
        }
      });

      setState(() {
        _servicesInitialized = true;
      });

    } catch (e) {
      print('Erro ao inicializar serviços: $e');
      // Continuar com funcionalidade limitada
      setState(() {
        _servicesInitialized = true;
      });
    }
  }

  void _cleanupServices() {
    try {
      final locationService = Provider.of<LocationService>(context, listen: false);
      final activityService = Provider.of<ActivityDetectionService>(context, listen: false);
      final idlingService = IdlingDetectionService();
      final phoneUsageService = PhoneUsageDetectionService();
      
      locationService.dispose();
      activityService.dispose();
      idlingService.stopDetection();
      phoneUsageService.stopDetection();
    } catch (e) {
      print('Erro ao limpar serviços: $e');
    }
  }

  Future<void> _logout() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Mostrar diálogo de confirmação
      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sair da Conta'),
          content: const Text('Tem certeza que deseja sair da sua conta?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sair'),
            ),
          ],
        ),
      );
      
      if (shouldLogout == true) {
        // Limpar serviços antes de fazer logout
        _cleanupServices();
        
        // Fazer logout
        await authService.signOut();
        
        // Navegação é automática via AuthWrapper
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao fazer logout: $e'),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Permissões Necessárias'),
        content: Text(
          'O Sentinel AI precisa de acesso à localização, sensores e notificações para funcionar corretamente. '
          'Sem essas permissões, algumas funcionalidades podem não estar disponíveis.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _initializeServices(); // Tentar novamente
            },
            child: Text('Tentar Novamente'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _servicesInitialized = true; // Continuar sem permissões
              });
            },
            child: Text('Continuar Sem Permissões'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_servicesInitialized) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
              SizedBox(height: 16),
              Text(
                'Inicializando Sentinel AI...',
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                _permissionsGranted 
                  ? 'Configurando sensores e GPS...'
                  : 'Verificando permissões...',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sentinel AI'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Sair da conta',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          UnifiedHomeScreen(),
          TripsScreenReal(),
          PredictiveMaintenanceScreen(),
          SettingsScreenReal(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        backgroundColor: Colors.white,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'Viagens',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build_circle),
            label: 'Manutenção',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Config',
          ),
        ],
      ),
    );
  }
}

