import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/models.dart';
import '../services/sos_service.dart';
import 'contacts_screen.dart';
import 'nearby_alerts_screen.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _sosActive = false;
  String? _activeAlertId;
  Position? _currentPosition;
  String _statusText = 'Press & hold SOS to alert';
  String _userName = '';
  String _userId = '';
  int _nearbyCount = 0;
  Timer? _locationTimer;
  StreamSubscription? _alertSubscription;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 1.0, end: 1.12).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _loadUser();
    _startLocationUpdates();
    _requestPermissions();
    _setupFCMListeners();
  }

  Future<void> _requestPermissions() async {
    await SOSService.requestAllPermissions();
  }

  Future<void> _loadUser() async {
    final profile = await SOSService.getUserProfile();
    setState(() {
      _userName = profile['name'] ?? '';
      _userId = profile['id'] ?? '';
    });
    // Start nearby check after userId is loaded
    _startNearbyCheck();
  }

  void _startLocationUpdates() {
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      final pos = await SOSService.getCurrentLocation();
      if (pos != null && mounted) setState(() => _currentPosition = pos);
    });
    SOSService.getCurrentLocation().then((pos) {
      if (pos != null && mounted) setState(() => _currentPosition = pos);
    });
  }

  void _startNearbyCheck() {
    _alertSubscription = SOSService.alertsStream().listen((alerts) {
      final cutoff = DateTime.now().subtract(const Duration(minutes: 30));
      final others = alerts.where((alert) {
        if (!alert.isActive) return false;
        if (alert.userId == _userId) return false;
        if (alert.timestamp.isBefore(cutoff)) return false;
        return true;
      }).toList();

      if (mounted) setState(() => _nearbyCount = others.length);
      if (others.isNotEmpty && !_sosActive) {
        _showNearbyAlertBanner(others.first);
      }
    });
  }

  void _setupFCMListeners() {
    // Foreground notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (!mounted) return;
      if (message.notification != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message.notification?.body ?? '🆘 SOS Alert Nearby!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.deepOrange,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NearbyAlertsScreen()),
              ),
            ),
          ),
        );
      }
    });

    // User taps notification when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NearbyAlertsScreen()),
      );
    });
  }

  void _showNearbyAlertBanner(SOSAlert alert) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '🆘 ${alert.userName} needs help!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.deepOrange,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NearbyAlertsScreen()),
          ),
        ),
      ),
    );
  }

  Future<void> _triggerSOS() async {
    HapticFeedback.heavyImpact();

    final pos = await SOSService.getCurrentLocation();
    if (pos == null) {
      _showError('Could not get location. Check permissions.');
      return;
    }
    setState(() {
      _currentPosition = pos;
      _sosActive = true;
      _statusText = '🆘 SOS ACTIVE — Help is on the way!';
    });

    // 1. Broadcast to Firestore
    final alertId = const Uuid().v4();
    _activeAlertId = alertId;
    final alert = SOSAlert(
      id: alertId,
      userId: _userId,
      userName: _userName.isEmpty ? 'A woman' : _userName,
      latitude: pos.latitude,
      longitude: pos.longitude,
      timestamp: DateTime.now(),
    );
    await SOSService.broadcastSOSAlert(alert);

    // 2. Send FCM notification to all users
    await SOSService.sendSOSNotificationToAll(alert);

    // 3. Send SMS to emergency contacts
    final contacts = await SOSService.getContacts();
    if (contacts.isNotEmpty) {
      await SOSService.sendSMSToContacts(contacts, pos);
    }

    // 4. Call Women Helpline 1091
    await Future.delayed(const Duration(seconds: 3));
    await SOSService.callHelpline();
  }

  Future<void> _cancelSOS() async {
    if (_activeAlertId != null) {
      await SOSService.cancelSOSAlert(_activeAlertId!);
    }
    setState(() {
      _sosActive = false;
      _activeAlertId = null;
      _statusText = 'Press & hold SOS to alert';
    });
    HapticFeedback.mediumImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('✅ SOS cancelled'),
            backgroundColor: Colors.green),
      );
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _locationTimer?.cancel();
    _alertSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      _sosActive ? const Color(0xFFFFEBEE) : const Color(0xFFFFF0F7),
      appBar: AppBar(
        backgroundColor: _sosActive ? Colors.red : const Color(0xFFE91E8C),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.shield, size: 22),
            const SizedBox(width: 8),
            Text(
              _userName.isEmpty ? 'SheSafe' : 'Hi, $_userName 👋',
              style:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          if (_nearbyCount > 0)
            IconButton(
              icon: Badge(
                label: Text('$_nearbyCount'),
                child: const Icon(Icons.notifications_active),
              ),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NearbyAlertsScreen())),
            ),
          IconButton(
            icon: const Icon(Icons.contacts),
            tooltip: 'Emergency Contacts',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ContactsScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              color: _sosActive ? Colors.red : const Color(0xFFE91E8C),
              padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Text(
                _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    if (_currentPosition != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black12,
                                blurRadius: 6,
                                offset: Offset(0, 2))
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on,
                                color: Color(0xFFE91E8C), size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '${_currentPosition!.latitude.toStringAsFixed(4)}, '
                                  '${_currentPosition!.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 48),

                    // SOS Button
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, child) {
                        final scale = _sosActive ? _pulseAnim.value : 1.0;
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: GestureDetector(
                        onLongPress: _sosActive ? null : _triggerSOS,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  '⚠️ Press & HOLD the SOS button to activate'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: _sosActive
                                  ? [
                                Colors.red.shade400,
                                Colors.red.shade700
                              ]
                                  : [
                                const Color(0xFFFF4081),
                                const Color(0xFFE91E8C)
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_sosActive
                                    ? Colors.red
                                    : const Color(0xFFE91E8C))
                                    .withValues(alpha: 0.5),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _sosActive
                                    ? Icons.warning_amber_rounded
                                    : Icons.sos,
                                color: Colors.white,
                                size: 64,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _sosActive ? 'ACTIVE' : 'SOS',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _sosActive
                                    ? 'Alert Sent'
                                    : 'Hold to activate',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    if (_sosActive)
                      ElevatedButton.icon(
                        onPressed: _cancelSOS,
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancel SOS Alert'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                      ),

                    const SizedBox(height: 32),

                    Row(
                      children: [
                        _actionCard(
                          icon: Icons.phone,
                          label: 'Call 1091',
                          sublabel: 'Women Helpline',
                          color: const Color(0xFF9C27B0),
                          onTap: SOSService.callHelpline,
                        ),
                        const SizedBox(width: 14),
                        _actionCard(
                          icon: Icons.people_alt,
                          label: 'Nearby Alerts',
                          sublabel: '$_nearbyCount active',
                          color: const Color(0xFFFF5722),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const NearbyAlertsScreen())),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        _actionCard(
                          icon: Icons.contacts_rounded,
                          label: 'Contacts',
                          sublabel: 'Manage emergency',
                          color: const Color(0xFF2196F3),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ContactsScreen())),
                        ),
                        const SizedBox(width: 14),
                        _actionCard(
                          icon: Icons.location_on,
                          label: 'My Location',
                          sublabel: 'Open in Maps',
                          color: const Color(0xFF4CAF50),
                          onTap: _currentPosition == null
                              ? null
                              : () => SOSService.openLocationInMaps(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10)
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Color(0xFFE91E8C), size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Holding SOS will: send your location to contacts via SMS, alert all SheSafe users, and call helpline 1091.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(sublabel,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.black45)),
            ],
          ),
        ),
      ),
    );
  }
}