import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool allRead = false;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadReadState();
  }

  Future<void> _loadReadState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        allRead = prefs.getBool('alerts_all_read') ?? false;
        _isLoaded = true;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alerts_all_read', true);
    if (mounted) {
      setState(() {
        allRead = true;
      });
    }
  }

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
        actions: [
          TextButton(
            onPressed: () {
              _markAllAsRead();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All alerts marked as read'),
                ),
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
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
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
              'Important updates from your Care Cube.',
              style: TextStyle(
                fontSize: 14,
                color: subTextColor,
              ),
            ),
            const SizedBox(height: 15),

            _buildAlertCard(
              icon: Icons.warning_amber_rounded,
              title: 'Missed Dose',
              message: 'The morning dose was not taken at 8:00 AM.',
              time: 'Today • 8:30 AM',
              backgroundColour: isDark ? const Color(0xFF2E1F1A) : const Color(0xFFFFF2E3),
              iconColour: const Color(0xFFB86B00),
              isUnread: !allRead,
            ),

            const SizedBox(height: 12),

            _buildAlertCard(
              icon: Icons.thermostat_rounded,
              title: 'High Temperature',
              message: 'The medicine storage temperature reached 31°C.',
              time: 'Yesterday • 4:15 PM',
              backgroundColour: isDark ? const Color(0xFF2E1A1A) : const Color(0xFFFFE8E8),
              iconColour: const Color(0xFFB33A3A),
              isUnread: !allRead,
            ),

            const SizedBox(height: 12),

            _buildAlertCard(
              icon: Icons.water_drop_rounded,
              title: 'High Humidity',
              message: 'Humidity rose above the recommended safe range.',
              time: 'Yesterday • 3:55 PM',
              backgroundColour: isDark ? const Color(0xFF1A212E) : const Color(0xFFEAF3FF),
              iconColour: const Color(0xFF2563A6),
              isUnread: false,
            ),

            const SizedBox(height: 12),

            _buildAlertCard(
              icon: Icons.battery_alert_rounded,
              title: 'Low Battery',
              message: 'Care Cube battery level is below 20%.',
              time: 'Monday • 7:10 PM',
              backgroundColour: isDark ? const Color(0xFF2E2A1A) : const Color(0xFFFFF7DE),
              iconColour: const Color(0xFF8A6500),
              isUnread: false,
            ),

            const SizedBox(height: 12),

            _buildAlertCard(
              icon: Icons.wifi_off_rounded,
              title: 'Box Disconnected',
              message: 'The connection with Care Cube was interrupted.',
              time: 'Monday • 6:42 PM',
              backgroundColour: isDark ? const Color(0xFF211E2E) : const Color(0xFFF0ECFF),
              iconColour: const Color(0xFF6A4EB6),
              isUnread: false,
            ),

            const SizedBox(height: 12),

            _buildAlertCard(
              icon: Icons.person_pin_circle_outlined,
              title: 'Caregiver Notified',
              message: 'The caregiver was notified about the missed dose.',
              time: 'Monday • 6:45 PM',
              backgroundColour: isDark ? const Color(0xFF1A2E2A) : const Color(0xFFE6F6F1),
              iconColour: const Color(0xFF16796F),
              isUnread: false,
            ),

            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2E2A1A) : const Color(0xFFFFF8E7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.orange.withOpacity(0.3) : const Color(0xFFFFE3A3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF9A6A00),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      'Demo mode: Real alerts will appear after Firebase, '
                          'notifications and ESP32 are connected.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: isDark ? Colors.white70 : const Color(0xFF6E5200),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF16796F),
            Color(0xFF2F9C8F),
          ],
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
                  allRead ? 'No unread alerts' : '2 alerts need your attention',
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
              allRead ? '0' : '2',
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
    required IconData icon,
    required String title,
    required String message,
    required String time,
    required Color backgroundColour,
    required Color iconColour,
    required bool isUnread,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: backgroundColour,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUnread ? iconColour.withOpacity(0.35) : Colors.transparent,
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
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1C2C39),
                        ),
                      ),
                    ),
                    if (isUnread)
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
                  message,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: isDark ? Colors.white70 : const Color(0xFF596873),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  time,
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
