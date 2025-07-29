import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/telematics_event.dart';
import '../models/trip.dart';
import '../models/location_data.dart';

/// Serviço para gerenciar funcionalidades de mapas
class MapService extends ChangeNotifier {
  static final MapService _instance = MapService._internal();
  factory MapService() => _instance;
  MapService._internal();

  // Controlador do mapa
  Completer<GoogleMapController>? _controller;
  GoogleMapController? _mapController;

  // Estado do mapa
  LatLng? _currentPosition;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<Circle> _circles = {};
  
  // Configurações
  bool _showTraffic = false;
  bool _showIncidents = true;
  bool _showRoute = true;
  MapType _mapType = MapType.normal;

  // Getters públicos
  Set<Marker> get markers => _markers;
  Set<Polyline> get polylines => _polylines;
  Set<Circle> get circles => _circles;
  LatLng? get currentPosition => _currentPosition;
  bool get showTraffic => _showTraffic;
  bool get showIncidents => _showIncidents;
  bool get showRoute => _showRoute;
  MapType get mapType => _mapType;

  /// Inicializa o serviço de mapas
  Future<void> initialize() async {
    try {
      _controller = Completer<GoogleMapController>();
      debugPrint('MapService inicializado');
    } catch (e) {
      debugPrint('Erro ao inicializar MapService: $e');
    }
  }

  /// Define o controlador do mapa quando estiver pronto
  void onMapCreated(GoogleMapController controller) {
    if (_controller != null && !_controller!.isCompleted) {
      _controller!.complete(controller);
      _mapController = controller;
      debugPrint('Controlador do mapa configurado');
    }
  }

  /// Atualiza a posição atual no mapa
  Future<void> updateCurrentPosition(Position position) async {
    try {
      final newPosition = LatLng(position.latitude, position.longitude);
      _currentPosition = newPosition;

      // Adicionar/atualizar marker da posição atual
      _markers.removeWhere((marker) => marker.markerId.value == 'current_position');
      _markers.add(
        Marker(
          markerId: const MarkerId('current_position'),
          position: newPosition,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'Localização Atual',
            snippet: 'Você está aqui',
          ),
        ),
      );

      notifyListeners();

      // Mover câmera para posição atual se necessário
      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLng(newPosition),
        );
      }
    } catch (e) {
      debugPrint('Erro ao atualizar posição no mapa: $e');
    }
  }

  /// Exibe rota de uma viagem no mapa
  Future<void> showTripRoute(Trip trip, List<LocationData> locations) async {
    try {
      if (locations.isEmpty) return;

      // Criar polyline da rota
      final routePoints = locations
          .map((loc) => LatLng(loc.latitude, loc.longitude))
          .toList();

      final polyline = Polyline(
        polylineId: PolylineId('trip_${trip.id}'),
        points: routePoints,
        color: _getTripRouteColor(trip),
        width: 4,
        patterns: trip.endTime == null ? [PatternItem.dash(10), PatternItem.gap(5)] : [],
      );

      _polylines.add(polyline);

      // Adicionar markers de início e fim
      if (routePoints.isNotEmpty) {
        // Marker de início
        _markers.add(
          Marker(
            markerId: MarkerId('trip_start_${trip.id}'),
            position: routePoints.first,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(
              title: 'Início da Viagem',
              snippet: 'Iniciada em ${_formatDateTime(trip.startTime)}',
            ),
          ),
        );

        // Marker de fim (se a viagem terminou)
        if (trip.endTime != null && routePoints.length > 1) {
          _markers.add(
            Marker(
              markerId: MarkerId('trip_end_${trip.id}'),
              position: routePoints.last,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(
                title: 'Fim da Viagem',
                snippet: 'Finalizada em ${_formatDateTime(trip.endTime!)}',
              ),
            ),
          );
        }
      }

      notifyListeners();

      // Ajustar câmera para mostrar toda a rota
      if (_mapController != null && routePoints.isNotEmpty) {
        await _fitBoundsToPoints(routePoints);
      }
    } catch (e) {
      debugPrint('Erro ao exibir rota da viagem: $e');
    }
  }

  /// Exibe incidentes no mapa com bolhas proporcionais
  Future<void> showIncidentsMap(List<TelematicsEvent> events) async {
    try {
      if (!_showIncidents) return;

      // Limpar círculos anteriores
      _circles.clear();

      // Agrupar eventos por localização (aproximada)
      final incidentGroups = _groupEventsByLocation(events);

      // Criar círculos para cada grupo de incidentes
      for (final group in incidentGroups) {
        final center = group['center'] as LatLng;
        final eventList = group['events'] as List<TelematicsEvent>;
        final severity = _calculateGroupSeverity(eventList);
        
        // Tamanho da bolha proporcional à severidade e quantidade
        final radius = _calculateBubbleRadius(eventList.length, severity);
        final color = _getIncidentColor(severity);

        _circles.add(
          Circle(
            circleId: CircleId('incident_${center.latitude}_${center.longitude}'),
            center: center,
            radius: radius,
            fillColor: color.withOpacity(0.3),
            strokeColor: color,
            strokeWidth: 2,
          ),
        );

        // Adicionar marker para detalhes
        _markers.add(
          Marker(
            markerId: MarkerId('incident_marker_${center.latitude}_${center.longitude}'),
            position: center,
            icon: BitmapDescriptor.defaultMarkerWithHue(_getIncidentHue(severity)),
            infoWindow: InfoWindow(
              title: 'Incidentes (${eventList.length})',
              snippet: _getIncidentSummary(eventList),
            ),
          ),
        );
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao exibir mapa de incidentes: $e');
    }
  }

  /// Agrupa eventos por localização próxima
  List<Map<String, dynamic>> _groupEventsByLocation(List<TelematicsEvent> events) {
    const double groupingRadius = 100.0; // metros
    final List<Map<String, dynamic>> groups = [];

    for (final event in events) {
      final eventLocation = LatLng(event.latitude, event.longitude);
      bool addedToGroup = false;

      // Tentar adicionar a um grupo existente
      for (final group in groups) {
        final center = group['center'] as LatLng;
        final distance = Geolocator.distanceBetween(
          center.latitude,
          center.longitude,
          eventLocation.latitude,
          eventLocation.longitude,
        );

        if (distance <= groupingRadius) {
          (group['events'] as List<TelematicsEvent>).add(event);
          addedToGroup = true;
          break;
        }
      }

      // Criar novo grupo se não foi adicionado a nenhum
      if (!addedToGroup) {
        groups.add({
          'center': eventLocation,
          'events': [event],
        });
      }
    }

    return groups;
  }

  /// Calcula severidade média de um grupo de eventos
  double _calculateGroupSeverity(List<TelematicsEvent> events) {
    if (events.isEmpty) return 0.0;
    
    double totalSeverity = 0.0;
    for (final event in events) {
      totalSeverity += event.severity ?? 0.0;
    }
    
    return totalSeverity / events.length;
  }

  /// Calcula raio da bolha baseado na quantidade e severidade
  double _calculateBubbleRadius(int eventCount, double severity) {
    // Raio base de 50m, aumentando com quantidade e severidade
    const double baseRadius = 50.0;
    final countFactor = math.sqrt(eventCount.toDouble()) * 20.0;
    final severityFactor = severity * 30.0;
    
    return baseRadius + countFactor + severityFactor;
  }

  /// Obtém cor do incidente baseada na severidade
  Color _getIncidentColor(double severity) {
    if (severity >= 0.8) return const Color(0xFFD32F2F); // Vermelho
    if (severity >= 0.6) return const Color(0xFFFF9800); // Laranja
    if (severity >= 0.4) return const Color(0xFFFFC107); // Amarelo
    return const Color(0xFF4CAF50); // Verde
  }

  /// Obtém matiz do marker baseada na severidade
  double _getIncidentHue(double severity) {
    if (severity >= 0.8) return BitmapDescriptor.hueRed;
    if (severity >= 0.6) return BitmapDescriptor.hueOrange;
    if (severity >= 0.4) return BitmapDescriptor.hueYellow;
    return BitmapDescriptor.hueGreen;
  }

  /// Gera resumo dos incidentes para InfoWindow
  String _getIncidentSummary(List<TelematicsEvent> events) {
    final types = <TelematicsEventType, int>{};
    
    for (final event in events) {
      types[event.eventType] = (types[event.eventType] ?? 0) + 1;
    }

    final summary = types.entries
        .map((entry) => '${_getEventTypeName(entry.key)}: ${entry.value}')
        .take(2)
        .join(', ');

    return summary;
  }

  /// Obtém nome amigável do tipo de evento
  String _getEventTypeName(TelematicsEventType type) {
    switch (type) {
      case TelematicsEventType.hardBraking:
        return 'Frenagem';
      case TelematicsEventType.rapidAcceleration:
        return 'Aceleração';
      case TelematicsEventType.sharpTurn:
        return 'Curva';
      case TelematicsEventType.speeding:
        return 'Velocidade';
      case TelematicsEventType.hardBraking:
        return 'Acidente';
      default:
        return 'Evento';
    }
  }

  /// Obtém cor da rota baseada no status da viagem
  Color _getTripRouteColor(Trip trip) {
    if (trip.endTime == null) {
      return const Color(0xFF2196F3); // Azul para viagem em andamento
    }
    return const Color(0xFF4CAF50); // Verde para viagem finalizada
  }

  /// Ajusta câmera para mostrar todos os pontos
  Future<void> _fitBoundsToPoints(List<LatLng> points) async {
    if (_mapController == null || points.isEmpty) return;

    try {
      double minLat = points.first.latitude;
      double maxLat = points.first.latitude;
      double minLng = points.first.longitude;
      double maxLng = points.first.longitude;

      for (final point in points) {
        minLat = math.min(minLat, point.latitude);
        maxLat = math.max(maxLat, point.latitude);
        minLng = math.min(minLng, point.longitude);
        maxLng = math.max(maxLng, point.longitude);
      }

      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0),
      );
    } catch (e) {
      debugPrint('Erro ao ajustar bounds da câmera: $e');
    }
  }

  /// Formata data/hora para exibição
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Move câmera para localização específica
  Future<void> moveToLocation(LatLng location, {double zoom = 15.0}) async {
    if (_mapController == null) return;

    try {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(location, zoom),
      );
    } catch (e) {
      debugPrint('Erro ao mover câmera: $e');
    }
  }

  /// Limpa todos os elementos do mapa
  void clearMap() {
    _markers.clear();
    _polylines.clear();
    _circles.clear();
    notifyListeners();
  }

  /// Limpa apenas rotas
  void clearRoutes() {
    _polylines.clear();
    _markers.removeWhere((marker) => 
        marker.markerId.value.startsWith('trip_'));
    notifyListeners();
  }

  /// Limpa apenas incidentes
  void clearIncidents() {
    _circles.clear();
    _markers.removeWhere((marker) => 
        marker.markerId.value.startsWith('incident_'));
    notifyListeners();
  }

  /// Alterna exibição de tráfego
  void toggleTraffic() {
    _showTraffic = !_showTraffic;
    notifyListeners();
  }

  /// Alterna exibição de incidentes
  void toggleIncidents() {
    _showIncidents = !_showIncidents;
    if (!_showIncidents) {
      clearIncidents();
    }
    notifyListeners();
  }

  /// Alterna exibição de rotas
  void toggleRoutes() {
    _showRoute = !_showRoute;
    if (!_showRoute) {
      clearRoutes();
    }
    notifyListeners();
  }

  /// Altera tipo do mapa
  void setMapType(MapType type) {
    _mapType = type;
    notifyListeners();
  }

  /// Obtém configurações atuais do mapa
  Map<String, dynamic> getMapSettings() {
    return {
      'showTraffic': _showTraffic,
      'showIncidents': _showIncidents,
      'showRoute': _showRoute,
      'mapType': _mapType.toString(),
    };
  }

  /// Cleanup do serviço
  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

