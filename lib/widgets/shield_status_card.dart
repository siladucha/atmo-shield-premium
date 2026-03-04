import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../services/shield_service.dart';
import '../services/settings_service.dart';
import '../utils/app_theme.dart';

class ShieldStatusCard extends StatelessWidget {
  const ShieldStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ShieldService, SettingsService>(
      builder: (context, shieldService, settingsService, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.largeSpacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.shield,
                          color: _getStatusColor(shieldService.status),
                          size: 28,
                        ),
                        const SizedBox(width: AppTheme.smallSpacing),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shield Status',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              _getStatusText(shieldService.status),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: _getStatusColor(shieldService.status),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (settingsService.isPremiumUser)
                      Switch(
                        value: settingsService.isShieldEnabled,
                        onChanged: (value) => _toggleShield(context, value),
                      )
                    else
                      _buildUpgradeButton(context),
                  ],
                ),

                const SizedBox(height: AppTheme.largeSpacing),

                // Status Content
                if (settingsService.isPremiumUser)
                  _buildPremiumContent(context, shieldService)
                else
                  _buildPreviewContent(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumContent(BuildContext context, ShieldService shieldService) {
    switch (shieldService.status) {
      case ShieldStatus.active:
        return _buildActiveStatus(context, shieldService);
      case ShieldStatus.initializing:
        return _buildInitializingStatus(context);
      case ShieldStatus.insufficientData:
        return _buildInsufficientDataStatus(context, shieldService);
      case ShieldStatus.error:
        return _buildErrorStatus(context, shieldService);
      case ShieldStatus.inactive:
      default:
        return _buildInactiveStatus(context);
    }
  }

  Widget _buildActiveStatus(BuildContext context, ShieldService shieldService) {
    final baseline = shieldService.currentBaseline;
    final lastAnalysis = shieldService.lastAnalysis;
    
    return Column(
      children: [
        // Status Gauge
        SizedBox(
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getStatusColor(ShieldStatus.active).withOpacity(0.2),
                  ),
                ),
              ),
              // Status indicator
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getStatusColor(ShieldStatus.active),
                ),
                child: const Icon(
                  Icons.shield,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppTheme.mediumSpacing),

        // Status Info
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatusMetric(
              context,
              'Baseline',
              baseline != null 
                  ? '${baseline.mean.toStringAsFixed(1)}ms'
                  : 'Calculating...',
              baseline?.qualityDescription ?? 'N/A',
            ),
            _buildStatusMetric(
              context,
              'Last Check',
              lastAnalysis != null
                  ? _formatTimeSince(lastAnalysis)
                  : 'Never',
              'Monitoring active',
            ),
            _buildStatusMetric(
              context,
              'Events Today',
              '${shieldService.recentEvents.where((e) => _isToday(e.detectedAt)).length}',
              'Stress detections',
            ),
          ],
        ),

        if (baseline != null && baseline.isValid) ...[
          const SizedBox(height: AppTheme.mediumSpacing),
          _buildBaselineInfo(context, baseline),
        ],
      ],
    );
  }

  Widget _buildInitializingStatus(BuildContext context) {
    return Column(
      children: [
        const SizedBox(
          height: 60,
          width: 60,
          child: CircularProgressIndicator(),
        ),
        const SizedBox(height: AppTheme.mediumSpacing),
        Text(
          'Initializing Shield...',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          'Setting up health monitoring and permissions',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInsufficientDataStatus(BuildContext context, ShieldService shieldService) {
    final baseline = shieldService.currentBaseline;
    final daysNeeded = baseline != null 
        ? math.max(0, 7 - baseline.dayCount)
        : 7;
    
    return Column(
      children: [
        Icon(
          Icons.hourglass_empty,
          size: 48,
          color: AppTheme.warningAmber,
        ),
        const SizedBox(height: AppTheme.mediumSpacing),
        Text(
          'Building Your Baseline',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          'Need $daysNeeded more days of HRV data for accurate stress detection',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTheme.mediumSpacing),
        LinearProgressIndicator(
          value: baseline != null ? baseline.dayCount / 7 : 0,
          backgroundColor: Colors.grey[200],
          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.warningAmber),
        ),
        const SizedBox(height: AppTheme.smallSpacing),
        Text(
          baseline != null 
              ? '${baseline.dayCount}/7 days collected'
              : '0/7 days collected',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildErrorStatus(BuildContext context, ShieldService shieldService) {
    return Column(
      children: [
        const Icon(
          Icons.error_outline,
          size: 48,
          color: AppTheme.errorRed,
        ),
        const SizedBox(height: AppTheme.mediumSpacing),
        Text(
          'Shield Error',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          shieldService.errorMessage ?? 'Unknown error occurred',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTheme.mediumSpacing),
        ElevatedButton(
          onPressed: () => _retryShield(context),
          child: const Text('Retry'),
        ),
      ],
    );
  }

  Widget _buildInactiveStatus(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.shield_outlined,
          size: 48,
          color: Colors.grey[400],
        ),
        const SizedBox(height: AppTheme.mediumSpacing),
        Text(
          'Shield Inactive',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          'Enable Shield to start proactive stress monitoring',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPreviewContent(BuildContext context) {
    return Column(
      children: [
        // Preview gauge (static)
        SizedBox(
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.grey[400]!,
                  ),
                ),
              ),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[400],
                ),
                child: const Icon(
                  Icons.lock,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppTheme.mediumSpacing),

        // Preview metrics
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatusMetric(context, 'Baseline', '---', 'Premium only'),
            _buildStatusMetric(context, 'Monitoring', '---', 'Premium only'),
            _buildStatusMetric(context, 'Events', '---', 'Premium only'),
          ],
        ),

        const SizedBox(height: AppTheme.mediumSpacing),

        Container(
          padding: const EdgeInsets.all(AppTheme.mediumSpacing),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.smallRadius),
            border: Border.all(
              color: AppTheme.primaryBlue.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Text(
                '🛡️ Upgrade to unlock proactive stress monitoring',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.smallSpacing),
              Text(
                'Catch stress 15-60 minutes before you feel it',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusMetric(BuildContext context, String label, String value, String subtitle) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }

  Widget _buildBaselineInfo(BuildContext context, baseline) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.mediumSpacing),
      decoration: BoxDecoration(
        color: AppTheme.accentGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: AppTheme.accentGreen,
            size: 20,
          ),
          const SizedBox(width: AppTheme.smallSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Baseline Established',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.accentGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${baseline.dayCount} days • ${(baseline.confidence * 100).toStringAsFixed(0)}% confidence',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _showUpgradeDialog(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: const Text('Upgrade'),
    );
  }

  Color _getStatusColor(ShieldStatus status) {
    switch (status) {
      case ShieldStatus.active:
        return AppTheme.accentGreen;
      case ShieldStatus.initializing:
        return AppTheme.primaryBlue;
      case ShieldStatus.insufficientData:
        return AppTheme.warningAmber;
      case ShieldStatus.error:
        return AppTheme.errorRed;
      case ShieldStatus.inactive:
      default:
        return Colors.grey[400]!;
    }
  }

  String _getStatusText(ShieldStatus status) {
    switch (status) {
      case ShieldStatus.active:
        return 'Active Monitoring';
      case ShieldStatus.initializing:
        return 'Initializing...';
      case ShieldStatus.insufficientData:
        return 'Building Baseline';
      case ShieldStatus.error:
        return 'Error';
      case ShieldStatus.inactive:
      default:
        return 'Inactive';
    }
  }

  String _formatTimeSince(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  bool _isToday(DateTime dateTime) {
    final now = DateTime.now();
    return dateTime.year == now.year &&
           dateTime.month == now.month &&
           dateTime.day == now.day;
  }

  Future<void> _toggleShield(BuildContext context, bool enabled) async {
    final settingsService = context.read<SettingsService>();
    final shieldService = context.read<ShieldService>();
    
    settingsService.isShieldEnabled = enabled;
    
    if (enabled) {
      await shieldService.startMonitoring();
    } else {
      await shieldService.stopMonitoring();
    }
  }

  Future<void> _retryShield(BuildContext context) async {
    final shieldService = context.read<ShieldService>();
    await shieldService.startMonitoring();
  }

  void _showUpgradeDialog(BuildContext context) {
    // TODO: Show upgrade dialog
    debugPrint('Show upgrade dialog');
  }
}