import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/database_service.dart';
import '../models/location_data.dart';

/// Serviço para manter rastreamento de localização em background
class BackgroundLocationService {
  static const String _isolateName = 'LocationBackgroundIsolate';
  static const String _portName = 'LocationBackgroundPort';
  
  static BackgroundLocationService? _instance;
  static BackgroundLocationService get instance {
    _instance ??= BackgroundLocationService._internal();
    return _instance!;
  }
  
  BackgroundLocationService._internal();
  
  bool _isRunning = false;
  ReceivePort? _receivePort;
  SendPort? _sendPort;
  
  bool get isRunning => _isRunning;

  /// Inicia o serviço de localização em background
  Future<bool> startBackgroundTracking() async {
    try {
      if (_isRunning) {
        debugPrint('Background tracking já está ativo');
        return true;
      }

      // Verificar permissões
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        debugPrint('Permissão de localização negada para background');
        return false;
      }

      // Configurar isolate para background
      _receivePort = ReceivePort();
      
      // Registrar callback para background
      IsolateNameServer.registerPortWithName(
        _receivePort!.sendPort,
        _portName,
      );
      
      // Escutar mensagens do isolate
      _receivePort!.listen(_handleBackgroundMessage);
      
      // Iniciar rastreamento em background
      await _startBackgroundIsolate();
      
      _isRunning = true;
      debugPrint('Background location tracking iniciado');
      return true;
    } catch (e) {
      debugPrint('Erro ao iniciar background tracking: $e');
      return false;
    }
  }

  /// Para o serviço de localização em background
  Future<void> stopBackgroundTracking() async {
    try {
      if (!_isRunning) {
        debugPrint('Background tracking já está parado');
        return;
      }

      // Parar isolate
      _sendPort?.send({'action': 'stop'});
      
      // Limpar recursos
      _receivePort?.close();
      _receivePort = null;
      _sendPort = null;
      
      // Remover registro do port
      IsolateNameServer.removePortNameMapping(_portName);
      
      _isRunning = false;
      debugPrint('Background location tracking parado');
    } catch (e) {
      debugPrint('Erro ao parar background tracking: $e');
    }
  }

  /// Inicia o isolate para processamento em background
  Future<void> _startBackgroundIsolate() async {
    try {
      // Criar isolate para background processing
      await Isolate.spawn(
        _backgroundIsolateEntryPoint,
        _receivePort!.sendPort,
        debugName: _isolateName,
      );
      
      // Aguardar confirmação do isolate
      final completer = Completer<SendPort>();
      
      _receivePort!.listen((message) {
        if (message is SendPort) {
          completer.complete(message);
        }
      });
      
      _sendPort = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Timeout ao iniciar isolate'),
      );
      
      // Enviar comando para iniciar tracking
      _sendPort!.send({'action': 'start'});
    } catch (e) {
      debugPrint('Erro ao iniciar isolate: $e');
      rethrow;
    }
  }

  /// Manipula mensagens do isolate de background
  void _handleBackgroundMessage(dynamic message) {
    try {
      if (message is Map<String, dynamic>) {
        switch (message['type']) {
          case 'location_update':
            _handleLocationUpdate(message['data']);
            break;
          case 'error':
            debugPrint('Erro no background isolate: ${message['error']}');
            break;
          case 'status':
            debugPrint('Status do background isolate: ${message['status']}');
            break;
        }
      }
    } catch (e) {
      debugPrint('Erro ao processar mensagem do background: $e');
    }
  }

  /// Processa atualização de localização do background
  void _handleLocationUpdate(Map<String, dynamic> locationData) async {
    try {
      // Converter dados para Position
      final position = Position(
        longitude: locationData['longitude'],
        latitude: locationData['latitude'],
        timestamp: DateTime.parse(locationData['timestamp']),
        accuracy: locationData['accuracy'],
        altitude: locationData['altitude'],
        altitudeAccuracy: locationData['altitudeAccuracy'] ?? 0.0,
        heading: locationData['heading'],
        headingAccuracy: locationData['headingAccuracy'] ?? 0.0,
        speed: locationData['speed'],
        speedAccuracy: locationData['speedAccuracy'] ?? 0.0,
        isMocked: locationData['isMocked'] ?? false,
      );

      // Salvar no banco de dados
      await _saveBackgroundLocation(position);
      
      // Notificar serviço principal se estiver ativo
      final locationService = LocationService();
      // Verificação removida pois isInitialized não existe
      
    } catch (e) {
      debugPrint('Erro ao processar localização do background: $e');
    }
  }

  /// Salva localização obtida em background
  Future<void> _saveBackgroundLocation(Position position) async {
    try {
      final databaseService = DatabaseService();
      
      // Verificar se há viagem ativa
      if (databaseService.activeTrip == null) {
        return;
      }

      final locationData = LocationData(
        tripId: databaseService.activeTrip!.id!,
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        accuracy: position.accuracy,
        speed: position.speed * 3.6, // m/s para km/h
        heading: position.heading,
        timestamp: position.timestamp,
      );

      // Método addLocation será implementado futuramente
      debugPrint('Localização processada do background: ${position.latitude}, ${position.longitude}');
      
    } catch (e) {
      debugPrint('Erro ao salvar localização do background: $e');
    }
  }

  /// Verifica se o background tracking está disponível
  static Future<bool> isBackgroundTrackingAvailable() async {
    try {
      // Verificar se o serviço de localização está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      // Verificar permissões
      LocationPermission permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
             permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('Erro ao verificar disponibilidade do background tracking: $e');
      return false;
    }
  }
}

/// Entry point para o isolate de background
void _backgroundIsolateEntryPoint(SendPort sendPort) async {
  // Configurar ReceivePort para este isolate
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);
  
  StreamSubscription<Position>? positionStream;
  bool isTracking = false;
  
  // Escutar comandos do isolate principal
  receivePort.listen((message) async {
    try {
      if (message is Map<String, dynamic>) {
        switch (message['action']) {
          case 'start':
            if (!isTracking) {
              await _startBackgroundLocationTracking(sendPort);
              isTracking = true;
            }
            break;
          case 'stop':
            if (isTracking) {
              await positionStream?.cancel();
              isTracking = false;
              sendPort.send({
                'type': 'status',
                'status': 'stopped'
              });
            }
            break;
        }
      }
    } catch (e) {
      sendPort.send({
        'type': 'error',
        'error': e.toString()
      });
    }
  });
}

/// Inicia rastreamento de localização no isolate de background
Future<void> _startBackgroundLocationTracking(SendPort sendPort) async {
  try {
    // Configurações para background
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 10, // metros
    );
    
    // Iniciar stream de posições
    final positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    );
    
    // Escutar atualizações de posição
    positionStream.listen(
      (Position position) {
        // Enviar atualização para o isolate principal
        sendPort.send({
          'type': 'location_update',
          'data': {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'altitude': position.altitude,
            'accuracy': position.accuracy,
            'altitudeAccuracy': position.altitudeAccuracy,
            'heading': position.heading,
            'headingAccuracy': position.headingAccuracy,
            'speed': position.speed,
            'speedAccuracy': position.speedAccuracy,
            'timestamp': (position.timestamp).toIso8601String(),
            'isMocked': position.isMocked,
          }
        });
      },
      onError: (error) {
        sendPort.send({
          'type': 'error',
          'error': 'Erro no stream de localização: $error'
        });
      },
    );
    
    sendPort.send({
      'type': 'status',
      'status': 'tracking_started'
    });
  } catch (e) {
    sendPort.send({
      'type': 'error',
      'error': 'Erro ao iniciar tracking: $e'
    });
  }
}

/// Callback para processamento em background (Android)
@pragma('vm:entry-point')
void backgroundLocationCallback(LocationUpdateNotification notification) async {
  try {
    // Este callback é chamado quando uma atualização de localização
    // é recebida em background no Android
    
    final sendPort = IsolateNameServer.lookupPortByName(
      BackgroundLocationService._portName,
    );
    
    if (sendPort != null) {
      sendPort.send({
        'type': 'location_update',
        'data': {
          'latitude': notification.latitude,
          'longitude': notification.longitude,
          'accuracy': notification.accuracy,
          'timestamp': DateTime.now().toIso8601String(),
        }
      });
    }
  } catch (e) {
    debugPrint('Erro no callback de background: $e');
  }
}

/// Notificação de atualização de localização
class LocationUpdateNotification {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  LocationUpdateNotification({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });
}

