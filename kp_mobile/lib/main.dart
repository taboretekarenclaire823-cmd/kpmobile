import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const KpMobileApp());
}

class KpMobileApp extends StatelessWidget {
  const KpMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KP Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F2A43),
        ),
        useMaterial3: true,
      ),
      home: const StartupGate(),
    );
  }
}

/// Checks for a saved token when the app opens. If it is still valid,
/// go straight to the home screen, otherwise show the login screen.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late final Future<Map<String, dynamic>?> _future = _load();

  Future<Map<String, dynamic>?> _load() async {
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) return null;

    try {
      final data = await ApiService.getMe();
      return data['user'] as Map<String, dynamic>;
    } catch (_) {
      return null; // expired token or server unreachable
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) return const LoginScreen();
        return HomeScreen(user: user, resident: user['resident']);
      },
    );
  }
}