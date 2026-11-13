import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/dispatch_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const VaganymesterApp());
}

class VaganymesterApp extends StatelessWidget {
  const VaganymesterApp({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF35DDC3);
    return MaterialApp(
      title: 'VÁGÁNYMESTER',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF081721),
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          surface: const Color(0xFF122637),
        ),
      ),
      home: const DispatchScreen(),
    );
  }
}
