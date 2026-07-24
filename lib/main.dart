/// EDUCATIONAL NOTE: Application Entry Point
/// In a clean architecture, main.dart is strictly used for application initialization.
/// It acts as the root, setting up dependencies, themes, and global configurations.
/// It delegates the actual UI rendering to the View layer (e.g., DashboardView), 
/// keeping the entry point minimal and focused.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/design_tokens.dart';
import 'views/dashboard_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const KoridorApp());
}

class KoridorApp extends StatelessWidget {
  const KoridorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Koridor Hız Asistanı',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: DesignTokens.background,
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      // Clean delegation to the Views layer
      home: const DashboardView(),
    );
  }
}
