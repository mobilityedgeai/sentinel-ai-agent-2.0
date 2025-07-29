import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_data.dart';
import '../models/trip.dart';

class OSMMapWidget extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final List<LocationData>? route;
  final Trip? trip;
  final double zoom;
  final bool showCurrentLocation;
  final bool showRoute;
  final VoidCallback? onMapReady;

  const OSMMapWidget({
    Key? key,
    this.latitude,
    this.longitude,
    this.route,
    this.trip,
    this.zoom = 15.0,
    this.showCurrentLocation = true,
    this.showRoute = false,
    this.onMapReady,
  }) : super(key: key);

  @override
  State<OSMMapWidget> createState() => _OSMMapWidgetState();
}

class _OSMMapWidgetState extends State<OSMMapWidget> {
  late MapController _mapController;
  
  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    // Chamar callback quando mapa estiver pronto
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onMapReady?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determinar centro do mapa
    LatLng center = LatLng(
      widget.latitude ?? -23.5505, // São Paulo como padrão
      widget.longitude ?? -46.6333,
    );

    // Se há uma viagem, usar o ponto inicial
    if (widget.trip != null && widget.trip!.startLatitude != null && widget.trip!.startLongitude != null) {
      center = LatLng(widget.trip!.startLatitude!, widget.trip!.startLongitude!);
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: widget.zoom,
        minZoom: 3.0,
        maxZoom: 18.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // Camada de tiles do OpenStreetMap
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.sentinelai.app',
          maxZoom: 18,
        ),
        
        // Camada de rota (se disponível)
        if (widget.showRoute && widget.route != null && widget.route!.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.route!.map((location) => 
                  LatLng(location.latitude, location.longitude)
                ).toList(),
                strokeWidth: 4.0,
                color: Colors.blue,
              ),
            ],
          ),
        
        // Camada de marcadores
        MarkerLayer(
          markers: _buildMarkers(),
        ),
      ],
    );
  }

  List<Marker> _buildMarkers() {
    List<Marker> markers = [];

    // Marcador da localização atual
    if (widget.showCurrentLocation && widget.latitude != null && widget.longitude != null) {
      markers.add(
        Marker(
          point: LatLng(widget.latitude!, widget.longitude!),
          width: 40,
          height: 40,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: const Icon(
                Icons.my_location,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      );
    }

    // Marcadores da viagem (início e fim)
    if (widget.trip != null) {
      // Marcador de início
      if (widget.trip!.startLatitude != null && widget.trip!.startLongitude != null) {
        markers.add(
          Marker(
            point: LatLng(widget.trip!.startLatitude!, widget.trip!.startLongitude!),
            width: 40,
            height: 40,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        );
      }

      // Marcador de fim
      if (widget.trip!.endLatitude != null && widget.trip!.endLongitude != null) {
        markers.add(
          Marker(
            point: LatLng(widget.trip!.endLatitude!, widget.trip!.endLongitude!),
            width: 40,
            height: 40,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(
                  Icons.stop,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  // Método para mover o mapa para uma localização específica
  void moveToLocation(double latitude, double longitude, {double? zoom}) {
    _mapController.move(
      LatLng(latitude, longitude),
      zoom ?? widget.zoom,
    );
  }

  // Método para ajustar o zoom para mostrar toda a rota
  void fitRoute() {
    if (widget.route != null && widget.route!.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(
        widget.route!.map((location) => 
          LatLng(location.latitude, location.longitude)
        ).toList(),
      );
      
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(20),
        ),
      );
    }
  }
}

