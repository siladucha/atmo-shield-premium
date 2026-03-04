import 'package:flutter/material.dart';
import 'screens/disclaimer_screen.dart';

void main() {
  runApp(const HRVMeasurementApp());
}

class HRVMeasurementApp extends StatelessWidget {
  const HRVMeasurementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HRV Measurement',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const DisclaimerScreen(),
    );
  }
}
