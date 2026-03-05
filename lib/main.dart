import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/disclaimer_screen.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox('settings');
  
  runApp(const HRVMeasurementApp());
}

class HRVMeasurementApp extends StatelessWidget {
  const HRVMeasurementApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if onboarding was completed
    final settingsBox = Hive.box('settings');
    final hasCompletedOnboarding = settingsBox.get('completed_onboarding', defaultValue: false);
    
    return MaterialApp(
      title: 'HRV Measurement',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: hasCompletedOnboarding ? const MainScreen() : const DisclaimerScreen(),
    );
  }
}
