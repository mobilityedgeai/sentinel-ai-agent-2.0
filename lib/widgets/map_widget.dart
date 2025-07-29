import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_data.dart';
import '../models/trip.dart';
import 'osm_map_widget.dart';

class MapWidget extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final List<LocationData>? route;
  final Trip? trip;
  final double zoom;
  final bool showCurrentLocation;
  final bool showRoute;
  final VoidCallback? onMapReady;
  final LatLng? initialPosition;
  final double initialZoom;
  final bool showControls;
  final VoidCallback? onMapCreated;
  final Function(LatLng)? onTap;

  const MapWidget({
    Key? key,
    this.latitude,
    this.longitude,
    this.route,
    this.trip,
    this.zoom = 15.0,
    this.showCurrentLocation = true,
    this.showRoute = false,
    this.onMapReady,
    this.initialPosition,
    this.initialZoom = 15.0,
    this.showControls = true,
    this.onMapCreated,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Usar OSMMapWidget para funcionalidades avançadas
    if (route != null || trip != null || latitude != null) {
      return OSMMapWidget(
        latitude: latitude,
        longitude: longitude,
        route: route,
        trip: trip,
        zoom: zoom,
        showCurrentLocation: showCurrentLocation,
        showRoute: showRoute,
        onMapReady: onMapReady,
      );
    }

    // Mapa simples para outros casos
    LatLng center = initialPosition ?? LatLng(-23.5505, -46.6333); // São Paulo como padrão
    
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: initialZoom,
        minZoom: 3.0,
        maxZoom: 18.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
        onTap: onTap != null ? (tapPosition, point) => onTap!(point) : null,
      ),
      children: [
        // Camada de tiles do OpenStreetMap
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.sentinelai.app',
          maxZoom: 18,
        ),
        
        // Marcador da localização atual (se habilitado)
        if (showCurrentLocation && latitude != null && longitude != null)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(latitude!, longitude!),
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
            ],
          ),
      ],
    );
  }
}

