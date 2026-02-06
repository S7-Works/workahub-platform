import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workahub_app/src/rust/frb_generated.dart';
import 'package:workahub_app/src/rust/api/db.dart';
import 'package:workahub_app/src/rust/api/media.dart';
import 'package:workahub_app/src/screens/login_screen.dart';
import 'package:workahub_app/src/screens/dashboard_screen.dart';
import 'package:workahub_app/src/utils/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await RustLib.init();
  
  // Initialize System Tray
  final trayManager = TrayManager();
  await trayManager.initSystemTray();

  // Initialize DB
  try {
    await initDb();
  } catch (e) {
    print("DB Init Error: $e");
  }

  // Initialize GStreamer
  try {
    await initGstreamer();
  } catch (e) {
    print("GStreamer Init Error: $e");
  }

  // Check Session
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getString('user_id') != null;

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workahub',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: isLoggedIn ? const DashboardScreen() : const LoginScreen(),
    );
  }
}
