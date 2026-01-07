import 'dart:ui'; // Required for ImageFilter
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'driver_map_screen.dart';

class RouteSelectionScreen extends StatefulWidget {
  final String busId;
  final String busNumber;

  const RouteSelectionScreen({super.key, required this.busId, required this.busNumber});

  @override
  State<RouteSelectionScreen> createState() => _RouteSelectionScreenState();
}

class _RouteSelectionScreenState extends State<RouteSelectionScreen> {
  String? _selectedStartStop;
  String? _selectedEndStop;

  final Color primaryTeal = const Color(0xFF11998e);
  final Color secondaryYellow = const Color(0xFFffdd57);

  // --- STREAMS ---
  Stream<List<String>> _getStopsStream() {
    return FirebaseFirestore.instance
        .collection('bus_stops')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()['name'] as String).toList());
  }

  Stream<DocumentSnapshot> _getBusStatusStream() {
    return FirebaseFirestore.instance.collection('buses').doc(widget.busId).snapshots();
  }

  // --- ACTIONS ---
  Future<void> _handleStartRide() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    try {
      // Set status to ACTIVE
      await FirebaseFirestore.instance.collection('buses').doc(widget.busId).set({
        'busNumber': widget.busNumber,
        'status': 'active',
        'startLocation': _selectedStartStop,
        'endLocation': _selectedEndStop,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) _navigateToMap(_selectedStartStop!, _selectedEndStop!);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _handleStopRide() async {
    try {
      // Set status to INACTIVE
      await FirebaseFirestore.instance.collection('buses').doc(widget.busId).update({
        'status': 'inactive',
      });
      // Optional: Clean up the active tracking doc so map stops showing bus
      await FirebaseFirestore.instance.collection('activeRides').doc(widget.busId).delete();

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ride Ended Successfully")));
    } catch (e) {
      debugPrint("Error stopping ride: $e");
    }
  }

  void _handleContinueRide(Map<String, dynamic> busData) {
    final start = busData['startLocation'] ?? 'Unknown';
    final end = busData['endLocation'] ?? 'Unknown';
    _navigateToMap(start, end);
  }

  void _navigateToMap(String start, String end) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverMapScreen(
          busId: widget.busId,
          startLocation: start,
          endLocation: end,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [primaryTeal, const Color(0xFF38ef7d)]),
        ),
        child: SafeArea(
          child: StreamBuilder<DocumentSnapshot>(
            stream: _getBusStatusStream(),
            builder: (context, busSnapshot) {

              // Determine if ride is currently active
              bool isRideActive = false;
              Map<String, dynamic>? busData;

              if (busSnapshot.hasData && busSnapshot.data!.exists) {
                busData = busSnapshot.data!.data() as Map<String, dynamic>;
                // Check if status field exists and is 'active'
                if (busData != null && busData.containsKey('status')) {
                  isRideActive = busData['status'] == 'active';
                }
              }

              return Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Column(
                        children: [
                          // 1. CONFIGURE ROUTE CARD (Blurred if Active)
                          _buildBlurredSection(
                            isBlurred: isRideActive,
                            child: _buildRouteConfigCard(isRideActive),
                          ),

                          const SizedBox(height: 20),

                          // 2. ACTIVE RIDE CONTROLS (Blurred if Inactive)
                          _buildBlurredSection(
                            isBlurred: !isRideActive,
                            child: _buildActiveControlsCard(isRideActive, busData),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildBlurredSection({required bool isBlurred, required Widget child}) {
    return AbsorbPointer(
      absorbing: isBlurred, // Prevent clicks when blurred
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(
            sigmaX: isBlurred ? 4.0 : 0.0,
            sigmaY: isBlurred ? 4.0 : 0.0
        ),
        child: Opacity(
          opacity: isBlurred ? 0.6 : 1.0, // Dim it slightly
          child: child,
        ),
      ),
    );
  }

  Widget _buildRouteConfigCard(bool isRideActive) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(30)),
      child: StreamBuilder<List<String>>(
        stream: _getStopsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.map, color: Colors.black54),
                  SizedBox(width: 10),
                  Text("New Ride", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                ],
              ),
              const SizedBox(height: 20),
              _buildDropdown("Starting Point", _selectedStartStop, (val) => setState(() => _selectedStartStop = val), snapshot.data!),
              const SizedBox(height: 20),
              _buildDropdown("Destination", _selectedEndStop, (val) => setState(() => _selectedEndStop = val), snapshot.data!),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_selectedStartStop != null && _selectedEndStop != null) ? _handleStartRide : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: secondaryYellow,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  icon: const Icon(Icons.rocket_launch),
                  label: const Text("START ROUTE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActiveControlsCard(bool isRideActive, Map<String, dynamic>? busData) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(30)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.directions_bus_filled, color: Colors.green),
              SizedBox(width: 10),
              Text("Ride in Progress", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
            ],
          ),
          const SizedBox(height: 10),
          if (isRideActive && busData != null)
            Text("${busData['startLocation']} ➔ ${busData['endLocation']}", style: const TextStyle(color: Colors.grey)),

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isRideActive ? () => _handleContinueRide(busData!) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  icon: const Icon(Icons.navigation),
                  label: const Text("CONTINUE", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isRideActive ? _handleStopRide : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  icon: const Icon(Icons.stop_circle),
                  label: const Text("STOP RIDE", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.all(20.0),
    child: Column(children: [
      const Icon(Icons.settings_suggest, size: 50, color: Colors.white),
      const SizedBox(height: 10),
      Text("Bus ${widget.busNumber}", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
      const Text("Driver Dashboard", style: TextStyle(color: Colors.white70, fontSize: 14)),
    ]),
  );

  Widget _buildDropdown(String label, String? value, ValueChanged<String?> onChanged, List<String> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: primaryTeal, fontWeight: FontWeight.bold)),
      const SizedBox(height: 5),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[300]!)
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value, isExpanded: true, dropdownColor: Colors.white,
            hint: const Text("Select Stop", style: TextStyle(color: Colors.black54)),
            items: items.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: Colors.black)))).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    ],
  );
}