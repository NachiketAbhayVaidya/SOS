import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/sos_service.dart';

class NearbyAlertsScreen extends StatefulWidget {
  const NearbyAlertsScreen({super.key});

  @override
  State<NearbyAlertsScreen> createState() => _NearbyAlertsScreenState();
}

class _NearbyAlertsScreenState extends State<NearbyAlertsScreen> {
  List<SOSAlert> _alerts = [];
  Position? _myPosition;
  bool _loading = true;
  Timer? _refreshTimer;
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _init();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  Future<void> _init() async {
    final profile = await SOSService.getUserProfile();
    _userId = profile['id'] ?? '';
    _myPosition = await SOSService.getCurrentLocation();
    await _load();
  }

  Future<void> _load() async {
    if (_myPosition == null) {
      _myPosition = await SOSService.getCurrentLocation();
    }
    if (_myPosition == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final alerts = await SOSService.getNearbyAlerts(
        _myPosition!.latitude, _myPosition!.longitude);
    if (mounted) {
      setState(() {
        _alerts = alerts.where((a) => a.userId != _userId).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _loading = false;
      });
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return DateFormat('HH:mm').format(dt);
  }

  String _distance(SOSAlert alert) {
    if (_myPosition == null) return '';
    final m = alert.distanceTo(_myPosition!.latitude, _myPosition!.longitude);
    return m < 1000 ? '${m.toStringAsFixed(0)}m away' : '${(m / 1000).toStringAsFixed(1)}km away';
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE91E8C),
        foregroundColor: Colors.white,
        title: const Text('Nearby SOS Alerts',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E8C)))
          : Column(
              children: [
                // Radius info bar
                Container(
                  width: double.infinity,
                  color: const Color(0xFFE91E8C),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.radar, color: Colors.white70, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Monitoring 500m radius · ${_alerts.length} active alert${_alerts.length == 1 ? '' : 's'}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _alerts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEEF6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_circle_outline,
                                    size: 64, color: Color(0xFFE91E8C)),
                              ),
                              const SizedBox(height: 20),
                              const Text('All Clear!',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A2E))),
                              const SizedBox(height: 8),
                              const Text(
                                'No SOS alerts within 500m.\nThis page refreshes every 10 seconds.',
                                textAlign: TextAlign.center,
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _alerts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final alert = _alerts[i];
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.red.shade200, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.red.withOpacity(0.08),
                                      blurRadius: 10)
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                              Icons.warning_amber_rounded,
                                              color: Colors.red,
                                              size: 24),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(alert.userName,
                                                  style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              Text(
                                                '${_timeAgo(alert.timestamp)} · ${_distance(alert)}',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade100,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: const Text('SOS',
                                              style: TextStyle(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.location_on,
                                              color: Colors.red, size: 16),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${alert.latitude.toStringAsFixed(5)}, ${alert.longitude.toStringAsFixed(5)}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () =>
                                                SOSService.openLocationInMaps(
                                                    alert.latitude,
                                                    alert.longitude),
                                            icon: const Icon(Icons.map,
                                                size: 16),
                                            label: const Text('View on Map'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFFE91E8C),
                                              side: const BorderSide(
                                                  color: Color(0xFFE91E8C)),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: SOSService.callHelpline,
                                            icon: const Icon(Icons.phone,
                                                size: 16),
                                            label: const Text('Call 1091'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
