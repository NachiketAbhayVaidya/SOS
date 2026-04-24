import 'package:geolocator/geolocator.dart';

class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String relation;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relation,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'relation': relation,
      };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        id: json['id'],
        name: json['name'],
        phone: json['phone'],
        relation: json['relation'],
      );
}

class SOSAlert {
  final String id;
  final String userId;
  final String userName;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  bool isActive;

  SOSAlert({
    required this.id,
    required this.userId,
    required this.userName,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toIso8601String(),
        'isActive': isActive,
      };

  factory SOSAlert.fromJson(Map<String, dynamic> json) => SOSAlert(
        id: json['id'],
        userId: json['userId'],
        userName: json['userName'],
        latitude: json['latitude'],
        longitude: json['longitude'],
        timestamp: DateTime.parse(json['timestamp']),
        isActive: json['isActive'] ?? true,
      );

  double distanceTo(double lat, double lon) {
    return Geolocator.distanceBetween(
      latitude, longitude, lat, lon,
    );
  }

  double _toRad(double deg) => deg * 3.141592653589793 / 180;
  double _sin2(double x) => _sin(x) * _sin(x);
  double _sin(double x) {
    // Taylor series approximation
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  double _cos(double deg) {
    final double x = _toRad(deg);
    double result = 1;
    double term = 1;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  double _asin(double x) {
    if (x >= 1) return 3.141592653589793 / 2;
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= x * x * (2 * i - 1) * (2 * i - 1) / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  double _sqrt(double x) {
    if (x == 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
}
