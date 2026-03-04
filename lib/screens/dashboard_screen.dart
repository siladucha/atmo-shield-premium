import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/shield_service.dart';
import '../services/settings_service.dart';
import '../widgets/shield_status_card.dart';
import '../widgets/recent_events_list.dart';
import '../widgets/quick_actions_panel.dart';
import '../utils/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final settingsService = context.read<SettingsService>();
    final shieldService = context.read<ShieldService>();
    
    // Initialize settings first
    if (!settingsService.isInitialized) {
      await settingsService.initialize();
    }
    
    // Start Shield monitoring if enabled
    if (settingsService.isShieldEnabled && !shieldService.isActive) {
      await shieldService.startMonitoring();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ATMO Shield Premium'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _navigateToSettings(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.mediumSpacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shield Status Card
              const ShieldStatusCard(),
              
              const SizedBox(height: AppTheme.largeSpacing),
              
              // Quick Actions Panel
              const QuickActionsPanel(),
              
              const SizedBox(height: AppTheme.largeSpacing),
              
              // Recent Events Section
              _buildSectionHeader(
                context,
                'Recent Activity',
                'Last 7 days',
                onViewAll: () => _navigateToAnalytics(context),
              ),
              
              const SizedBox(height: AppTheme.mediumSpacing),
              
              const RecentEventsList(),
              
              const SizedBox(height: AppTheme.largeSpacing),
              
              // Premium Features Teaser (if not premium user)
              Consumer<SettingsService>(
                builder: (context, settings, child) {
                  if (!settings.isPremiumUser) {
                    return _buildPremiumTeaser(context);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Consumer<ShieldService>(
        builder: (context, shieldService, child) {
          if (shieldService.status == ShieldStatus.active) {
            return FloatingActionButton(
              onPressed: () => _performManualCheck(context),
              tooltip: 'Manual Stress Check',
              child: const Icon(Icons.psychology),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String subtitle, {
    VoidCallback? onViewAll,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: const Text('View All'),
          ),
      ],
    );
  }

  Widget _buildPremiumTeaser(BuildContext context) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.shieldGradient,
          borderRadius: BorderRadius.circular(AppTheme.mediumRadius),
        ),
        padding: const EdgeInsets.all(AppTheme.largeSpacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.shield,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: AppTheme.mediumSpacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unlock Full Shield Power',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Proactive stress detection with AI-powered interventions',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.mediumSpacing),
            
            // Feature highlights
            _buildFeatureHighlight('🎯', 'Catch stress 15-60 minutes early'),
            _buildFeatureHighlight('🧘', 'Automatic NeuroYoga recommendations'),
            _buildFeatureHighlight('📊', 'Advanced analytics & trends'),
            _buildFeatureHighlight('🔒', '100% private, on-device processing'),
            
            const SizedBox(height: AppTheme.largeSpacing),
            
            // Upgrade button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showUpgradeDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Upgrade to Premium - \$19.99',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureHighlight(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: AppTheme.smallSpacing),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshData() async {
    final shieldService = context.read<ShieldService>();
    
    if (shieldService.isActive) {
      await shieldService.performManualAnalysis();
    }
  }

  Future<void> _performManualCheck(BuildContext context) async {
    final shieldService = context.read<ShieldService>();
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      await shieldService.performManualAnalysis();
      
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Manual stress check completed'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during manual check: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _navigateToSettings(BuildContext context) {
    // TODO: Navigate to settings screen
    debugPrint('Navigate to settings');
  }

  void _navigateToAnalytics(BuildContext context) {
    // TODO: Navigate to analytics screen
    debugPrint('Navigate to analytics');
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🛡️ Upgrade to Shield Premium'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unlock the full power of proactive stress monitoring:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            _buildUpgradeFeature('Proactive stress detection (15-60 min early)'),
            _buildUpgradeFeature('Automatic NeuroYoga protocol recommendations'),
            _buildUpgradeFeature('Advanced HRV analytics and trends'),
            _buildUpgradeFeature('Smart notifications with calendar integration'),
            _buildUpgradeFeature('100% private, on-device processing'),
            const SizedBox(height: 16),
            const Text(
              'Choose your plan:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            _buildPricingOption('One-time purchase', '\$19.99', 'Best value'),
            _buildPricingOption('Monthly subscription', '\$4.99/month', '7-day free trial'),
            _buildPricingOption('Annual subscription', '\$39.99/year', 'Save 33%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _processPurchase(context);
            },
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeFeature(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.check, color: AppTheme.accentGreen, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildPricingOption(String title, String price, String badge) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(badge, style: TextStyle(
                fontSize: 12,
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w500,
              )),
            ],
          ),
          Text(
            price,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _processPurchase(BuildContext context) {
    // TODO: Implement in-app purchase flow
    debugPrint('Process premium purchase');
    
    // For now, show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Purchase flow would be implemented here'),
        backgroundColor: AppTheme.accentGreen,
      ),
    );
  }
}