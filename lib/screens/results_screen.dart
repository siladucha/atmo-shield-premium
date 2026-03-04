import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/generation_result.dart';
import 'generation_screen.dart';

class ResultsScreen extends StatelessWidget {
  final GenerationResult result;

  const ResultsScreen({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSuccess = result.status == GenerationStatus.success;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generation Results'),
        backgroundColor: isSuccess ? Colors.green : Colors.orange,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status icon and message
            Icon(
              isSuccess ? Icons.check_circle : Icons.warning,
              size: 80,
              color: isSuccess ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              isSuccess ? 'Generation Complete!' : 'Generation Completed with Issues',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Generation time: ${result.generationTime.inSeconds} seconds',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Record counts card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Generated Records',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _buildRecordCount(
                      context,
                      'Heart Rate',
                      result.hrRecordsGenerated,
                      Icons.favorite,
                      Colors.red,
                    ),
                    _buildRecordCount(
                      context,
                      'HRV (SDNN)',
                      result.hrvRecordsGenerated,
                      Icons.monitor_heart,
                      Colors.pink,
                    ),
                    _buildRecordCount(
                      context,
                      'Respiratory Rate',
                      result.rrRecordsGenerated,
                      Icons.air,
                      Colors.blue,
                    ),
                    if (result.stepsRecordsGenerated > 0)
                      _buildRecordCount(
                        context,
                        'Steps',
                        result.stepsRecordsGenerated,
                        Icons.directions_walk,
                        Colors.green,
                      ),
                    if (result.sleepRecordsGenerated > 0)
                      _buildRecordCount(
                        context,
                        'Sleep',
                        result.sleepRecordsGenerated,
                        Icons.bedtime,
                        Colors.indigo,
                      ),
                    const Divider(height: 24),
                    _buildRecordCount(
                      context,
                      'Total Records',
                      result.hrRecordsGenerated +
                          result.hrvRecordsGenerated +
                          result.rrRecordsGenerated +
                          result.stepsRecordsGenerated +
                          result.sleepRecordsGenerated,
                      Icons.analytics,
                      Colors.purple,
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ),

            // Errors section (if any)
            if (result.errors.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            'Errors (${result.errors.length})',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[900],
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...result.errors.map((error) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '• $error',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Open Apple Health button
            ElevatedButton.icon(
              onPressed: _openAppleHealth,
              icon: const Icon(Icons.health_and_safety, size: 24),
              label: const Text(
                'Open Apple Health',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Generate Again button
            OutlinedButton.icon(
              onPressed: () => _generateAgain(context),
              icon: const Icon(Icons.refresh, size: 24),
              label: const Text(
                'Generate Again',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: Colors.blue, width: 2),
              ),
            ),

            const SizedBox(height: 24),

            // Info text
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(height: 8),
                    Text(
                      'The generated data covers 365 days and includes realistic patterns, trends, and stress events for comprehensive testing.',
                      style: TextStyle(color: Colors.grey[700]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCount(
    BuildContext context,
    String label,
    int count,
    IconData icon,
    Color color, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  ),
            ),
          ),
          Text(
            count.toString(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAppleHealth() async {
    final uri = Uri.parse('x-apple-health://');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        debugPrint('Cannot launch Apple Health app');
      }
    } catch (e) {
      debugPrint('Error launching Apple Health: $e');
    }
  }

  void _generateAgain(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const GenerationScreen(),
      ),
      (route) => false,
    );
  }
}
