import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

bool _timeZonesLoaded = false;

/// The journey keeps its original calendar even when the device travels.
DateTime accountCalendarTime(DateTime instant, String? timeZone) {
  if (timeZone == null) return instant;
  if (!_timeZonesLoaded) {
    tzdata.initializeTimeZones();
    _timeZonesLoaded = true;
  }
  try {
    return tz.TZDateTime.from(
        instant.toUtc(), timeZone == 'UTC' ? tz.UTC : tz.getLocation(timeZone));
  } catch (_) {
    return instant;
  }
}

final localClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
