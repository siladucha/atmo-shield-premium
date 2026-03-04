import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/generation_config.dart';
import '../services/health_permissions_manager.dart';
import 'progress_screen.dart';

class GenerationScreen extends StatefulWidget {
  const GenerationScreen({super.key});

  @override
  State<GenerationScreen> createState() => _GenerationScreenState();
}

class _GenerationScreenState extends State<GenerationScreen> {
  bool _includeSteps = false;
  bool _includeSleep = false;
  bool _permissionsGranted = false;
  bool _isRequestingPermissions = false;

  @override
  void initState() {
    super.initState();
    _checkCachedPermissions();
  }

  /// Check if permissions are already cached
  Future<void> _checkCachedPermissions() async {
    final manager = HealthPermissionsManager();
    final hasPermissions = await manager.hasPermissions();
    
    if (mounted) {
      setState(() {
        _permissionsGranted = hasPermissions;
      });
      
      if (hasPermissions) {
        debugPrint('🏥 [GenerationScreen] Permissions already granted (from cache)');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HealthKit Data Generator'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // App icon and title
            const Icon(
              Icons.favorite,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Generate Test Data',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Create one year of synthetic health data for testing ATMO Shield',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),

            // Optional features section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Optional Features',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Include Steps Data'),
                      subtitle: const Text('5,000-10,000 steps per day'),
                      value: _includeSteps,
                      onChanged: (value) {
                        setState(() {
                          _includeSteps = value;
                        });
                      },
                      secondary: const Icon(Icons.directions_walk),
                    ),
                    SwitchListTile(
                      title: const Text('Include Sleep Data'),
                      subtitle: const Text('7-8 hours per night'),
                      value: _includeSleep,
                      onChanged: (value) {
                        setState(() {
                          _includeSleep = value;
                        });
                      },
                      secondary: const Icon(Icons.bedtime),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Request Permissions button
            if (!_permissionsGranted)
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isRequestingPermissions ? null : _onRequestPermissions,
                    icon: _isRequestingPermissions
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.security, size: 24),
                    label: Text(
                      _isRequestingPermissions
                          ? 'Requesting Permissions...'
                          : 'Request HealthKit Permissions',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Grant permissions to write health data',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                ],
              ),

            // Permissions granted indicator
            if (_permissionsGranted)
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'HealthKit Permissions Granted',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),

            // Generate button
            ElevatedButton.icon(
              onPressed: _permissionsGranted ? _onGeneratePressed : null,
              icon: const Icon(Icons.favorite, size: 24),
              label: Text(
                _permissionsGranted
                    ? 'Generate 1 Year Data'
                    : 'Grant Permissions First',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _permissionsGranted ? Colors.blue : Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Info text
            Text(
              'This will generate:\n'
              '• Heart Rate (5,000-10,000 records)\n'
              '• HRV (600-900 records)\n'
              '• Respiratory Rate (365 records)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _onGeneratePressed() {
    final config = GenerationConfig(
      includeSteps: _includeSteps,
      includeSleep: _includeSleep,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProgressScreen(config: config),
      ),
    );
  }

  Future<void> _onRequestPermissions() async {
    setState(() {
      _isRequestingPermissions = true;
    });

    try {
      final manager = HealthPermissionsManager();

      // Request all permissions (will show iOS dialog)
      final granted = await manager.requestAllPermissions();

      if (mounted) {
        setState(() {
          _permissionsGranted = granted;
          _isRequestingPermissions = false;
        });

        if (granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ HealthKit permissions granted!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ HealthKit permissions denied. Please grant permissions in Settings.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRequestingPermissions = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting permissions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
