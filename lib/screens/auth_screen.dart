import 'package:flutter/material.dart';

import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _loginIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _registerLoginIdController = TextEditingController();
  final TextEditingController _registerPasswordController = TextEditingController();

  bool _isLoginMode = true;
  String? _registeredLoginId;
  String? _registeredPassword;
  String? _message;

  @override
  void dispose() {
    _loginIdController.dispose();
    _passwordController.dispose();
    _registerLoginIdController.dispose();
    _registerPasswordController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
      _message = null;
    });
  }

  void _register() {
    final loginId = _registerLoginIdController.text.trim();
    final password = _registerPasswordController.text.trim();

    if (loginId.isEmpty || password.isEmpty) {
      setState(() {
        _message = 'Please enter both login ID and password.';
      });
      return;
    }

    setState(() {
      _registeredLoginId = loginId;
      _registeredPassword = password;
      _message = 'Registration complete. Now login with the same credentials.';
      _isLoginMode = true;
      _loginIdController.text = loginId;
      _passwordController.text = password;
    });
  }

  void _login() {
    final loginId = _loginIdController.text.trim();
    final password = _passwordController.text.trim();

    if (loginId.isEmpty || password.isEmpty) {
      setState(() {
        _message = 'Enter both login ID and password to continue.';
      });
      return;
    }

    if (_registeredLoginId == null || _registeredPassword == null) {
      setState(() {
        _message = 'No user registered yet. Please register first.';
      });
      return;
    }

    if (loginId == _registeredLoginId && password == _registeredPassword) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      setState(() {
        _message = 'Credentials do not match registration. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF081621),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'AeroPulse',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLoginMode ? 'Welcome back! Log in to continue.' : 'Create an account to access your dashboard.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F2633),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_message != null) ...[
                          Text(
                            _message!,
                            style: const TextStyle(color: Colors.greenAccent, fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_isLoginMode) ...[
                          _buildTextField(controller: _loginIdController, label: 'Login ID', hint: 'Enter login id'),
                          const SizedBox(height: 16),
                          _buildTextField(controller: _passwordController, label: 'Password', hint: 'Enter password', obscureText: true),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _login,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text('Login', style: TextStyle(fontSize: 16)),
                            ),
                          ),
                        ] else ...[
                          _buildTextField(controller: _registerLoginIdController, label: 'Login ID', hint: 'Choose a login id'),
                          const SizedBox(height: 16),
                          _buildTextField(controller: _registerPasswordController, label: 'Password', hint: 'Choose a password', obscureText: true),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _register,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text('Register', style: TextStyle(fontSize: 16)),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _toggleMode,
                          child: Text(
                            _isLoginMode ? 'Need an account? Register' : 'Already registered? Login',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF112635),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1F3647)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.greenAccent),
        ),
      ),
    );
  }
}
