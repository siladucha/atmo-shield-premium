import 'dart:math';

/// Generates and tracks stress days across a 365-day period.
///
/// Creates 2-3 random stress days per month to simulate realistic stress patterns.
/// Provides consistent stress day identification for correlated metric generation
/// (HRV drops, RR increases, HR variations).
///
/// **Validates: Requirements 6.4, 6.6**
class StressCalendar {
  final Set<DateTime> _stressDays;
  final Random _random;

  /// Creates a StressCalendar with stress days distributed across the date range.
  ///
  /// Generates 2-3 stress days per month between [start] and [end] dates.
  /// Uses [seed] for reproducible random generation (optional).
  StressCalendar(DateTime start, DateTime end, {int? seed})
      : _random = Random(seed),
        _stressDays = {} {
    _generateStressDays(start, end);
  }

  /// Generates 2-3 random stress days per month across the date range.
  void _generateStressDays(DateTime start, DateTime end) {
    final totalDays = end.difference(start).inDays;
    final months = (totalDays / 30).ceil();

    for (int month = 0; month < months; month++) {
      // 2-3 stress days per month
      final stressCount = 2 + _random.nextInt(2);

      for (int i = 0; i < stressCount; i++) {
        // Calculate random day within this month's range
        final monthStartDay = month * 30;
        final monthEndDay = min((month + 1) * 30, totalDays);
        final daysInMonth = monthEndDay - monthStartDay;

        if (daysInMonth > 0) {
          final randomDayOffset = monthStartDay + _random.nextInt(daysInMonth);
          final stressDay = start.add(Duration(days: randomDayOffset));

          // Normalize to date only (remove time component)
          final normalizedDay =
              DateTime(stressDay.year, stressDay.month, stressDay.day);
          _stressDays.add(normalizedDay);
        }
      }
    }
  }

  /// Returns true if the given date is a stress day.
  ///
  /// Normalizes the input date to remove time components before checking.
  /// This ensures consistent identification regardless of time of day.
  bool isStressDay(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return _stressDays.contains(normalized);
  }

  /// Returns the total number of stress days generated.
  int get stressDayCount => _stressDays.length;

  /// Returns an unmodifiable set of all stress days.
  Set<DateTime> get stressDays => Set.unmodifiable(_stressDays);
}
