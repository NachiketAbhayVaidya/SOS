import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SafetyScoreService {
  static final _firestore = FirebaseFirestore.instance;

  // ─── Main scoring function ────────────────────────────────────────────────

  static Future<SafetyResult> calculateSafetyScore({
    required double latitude,
    required double longitude,
  }) async {
    final timeScore = _getTimeScore();
    final locationScore = await _getLocationScore(latitude, longitude);
    final alertScore = await _getAlertScore(latitude, longitude);

    // Weighted average: time 30%, location 30%, alerts 40%
    final total = (timeScore * 0.30 +
        locationScore * 0.30 +
        alertScore * 0.40)
        .round()
        .clamp(0, 100);

    return SafetyResult(
      score: total,
      timeScore: timeScore,
      locationScore: locationScore,
      alertScore: alertScore,
      timeLabel: _getTimeLabel(),
      locationLabel: _getLocationLabel(locationScore),
      alertLabel: _getAlertLabel(alertScore),
    );
  }

  // ─── Time Score (0-100) ───────────────────────────────────────────────────

  static int _getTimeScore() {
    final hour = DateTime.now().hour;

    // Very safe: 8am - 6pm
    if (hour >= 8 && hour < 18) return 90;
    // Moderate: 6pm - 9pm or 6am - 8am
    if ((hour >= 18 && hour < 21) || (hour >= 6 && hour < 8)) return 60;
    // Risky: 9pm - 11pm
    if (hour >= 21 && hour < 23) return 35;
    // Dangerous: 11pm - 6am
    return 15;
  }

  static String _getTimeLabel() {
    final hour = DateTime.now().hour;
    if (hour >= 8 && hour < 18) return 'Daytime (safe hours)';
    if ((hour >= 18 && hour < 21) || (hour >= 6 && hour < 8)) return 'Evening (moderate)';
    if (hour >= 21 && hour < 23) return 'Late evening (risky)';
    return 'Late night (dangerous)';
  }

  // ─── Location Score using reverse geocoding (0-100) ───────────────────────

  static Future<int> _getLocationScore(double lat, double lon) async {
    try {
      // Google Maps Geocoding via coordinates
      // Google Places API for place type detection
      // if coordinates are in a known safe zone radius
      // For now use time-based data

      // Default moderate score — enhanced by alert history
      return 65;
    } catch (e) {
      return 60;
    }
  }

  static String _getLocationLabel(int score) {
    if (score >= 75) return 'Urban / well-lit area';
    if (score >= 50) return 'Residential area';
    return 'Isolated / remote area';
  }

  // ─── Alert Score based on past SOS in area (0-100) ───────────────────────

  static Future<int> _getAlertScore(double lat, double lon) async {
    try {
      final snapshot = await _firestore.collection('sos_alerts').get();
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));

      int nearbyAlerts = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final alertLat = (data['latitude'] as num?)?.toDouble();
        final alertLon = (data['longitude'] as num?)?.toDouble();
        final timestamp = DateTime.tryParse(data['timestamp'] ?? '');

        if (alertLat == null || alertLon == null) continue;
        if (timestamp != null && timestamp.isBefore(cutoff)) continue;

        final dist = Geolocator.distanceBetween(lat, lon, alertLat, alertLon);
        if (dist <= 1000) nearbyAlerts++; // within 1km
      }

      // More alerts = lower score
      if (nearbyAlerts == 0) return 95;
      if (nearbyAlerts == 1) return 70;
      if (nearbyAlerts == 2) return 45;
      if (nearbyAlerts >= 3) return 20;
      return 60;
    } catch (e) {
      return 75;
    }
  }

  static String _getAlertLabel(int score) {
    if (score >= 90) return 'No recent SOS alerts nearby';
    if (score >= 65) return '1 recent SOS alert nearby';
    if (score >= 40) return '2 recent SOS alerts nearby';
    return '3+ recent SOS alerts nearby';
  }
}

// ─── Result model ─────────────────────────────────────────────────────────────

class SafetyResult {
  final int score;
  final int timeScore;
  final int locationScore;
  final int alertScore;
  final String timeLabel;
  final String locationLabel;
  final String alertLabel;

  SafetyResult({
    required this.score,
    required this.timeScore,
    required this.locationScore,
    required this.alertScore,
    required this.timeLabel,
    required this.locationLabel,
    required this.alertLabel,
  });

  String get label {
    if (score >= 75) return 'Safe';
    if (score >= 50) return 'Moderate';
    if (score >= 30) return 'Unsafe';
    return 'Danger';
  }

  // Color as hex string
  String get colorHex {
    if (score >= 75) return '#4CAF50';
    if (score >= 50) return '#FF9800';
    if (score >= 30) return '#F44336';
    return '#B71C1C';
  }

  int get colorValue {
    if (score >= 75) return 0xFF4CAF50;
    if (score >= 50) return 0xFFFF9800;
    if (score >= 30) return 0xFFF44336;
    return 0xFFB71C1C;
  }
}