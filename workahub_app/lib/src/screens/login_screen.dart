import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workahub_app/src/rust/api/auth.dart';
import 'package:workahub_app/src/screens/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _orgController = TextEditingController();
  
  bool _isLoading = false;
  String? _error;
  List<String> _organizations = [];
  bool _orgSelected = false;

  Future<void> _checkEmail() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final orgs = await requireOrganization(email: _emailController.text);
      setState(() {
        _organizations = orgs;
        if (orgs.isNotEmpty) _orgController.text = orgs[0]; // Default to first
      });
    } catch (e) {
      setState(() => _error = "Failed to fetch orgs: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final response = await login(
        username: _emailController.text, 
        password: _passwordController.text, 
        org: _orgController.text
      );
      
      // Save Session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', response.userId);
      await prefs.setString('username', response.username);
      await prefs.setString('org', _orgController.text);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen())
        );
      }
    } catch (e) {
      setState(() => _error = "Login failed: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Workahub Login", style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 20),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: "Email"),
                  onEditingComplete: _organizations.isEmpty ? _checkEmail : null,
                ),
                
                if (_organizations.isNotEmpty) ...[
                   DropdownButtonFormField<String>(
                     value: _orgController.text.isNotEmpty ? _orgController.text : null,
                     items: _organizations.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                     onChanged: (val) => setState(() => _orgController.text = val!),
                     decoration: const InputDecoration(labelText: "Organization"),
                   ),
                   TextField(
                     controller: _passwordController,
                     decoration: const InputDecoration(labelText: "Password"),
                     obscureText: true,
                   ),
                   const SizedBox(height: 20),
                   SizedBox(
                     width: double.infinity,
                     child: ElevatedButton(
                       onPressed: _isLoading ? null : _login,
                       child: _isLoading ? const CircularProgressIndicator() : const Text("Login"),
                     ),
                   ),
                ] else ...[
                   const SizedBox(height: 20),
                   SizedBox(
                     width: double.infinity,
                     child: ElevatedButton(
                       onPressed: _isLoading ? null : _checkEmail,
                       child: _isLoading ? const CircularProgressIndicator() : const Text("Next"),
                     ),
                   ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}