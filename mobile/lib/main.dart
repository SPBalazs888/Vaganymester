import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/session_store.dart';
import 'ui/dispatch_screen.dart';
import 'ui/main_menu.dart';

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
      home: const HomeGate(),
    );
  }
}

class HomeGate extends StatefulWidget {
  const HomeGate({super.key});
  @override
  State<HomeGate> createState() => _HomeGateState();
}

class _HomeGateState extends State<HomeGate> {
  final SessionStore store = SessionStore();
  bool loaded = false;
  bool playing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await store.load();
    if (mounted) setState(() => loaded = true);
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => playing
          ? DispatchScreen(
              store: store,
              onExit: () => setState(() => playing = false),
            )
          : MainMenu(
              store: store,
              onStart: () => setState(() => playing = true),
            ),
    );
  }
}
