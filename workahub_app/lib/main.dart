import 'package:flutter/material.dart';
import 'package:workahub_app/src/rust/frb_generated.dart';
import 'package:workahub_app/src/rust/api/db.dart';
import 'package:workahub_app/src/screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  
  // Initialize DB
  final dbMsg = await initDb();
  print(dbMsg);

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
      home: const LoginScreen(),
    );
  }
}