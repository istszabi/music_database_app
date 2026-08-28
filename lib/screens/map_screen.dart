import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import '../models/music_data_models.dart';
import '../services/ticketmaster_service.dart';

class MapScreen extends StatefulWidget {
  final String initialArtistName;

  const MapScreen({super.key, required this.initialArtistName});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  ConcertLocation? _selected;

  late Future<List<ConcertLocation>> _concertsFuture;

  @override
  void initState() {
    super.initState();
    _concertsFuture = TicketmasterService.fetchUpcomingConcerts(
      widget.initialArtistName,
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: Text('${widget.initialArtistName} — Tour Map'),
      ),
      body: FutureBuilder<List<ConcertLocation>>(
        future: _concertsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final concerts = snapshot.data ?? [];

          if (concerts.isEmpty) {
            return Center(
              child: Text(
                'No upcoming concerts for ${widget.initialArtistName}.',
                style: const TextStyle(color: Colors.grey),
              ),
            );
          }

          _selected ??= concerts.first;

          final points = concerts
              .map((c) => LatLng(c.latitude, c.longitude))
              .toList();
          final center = points.first;

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: points.length == 1 ? 8 : 3,
                  minZoom: 3,
                  maxZoom: 17,
                  cameraConstraint: CameraConstraint.contain(
                    bounds: LatLngBounds(
                      const LatLng(-85, -180),
                      const LatLng(85, 180),
                    ),
                  ),
                  onTap: (_, __) => setState(() => _selected = null),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.music_database_app',
                    tileProvider: CancellableNetworkTileProvider(),
                    maxNativeZoom: 19,
                    keepBuffer: 1,
                    panBuffer: 1,
                  ),
                  MarkerLayer(
                    markers: concerts.map((c) {
                      final isSelected = _selected == c;
                      return Marker(
                        point: LatLng(c.latitude, c.longitude),
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () => setState(() => _selected = c),
                          child: Icon(
                            Icons.location_on,
                            size: isSelected ? 40 : 32,
                            color: isSelected
                                ? const Color(0xFF1DB954)
                                : const Color(0xFFBB86FC),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              if (_selected != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFF1DB954),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selected!.venueName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_selected!.city} • ${_selected!.date}',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
