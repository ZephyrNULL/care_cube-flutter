import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/mqtt_service.dart';
import 'connect_box_screen.dart';

class AlertItem {
  final String icon;
  final String title;
  final String message;
  final String time;
  final String type;
  bool isUnread;

  AlertItem({
    required this.icon,
    required this.title,
    required this.message,
    required this.time,
    required this.type,
    this.isUnread = true,
  });
}

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool allRead = false;
  bool _isLoaded = false;
  bool _isBoxConnected = false;

  final List<AlertItem> _alerts = [];
  StreamSubscription? _alertSubscription;

  @override
  void initState() {
    super.initState();
    _loadState();
    _listenToAlerts();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        allRead = prefs.getBool('alerts_all_read') ?? false;
        _isBoxConnected = prefs.getBool('box_connected') ?? false;
        _isLoaded = true;
      });
    }
  }

  void _listenToAlerts() {
    _alertSubscription = MqttService().alertStream.listen((alert) {
      if (!mounted) return;

      final type = alert['type'] ?? 'info';
      final title = alert['title'] ?? 'Care Cube';
      final body = alert['body'] ?? '';
      final timestamp = alert['timestamp'] ?? DateTime.now().toIso8601String();

      // Parse timestamp for display
      final dt = DateTime.tryParse(timestamp);
      final timeStr = dt != null ? _formatTime(dt) : 'Just now';

      // Map type to icon
      String icon;
      String bgColor;
      switch (type) {
        case 'reminder':
          icon = 'warning';
          bgColor = 'orange';
          break;
        case 'confirmed':
          icon = 'check';
          bgColor = 'green';
          break;
        case 'status':
          icon = 'wifi';
          bgColor = 'blue';
          break;
        default:
          icon = 'info';
          bgColor = 'blue';
      }

      setState(() {
        _alerts.insert(0, AlertItem(
          icon: icon,
          title: title,
          message: body,
          time: timeStr,
          type: type,
          isUnread: true,
        ));

        // Keep only last 50 alerts
        if (_alerts.length > 50) {
          _alerts.removeRange(50, _alerts.length);
        }
      });
    });
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  void dispose() {
    _alertSubscription?.cancel();
    super.dispose();
  }

  Future<void> _markAllAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alerts_all_read', true);
    if (mounted) {
      setState(() {
        allRead = true;
        for (var alert in _alerts) {
          alert.isUnread = false;
        }
      });
    }
  }

  int get _unreadCount => _alerts.where((a) => a.isUnread).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_isLoaded) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5FAF8),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF16796F)),
        ),
      );
    }

    final textColor = isDark ? Colors.white : const Color(0xFF1C2C39);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF68777E);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5FAF8),
      appBar: AppBar(
        title: const Text(
          'Alerts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF16796F),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: _isBoxConnected ? [
          if (_alerts.isNotEmpty)
            TextButton(
              onPressed: () {
                _markAllAsRead();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All alerts marked as read')),
                );
              },
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ] : null,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadState,
          color: const Color(0xFF16796F),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _buildSummaryCard(),
              const SizedBox(height: 22),
              Text(
                'Recent Alerts',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isBoxConnected
                    ? 'Important updates from your Care Cube.'
                    : 'Link your box to receive real-time alerts.',
                style: TextStyle(
                  fontSize: 14,
                  color: subTextColor,
                ),
              ),
              const SizedBox(height: 15),

              if (!_isBoxConnected)
                _buildInlineConnectPrompt(textColor, subTextColor, isDark)
              else if (_alerts.isEmpty)
                _buildEmptyAlertsState(isDark, textColor, subTextColor)
              else ...[
                for (var alert in _alerts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildAlertCard(
                      alert: alert,
                      isDark: isDark,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyAlertsState(bool isDark, Color textColor, Color subTextColor) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 64,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No alerts yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Alerts from your Care Cube will appear here when medicine reminders are triggered.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: subTextColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineConnectPrompt(Color textColor, Color subTextColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE3ECE9)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.wifi_tethering_off_rounded,
            size: 60,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Connect Box to See Alerts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'You haven\'t linked your Care Cube box yet. Link it now to start receiving notifications.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: subTextColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ConnectBoxScreen()),
                ).then((_) => _loadState());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16796F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('CONNECT BOX NOW', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16796F), Color(0xFF2F9C8F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16796F).withOpacity(0.22),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alert Centre',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  !_isBoxConnected
                      ? 'Connect box to start'
                      : (_unreadCount == 0 ? 'No unread alerts' : '$_unreadCount unread alert${_unreadCount == 1 ? '' : 's'}'),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Text(
              !_isBoxConnected ? '!' : '$_unreadCount',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF16796F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard({
    required AlertItem alert,
    required bool isDark,
  }) {
    IconData icon;
    Color backgroundColour;
    Color iconColour;

    switch (alert.icon) {
      case 'warning':
        icon = Icons.warning_amber_rounded;
        backgroundColour = isDark ? const Color(0xFF2E1F1A) : const Color(0xFFFFF2E3);
        iconColour = const Color(0xFFB86B00);
        break;
      case 'check':
        icon = Icons.check_circle_rounded;
        backgroundColour = isDark ? const Color(0xFF1A2E2A) : const Color(0xFFE6F6F1);
        iconColour = const Color(0xFF16796F);
        break;
      case 'wifi':
        icon = Icons.wifi_off_rounded;
        backgroundColour = isDark ? const Color(0xFF211E2E) : const Color(0xFFF0ECFF);
        iconColour = const Color(0xFF6A4EB6);
        break;
      default:
        icon = Icons.info_outline_rounded;
        backgroundColour = isDark ? const Color(0xFF1A212E) : const Color(0xFFEAF3FF);
        iconColour = const Color(0xFF2563A6);
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: backgroundColour,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: alert.isUnread ? iconColour.withOpacity(0.35) : Colors.transparent,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 47,
            height: 47,
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.white.withOpacity(0.78),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: iconColour,
              size: 27,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        alert.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1C2C39),
                        ),
                      ),
                    ),
                    if (alert.isUnread)
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: iconColour,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  alert.message,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: isDark ? Colors.white70 : const Color(0xFF596873),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  alert.time,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: iconColour,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
