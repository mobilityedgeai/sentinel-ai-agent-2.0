import 'dart:async';
import 'package:flutter/foundation.dart';

/// Serviço para notificações em tempo real
class RealTimeNotifier extends ChangeNotifier {
  Timer? _updateTimer;
  bool _isActive = false;
  
  // Callbacks para diferentes tipos de atualizações
  final List<VoidCallback> _locationCallbacks = [];
  final List<VoidCallback> _eventCallbacks = [];
  final List<VoidCallback> _scoreCallbacks = [];
  final List<VoidCallback> _tripCallbacks = [];
  
  bool get isActive => _isActive;
  
  /// Inicia o sistema de notificações em tempo real
  void start() {
    if (_isActive) return;
    
    _isActive = true;
    
    // Timer para forçar atualizações a cada 2 segundos
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _notifyAllCallbacks();
    });
    
    debugPrint('🔔 RealTimeNotifier iniciado');
  }
  
  /// Para o sistema de notificações
  void stop() {
    _isActive = false;
    _updateTimer?.cancel();
    _updateTimer = null;
    
    debugPrint('🔕 RealTimeNotifier parado');
  }
  
  /// Adiciona callback para atualizações de localização
  void addLocationCallback(VoidCallback callback) {
    _locationCallbacks.add(callback);
  }
  
  /// Remove callback de localização
  void removeLocationCallback(VoidCallback callback) {
    _locationCallbacks.remove(callback);
  }
  
  /// Adiciona callback para eventos telemáticos
  void addEventCallback(VoidCallback callback) {
    _eventCallbacks.add(callback);
  }
  
  /// Remove callback de eventos
  void removeEventCallback(VoidCallback callback) {
    _eventCallbacks.remove(callback);
  }
  
  /// Adiciona callback para scores
  void addScoreCallback(VoidCallback callback) {
    _scoreCallbacks.add(callback);
  }
  
  /// Remove callback de scores
  void removeScoreCallback(VoidCallback callback) {
    _scoreCallbacks.remove(callback);
  }
  
  /// Adiciona callback para viagens
  void addTripCallback(VoidCallback callback) {
    _tripCallbacks.add(callback);
  }
  
  /// Remove callback de viagens
  void removeTripCallback(VoidCallback callback) {
    _tripCallbacks.remove(callback);
  }
  
  /// Notifica atualização de localização
  void notifyLocationUpdate() {
    if (!_isActive) return;
    
    for (var callback in _locationCallbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('❌ Erro em callback de localização: $e');
      }
    }
    
    notifyListeners();
  }
  
  /// Notifica novo evento telemático
  void notifyEventUpdate() {
    if (!_isActive) return;
    
    for (var callback in _eventCallbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('❌ Erro em callback de evento: $e');
      }
    }
    
    notifyListeners();
  }
  
  /// Notifica atualização de score
  void notifyScoreUpdate() {
    if (!_isActive) return;
    
    for (var callback in _scoreCallbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('❌ Erro em callback de score: $e');
      }
    }
    
    notifyListeners();
  }
  
  /// Notifica atualização de viagem
  void notifyTripUpdate() {
    if (!_isActive) return;
    
    for (var callback in _tripCallbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('❌ Erro em callback de viagem: $e');
      }
    }
    
    notifyListeners();
  }
  
  /// Notifica todos os callbacks
  void _notifyAllCallbacks() {
    if (!_isActive) return;
    
    notifyLocationUpdate();
    notifyEventUpdate();
    notifyScoreUpdate();
    notifyTripUpdate();
  }
  
  @override
  void dispose() {
    stop();
    _locationCallbacks.clear();
    _eventCallbacks.clear();
    _scoreCallbacks.clear();
    _tripCallbacks.clear();
    super.dispose();
  }
}

