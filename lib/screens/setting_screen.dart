import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../services/esp32_service.dart';
import '../services/supabase_config.dart';
import '../services/notification_service.dart';
import 'connect_box_screen.dart';
import 'sound_selection_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool doseReminders = true;
  bool caregiverAlerts = true;
  bool storageAlerts = true;
  bool vibration = true;
  bool darkMode = false;

  String alarmSound = 'alarm';
  String alarmSoundName = 'System Alarm';

  String _boxIp = '';
  bool _isBoxConnected = false;
  final Esp32Service _esp32Service = Esp32Service();
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      doseReminders = prefs.getBool('doseReminders') ?? true;
      caregiverAlerts = prefs.getBool('caregiverAlerts') ?? true;
      storageAlerts = prefs.getBool('storageAlerts') ?? true;
      vibration = prefs.getBool('vibration') ?? true;
      darkMode = prefs.getBool('darkMode') ?? false;
      alarmSound = prefs.getString('alarm_sound') ?? 'alarm';
      alarmSoundName = prefs.getString('alarm_sound_name') ?? (alarmSound == 'alarm' ? 'System Alarm' : 'System Reminder');
      _boxIp = prefs.getString('esp32_ip') ?? '';
      _isBoxConnected = prefs.getBool('box_connected') ?? false;
    });

    if (_boxIp.isNotEmpty) {
      _esp32Service.setBoxIp(_boxIp);
      final connected = await _esp32Service.testConnection();
      if (mounted) {
        setState(() {
          _isBoxConnected = connected;
        });
      }
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  Future<void> _syncData() async {
    if (_isBoxConnected) {
      final status = await _esp32Service.getBoxStatus();
      if (status != null && mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('box_temperature', status['temperature']?.toString() ?? '26.5');
        await prefs.setString('box_humidity', status['humidity']?.toString() ?? '58');
        await prefs.setString('box_battery', status['battery']?.toString() ?? '93');
        _showDemoMessage('Data synced from Care Cube box successfully!');
      } else {
        _showDemoMessage('Failed to sync data from box.');
      }
    } else {
      _showDemoMessage('Box not connected. Connect first to sync.');
    }
  }

  Future<void> _launchURL() async {
    final Uri url = Uri.parse('https://www.carecube.com');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      _showDemoMessage('Could not launch website');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5FAF8),
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF16796F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 22),

            const _SettingsSectionTitle(title: 'Notifications'),
            const SizedBox(height: 12),
            _buildSettingsCard(
              isDark: isDark,
              children: [
                _buildSwitchTile(
                  icon: Icons.alarm_rounded,
                  title: 'Dose Reminders',
                  subtitle: 'Receive alerts when it is time to take a dose',
                  value: doseReminders,
                  onChanged: (value) async {
                    setState(() {
                      doseReminders = value;
                    });
                    await _saveSetting('doseReminders', value);
                    if (!value) {
                      await _notificationService.cancelAllAlarms();
                      _showDemoMessage('All dose reminders cancelled.');
                    } else {
                      _showDemoMessage('Dose reminders will be active for new schedules.');
                    }
                  },
                ),
                const _SettingsDivider(),
                _buildSwitchTile(
                  icon: Icons.people_outline_rounded,
                  title: 'Caregiver Alerts',
                  subtitle: 'Notify the caregiver about missed doses',
                  value: caregiverAlerts,
                  onChanged: (value) {
                    setState(() {
                      caregiverAlerts = value;
                    });
                    _saveSetting('caregiverAlerts', value);
                  },
                ),
                const _SettingsDivider(),
                _buildSwitchTile(
                  icon: Icons.thermostat_rounded,
                  title: 'Storage Alerts',
                  subtitle: 'Warn about unsafe temperature or humidity',
                  value: storageAlerts,
                  onChanged: (value) {
                    setState(() {
                      storageAlerts = value;
                    });
                    _saveSetting('storageAlerts', value);
                  },
                ),
                const _SettingsDivider(),
                _buildSwitchTile(
                  icon: Icons.vibration_rounded,
                  title: 'Vibration',
                  subtitle: 'Vibrate the phone with reminder alerts',
                  value: vibration,
                  onChanged: (value) {
                    setState(() {
                      vibration = value;
                    });
                    _saveSetting('vibration', value);
                  },
                ),
              ],
            ),

            const SizedBox(height: 22),

            const _SettingsSectionTitle(title: 'Reminder Preferences'),
            const SizedBox(height: 12),
            _buildSettingsCard(
              isDark: isDark,
              children: [
                _buildActionTile(
                  icon: Icons.music_note_rounded,
                  title: 'Reminder Sound',
                  subtitle: alarmSoundName,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SoundSelectionScreen(),
                      ),
                    );
                    _loadSettings(); // Reload to get updated sound name
                  },
                ),
              ],
            ),

            const SizedBox(height: 22),

            const _SettingsSectionTitle(title: 'Appearance'),
            const SizedBox(height: 12),
            _buildSettingsCard(
              isDark: isDark,
              children: [
                _buildSwitchTile(
                  icon: Icons.dark_mode_outlined,
                  title: 'Dark Mode',
                  subtitle: 'Use a darker appearance for the app',
                  value: darkMode,
                  onChanged: (value) {
                    setState(() {
                      darkMode = value;
                    });
                    _saveSetting('darkMode', value);
                    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                  },
                ),
              ],
            ),

            const SizedBox(height: 22),

            const _SettingsSectionTitle(title: 'Care Cube'),
            const SizedBox(height: 12),
            _buildSettingsCard(
              isDark: isDark,
              children: [
                _buildActionTile(
                  icon: Icons.wifi_tethering_rounded,
                  title: 'Box Connection',
                  subtitle: _isBoxConnected ? 'Connected to $_boxIp' : 'Not connected',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ConnectBoxScreen(),
                      ),
                    );
                  },
                ),
                const _SettingsDivider(),
                _buildActionTile(
                  icon: Icons.sync_rounded,
                  title: 'Sync Data',
                  subtitle: _isBoxConnected ? 'Tap to sync from box' : 'Connect box first',
                  onTap: _syncData,
                ),
                const _SettingsDivider(),
                _buildActionTile(
                  icon: Icons.code_rounded,
                  title: 'Generate ESP32 Code',
                  subtitle: 'Get Arduino code for your ESP32',
                  onTap: () {
                    _showEsp32CodeDialog();
                  },
                ),
                const _SettingsDivider(),
                _buildActionTile(
                  icon: Icons.restart_alt_rounded,
                  title: 'Reset Care Cube',
                  subtitle: 'Restore box settings to default',
                  onTap: () {
                    _showResetDialog();
                  },
                ),
              ],
            ),

            const SizedBox(height: 22),

            const _SettingsSectionTitle(title: 'Account'),
            const SizedBox(height: 12),
            _buildSettingsCard(
              isDark: isDark,
              children: [
                _buildActionTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Email',
                  subtitle: supabase.auth.currentUser?.email ?? 'Not signed in',
                  onTap: () {},
                ),
                const _SettingsDivider(),
                _buildActionTile(
                  icon: Icons.info_outline_rounded,
                  title: 'Supabase Status',
                  subtitle: 'Authentication: Active',
                  onTap: () {
                    _showDemoMessage(
                      'Supabase email OTP authentication is active.\n'
                          'URL: ${SupabaseConfig.supabaseUrl}',
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 22),

            const _SettingsSectionTitle(title: 'Support'),
            const SizedBox(height: 12),
            _buildSettingsCard(
              isDark: isDark,
              children: [
                _buildActionTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & Support',
                  subtitle: 'Get help using Care Cube',
                  onTap: () {
                    _launchURL();
                  },
                ),
                const _SettingsDivider(),
                _buildActionTile(
                  icon: Icons.info_outline_rounded,
                  title: 'About',
                  subtitle: 'Care Cube version 1.0.0',
                  onTap: () {
                    _showAboutDialog();
                  },
                ),
              ],
            ),

            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2825) : const Color(0xFFE6F6F1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF16796F),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Color(0xFF16796F),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      'Supabase authentication is active. '
                          'ESP32 integration is ready. Configure your box connection above.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: isDark ? Colors.white70 : const Color(0xFF135F58),
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

  Widget _buildHeaderCard() {
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
      child: const Row(
        children: [
          Icon(
            Icons.settings_rounded,
            size: 42,
            color: Colors.white,
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Care Cube Settings',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Manage reminders, alerts and box preferences.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({
    required List<Widget> children,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE3ECE9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 11,
      ),
      child: Row(
        children: [
          _buildIconBox(icon),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1C2C39),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: isDark ? Colors.white70 : const Color(0xFF7B898F),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            activeColor: const Color(0xFF16796F),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(19),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        child: Row(
          children: [
            _buildIconBox(icon),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1C2C39),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white70 : const Color(0xFF7B898F),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF8D999E),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconBox(IconData icon) {
    return Container(
      width: 43,
      height: 43,
      decoration: BoxDecoration(
        color: const Color(0xFFE6F6F1),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        icon,
        color: const Color(0xFF16796F),
        size: 23,
      ),
    );
  }

  void _showEsp32CodeDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final boxId = prefs.getString('esp32_box_id') ?? 'care_cube_1234';
    final esp32Service = Esp32Service();
    final code = esp32Service.generateEsp32ArduinoCode([], boxId);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('ESP32 Arduino Code'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: Text(
                code,
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('CLOSE'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showDemoMessage(
                  'Copy this code to your Arduino IDE and upload to ESP32.',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16796F),
                foregroundColor: Colors.white,
              ),
              child: const Text('COPY CODE'),
            ),
          ],
        );
      },
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Reset Care Cube?'),
          content: const Text(
            'This will restore the Care Cube settings to their default values and clear the ESP32 connection.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                if (_isBoxConnected) {
                  await _esp32Service.resetBox();
                }

                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('esp32_ip');
                await prefs.setBool('box_connected', false);

                setState(() {
                  _boxIp = '';
                  _isBoxConnected = false;
                });

                _showDemoMessage('Care Cube settings have been reset.');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB33A3A),
                foregroundColor: Colors.white,
              ),
              child: const Text('RESET'),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('About Care Cube'),
          content: const Text(
            'Care Cube is a smart medicine reminder and monitoring system '
                'designed to support patients and caregivers.\n\n'
                'Features:\n'
                '- Supabase Email OTP Authentication\n'
                '- ESP32 Medicine Box Integration\n'
                '- Real-time Temperature & Humidity Monitoring\n'
                '- Medicine Schedule Management\n'
                '- Caregiver Alerts\n\n'
                'Version 1.0.0',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }

  void _showDemoMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  final String title;

  const _SettingsSectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 70),
      child: Divider(height: 1),
    );
  }
}
