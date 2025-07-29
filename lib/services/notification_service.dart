import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/telematics_event.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    try {
      // Configurações para Android
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // Configurações para iOS
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Configurações gerais
      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      // Inicializar plugin
      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Criar canais de notificação para Android
      await _createNotificationChannels();

      _isInitialized = true;
      debugPrint('NotificationService: Inicializado com sucesso');

    } catch (e) {
      debugPrint('Erro ao inicializar NotificationService: $e');
      _isInitialized = false;
    }
  }

  Future<void> _createNotificationChannels() async {
    // Canal para notificações de viagem
    const AndroidNotificationChannel tripChannel = AndroidNotificationChannel(
      'trip_notifications',
      'Notificações de Viagem',
      description: 'Notificações sobre início e fim de viagens',
      importance: Importance.high,
      playSound: true,
    );

    // Canal para alertas de segurança
    const AndroidNotificationChannel safetyChannel = AndroidNotificationChannel(
      'safety_alerts',
      'Alertas de Segurança',
      description: 'Alertas sobre eventos de direção perigosos',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    // Canal para notificações gerais
    const AndroidNotificationChannel generalChannel = AndroidNotificationChannel(
      'general_notifications',
      'Notificações Gerais',
      description: 'Notificações gerais do aplicativo',
      importance: Importance.defaultImportance,
    );

    // Registrar canais
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(tripChannel);

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(safetyChannel);

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(generalChannel);
  }

  void _onNotificationTapped(NotificationResponse notificationResponse) {
    final payload = notificationResponse.payload;
    debugPrint('Notificação tocada: $payload');
    
    // Aqui você pode implementar navegação baseada no payload
    // Por exemplo, abrir uma tela específica baseada no tipo de notificação
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = 'general_notifications',
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      const NotificationDetails notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'general_notifications',
          'Notificações Gerais',
          channelDescription: 'Notificações gerais do aplicativo',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      );

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      debugPrint('Notificação exibida: $title - $body');

    } catch (e) {
      debugPrint('Erro ao exibir notificação: $e');
    }
  }

  Future<void> showTripStartNotification({String? location}) async {
    const NotificationDetails notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'trip_notifications',
        'Notificações de Viagem',
        channelDescription: 'Notificações sobre início e fim de viagens',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF2196F3),
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(
        sound: 'default.wav',
      ),
    );

    final locationText = location != null ? ' em $location' : '';
    
    await _flutterLocalNotificationsPlugin.show(
      1001,
      '🚗 Viagem Iniciada',
      'O Sentinel AI está monitorando sua viagem$locationText.',
      notificationDetails,
      payload: 'trip_started',
    );
  }

  Future<void> showTripEndNotification({
    String? location,
    double? distance,
    int? duration,
    double? safetyScore,
  }) async {
    const NotificationDetails notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'trip_notifications',
        'Notificações de Viagem',
        channelDescription: 'Notificações sobre início e fim de viagens',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF4CAF50),
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(
        sound: 'default.wav',
      ),
    );

    String body = 'Sua viagem foi concluída com segurança.';
    
    if (distance != null && duration != null && safetyScore != null) {
      final distanceText = '${distance.toStringAsFixed(1)} km';
      final durationText = '${(duration / 60).toStringAsFixed(0)} min';
      final scoreText = '${safetyScore.toStringAsFixed(0)}%';
      
      body = '$distanceText • $durationText • Score: $scoreText';
    }
    
    await _flutterLocalNotificationsPlugin.show(
      1002,
      '🏁 Viagem Finalizada',
      body,
      notificationDetails,
      payload: 'trip_ended',
    );
  }

  Future<void> showSafetyAlert(TelematicsEventType eventType, {
    double? severity,
    String? location,
  }) async {
    final vibrationPattern = Int64List.fromList([0, 1000, 500, 1000]);
    
    final NotificationDetails notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'safety_alerts',
        'Alertas de Segurança',
        channelDescription: 'Alertas sobre eventos de direção perigosos',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFFFF5722),
        playSound: true,
        enableVibration: true,
        vibrationPattern: vibrationPattern,
      ),
      iOS: DarwinNotificationDetails(
        sound: 'default.wav',
      ),
    );

    final eventInfo = _getEventInfo(eventType);
    final severityText = severity != null ? 
        ' (${severity.toStringAsFixed(1)} ${eventInfo['unit']})' : '';
    final locationText = location != null ? ' em $location' : '';
    
    await _flutterLocalNotificationsPlugin.show(
      2000 + eventType.index,
      '⚠️ ${eventInfo['title']}',
      '${eventInfo['description']}$severityText$locationText',
      notificationDetails,
      payload: 'safety_alert_${eventType.toString()}',
    );
  }

  Map<String, String> _getEventInfo(TelematicsEventType eventType) {
    switch (eventType) {
      case TelematicsEventType.hardBraking:
        return {
          'title': 'Freada Brusca Detectada',
          'description': 'Cuidado com freadas muito bruscas',
          'unit': 'm/s²',
        };
      case TelematicsEventType.rapidAcceleration:
        return {
          'title': 'Aceleração Rápida Detectada',
          'description': 'Evite acelerações muito bruscas',
          'unit': 'm/s²',
        };
      case TelematicsEventType.sharpTurn:
        return {
          'title': 'Curva Acentuada Detectada',
          'description': 'Reduza a velocidade em curvas',
          'unit': 'rad/s',
        };
      case TelematicsEventType.speeding:
        return {
          'title': 'Excesso de Velocidade',
          'description': 'Respeite os limites de velocidade',
          'unit': 'km/h',
        };
      case TelematicsEventType.highGForce:
        return {
          'title': 'Força G Alta Detectada',
          'description': 'Movimento brusco detectado',
          'unit': 'm/s²',
        };
      default:
        return {
          'title': 'Evento de Segurança',
          'description': 'Evento detectado durante a direção',
          'unit': '',
        };
    }
  }

  Future<void> showGeneralAlert(String message) async {
    await showNotification(
      title: '🔔 Sentinel AI',
      body: message,
      payload: 'general_alert',
    );
  }

  Future<void> showSpeedingAlert(double currentSpeed, double speedLimit) async {
    await showSafetyAlert(
      TelematicsEventType.speeding,
      severity: currentSpeed - speedLimit,
      location: null,
    );
  }

  Future<void> showBatteryOptimizationAlert() async {
    await showNotification(
      title: '🔋 Otimização de Bateria',
      body: 'Desative a otimização de bateria para melhor funcionamento do app.',
      payload: 'battery_optimization',
    );
  }

  Future<void> showPermissionAlert(String permissionName) async {
    await showNotification(
      title: '🔐 Permissão Necessária',
      body: 'O app precisa da permissão de $permissionName para funcionar corretamente.',
      payload: 'permission_alert',
    );
  }

  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  Future<bool> hasNotificationPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      return await androidImplementation?.areNotificationsEnabled() ?? false;
    }
    return true; // iOS gerencia permissões automaticamente
  }

  Future<bool> requestNotificationPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      // Para versão 15.1.3, o método correto é requestPermission
      return await androidImplementation?.requestPermission() ?? false;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      
      return await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      ) ?? false;
    }
    return true;
  }
}

