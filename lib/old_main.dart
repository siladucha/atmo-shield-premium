import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main_generator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🚀 HealthKit Data Generator starting...');
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  print('📱 Screen orientation configured');
  print('✅ Initialization complete, launching Data Generator');
  
  runApp(const HealthKitDataGeneratorApp());
}