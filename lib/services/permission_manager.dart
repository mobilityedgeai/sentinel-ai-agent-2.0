import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionManager extends ChangeNotifier {
  bool _hasLocationPermission = false;
  bool _hasNotificationPermission = false;
  bool _hasActivityRecognitionPermission = false;

  bool get hasLocationPermission => _hasLocationPermission;
  bool get hasNotificationPermission => _hasNotificationPermission;
  bool get hasActivityRecognitionPermission => _hasActivityRecognitionPermission;

  Future<bool> checkAllPermissions() async {
    try {
      // Verificar permissão de localização
      final locationStatus = await Permission.location.status;
      _hasLocationPermission = locationStatus.isGranted;

      // Verificar permissão de localização em segundo plano
      final backgroundLocationStatus = await Permission.locationAlways.status;
      if (!backgroundLocationStatus.isGranted) {
        _hasLocationPermission = false;
      }

      // Verificar permissão de notificação
      final notificationStatus = await Permission.notification.status;
      _hasNotificationPermission = notificationStatus.isGranted;

      // Verificar permissão de reconhecimento de atividade (Android)
      if (defaultTargetPlatform == TargetPlatform.android) {
        final activityStatus = await Permission.activityRecognition.status;
        _hasActivityRecognitionPermission = activityStatus.isGranted;
      } else {
        _hasActivityRecognitionPermission = true; // iOS não precisa dessa permissão específica
      }

      notifyListeners();
      return _hasLocationPermission && _hasNotificationPermission && _hasActivityRecognitionPermission;
    } catch (e) {
      debugPrint('Erro ao verificar permissões: $e');
      return false;
    }
  }

  Future<bool> requestAllPermissions() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
        Permission.locationAlways,
        Permission.notification,
        if (defaultTargetPlatform == TargetPlatform.android) Permission.activityRecognition,
      ].request();

      // Verificar permissão de localização
      _hasLocationPermission = statuses[Permission.location]?.isGranted == true &&
                              statuses[Permission.locationAlways]?.isGranted == true;

      // Verificar permissão de notificação
      _hasNotificationPermission = statuses[Permission.notification]?.isGranted == true;

      // Verificar permissão de reconhecimento de atividade
      if (defaultTargetPlatform == TargetPlatform.android) {
        _hasActivityRecognitionPermission = statuses[Permission.activityRecognition]?.isGranted == true;
      } else {
        _hasActivityRecognitionPermission = true;
      }

      notifyListeners();
      return _hasLocationPermission && _hasNotificationPermission && _hasActivityRecognitionPermission;
    } catch (e) {
      debugPrint('Erro ao solicitar permissões: $e');
      return false;
    }
  }

  Future<bool> checkLocationPermission() async {
    try {
      final status = await Permission.location.status;
      final backgroundStatus = await Permission.locationAlways.status;
      
      _hasLocationPermission = status.isGranted && backgroundStatus.isGranted;
      notifyListeners();
      return _hasLocationPermission;
    } catch (e) {
      debugPrint('Erro ao verificar permissão de localização: $e');
      return false;
    }
  }

  Future<bool> checkNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      _hasNotificationPermission = status.isGranted;
      notifyListeners();
      return _hasNotificationPermission;
    } catch (e) {
      debugPrint('Erro ao verificar permissão de notificação: $e');
      return false;
    }
  }

  Future<bool> checkActivityRecognitionPermission() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.activityRecognition.status;
        _hasActivityRecognitionPermission = status.isGranted;
      } else {
        _hasActivityRecognitionPermission = true;
      }
      notifyListeners();
      return _hasActivityRecognitionPermission;
    } catch (e) {
      debugPrint('Erro ao verificar permissão de reconhecimento de atividade: $e');
      return false;
    }
  }

  Future<bool> requestLocationPermission() async {
    try {
      final status = await Permission.location.request();
      if (status.isGranted) {
        // Solicitar também permissão de localização em segundo plano
        final backgroundStatus = await Permission.locationAlways.request();
        _hasLocationPermission = backgroundStatus.isGranted;
      } else {
        _hasLocationPermission = false;
      }
      
      notifyListeners();
      return _hasLocationPermission;
    } catch (e) {
      debugPrint('Erro ao solicitar permissão de localização: $e');
      return false;
    }
  }

  Future<bool> requestNotificationPermission() async {
    try {
      final status = await Permission.notification.request();
      _hasNotificationPermission = status.isGranted;
      notifyListeners();
      return _hasNotificationPermission;
    } catch (e) {
      debugPrint('Erro ao solicitar permissão de notificação: $e');
      return false;
    }
  }

  Future<bool> requestActivityRecognitionPermission() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.activityRecognition.request();
        _hasActivityRecognitionPermission = status.isGranted;
      } else {
        _hasActivityRecognitionPermission = true;
      }
      notifyListeners();
      return _hasActivityRecognitionPermission;
    } catch (e) {
      debugPrint('Erro ao solicitar permissão de reconhecimento de atividade: $e');
      return false;
    }
  }

  Future<void> openAppSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      debugPrint('Erro ao abrir configurações do app: $e');
    }
  }

  String getPermissionStatusReport() {
    return '''
Relatório de Permissões:
- Localização: ${_hasLocationPermission ? '✅ Concedida' : '❌ Negada'}
- Notificações: ${_hasNotificationPermission ? '✅ Concedida' : '❌ Negada'}
- Reconhecimento de Atividade: ${_hasActivityRecognitionPermission ? '✅ Concedida' : '❌ Negada'}
    ''';
  }

  bool get allPermissionsGranted => 
      _hasLocationPermission && 
      _hasNotificationPermission && 
      _hasActivityRecognitionPermission;
}

