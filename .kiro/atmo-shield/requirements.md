# ATMO Shield Premium Integration - Requirements Specification

## 🎯 Feature Overview

**ATMO Shield Premium Integration** transforms the existing ATMO v1.4.0 NeuroYoga application by seamlessly integrating advanced proactive stress monitoring capabilities as premium functionality. This integration maintains all existing free features while adding a comprehensive premium tier that provides predictive stress detection, automated NeuroYoga interventions, and advanced health analytics.

**Core Value Proposition**: "Upgrade your NeuroYoga practice with AI-powered stress prediction - catch stress 15-60 minutes before you feel it."

**Integration Philosophy**: Zero disruption to existing functionality, seamless premium upgrade experience, and unified user interface that naturally extends the current ATMO experience.

**⚠️ Medical Disclaimer**: ATMO Shield Premium is designed for wellness purposes only and is not intended to diagnose, treat, cure, or prevent any medical condition. Always consult healthcare professionals for medical concerns.

## 📋 Glossary

- **ATMO Base**: The existing free ATMO v1.4.0 NeuroYoga application with breathing protocols, acupressure, and dashboard
- **Shield Premium**: The advanced proactive stress monitoring functionality integrated as premium features
- **Hybrid Architecture**: Native iOS/Android modules for background processing with Flutter UI integration
- **HRV**: Heart Rate Variability - the primary biometric used for stress detection
- **Z-Score Analysis**: Statistical method for detecting stress patterns based on personal baseline
- **NeuroYoga Protocol**: Existing ATMO breathing and acupressure techniques enhanced with predictive timing
- **Method Channel**: Flutter's communication bridge between Dart and native platform code
- **Premium Tier**: Paid functionality that unlocks Shield features while maintaining free base features

## 📋 User Stories

### Epic 1: Proactive Stress Detection

#### 1.1 Platform Permissions and Setup
**As a** user setting up ATMO Shield  
**I want** the system to request only necessary permissions with clear explanations  
**So that** I understand why each permission is needed and feel comfortable granting access  

**Acceptance Criteria - iOS:**
- Request HealthKit permissions with custom usage descriptions in Info.plist:
  - `NSHealthShareUsageDescription`: "ATMO Shield analyzes heart rate variability patterns for wellness insights and personalized NeuroYoga recommendations. This is for wellness purposes only, not medical diagnosis."
  - `NSHealthUpdateUsageDescription`: "ATMO saves wellness analysis results to Health app for your progress tracking"
- Request specific HealthKit data types:
  - `HKQuantityTypeIdentifierHeartRateVariabilitySDNN` (primary)
  - `HKQuantityTypeIdentifierRestingHeartRate` (context)
  - `HKQuantityTypeIdentifierStepCount` (activity context)
  - `HKCategoryTypeIdentifierSleepAnalysis` (sleep context)
- Background processing permissions (conservative approach):
  - `UIBackgroundModes`: ["fetch"] only (no background-processing to avoid App Store issues)
  - Register BGAppRefreshTask with identifier "com.atmo.shield.refresh"
  - HealthKit observer queries for data delivery (15-60 min typical delay)
- Calendar access (optional):
  - `NSCalendarsUsageDescription`: "ATMO checks calendar for smart wellness notification timing"
- Notification permissions:
  - Request authorization for alerts, badges, and sounds
  - Register notification categories for actionable notifications

**Acceptance Criteria - Android:**
- Android 14+ (Health Connect primary):
  - `android.permission.health.READ_HEART_RATE_VARIABILITY`
  - `android.permission.health.READ_RESTING_HEART_RATE`
  - `android.permission.health.READ_STEPS`
  - `android.permission.health.READ_SLEEP`
- Android 10-13 (Google Fit primary, not fallback):
  - `com.google.android.gms.permission.ACTIVITY_RECOGNITION`
  - `android.permission.BODY_SENSORS`
  - `com.google.android.gms.permission.FITNESS_ACTIVITY_READ`
  - `com.google.android.gms.permission.FITNESS_BODY_READ`
- Background processing:
  - `android.permission.WAKE_LOCK`
  - `android.permission.FOREGROUND_SERVICE`
  - `android.permission.FOREGROUND_SERVICE_DATA_SYNC` (correct permission)
- Calendar access (optional):
  - `android.permission.READ_CALENDAR`
- Notification permissions:
  - `android.permission.POST_NOTIFICATIONS` (Android 13+)
  - `android.permission.VIBRATE`

**Acceptance Criteria - Permission Flow:**
- Progressive permission requests (not all at once)
- Clear rationale dialogs explaining health benefits
- Graceful degradation when permissions denied
- Settings screen to review and modify permissions
- Fallback modes for limited permission scenarios

#### 1.2 HRV Data Collection
**As a** user who wants proactive stress management  
**I want** ATMO Shield to continuously monitor my HRV data from health platforms  
**So that** stress patterns can be detected before I consciously feel them  

**Acceptance Criteria:**
- iOS: HealthKit integration with observer queries for background delivery
- Android: Health Connect (primary) or Google Fit (fallback) integration
- HRV data is collected and aggregated daily with mean, median, and sample count
- Data collection works in background when app is closed
- System handles missing or invalid data gracefully
- Historical data is maintained for 90+ days for baseline calculation
- Cross-platform data format standardization

#### 1.2 Baseline Calculation
**As a** user with varying stress patterns  
**I want** the system to establish my personal HRV baseline  
**So that** stress detection is personalized to my unique physiology  

**Acceptance Criteria:**
- System calculates 21-day rolling baseline (mean and standard deviation)
- Minimum 7 days of data required before baseline becomes valid
- Baseline updates automatically as new data arrives
- System provides confidence level for baseline quality
- Long-term 90-day baseline maintained for trend analysis

#### 1.3 Z-Score Analysis
**As a** user experiencing stress variations  
**I want** the system to detect when my HRV deviates significantly from baseline  
**So that** stress events are identified with statistical precision  

**Acceptance Criteria:**
- Z-score calculated as (current_HRV - baseline_mean) / baseline_std
- Stress threshold set at Z-score ≤ -1.8 (sympathetic overdrive)
- Severe stress threshold at Z-score ≤ -2.5
- Critical stress threshold at Z-score ≤ -3.0
- System accounts for contextual factors (exercise, sleep, calendar events)

### Epic 2: Pattern Recognition

#### 2.1 Sympathetic Overdrive Detection
**As a** user experiencing acute stress  
**I want** the system to detect sympathetic nervous system activation  
**So that** I receive immediate breathing protocol recommendations  

**Acceptance Criteria:**
- Detects Z-score ≤ -1.8 with low recent activity (< 500 steps/hour)
- Excludes false positives from exercise or sleep
- Severity classification: low (-1.8 to -2.0), medium (-2.0 to -2.5), high (-2.5 to -3.0), critical (< -3.0)
- Recommends appropriate breathing protocol based on severity
- Logs detection event with timestamp and metadata

#### 2.2 Neural Rigidity Detection (Revised Algorithm)
**As a** user with low HRV variability  
**I want** the system to detect when my nervous system becomes "stuck"  
**So that** I receive point stimulation recommendations to restore flexibility  

**Acceptance Criteria:**
- Analyzes last 7 daily HRV aggregates for variability patterns
- **Algorithm Option 1 - Coefficient of Variation**: `std_deviation / mean < 0.1` (low variability)
- **Algorithm Option 2 - Percentage Change**: `total_change / baseline_mean < 5%` over 7 days
- **Algorithm Option 3 - Range Analysis**: `(max_hrv - min_hrv) / baseline_mean < 0.15` over 7 days
- Requires minimum 7 days of valid data
- Recommends NeuroYoga point stimulation (Yintang protocol)
- Distinguishes from normal stable periods (requires baseline comparison)
- Provides trend analysis showing rigidity duration

**Technical Note**: Original algorithm `< 2.0ms total change` is unrealistic as daily HRV changes are typically 5-15ms.

#### 2.3 Energy Depletion Detection
**As a** user experiencing chronic stress  
**I want** the system to detect prolonged low HRV periods  
**So that** I receive restorative protocol recommendations  

**Acceptance Criteria:**
- Detects 3+ consecutive days with Z-score ≤ -1.5
- Identifies declining energy reserves before burnout
- Recommends restorative breathing protocols
- Tracks recovery progress over time
- Provides early warning before critical depletion

### Epic 3: Smart Notifications

#### 3.1 Contextual Intervention Timing
**As a** busy professional  
**I want** stress notifications to consider my calendar and activity  
**So that** interventions are timed appropriately for my schedule  

**Acceptance Criteria:**
- Integrates with device calendar to identify important events
- Increases notification priority 1 hour before important meetings
- Reduces notification frequency during exercise periods
- Respects user-defined quiet hours
- Provides different urgency levels based on context

#### 3.2 Actionable Notifications
**As a** user receiving stress alerts  
**I want** notifications to include specific protocol recommendations  
**So that** I can take immediate action without opening the app  

**Acceptance Criteria:**
- Notifications include protocol name and duration (e.g., "2-minute Square Breathing")
- Tapping notification opens directly to recommended protocol
- Includes severity indicator and brief explanation
- Provides "Start Now" and "Remind Later" options
- Tracks notification response rates for optimization

#### 3.3 Notification Cooldown
**As a** user who doesn't want to be overwhelmed  
**I want** the system to limit notification frequency  
**So that** I'm not constantly interrupted by alerts  

**Acceptance Criteria:**
- Default cooldown: 3 hours between notifications
- Intensive mode: 1 hour cooldown for high-stress periods
- Critical events override cooldown restrictions
- User can customize cooldown periods (1-6 hours)
- System learns from user response patterns

### Epic 4: NeuroYoga Protocol Integration

#### 4.1 Breathing Protocol Recommendations
**As a** user receiving stress alerts  
**I want** specific NeuroYoga breathing protocol recommendations based on my stress level  
**So that** I can use scientifically validated techniques from ATMO's existing library  

**Acceptance Criteria:**
- **Z-score ≤ -1.8 (Low Stress)**: Recommend coherent breathing protocols
  - Primary: "5-0-5-0" (Coherent 5-5) - 5 cycles
  - Alternative: "6-0-6-0" (Coherent 6-6) - 6 cycles
  - PubMed Reference: "Heart rate variability coherence training improves autonomic balance (Thayer & Lane, 2009)"
- **Z-score ≤ -2.0 (Medium Stress)**: Recommend calming protocols
  - Primary: "4-0-6-0" (Light Calming) - 6 cycles
  - Alternative: "4-0-8-0" (Deep Calming) - 5 cycles
  - PubMed Reference: "Extended exhale breathing activates parasympathetic response (Zaccaro et al., 2018)"
- **Z-score ≤ -2.5 (High Stress)**: Recommend intensive calming protocols
  - Primary: "4-0-8-0" (Deep Calming) - 7 cycles
  - Alternative: "4-7-8-0" (Huberman Classic) - 5 cycles
  - PubMed Reference: "4-7-8 breathing technique reduces anxiety and stress markers (Sharma et al., 2017)"
- **Z-score ≤ -3.0 (Critical Stress)**: Recommend emergency protocols
  - Primary: "physiological_sigh" (Instant Stress Reset) - 5 repetitions
  - Alternative: "4-0-10-0" (Before Sleep) - 5 cycles
  - PubMed Reference: "Physiological sighs rapidly downregulate stress response (Balban et al., 2023)"

#### 4.2 Protocol Selection Algorithm
**As a** system providing breathing recommendations  
**I want** to select protocols from existing ATMO NeuroYoga library based on stress severity and time context  
**So that** users receive appropriate interventions using proven techniques  

**Acceptance Criteria:**
- Load protocol definitions from `Data/specs/breathing_spec.json`
- Consider time-of-day context from `Data/specs/breathing_spec_day.json`
- **Morning Stress (5-11 AM)**: Prefer energizing protocols even for stress (5-0-4-0, 6-0-4-0)
- **Afternoon Stress (11-17 PM)**: Use coherent protocols for focus maintenance (5-0-5-0, 6-0-6-0)
- **Evening Stress (17-23 PM)**: Prioritize calming protocols (4-0-6-0, 4-0-8-0)
- **Night Stress (23-5 AM)**: Use sleep-preparation protocols (4-0-10-0, 4-7-8-0)
- Include full protocol instructions and phase captions in notifications
- Provide scientific rationale for each recommendation

#### 4.3 Smart Notification Content
**As a** user receiving Shield notifications  
**I want** actionable notifications with scientific context and immediate protocol access  
**So that** I understand why the intervention is recommended and can act immediately  

**Acceptance Criteria:**
- **Notification Title**: "NeuroYoga Stress Alert - [Severity Level]"
- **Scientific Context**: Brief PubMed-based explanation (1-2 sentences)
- **Protocol Recommendation**: Specific technique name and duration
- **Quick Actions**: "Start [Protocol Name]" and "Remind in 15 min"
- **Example Notification**:
  ```
  🛡️ NeuroYoga Stress Alert - Medium Level
  
  Your HRV shows sympathetic overdrive (Z-score: -2.1). 
  Research shows extended exhale breathing activates 
  parasympathetic recovery within 2-3 minutes.
  
  Recommended: Light Calming (4-0-6-0) - 6 cycles
  Duration: ~1 minute
  
  [Start Protocol] [Remind Later]
  ```

### Epic 5: Shield Dashboard & Analytics

#### 5.1 Real-Time Status Dashboard
**As a** user monitoring my nervous system state  
**I want** a comprehensive Shield dashboard integrated into ATMO's main interface  
**So that** I can see my current status and recent patterns at a glance  

**Acceptance Criteria:**
- **Main Dashboard Integration**: Shield status card in existing body_zone_screen.dart
- **Status Indicator**: Circular gauge with color coding:
  - Green (Z-score > -1.0): "Optimal State"
  - Yellow (Z-score -1.0 to -1.8): "Mild Activation"
  - Orange (Z-score -1.8 to -2.5): "Stress Detected"
  - Red (Z-score < -2.5): "High Stress"
- **Current Metrics Display**:
  - Current Z-score with trend arrow (↑↓→)
  - Time since last HRV reading
  - Baseline confidence level (%)
  - Today's intervention count
- **Quick Actions**:
  - "Manual Check" button for immediate HRV analysis
  - "Start Recommended Protocol" (if stress detected)
  - "Shield Settings" access

#### 5.2 Comprehensive Trend Analysis
**As a** user tracking my stress patterns over time  
**I want** detailed analytics showing weekly, monthly, and seasonal trends  
**So that** I can identify patterns and optimize my stress management  

**Acceptance Criteria - Weekly Trends:**
- **7-Day HRV Pattern**: Line chart showing daily average HRV with baseline corridor
- **Stress Event Frequency**: Bar chart showing detection events by day of week
- **Protocol Effectiveness**: Success rate of interventions by protocol type
- **Weekly Summary**: 
  - Average Z-score for the week
  - Most stressful day/time patterns
  - Most effective protocols used
  - Improvement trend vs previous week

**Acceptance Criteria - Monthly Trends:**
- **30-Day Baseline Evolution**: Chart showing how personal baseline changes over time
- **Stress Pattern Heatmap**: Calendar view showing stress levels by day with color coding
- **Intervention Analytics**: 
  - Total interventions performed
  - Average response time to notifications
  - Protocol completion rates
  - HRV improvement measurements
- **Monthly Insights**:
  - Stress triggers identification (calendar correlation)
  - Best/worst performing days
  - Seasonal adjustment recommendations

**Acceptance Criteria - Seasonal & Long-term Analysis:**
- **Seasonal Patterns**: 3-month rolling analysis showing:
  - HRV baseline seasonal adjustments
  - Stress frequency changes with weather/daylight
  - Protocol preference shifts by season
  - Sleep pattern correlations
- **Predictive Insights**:
  - "Your stress typically increases on Mondays at 2 PM"
  - "Winter months show 15% higher stress frequency"
  - "Your HRV improves most with evening calming protocols"
- **Long-term Health Trends**:
  - 6-month HRV improvement trajectory
  - Stress resilience building over time
  - Protocol effectiveness evolution
  - Baseline stability improvements

#### 5.3 Advanced Analytics Interface
**As a** user interested in detailed health insights  
**I want** comprehensive analytics screens with exportable data  
**So that** I can share information with healthcare providers and track long-term progress  

**Acceptance Criteria:**
- **Analytics Navigation**: New "Shield Analytics" section in settings menu
- **Multi-timeframe Views**: Toggle between 7/30/90/180-day views
- **Interactive Charts**: 
  - Zoom and pan functionality
  - Tap data points for detailed information
  - Overlay calendar events and activities
- **Correlation Analysis**:
  - HRV vs sleep quality
  - Stress events vs calendar meetings
  - Protocol effectiveness vs time of day
  - Weather/seasonal impact on baseline
- **Export Functionality**:
  - CSV export for healthcare providers
  - PDF reports with key insights
  - Share anonymized data for research (opt-in)

### Epic 6: Shield Settings & Configuration

#### 6.1 Shield Control Center
**As a** user wanting to customize Shield behavior  
**I want** comprehensive settings integrated into ATMO's existing settings menu  
**So that** I can optimize Shield for my lifestyle and preferences  

**Acceptance Criteria - Settings Menu Integration:**
- **New Section**: "ATMO Shield" in existing settings_overlay.dart
- **Shield Status Toggle**: Master on/off switch with current status
- **Mode Selection**:
  - **Minimal Mode**: Only critical stress alerts (Z-score ≤ -2.5)
  - **Balanced Mode**: Standard sensitivity (Z-score ≤ -1.8)
  - **Intensive Mode**: High sensitivity (Z-score ≤ -1.5)
  - **Custom Mode**: User-defined thresholds
- **Monitoring Schedule**:
  - Active hours selection (e.g., 7 AM - 10 PM)
  - Quiet hours with no notifications
  - Weekend mode adjustments

#### 6.2 Notification Preferences
**As a** user receiving Shield notifications  
**I want** granular control over when and how I'm notified  
**So that** Shield integrates seamlessly with my daily routine  

**Acceptance Criteria:**
- **Notification Types**:
  - Stress alerts (with severity filtering)
  - Daily baseline updates
  - Weekly progress summaries
  - Protocol completion celebrations
- **Timing Controls**:
  - Cooldown periods between notifications (1-6 hours)
  - Calendar integration for meeting awareness
  - "Do Not Disturb" during focused work blocks
  - Smart timing based on activity level
- **Delivery Methods**:
  - Push notifications with quick actions
  - In-app alerts only
  - Apple Watch haptic notifications
  - Email summaries (weekly/monthly)

#### 6.3 Advanced Configuration
**As a** power user wanting maximum customization  
**I want** advanced Shield configuration options  
**So that** I can fine-tune the system for optimal performance  

**Acceptance Criteria:**
- **Detection Sensitivity**:
  - Custom Z-score thresholds for each severity level
  - Baseline calculation period (7-30 days)
  - Minimum data quality requirements
  - Context filtering (exercise, sleep, calendar)
- **Protocol Preferences**:
  - Favorite breathing patterns for each stress level
  - Protocol duration preferences (short/standard/extended)
  - Time-of-day protocol overrides
  - Custom protocol sequences
- **Data Management**:
  - Data retention periods (30/90/180/365 days)
  - Export scheduling (weekly/monthly)
  - Privacy settings for data sharing
  - Backup and restore options
- **Integration Settings**:
  - Calendar app selection and permissions
  - Health app data sources priority
  - Third-party wearable device support
  - Research participation opt-in/out

### Epic 7: ATMO Shield Preview Integration

#### 7.1 Shield Preview in Main App Settings
**As a** current ATMO user  
**I want** to see ATMO Shield preview information in the settings menu  
**So that** I can learn about upcoming advanced features and express interest  

**Acceptance Criteria:**
- **Settings Menu Addition**: New "ATMO Shield - Coming Soon" section in settings_overlay.dart
- **Preview Content**:
  - Shield logo and branding
  - "Advanced NeuroYoga with AI Prediction" tagline
  - Key features preview: "Proactive stress detection", "Automatic interventions", "Predictive analytics"
  - Expected availability: "Q2 2025"
- **Interest Collection**:
  - "Notify me when available" toggle
  - Email collection for Shield updates (optional)
  - Beta testing interest checkbox
- **Technology Teaser**:
  - "Military-grade statistical analysis"
  - "Privacy-first predictive intervention"
  - "Seamless integration with existing NeuroYoga protocols"

#### 7.2 Shield Announcement Modal
**As a** user opening ATMO after Shield announcement  
**I want** to see an informative modal about the upcoming Shield technology  
**So that** I understand the future roadmap and can opt-in for updates  

**Acceptance Criteria:**
- **Modal Trigger**: Show once per app version update (v1.5.0+)
- **Modal Content**:
  - Hero image/animation of Shield concept
  - "The Future of NeuroYoga" headline
  - Brief explanation of proactive stress management
  - Benefits: "Catch stress before you feel it", "Automatic protocol recommendations", "Long-term trend analysis"
- **Call-to-Action**:
  - "Learn More" → Opens detailed Shield information screen
  - "Get Notified" → Enables Shield updates in settings
  - "Maybe Later" → Dismisses modal, can be accessed from settings
- **Dismissal Logic**: Don't show again if user selects "Maybe Later" or enables notifications

#### 7.3 Shield Information Screen
**As a** user interested in Shield technology  
**I want** detailed information about Shield capabilities and timeline  
**So that** I can understand the value proposition and development progress  

**Acceptance Criteria:**
- **Comprehensive Overview**:
  - Shield concept explanation with visual diagrams
  - Technical capabilities: HRV monitoring, Z-score analysis, predictive algorithms
  - Integration with existing NeuroYoga protocols
  - Privacy-first architecture emphasis
- **Feature Highlights**:
  - Real-time stress detection with 15-60 minute advance warning
  - Automatic breathing protocol recommendations based on PubMed research
  - Comprehensive trend analysis (weekly, monthly, seasonal)
  - Smart notification system with calendar integration
- **Development Timeline**:
  - Current status: "Requirements Complete, Design Phase"
  - Beta testing: "Q1 2025"
  - Public release: "Q2 2025"
  - Regular progress updates for interested users
- **FAQ Section**:
  - "How does Shield differ from current ATMO?"
  - "What devices are supported?"
  - "How is my privacy protected?"
  - "Will Shield cost extra?"

### Epic 8: Data Models & Storage

#### 8.1 HRV Data Models
**As a** system processing HRV data  
**I want** structured data models for Shield analytics  
**So that** data is consistently stored and efficiently queried  

**Acceptance Criteria:**
- **HRVReading Model**:
  ```dart
  class HRVReading {
    final DateTime timestamp;
    final double value; // SDNN in milliseconds
    final String source; // 'healthkit', 'health_connect', 'google_fit'
    final int sampleCount; // Number of readings in aggregate
    final double confidence; // Data quality score 0-1
  }
  ```
- **BaselineData Model**:
  ```dart
  class BaselineData {
    final DateTime calculatedAt;
    final double mean;
    final double standardDeviation;
    final int dayCount; // Days of data used
    final double confidence; // Baseline quality 0-1
    final String platform; // Platform-specific baseline
  }
  ```
- **StressEvent Model**:
  ```dart
  class StressEvent {
    final DateTime detectedAt;
    final double zScore;
    final String severity; // 'low', 'medium', 'high', 'critical'
    final String? recommendedProtocol;
    final bool notificationSent;
    final DateTime? interventionStarted;
    final bool interventionCompleted;
    final double? postInterventionHRV;
  }
  ```

#### 8.2 Trend Analysis Data Structures
**As a** system providing trend analysis  
**I want** efficient data structures for pattern recognition  
**So that** weekly, monthly, and seasonal insights can be calculated quickly  

**Acceptance Criteria:**
- **WeeklyTrend Model**:
  ```dart
  class WeeklyTrend {
    final DateTime weekStart;
    final double averageHRV;
    final double averageZScore;
    final int stressEventCount;
    final Map<String, int> protocolUsage; // protocol -> usage count
    final Map<int, double> dailyAverages; // weekday -> HRV average
    final double weekOverWeekChange; // % change from previous week
  }
  ```
- **MonthlyInsights Model**:
  ```dart
  class MonthlyInsights {
    final DateTime month;
    final BaselineData startBaseline;
    final BaselineData endBaseline;
    final List<StressEvent> allEvents;
    final Map<String, double> protocolEffectiveness; // protocol -> success rate
    final List<String> identifiedTriggers; // calendar/activity correlations
    final double overallImprovement; // HRV improvement %
  }
  ```
- **SeasonalPattern Model**:
  ```dart
  class SeasonalPattern {
    final String season; // 'spring', 'summer', 'fall', 'winter'
    final double baselineAdjustment; // Seasonal HRV variation
    final Map<String, double> stressFrequency; // month -> events per day
    final List<String> seasonalRecommendations;
    final double daylightCorrelation; // Correlation with daylight hours
  }
  ```

#### 8.3 Local Storage Implementation
**As a** privacy-conscious system  
**I want** encrypted local storage for all Shield data  
**So that** sensitive biometric information never leaves the device  

**Acceptance Criteria:**
- **Hive Database Integration**: Extend existing ATMO Hive setup
- **Encryption**: AES-256-GCM for all Shield data boxes
- **Data Boxes**:
  - `shield_hrv_readings`: HRV data with automatic cleanup (90 days)
  - `shield_baselines`: Baseline calculations with versioning
  - `shield_events`: Stress events and interventions
  - `shield_trends`: Pre-calculated trend data for performance
  - `shield_settings`: User preferences and configuration
- **Data Retention**: Configurable retention periods with automatic cleanup
- **Export Support**: CSV/JSON export functionality for user data portability
- **Migration Support**: Schema versioning for future updates

### Epic 9: Premium App Store Integration

#### 9.1 Integrated Premium Release Strategy
**As a** business launching Shield as integrated premium functionality  
**I want** Shield to be included directly in the main ATMO app for App Store release  
**So that** users get a seamless premium experience without separate downloads  

**Acceptance Criteria - App Store Release:**
- Shield premium functionality integrated directly into main ATMO app
- Single app bundle includes both free ATMO features and premium Shield
- In-app purchase or premium app pricing unlocks Shield functionality
- No separate Shield app or complex installation process
- Seamless user experience from free features to premium Shield

**Acceptance Criteria - Premium Feature Integration:**
- Shield appears in main app settings with premium badge
- Dashboard shows Shield preview for free users, full functionality for premium
- Upgrade flow integrated into existing ATMO UI/UX patterns
- Premium users get immediate access to all Shield features
- Free users see compelling Shield preview and upgrade prompts

**Acceptance Criteria - App Store Compliance:**
- Single app submission with premium features clearly disclosed
- App Store metadata describes both free and premium functionality
- Privacy policy covers Shield health data usage
- App Store review materials include Shield feature demonstration
- Compliance with App Store health data guidelines

#### 9.2 Premium Pricing and Monetization
**As a** business monetizing Shield functionality  
**I want** flexible premium pricing integrated into the App Store ecosystem  
**So that** we can maximize revenue while providing value to users  

**Acceptance Criteria - Pricing Strategy:**
- **Premium App**: $19.99 one-time purchase (includes all ATMO + Shield)
- **In-App Purchase**: $9.99 Shield upgrade for existing free users
- **Subscription Option**: $4.99/month for Shield premium features
- **Family Sharing**: Premium features available to family members
- **Educational Discount**: 50% off for students and educators

**Acceptance Criteria - Purchase Integration:**
- Native iOS/Android in-app purchase integration
- Restore purchases functionality for device transfers
- Family sharing support for premium features
- Clear upgrade flow from free to premium
- Receipt validation and license management

#### 9.3 App Store Marketing and Positioning
**As a** business launching premium Shield functionality  
**I want** compelling App Store presence that drives premium conversions  
**So that** Shield generates significant revenue and user adoption  

**Acceptance Criteria - App Store Optimization:**
- **App Title**: "ATMO - NeuroYoga with AI Stress Shield"
- **Subtitle**: "Proactive stress detection + 3-minute NeuroYoga sessions"
- **Keywords**: neuroyoga, stress detection, HRV monitoring, proactive wellness, AI health
- **Category**: Health & Fitness (Premium tier)
- **Screenshots**: Showcase both free NeuroYoga and premium Shield features

**Acceptance Criteria - Marketing Materials:**
- App preview video demonstrating Shield proactive detection
- Screenshots showing Shield dashboard and stress alerts
- App description emphasizes unique proactive approach
- User testimonials highlighting Shield effectiveness
- Press kit for health and wellness media coverage

**Acceptance Criteria - Launch Coordination:**
- Coordinated launch across iOS App Store, Google Play, Mac App Store
- Press release announcing Shield technology breakthrough
- Influencer partnerships in wellness and biohacking communities
- Social media campaign highlighting proactive stress management
- Email marketing to existing ATMO user baseonsors**: For open source supporters
- **Academic Program**: Free licenses for research
- **Beta Program**: Invitation-only early access

### Epic 10: Privacy and Performance
#### 10.1 Local Data Processing
**As a** privacy-conscious user  
**I want** all my biometric data to remain on my device  
**So that** my sensitive health information is never shared  

**Acceptance Criteria:**
- 100% on-device processing using local algorithms
- No cloud storage or transmission of HRV data
- Local Hive database for all historical data
- Encrypted storage for sensitive metadata
- Clear privacy policy explaining data handling

#### 10.2 Battery Optimization
**As a** mobile device user  
**I want** Shield to minimize battery impact  
**So that** I can use continuous monitoring without draining my phone  

**Acceptance Criteria:**
- iOS background processing: < 30 seconds per analysis (system limit)
- Android background processing: < 10 minutes (target < 30 seconds)
- Automatic reduction of analysis frequency when battery < 20%
- Low Power Mode compatibility with reduced functionality
- Memory usage < 50MB for 90 days of data
- No impact on app cold start time (< 0.5 second addition)
- **Realistic battery impact**: 3-8% additional drain (initial target 5%)

#### 10.3 Reliability and Error Handling

## 🔧 Technical Requirements

### Platform Support
- iOS 16.0+ (primary target)
- Android 10+ (API 29+) with Health Connect support
- Flutter 3.0+ framework
- Cross-platform health data integration

### iOS-Specific Requirements

#### HealthKit Integration
```xml
<!-- Info.plist entries -->
<key>NSHealthShareUsageDescription</key>
<string>ATMO Shield analyzes heart rate variability patterns for wellness insights and personalized NeuroYoga recommendations. This is for wellness purposes only, not medical diagnosis.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>ATMO saves wellness analysis results to Health app for your progress tracking</string>

<key>NSCalendarsUsageDescription</key>
<string>ATMO checks calendar for smart wellness notification timing around important events</string>

<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
</array>
```

#### Background Processing Setup (Revised Architecture)
- **Primary**: Custom Swift Method Channel for HKObserverQuery (health plugin insufficient)
- **Secondary**: BGAppRefreshTask registration: `com.atmo.shield.refresh`
- **Reality**: HealthKit observer queries (15-60 min typical delay, not real-time)
- **Flutter Limitation**: Dart isolate killed after ~30 seconds in background
- **Solution**: Native Swift processing → save to UserDefaults → Flutter reads on foreground
- Fallback to local notifications if background processing fails

#### Required Entitlements
```xml
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.background-delivery</key>
<true/>
```

#### Native iOS Module Requirements
```swift
// Required Swift implementation for background processing
class ATMOShieldNative {
    func setupHealthKitObserver() // HKObserverQuery setup
    func processHRVInBackground() // Z-score calculation in native
    func saveAnalysisResults()    // UserDefaults/AppGroup storage
    func scheduleNotification()   // Local notification trigger
}
```

#### Required Entitlements
```xml
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.background-delivery</key>
<true/>
```

### Android-Specific Requirements

#### Health Connect Integration (Android 14+)
```xml
<!-- AndroidManifest.xml permissions -->
<uses-permission android:name="android.permission.health.READ_HEART_RATE_VARIABILITY" />
<uses-permission android:name="android.permission.health.READ_RESTING_HEART_RATE" />
<uses-permission android:name="android.permission.health.READ_STEPS" />
<uses-permission android:name="android.permission.health.READ_SLEEP" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_HEALTH" />
<uses-permission android:name="android.permission.READ_CALENDAR" />
```

#### Google Fit Fallback (Android 13 and below)
```xml
<uses-permission android:name="com.google.android.gms.permission.ACTIVITY_RECOGNITION" />
<uses-permission android:name="android.permission.BODY_SENSORS" />
<uses-permission android:name="com.google.android.gms.permission.FITNESS_ACTIVITY_READ" />
<uses-permission android:name="com.google.android.gms.permission.FITNESS_BODY_READ" />
```

#### Android Background Processing
- WorkManager for periodic data sync (every 15-60 minutes)
- Foreground service for critical analysis (when needed)
- Doze mode and battery optimization handling
- Background execution limits: 10 minutes maximum (target < 30 seconds)
- **Platform-specific calibration**: Separate baselines for Health Connect vs Google Fit data

#### Native Android Module Requirements
```kotlin
// Required Kotlin implementation for background processing
class ATMOShieldNative {
    fun setupHealthConnectObserver() // Health Connect data monitoring
    fun setupGoogleFitFallback()     // Google Fit for Android <14
    fun processHRVInBackground()     // Analysis in native
    fun saveAnalysisResults()        // SharedPreferences storage
    fun scheduleNotification()       // Local notification trigger
}
```

### Cross-Platform Data Calibration

#### HRV Data Normalization (Critical for Accuracy)
**Problem**: Different platforms provide different HRV ranges and accuracy:
- HealthKit (Apple Watch): 30-120ms typical range
- Health Connect: 25-100ms typical range (varies by device)
- Google Fit: 20-90ms typical range (varies by source app)

**Solution**: Platform-specific normalization:
```dart
class HRVNormalizer {
  static double normalize(double rawHRV, Platform platform) {
    switch (platform) {
      case Platform.healthKit:
        return (rawHRV - 30) / (120 - 30); // 0-1 normalized
      case Platform.healthConnect:
        return (rawHRV - 25) / (100 - 25); // 0-1 normalized
      case Platform.googleFit:
        return (rawHRV - 20) / (90 - 20);  // 0-1 normalized
    }
  }
}
```

#### Separate Baseline Management
- Maintain platform-specific baselines
- Cross-platform migration with recalibration period
- User notification when switching platforms: "Recalibrating for new device..."
- Gradual baseline adjustment over 7-14 days

### Revised Architecture (Hybrid Native-Flutter)

#### Core Architecture Decision
**Problem**: Pure Flutter approach insufficient for background health data processing
**Solution**: Hybrid architecture with native modules for critical functionality

```
┌─────────────────────────────────────────┐
│           Flutter UI Layer              │
│  (Dashboard, Settings, Notifications)   │
├─────────────────────────────────────────┤
│         Method Channel Bridge           │
├─────────────────────────────────────────┤
│     Native Background Modules           │
│  iOS: Swift + HealthKit                 │
│  Android: Kotlin + Health Connect       │
├─────────────────────────────────────────┤
│        Local Storage Layer              │
│  iOS: UserDefaults + Keychain           │
│  Android: SharedPreferences + Keystore  │
└─────────────────────────────────────────┘
```

### Permission Request Strategy
**Flutter Layer**:
- UI rendering and user interactions
- Settings management and preferences
- Data visualization and charts
- Protocol recommendations display

**Native Layer**:
- Background health data monitoring
- Z-score calculations and pattern detection
- Local notification scheduling
- Platform-specific data normalization

**Method Channel Communication**:
```dart
// Flutter → Native
await platform.invokeMethod('startMonitoring');
await platform.invokeMethod('updateSettings', settings);

// Native → Flutter
platform.setMethodCallHandler((call) {
  switch (call.method) {
    case 'onStressDetected':
      _handleStressDetection(call.arguments);
    case 'onDataUpdated':
      _refreshDashboard();
  }
});
```

#### Progressive Permission Flow
1. **Initial Setup**: Core HealthKit/Health Connect permissions
2. **Feature Discovery**: Calendar permissions when user enables smart timing
3. **Optimization**: Background processing permissions after user sees value
4. **Enhancement**: Notification permissions for proactive alerts

#### Permission Rationale Messages
- **HRV Access**: "Monitor your stress levels automatically"
- **Background Processing**: "Detect stress patterns even when app is closed"
- **Calendar Access**: "Time notifications around your important meetings"
- **Notifications**: "Get immediate alerts when stress is detected"

#### Graceful Degradation
- **No HRV Permission**: Manual stress tracking mode
- **No Background**: Analysis only when app is open
- **No Calendar**: Standard notification timing
- **No Notifications**: In-app alerts only

### Performance Targets
- Z-score calculation: < 100ms
- Background analysis: < 10 seconds total
- UI response time: < 120ms
- Memory usage: < 50MB for full dataset
- Battery impact: < 5% additional drain

### Data Requirements
- HRV data retention: 90 days minimum
- Detection events: 30 days retention
- Baseline history: 180 days for trend analysis
- Local storage: Hive database with encryption
- Export format: CSV for user data portability

## 🧪 Success Metrics

### Technical KPIs (Realistic for 2026)
- Detection accuracy: > 75% (validated against user feedback, reduced from 85%)
- False positive rate: < 20% (increased from 15% - more realistic)
- Background task success rate: > 90% (reduced from 95% due to iOS limitations)
- App crash rate: < 0.1%
- User retention with Shield enabled: > 70% (reduced from 80%)
- **Background data delivery**: 15-60 minutes average (iOS HealthKit reality)
- **Cross-platform data consistency**: ±10% variance between iOS/Android acceptable

### User Experience KPIs
- Time to first detection: < 7 days (with sufficient data)
- Notification response rate: > 60%
- Protocol completion rate after notification: > 70%
- User satisfaction score: > 4.5/5
- Feature adoption rate: > 40% of active users

### Health Impact KPIs
- Measurable HRV improvement: > 70% of users after 30 days
- Stress event frequency reduction: > 30% after 60 days
- User-reported stress level improvement: > 60% of users
- Protocol effectiveness rating: > 4.0/5 average
- Long-term engagement: > 50% still active after 90 days

## 🚀 Implementation Phases (App Store Premium Release)

**🎯 Target**: ATMO v1.5.0 with integrated Shield premium functionality for App Store release

### Phase 0: Critical PoC (Weeks 1-2)
- **Week 1**: Background delivery reality check
- **Week 2**: Cross-platform data comparison and algorithm validation
- **Deliverable**: Go/No-Go decision based on technical feasibility

### Phase 1: iOS Native Foundation (Weeks 3-6)
- **Week 3-4**: Swift Method Channel development for HealthKit
- **Week 5**: Background processing and observer query implementation
- **Week 6**: Local storage and notification system
- **Deliverable**: Working iOS background monitoring

### Phase 2: Flutter UI Layer (Weeks 7-10)
- **Week 7-8**: Dashboard UI with status indicators
- **Week 9**: Settings screen and user preferences
- **Week 10**: Analytics and trend visualization
- **Deliverable**: Complete iOS app with UI

### Phase 3: Android Native Implementation (Weeks 11-14)
- **Week 11-12**: Kotlin Method Channel for Health Connect/Google Fit
- **Week 13**: Android background processing and WorkManager
- **Week 14**: Cross-platform data calibration
- **Deliverable**: Working Android implementation

### Phase 4: App Store Integration & Release (Weeks 15-18)
- **Week 15**: Premium Shield integration into main ATMO app
- **Week 16**: App Store compliance and review preparation
- **Week 17**: Beta testing with TestFlight premium builds
- **Week 18**: App Store submission and launch coordination

**Total Timeline**: 18 weeks (4.5 months)
**Target Release**: ATMO v1.5.0 with Shield Premium in App Store
**Critical Path**: PoC success in first 2 weeks

## 📝 Assumptions and Dependencies

### Assumptions
- Users have Apple Watch or iPhone with HRV capability
- Users are willing to grant HealthKit permissions
- HRV data quality is sufficient for analysis (> 5 readings/day)
- Users understand and value proactive stress management
- Calendar integration provides meaningful context

### Dependencies
- HealthKit API stability and background delivery (iOS) - **15-60 min delays expected**
- Health Connect availability and adoption (Android 14+) - **limited device support initially**
- Google Fit API continued support through 2026 (Android legacy)
- Flutter plugin ecosystem (`health`, `background_fetch`, `workmanager`)
- **Custom Method Channels likely required** for full HealthKit observer query support
- iOS background processing limitations and policies - **strict 30-second limits**
- Android Doze mode and battery optimization policies
- App Store approval for HealthKit usage - **high scrutiny for background health apps**
- Google Play approval for health data permissions
- User education on HRV and stress correlation
- **Cross-platform HRV data quality variations** - different sources, different accuracy

### Risks and Mitigations

#### Permission-Related Risks
- **Risk**: Users deny HealthKit/Health Connect permissions
  **Mitigation**: Provide clear value proposition and fallback manual tracking mode
- **Risk**: iOS background processing gets killed by system
  **Mitigation**: Multiple fallback strategies (local notifications, app refresh, observer queries)
- **Risk**: Android battery optimization disables background work
  **Mitigation**: Guide users to whitelist app, use foreground service for critical tasks
- **Risk**: Health Connect not available on older Android devices
  **Mitigation**: Google Fit fallback integration for Android 13 and below
- **Risk**: App Store rejection for health data usage
  **Mitigation**: Clear privacy policy, minimal data collection, medical disclaimers

#### Technical Risks
- **Risk**: Insufficient HRV data quality across platforms
  **Mitigation**: Cross-platform data validation, clear guidance on improving data collection
- **Risk**: False positive stress detections due to platform differences
  **Mitigation**: Platform-specific calibration, contextual filtering, user feedback learning
- **Risk**: User notification fatigue from cross-platform inconsistencies
  **Mitigation**: Unified notification logic, platform-specific timing optimization

#### Compliance Risks
- **Risk**: GDPR/HIPAA compliance issues with health data
  **Mitigation**: Local-only processing, encrypted storage, clear consent flows
- **Risk**: Platform policy changes affecting health data access
  **Mitigation**: Regular policy monitoring, alternative data source preparation
- **Risk**: Medical device regulation concerns
  **Mitigation**: Clear wellness positioning, avoid medical claims, FDA guidance compliance

---

## 🧪 Critical Proof of Concept (PoC) Requirements

### PoC Phase 0: Background Reality Check (Week 1)
**Objective**: Validate core assumptions about iOS background HRV delivery

**Critical Tests**:
1. **HealthKit Observer Query Test**:
   - **CRITICAL**: Test if `health` plugin supports HKObserverQuery in background
   - **Expected Result**: Plugin likely does NOT support background observers
   - **Fallback Plan**: Custom Swift Method Channel implementation required
   - Measure actual delays (expected: 15-60+ minutes)
   - Document when system kills background delivery

2. **Flutter Background Limitations**:
   - Test Flutter isolate survival time in background (expected: ~30 seconds max)
   - **Architecture Decision**: Move critical logic to native Swift/Kotlin modules
   - Test Method Channel communication from background

3. **Cross-Platform HRV Data Comparison**:
   - Compare HRV values: HealthKit vs Health Connect vs Google Fit
   - **Expected Issue**: Different ranges and accuracy between platforms
   - Test calibration algorithms for data normalization

4. **Neural Rigidity Algorithm Validation**:
   - Test current algorithm: `|day1_mean - day2_mean| + ... < 2.0ms`
   - **Expected Result**: Algorithm will NEVER trigger (daily HRV changes are 5-15ms)
   - **Alternative Algorithm**: Use coefficient of variation: `std_dev / mean < 0.1`

**Success Criteria**:
- Background data delivery works (even if delayed)
- Can detect HRV changes within 60 minutes
- Cross-platform data can be normalized
- Revised algorithms show realistic trigger rates

**Failure Criteria**:
- No background delivery at all
- Delays > 2 hours consistently
- Cannot normalize cross-platform data
- Algorithms never trigger or trigger constantly

## 🔄 Fallback Strategy

### If Background Processing Fails
**Scenario**: iOS/Android kills background processing or data delivery is too delayed (>2 hours)

**Fallback Mode: "Smart Periodic Check"**
- App sends daily notification: "Time for your stress check - open ATMO"
- User opens app → immediate HRV analysis of last 24 hours
- Manual stress level input (1-10 scale) as backup data source
- Reduced functionality but still valuable for users

### If Cross-Platform Calibration Fails
**Scenario**: Cannot normalize HRV data between platforms accurately

**Fallback Mode: "Platform-Specific Baselines"**
- Separate baselines for each platform
- User migration requires 7-day recalibration period
- Clear messaging: "Switching devices - recalibrating for accuracy"
- Gradual baseline adjustment with confidence indicators

### If Detection Algorithms Fail
**Scenario**: Too many false positives or no detections at all

**Fallback Mode: "User-Guided Detection"**
- Simplified threshold-based detection (fixed percentiles)
- User feedback loop: "Was this stress detection accurate?"
- Machine learning from user feedback (local only)
- Manual protocol recommendations based on time of day

---

## 💰 Revised Cost Estimation

### Development Costs (Realistic)
| Component | Time | Cost (@$75/hour) |
|-----------|------|------------------|
| PoC & Architecture | 2 weeks | $6,000 |
| iOS Native Module | 4 weeks | $12,000 |
| Android Native Module | 4 weeks | $12,000 |
| Flutter UI & Integration | 6 weeks | $18,000 |
| Testing & Polish | 2 weeks | $6,000 |
| **Total** | **18 weeks** | **$54,000** |

### Risk Factors
- **Optimistic**: 16 weeks, $48,000 (if PoC goes smoothly)
- **Realistic**: 18 weeks, $54,000 (base estimate)
- **Pessimistic**: 24 weeks, $72,000 (if major technical issues)

### Additional Costs
- App Store Developer Account: $99/year
- Google Play Developer Account: $25 one-time
- Testing devices (iOS/Android): ~$2,000
- **Total Project Cost**: $56,000 - $74,000

---

**Document Version**: 1.1  
**Last Updated**: January 27, 2025  
**Status**: Ready for PoC Phase  
**Critical Next Step**: Execute PoC Phase 0 before any further development