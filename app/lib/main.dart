import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/settings.dart';
import 'ui/theme.dart';

/// Punto de entrada. El Broker (`server/`) debe estar corriendo antes de
/// crear o unirse a una sala.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await Settings.load();
  runApp(NexoBingoApp(settings: settings));
}

class NexoBingoApp extends StatelessWidget {
  const NexoBingoApp({super.key, required this.settings, this.showStartupDialogs = true});

  final Settings settings;
  final bool showStartupDialogs;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NexoBingo',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: HomeScreen(settings: settings, showStartupDialogs: showStartupDialogs),
    );
  }
}
