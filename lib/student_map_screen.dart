import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class StudentMapScreen extends StatefulWidget {
  final String busId;

  const StudentMapScreen({super.key, required this.busId});

  @override
  State<StudentMapScreen> createState() => _StudentMapScreenState();
}

class _StudentMapScreenState extends State<StudentMapScreen> {
  final MapController _mapController = MapController();

  // State for Route Line
  List<LatLng> _routePoints = [];
  String? _lastRouteKey;
  bool _hasCenteredOnBus = false;

  // --- 1. GEOCODING HELPER ---
  Future<LatLng?> _getCoordinates(String place) async {
    if (place.isEmpty) return null;
    // Append "India" to ensure better accuracy for local town names
    String query = "$place, India";

    final url = Uri.parse("https://nominatim.openstreetmap.org/search?format=json&q=$query&limit=1");
    try {
      final response = await http.get(url, headers: {'User-Agent': 'BusTracker_Student/1.0'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          return LatLng(double.parse(data[0]['lat']), double.parse(data[0]['lon']));
        }
      }
    } catch (e) {
      debugPrint("Geocoding Error: $e");
    }
    // Fallback coordinates if API fails
    if (place.toLowerCase().contains("chennai")) return const LatLng(13.0827, 80.2707);
    if (place.toLowerCase().contains("bangalore")) return const LatLng(12.9716, 77.5946);
    return null;
  }

  // --- 2. FETCH ROUTE LOGIC ---
  Future<void> _loadRoute(String startName, String endName) async {
    // Only fetch if start/end have changed or we haven't fetched yet
    String currentKey = "$startName|$endName";
    if (_lastRouteKey == currentKey) return;

    _lastRouteKey = currentKey;
    debugPrint("🔄 Calculating New Route: $startName to $endName");

    LatLng? start = await _getCoordinates(startName);
    LatLng? end = await _getCoordinates(endName);

    if (start == null || end == null) return;

    final url = Uri.parse(
        "http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'].isNotEmpty) {
          final geometry = data['routes'][0]['geometry']['coordinates'] as List;
          if (mounted) {
            setState(() {
              _routePoints = geometry.map((p) => LatLng(p[1].toDouble(), p[0].toDouble())).toList();
            });
            // Automatically fit the camera to show the whole route once
            if (_routePoints.isNotEmpty) {
              final bounds = LatLngBounds.fromPoints(_routePoints);
              _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)));
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Routing Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Tracking Bus ${widget.busId}"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // Button to manually re-center on the bus
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () => _hasCenteredOnBus = false, // Reset flag to force re-center
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // LISTEN TO THE EXACT SAME COLLECTION AS DRIVER
        stream: FirebaseFirestore.instance.collection('activeRides').doc(widget.busId).snapshots(),
        builder: (context, snapshot) {

          // 1. Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. No Data (Driver hasn't clicked "Start Ride")
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.directions_bus_outlined, size: 60, color: Colors.grey),
                  const SizedBox(height: 20),
                  Text("Waiting for Bus ${widget.busId} to start...", style: const TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }

          // 3. Data Received
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final double lat = data['latitude'];
          final double lng = data['longitude'];
          final LatLng busPos = LatLng(lat, lng);

          final String start = data['start'] ?? "";
          final String end = data['end'] ?? "";
          final String eta = data['eta'] ?? "--:--";
          final String duration = data['duration'] ?? "-- mins";

          // --- LOGIC: Trigger Route Calculation ---
          if (start.isNotEmpty && end.isNotEmpty) {
            // We use Future.delayed to avoid calling setState during build
            Future.delayed(Duration.zero, () => _loadRoute(start, end));
          }

          // --- LOGIC: Auto-Follow Bus ---
          // If we haven't centered yet, or if you want it to ALWAYS follow:
          // Remove the 'if' condition to make it locked on the bus.
          // Keeping it simple: Auto-center on first valid location.
          if (!_hasCenteredOnBus) {
            _hasCenteredOnBus = true;
            // Use a slight delay to ensure map is ready
            Future.delayed(const Duration(milliseconds: 500), () {
              try { _mapController.move(busPos, 15); } catch(e) {/*Ignore map not ready error*/}
            });
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: busPos, // Start at bus location
                  initialZoom: 15,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.bustrack',
                  ),

                  // Blue Route Line
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          color: Colors.blue,
                          strokeWidth: 5.0,
                        ),
                      ],
                    ),

                  // Bus Marker
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: busPos,
                        width: 60,
                        height: 60,
                        child: const Icon(Icons.directions_bus_filled, color: Colors.blue, size: 50),
                      ),
                    ],
                  ),
                ],
              ),

              // Student Info Card
              Positioned(
                top: 20, left: 20, right: 20,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [const BoxShadow(blurRadius: 10, color: Colors.black26)],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("$start ➝ $end", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 16, color: Colors.green),
                                const SizedBox(width: 5),
                                Text("Arriving in $duration", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              ],
                            )
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          const Text("ETA", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(eta, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        ],
                      )
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