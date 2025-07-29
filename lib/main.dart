import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'constants/app_theme.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/location_service.dart';
import 'services/activity_detection_service.dart';
import 'services/trip_manager.dart';
import 'services/real_data_service.dart';
import 'services/predictive_maintenance_real_service.dart';
import 'services/real_time_notifier.dart';
import 'services/hybrid_trip_detection_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool firebaseInitialized = false;
  try {
    await Firebase.initializeApp();
    firebaseInitialized = true;
    debugPrint('Firebase inicializado com sucesso');
  } catch (e) {
    debugPrint('Erro ao inicializar Firebase: $e');
    debugPrint('Continuando sem Firebase...');
  }

  runApp(MyApp(firebaseInitialized: firebaseInitialized));
}

class MyApp extends StatelessWidget {
  final bool firebaseInitialized;
  
  const MyApp({super.key, required this.firebaseInitialized});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => DatabaseService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
        ChangeNotifierProvider(create: (_) => ActivityDetectionService()),
        ChangeNotifierProvider(create: (_) => TripManager()),
        ChangeNotifierProvider(create: (_) => RealDataService()),
        ChangeNotifierProvider(create: (_) => PredictiveMaintenanceRealService()),
        ChangeNotifierProvider(create: (_) => RealTimeNotifier()),
        ChangeNotifierProvider(create: (_) => HybridTripDetectionService()),
      ],
      child: MaterialApp(
        title: 'Sentinel AI',
        theme: AppTheme.lightTheme,
        home: firebaseInitialized ? const AuthWrapper() : const MainScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (snapshot.hasData) {
          return const MainScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

