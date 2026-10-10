import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/auth_screen.dart';
import 'services/telemetry_service.dart';
import 'services/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Ignore duplicate app error on hot restart
  }
  await ThemeModeProvider.load();
  await TelemetryService.init();
  runApp(const DroneMonApp());
}

class DroneMonApp extends StatefulWidget {
  const DroneMonApp({super.key});

  @override
  State<DroneMonApp> createState() => _DroneMonAppState();
}

class _DroneMonAppState extends State<DroneMonApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      TelemetryService.ensureConnection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeModeProvider.instance,
      builder: (context, isDark, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'FWD FYNEX',
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF081621),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0F2633),
              elevation: 0,
            ),
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.greenAccent,
              brightness: Brightness.dark,
            ),
          ),
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: const Color(0xFFF2F5FA),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              elevation: 0,
            ),
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.greenAccent,
              brightness: Brightness.light,
            ),
          ),
          home: const AuthScreen(),
        );
      },
    );
  }
}
