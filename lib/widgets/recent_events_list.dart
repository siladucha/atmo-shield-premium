import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/shield_service.dart';
import '../models/stress_event.dart';
import '../utils/app_theme.dart';

class RecentEventsList extends StatelessWidget {
  const RecentEventsList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ShieldService>(
      builder: (context, shieldService, child) {
        final events = shieldService.recentEvents.take(5).toList();
        
        if (events.isEmpty) {
          return _buildEmptyState(context);
        }
        
        return Column(
          children: events.map((event) => _buildEventCard(context, event)).toList(),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.largeSpacing),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(AppTheme.mediumRadius),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(
            Icons.timeline,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: AppTheme.mediumSpacing),
          Text(
            'No Recent Events',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          Text(
            'Stress events will appear here when detected',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, StressEvent event) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.smallSpacing),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.mediumSpacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with severity and time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(int.parse(event.severityColor.substring(1), radix: 16) + 0xFF000000),
                      ),
                    ),
                    const SizedBox(width: AppTheme.smallSpacing),
                    Text(
                      event.severityDescription,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatEventTime(event.detectedAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.smallSpacing),
            
            // Z-score and pattern
            Row(
              children: [
                _buildMetricChip(
                  context,
                  'Z-Score',
                  event.zScore.toStringAsFixed(1),
                  AppTheme.getZScoreColor(event.zScore),
                ),
                const SizedBox(width: AppTheme.smallSpacing),
                _buildMetricChip(
                  context,
                  'Pattern',
                  event.patternDescription,
                  Colors.grey[600]!,
                ),
              ],
            ),
            
            if (event.recommendedProtocol != null) ...[
              const SizedBox(height: AppTheme.mediumSpacing),
              
              // Recommended protocol
              Container(
                padding: const EdgeInsets.all(AppTheme.smallSpacing),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.psychology,
                      size: 16,
                      color: AppTheme.primaryBlue,
                    ),
                    const SizedBox(width: AppTheme.smallSpacing),
                    Expanded(
                      child: Text(
                        'Recommended: ${_getProtocolDisplayName(event.recommendedProtocol!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Action buttons
            const SizedBox(height: AppTheme.mediumSpacing),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Intervention status
                Row(
                  children: [
                    Icon(
                      event.interventionCompleted 
                          ? Icons.check_circle 
                          : event.interventionStarted != null
                              ? Icons.play_circle
                              : Icons.circle_outlined,
                      size: 16,
                      color: event.interventionCompleted 
                          ? AppTheme.accentGreen
                          : event.interventionStarted != null
                              ? AppTheme.warningAmber
                              : Colors.grey[400],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      event.interventionCompleted 
                          ? 'Completed'
                          : event.interventionStarted != null
                              ? 'In Progress'
                              : 'Not Started',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: event.interventionCompleted 
                            ? AppTheme.accentGreen
                            : event.interventionStarted != null
                                ? AppTheme.warningAmber
                                : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                
                // Action buttons
                Row(
                  children: [
                    if (event.recommendedProtocol != null && !event.interventionCompleted)
                      TextButton(
                        onPressed: () => _startProtocol(context, event),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        child: const Text('Start'),
                      ),
                    
                    IconButton(
                      onPressed: () => _showEventDetails(context, event),
                      icon: const Icon(Icons.info_outline),
                      iconSize: 20,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatEventTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  String _getProtocolDisplayName(String protocol) {
    final protocolNames = {
      'physiological_sigh': 'Physiological Sigh',
      '4-7-8-0': 'Huberman Classic (4-7-8)',
      '4-0-8-0': 'Deep Calming (4-0-8)',
      '4-0-6-0': 'Light Calming (4-0-6)',
      '5-0-5-0': 'Coherent 5-5',
      '6-0-6-0': 'Coherent 6-6',
      '5-0-4-0': 'Energizing (5-0-4)',
      '4-0-10-0': 'Before Sleep (4-0-10)',
    };
    
    return protocolNames[protocol] ?? protocol;
  }

  void _startProtocol(BuildContext context, StressEvent event) {
    // TODO: Navigate to protocol screen
    debugPrint('Start protocol: ${event.recommendedProtocol}');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting ${_getProtocolDisplayName(event.recommendedProtocol!)}'),
        backgroundColor: AppTheme.primaryBlue,
      ),
    );
  }

  void _showEventDetails(BuildContext context, StressEvent event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${event.severityDescription} Event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Time', _formatFullDateTime(event.detectedAt)),
            _buildDetailRow('Z-Score', event.zScore.toStringAsFixed(2)),
            _buildDetailRow('Pattern', event.patternDescription),
            _buildDetailRow('Confidence', '${(event.confidence * 100).toStringAsFixed(0)}%'),
            if (event.recommendedProtocol != null)
              _buildDetailRow('Protocol', _getProtocolDisplayName(event.recommendedProtocol!)),
            if (event.interventionStarted != null)
              _buildDetailRow('Started', _formatFullDateTime(event.interventionStarted!)),
            if (event.interventionCompleted)
              _buildDetailRow('Status', 'Completed'),
            if (event.postInterventionHRV != null)
              _buildDetailRow('Post-HRV', '${event.postInterventionHRV!.toStringAsFixed(1)}ms'),
            if (event.interventionEffectiveness != null)
              _buildDetailRow('Effectiveness', '${(event.interventionEffectiveness! * 100).toStringAsFixed(1)}%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (event.recommendedProtocol != null && !event.interventionCompleted)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startProtocol(context, event);
              },
              child: const Text('Start Protocol'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatFullDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}