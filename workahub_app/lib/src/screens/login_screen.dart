import 'package:flutter/material.dart';
import 'package:workahub_app/src/rust/api/auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  String? _error;
  
  // State machine for login flow
  // 0: Email
  // 1: Org Selection
  // 2: Password
  int _step = 0;
  
  List<String> _organizations = [];
  String? _selectedOrg;

  Future<void> _handleNext() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_step == 0) {
        // Fetch Orgs
        final email = _emailController.text;
        if (email.isEmpty) {
            throw Exception("Email required");
        }
        final orgs = await requireOrganization(email: email);
        setState(() {
          _organizations = orgs;
          if (_organizations.isNotEmpty) {
              _selectedOrg = _organizations[0];
              _step = 1;
              if (_organizations.length == 1) {
                  // Skip selection if only one
                  _handleOrgSelect();
              }
          } else {
              _error = "No organizations found";
          }
        });
      } else if (_step == 1) {
        // Org Selected, move to password
        _handleOrgSelect();
      } else if (_step == 2) {
          // Login
          final user = await login(
              username: _emailController.text, 
              password: _passwordController.text, 
              org: _selectedOrg!
          );
          if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Welcome ${user.username}!"))
              );
              // Navigate to dashboard (TODO)
          }
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
          setState(() {
            _isLoading = false;
          });
      }
    }
  }

  void _handleOrgSelect() {
      // Move to password
      setState(() {
          _step = 2;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Workahub", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 32),
                  
                  if (_step == 0)
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
                    ),
                    
                  if (_step == 1 && _organizations.length > 1)
                     DropdownButtonFormField<String>(
                         value: _selectedOrg,
                         items: _organizations.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                         onChanged: (v) => setState(() => _selectedOrg = v),
                         decoration: const InputDecoration(labelText: "Organization", border: OutlineInputBorder()),
                     ),

                  if (_step == 2)
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()),
                    ),
                    
                  const SizedBox(height: 16),
                  
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    
                  const SizedBox(height: 16),
                  
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: _isLoading ? null : _handleNext,
                          child: _isLoading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                            : Text(_step == 2 ? "Login" : "Next"),
                      ),
                  ),
                  
                  if (_step > 0)
                      TextButton(
                          onPressed: () => setState(() => _step = 0), 
                          child: const Text("Back")
                      )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
