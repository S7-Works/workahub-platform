import 'package:flutter/material.dart';
import 'package:workahub_app/src/rust/frb_generated.dart';
import 'package:workahub_app/src/rust/api/db.dart';
import 'package:workahub_app/src/rust/api/media.dart';
import 'package:workahub_app/src/screens/login_screen.dart';
import 'package:workahub_app/src/screens/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  
  // Initialize DB
  try {
    final dbMsg = await initDb();
    print(dbMsg);
  } catch (e) {
    print("DB Init Error: $e");
  }

  // Initialize GStreamer
  try {
    final gstMsg = await initGstreamer();
    print(gstMsg);
  } catch (e) {
    print("GStreamer Init Error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workahub',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Temporarily set Dashboard as home for testing
      home: const DashboardScreen(),
    );
  }
}
