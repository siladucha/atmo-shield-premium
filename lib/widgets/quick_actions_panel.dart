import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/shield_service.dart';
import '../services/settings_service.dart';
import '../utils/app_theme.dart';

class QuickActionsPanel extends StatelessWidget {
  const QuickActionsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ShieldService, SettingsService>(
      builder: (context, shieldService, settingsService, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.mediumSpacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                
                const SizedBox(height: AppTheme.mediumSpacing),
                
                if (settingsService.isPremiumUser) 
                  _buildPremiumActions(context, shieldService, settingsService)
                else
                  _buildFreeUserActions(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumActions(BuildContext context, ShieldService shieldService, SettingsService settingsService) {
    return Column(
      children: [
        // First row of actions
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.psychology,
                label: 'Manual Check',
                subtitle: 'Check stress now',
                color: AppTheme.primaryBlue,
                onTap: shieldService.isActive 
                    ? () => _performManualCheck(context)
                    : null,
              ),
            ),
            
            const SizedBox(width: AppTheme.smallSpacing),
            
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.analytics,
                label: 'Analytics',
                subtitle: 'View trends',
                color: AppTheme.accentGreen,
                onTap: () => _navigateToAnalytics(context),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: AppTheme.smallSpacing),
        
        // Second row of actions
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.settings,
                label: 'Settings',
                subtitle: 'Configure Shield',
                color: Colors.grey[600]!,
                onTap: () => _navigateToSettings(context),
              ),
            ),
            
            const SizedBox(width: AppTheme.smallSpacing),
            
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.refresh,
                label: 'Refresh Data',
                subtitle: 'Sync health data',
                color: AppTheme.warningAmber,
                onTap: () => _refreshHealthData(context),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: AppTheme.mediumSpacing),
        
        // Shield toggle
        _buildShieldToggle(context, shieldService, settingsService),
      ],
    );
  }

  Widget _buildFreeUserActions(BuildContext context) {
    return Column(
      children: [
        // Preview actions (disabled)
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.psychology,
                label: 'Manual Check',
                subtitle: 'Premium only',
                color: Colors.grey[400]!,
                onTap: null,
                showLock: true,
              ),
            ),
            
            const SizedBox(width: AppTheme.smallSpacing),
            
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.analytics,
                label: 'Analytics',
                subtitle: 'Premium only',
                color: Colors.grey[400]!,
                onTap: null,
                showLock: true,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: AppTheme.smallSpacing),
        
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.settings,
                label: 'Settings',
                subtitle: 'Basic settings',
                color: Colors.grey[600]!,
                onTap: () => _navigateToSettings(context),
              ),
            ),
            
            const SizedBox(width: AppTheme.smallSpacing),
            
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.star,
                label: 'Upgrade',
                subtitle: 'Unlock Shield',
                color: AppTheme.primaryBlue,
                onTap: () => _showUpgradeDialog(context),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: AppTheme.mediumSpacing),
        
        // Upgrade prompt
        _buildUpgradePrompt(context),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
    bool showLock = false,
  }) {
    final isEnabled = onTap != null;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.mediumSpacing),
          decoration: BoxDecoration(
            color: isEnabled 
                ? color.withOpacity(0.1) 
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(AppTheme.smallRadius),
            border: Border.all(
              color: isEnabled 
                  ? color.withOpacity(0.3) 
                  : Colors.grey[300]!,
            ),
          ),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    icon,
                    color: isEnabled ? color : Colors.grey[400],
                    size: 28,
                  ),
                  if (showLock)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock,
                          color: Colors.grey[600],
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: AppTheme.smallSpacing),
              
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: isEnabled ? color : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isEnabled ? Colors.grey[600] : Colors.grey[400],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShieldToggle(BuildContext context, ShieldService shieldService, SettingsService settingsService) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.mediumSpacing),
      decoration: BoxDecoration(
        color: settingsService.isShieldEnabled 
            ? AppTheme.accentGreen.withOpacity(0.1)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
        border: Border.all(
          color: settingsService.isShieldEnabled 
              ? AppTheme.accentGreen.withOpacity(0.3)
              : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.shield,
            color: settingsService.isShieldEnabled 
                ? AppTheme.accentGreen 
                : Colors.grey[400],
            size: 24,
          ),
          
          const SizedBox(width: AppTheme.mediumSpacing),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shield Monitoring',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  settingsService.isShieldEnabled 
                      ? 'Active - Monitoring your stress levels'
                      : 'Inactive - Enable to start monitoring',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          Switch(
            value: settingsService.isShieldEnabled,
            onChanged: (value) => _toggleShield(context, value),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradePrompt(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.mediumSpacing),
      decoration: BoxDecoration(
        gradient: AppTheme.shieldGradient,
        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.star,
            color: Colors.white,
            size: 24,
          ),
          
          const SizedBox(width: AppTheme.mediumSpacing),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unlock Premium Features',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Get proactive stress monitoring and AI-powered interventions',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          
          ElevatedButton(
            onPressed: () => _showUpgradeDialog(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  Future<void> _performManualCheck(BuildContext context) async {
    final shieldService = context.read<ShieldService>();
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Analyzing your current stress level...'),
          ],
        ),
      ),
    );
    
    try {
      await shieldService.performManualAnalysis();
      
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Manual stress check completed'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error during manual check: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _refreshHealthData(BuildContext context) async {
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Refreshing health data...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
    
    // TODO: Implement health data refresh
    await Future.delayed(const Duration(seconds: 2));
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Health data refreshed'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    }
  }

  Future<void> _toggleShield(BuildContext context, bool enabled) async {
    final settingsService = context.read<SettingsService>();
    final shieldService = context.read<ShieldService>();
    
    settingsService.isShieldEnabled = enabled;
    
    try {
      if (enabled) {
        await shieldService.startMonitoring();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🛡️ Shield monitoring started'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
      } else {
        await shieldService.stopMonitoring();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shield monitoring stopped'),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error toggling Shield: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _navigateToAnalytics(BuildContext context) {
    // TODO: Navigate to analytics screen
    debugPrint('Navigate to analytics');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📊 Analytics screen coming soon'),
      ),
    );
  }

  void _navigateToSettings(BuildContext context) {
    // TODO: Navigate to settings screen
    debugPrint('Navigate to settings');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚙️ Settings screen coming soon'),
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Text('Upgrade to Shield Premium'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unlock proactive stress monitoring with:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            _buildUpgradeFeature('🎯 Stress detection 15-60 minutes early'),
            _buildUpgradeFeature('🧘 Automatic NeuroYoga recommendations'),
            _buildUpgradeFeature('📊 Advanced HRV analytics'),
            _buildUpgradeFeature('🔔 Smart contextual notifications'),
            _buildUpgradeFeature('🔒 100% private, on-device processing'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.star, color: AppTheme.primaryBlue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'One-time purchase • No subscriptions • Lifetime updates',
                      style: TextStyle(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
            child: const Text('Upgrade - \$19.99'),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeFeature(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }

  void _processPurchase(BuildContext context) {
    // TODO: Implement in-app purchase
    debugPrint('Process premium purchase');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('💳 Purchase flow would be implemented here'),
        backgroundColor: AppTheme.primaryBlue,
      ),
    );
  }
}