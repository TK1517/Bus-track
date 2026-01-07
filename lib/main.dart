import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

// Make sure these files exist in your lib folder:
import 'route_selection_screen.dart';
import 'student_map_screen.dart';

// ==========================================
// 1. INITIALIZATION & MAIN APP
// ==========================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bus Tracker',
      theme: ThemeData(
        // FIXED: Use Lato instead of Segoe UI (which caused the first error)
        textTheme: GoogleFonts.latoTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
        ),
        primarySwatch: Colors.deepPurple,
      ),
      home: const RoleSelectionScreen(),
    );
  }
}

// ==========================================
// 2. GLOBAL STYLES
// ==========================================

const BoxDecoration driverBackground = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4b2b6f), Color(0xFF8b2f6b)],
  ),
);

const BoxDecoration studentBackground = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
  ),
);

const BoxDecoration roleBackground = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
  ),
);

final BoxDecoration glassDecoration = BoxDecoration(
  color: Colors.white.withOpacity(0.18),
  borderRadius: BorderRadius.circular(22),
  border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.35),
      blurRadius: 40,
      offset: const Offset(0, 15),
    ),
  ],
);

// ==========================================
// 3. ROLE SELECTION SCREEN
// ==========================================

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: roleBackground,
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Welcome 🚍🎓", style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("Choose your role to continue", style: TextStyle(fontSize: 16, color: Colors.white70)),
                const SizedBox(height: 50),
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildRoleCard(context, "Driver", "Login as a Driver", const DriverLoginScreen()),
                    _buildRoleCard(context, "Student", "Login as a Student", const StudentLoginScreen()),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context, String title, String subtitle, Widget page) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Container(
        width: 150,
        height: 180,
        padding: const EdgeInsets.all(20),
        decoration: glassDecoration,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4. DRIVER LOGIN SCREEN
// ==========================================

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DriverDashboard()));
      }
    } catch (e) {
      print("LOGIN ERROR: $e");
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Container(
        decoration: driverBackground,
        height: double.infinity,
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              padding: const EdgeInsets.all(40),
              decoration: glassDecoration,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("🚍 Driver Login", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),
                  _buildInput("Driver Email", _emailController, false),
                  const SizedBox(height: 15),
                  _buildInput("Password", _passwordController, true),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFffdd57),
                        foregroundColor: const Color(0xFF5a2d82),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.purple)
                          : const Text("Login", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFffbaba))),
                    )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String hint, TextEditingController controller, bool isPassword) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFffdd57))),
      ),
    );
  }
}

// ==========================================
// 5. DRIVER DASHBOARD (BUS LIST) [FIXED]
// ==========================================

class DriverDashboard extends StatelessWidget {
  const DriverDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Added Buses"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.pop(context);
            },
          )
        ],
      ),
      body: Container(
        decoration: driverBackground,
        child: StreamBuilder(
          stream: FirebaseFirestore.instance
              .collection('drivers')
              .doc(user!.uid)
              .collection('buses')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No buses added yet", style: TextStyle(fontSize: 18, color: Colors.white70)));
            }

            var buses = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.only(top: 100, left: 20, right: 20, bottom: 80),
              itemCount: buses.length,
              itemBuilder: (context, index) {
                var bus = buses[index];

                // FIXED: Wrapped in GestureDetector to make it clickable
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RouteSelectionScreen(
                          // FIXED: Accessing the correct fields from the 'bus' object
                          busId: bus['busId'],
                          busNumber: bus['busNumber'],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Color(0xFFffdd57),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              "${index + 1}",
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(bus['busNumber'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(bus['busId'], style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBusDialog(context),
        backgroundColor: const Color(0xFFffdd57),
        label: const Text("Add Bus", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  void _showAddBusDialog(BuildContext context) {
    final busNumController = TextEditingController();
    final busIdController = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;
    String? dialogError;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF4b2b6f),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("➕ Add Bus", style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: busNumController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Bus Number (e.g., 42)",
                    hintStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: busIdController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Bus ID (e.g., TN-01-AB-1234)",
                    hintStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                if (dialogError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(dialogError!, style: const TextStyle(color: Color(0xFFffbaba), fontSize: 13)),
                  )
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white70))),
              TextButton(
                onPressed: () async {
                  final busId = busIdController.text.trim().toUpperCase();
                  final busNum = busNumController.text.trim();

                  if (busId.isEmpty || busNum.isEmpty) {
                    setState(() => dialogError = "Please fill all fields");
                    return;
                  }

                  final validBusSnap = await FirebaseFirestore.instance.collection('validBuses').doc(busId).get();
                  if (!validBusSnap.exists) {
                    setState(() => dialogError = "❌ Invalid Bus ID (Not found in system)");
                    return;
                  }

                  await FirebaseFirestore.instance.collection('drivers').doc(user!.uid).collection('buses').add({
                    'busNumber': busNum,
                    'busId': busId,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Bus Added Successfully"), backgroundColor: Colors.green));
                  }
                },
                child: const Text("Add", style: TextStyle(color: Color(0xFFbaffc9), fontWeight: FontWeight.bold)),
              )
            ],
          );
        });
      },
    );
  }
}

// ==========================================
// 6. STUDENT LOGIN SCREEN [UPDATED TO AUTO-LIST ACTIVE BUSES]
// ==========================================


class StudentLoginScreen extends StatelessWidget {
  const StudentLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text("Active Buses"), backgroundColor: Colors.transparent, elevation: 0),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF11998e), Color(0xFF38ef7d)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('buses')
              .where('status', isEqualTo: 'active')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No buses on route.", style: TextStyle(color: Colors.white, fontSize: 18)));
            }

            return ListView.builder(
              padding: const EdgeInsets.only(top: 100, left: 20, right: 20),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var busData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                var busId = snapshot.data!.docs[index].id;
                return Card(
                  color: Colors.white.withOpacity(0.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    leading: const Icon(Icons.directions_bus, color: Colors.yellow),
                    title: Text("Bus: ${busData['busNumber']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text("${busData['startLocation']} ➔ ${busData['endLocation']}", style: const TextStyle(color: Colors.white70)),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentMapScreen(busId: busId))),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}