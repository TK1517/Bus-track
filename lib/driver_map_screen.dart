import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // Standard OpenStreetMap package
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DriverMapScreen extends StatefulWidget {
  final String busId;
  final String startLocation;
  final String endLocation;

  const DriverMapScreen({
    super.key,
    required this.busId,
    required this.startLocation,
    required this.endLocation,
  });

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  final MapController _mapController = MapController();

  // -- State Variables --
  List<LatLng> _routePoints = [];
  LatLng? _currentPos;
  LatLng? _startCoord;
  LatLng? _endCoord;
  bool _isLoading = true;
  String _eta = "Calculating...";
  String _duration = "-- mins";

  // -- Timers & Streams --
  StreamSubscription<Position>? _positionStream;
  Timer? _uploadTimer;

  @override
  void initState() {
    super.initState();
    _initRide();
  }

  Future<void> _initRide() async {
    // 1. Get Coordinates (Robust Method)
    _startCoord = await _getCoordinates(widget.startLocation);
    _endCoord = await _getCoordinates(widget.endLocation);

    if (_startCoord == null || _endCoord == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not find locations. Using backup mode.")));
      // Fallback to defaults to prevent crash
      _startCoord = const LatLng(13.0827, 80.2707); // Chennai
      _endCoord = const LatLng(12.9716, 77.5946);   // Bangalore
    }

    // 2. Set Bus Position IMMEDIATELY to Start Location
    setState(() {
      _currentPos = _startCoord;
    });

    // 3. Fetch Route Line & Zoom
    await _fetchRoute(_startCoord!, _endCoord!);

    // 4. Start Tracking Logic
    _startLocalTracking();

    // 5. Start Cloud Uploads (TEMPORARY: Every 10 Seconds for Testing)
    _uploadLocationToFirebase(); // First upload

    // 👇 UPDATED TIMER HERE
    _uploadTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _uploadLocationToFirebase();
    });

    if (mounted) setState(() => _isLoading = false);
  }

  // --- 1. ROBUST GEOCODING (Free Nominatim API) ---
  Future<LatLng?> _getCoordinates(String place) async {
    String query = place.trim();
    if (query.isEmpty) return null;

    // Use a unique User-Agent to avoid blocking
    final url = Uri.parse("https://nominatim.openstreetmap.org/search?format=json&q=$query&limit=1");

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'BusTracker_Final_Project/1.0',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          return LatLng(double.parse(data[0]['lat']), double.parse(data[0]['lon']));
        }
      }
    } catch (e) {
      debugPrint("Geocoding Network Error: $e");
    }

    // --- FALLBACKS (If API blocks/fails) ---
    debugPrint("⚠️ API failed for $place, using fallback.");
    String lower = place.toLowerCase();
    if (lower.contains("chennai")) return const LatLng(13.0827, 80.2707);
    if (lower.contains("bangalore")) return const LatLng(12.9716, 77.5946);
    if (lower.contains("kochi")) return const LatLng(9.9312, 76.2673);
    if (lower.contains("coimbatore")) return const LatLng(11.0168, 76.9558);
    if (lower.contains("trichy")) return const LatLng(10.7905, 78.7047);
    if (lower.contains("madurai")) return const LatLng(9.9252, 78.1198);

    return null; // Start location will be used as final fallback in init
  }

  // --- 2. FETCH ROUTE (Free OSRM API) ---
  Future<void> _fetchRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
        "http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'];
        if (routes.isNotEmpty) {
          final geometry = routes[0]['geometry']['coordinates'] as List;
          final durationSeconds = routes[0]['duration'];

          if (mounted) {
            setState(() {
              // Convert OSRM points [long, lat] to FlutterMap [lat, long]
              _routePoints = geometry.map((p) => LatLng(p[1].toDouble(), p[0].toDouble())).toList();

              // Calculate ETA Text
              final int mins = (durationSeconds / 60).round();
              final hours = (mins / 60).floor();
              final remMins = mins % 60;
              _duration = hours > 0 ? "${hours}h ${remMins}m" : "$mins mins";

              final arrivalTime = DateTime.now().add(Duration(seconds: durationSeconds.toInt()));
              _eta = "${arrivalTime.hour}:${arrivalTime.minute.toString().padLeft(2, '0')}";
            });

            // ZOOM TO FIT ROUTE
            if (_routePoints.isNotEmpty) {
              final bounds = LatLngBounds.fromPoints(_routePoints);
              _mapController.fitCamera(
                CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Routing Error: $e");
    }
  }

  // --- 3. LOCAL TRACKING (Visual Blue Dot) ---
  void _startLocalTracking() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    const locationSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 20);

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      final newPos = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() => _currentPos = newPos);
      }
    });
  }

  // --- 4. CLOUD UPLOAD (Every 10 Seconds for Test) ---
  Future<void> _uploadLocationToFirebase() async {
    if (_currentPos == null) return;
    try {
      await FirebaseFirestore.instance.collection('activeRides').doc(widget.busId).set({
        'latitude': _currentPos!.latitude,
        'longitude': _currentPos!.longitude,
        'start': widget.startLocation,
        'end': widget.endLocation,
        'eta': _eta,
        'duration': _duration,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      debugPrint("☁️ Location uploaded to Firebase");
    } catch (e) {
      debugPrint("Upload Error: $e");
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _uploadTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // --- MAP LAYER ---
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(10.8505, 76.2711), // Default Kerala Center
              initialZoom: 13,
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
                    Polyline(points: _routePoints, color: Colors.blue, strokeWidth: 5.0),
                  ],
                ),

              // Markers (Bus, Start, End)
              MarkerLayer(
                markers: [
                  // Start Flag
                  if (_startCoord != null)
                    Marker(
                      point: _startCoord!,
                      width: 40, height: 40,
                      child: const Icon(Icons.flag, color: Colors.green, size: 40),
                    ),
                  // End Flag
                  if (_endCoord != null)
                    Marker(
                      point: _endCoord!,
                      width: 40, height: 40,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                    ),
                  // Moving Bus Icon
                  if (_currentPos != null)
                    Marker(
                      point: _currentPos!,
                      width: 60, height: 60,
                      // You can replace Icon with Image.asset('assets/bus.png') if you added it
                      child: const Icon(Icons.directions_bus, color: Colors.blue, size: 50),
                    ),
                ],
              ),
            ],
          ),

          // --- INFO PANEL (Bottom) ---
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("From: ${widget.startLocation}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text("To: ${widget.endLocation}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          const Text("ETA", style: TextStyle(color: Colors.grey)),
                          Text(_duration, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text("Arriving at: $_eta", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text("🛑 Stop Ride", style: TextStyle(color: Colors.white)),
                    ),
                  )
                ],
              ),
            ),
          ),

          // --- LOADER ---
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }
}