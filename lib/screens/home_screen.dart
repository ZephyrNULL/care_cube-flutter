import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import '../services/mqtt_service.dart';
import '../models/medicine_schedule.dart';
import 'alert_screen.dart';
import 'medicine_screen.dart';
import 'profile_screen.dart';
import 'setting_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final MqttService _mqttService = MqttService();
  int currentIndex = 0;
  String firstName = 'User';
  Map<String, dynamic>? _boxStatus;
  bool _isBoxConnected = false;
  late Stream<List<MedicineSchedule>> _schedulesStream;

  @override
  void initState() {
    super.initState();
    _schedulesStream = _supabaseService.schedulesStream;
    loadUserName();
    _initMqtt();
  }

  Future<void> _initMqtt() async {
    final prefs = await SharedPreferences.getInstance();
    final boxId = prefs.getString('esp32_box_id') ?? '';
    if (boxId.isEmpty) return;

    final connected = await _mqttService.connect(boxId);
    if (connected && mounted) {
      setState(() => _isBoxConnected = true);
    }
    _mqttService.statusStream.listen((data) {
      if (data.containsKey('dose_taken')) {
        final compartment = data['dose_taken'].toString();
        _handleDoseTakenFromBox(compartment);
      }
      if (mounted) {
        setState(() {
          _boxStatus = data;
          _isBoxConnected = true;
        });
      }
    });
  }

  String? _liveStatusFor(String compartment) {
    if (_boxStatus == null) return null;
    final match = RegExp(r'(\d+)').firstMatch(compartment);
    if (match == null) return null;
    final key = 'compartment${match.group(1)}_present';
    final value = _boxStatus?[key];
    if (value is! bool) return null;
    return value ? 'Filled' : 'Empty';
  }

  Future<void> _handleDoseTakenFromBox(String compartment) async {
    final schedules = await _supabaseService.getSchedules();
    for (var s in schedules) {
      if (s.compartment.toLowerCase().contains(compartment.toLowerCase()) && !s.isTaken) {
        await _supabaseService.updateScheduleTaken(s.id, true);
        break;
      }
    }
  }

  Future<void> loadUserName() async {
    final preferences = await SharedPreferences.getInstance();
    final fullName = preferences.getString('userName') ?? preferences.getString('fullName') ?? 'User';
    if (!mounted) return;
    setState(() {
      firstName = fullName.trim().isEmpty ? 'User' : fullName.trim().split(RegExp(r'\s+')).first;
    });
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    if (hour < 21) return 'Good Evening';
    return 'Good Night';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5FAF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16796F),
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 85,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${getGreeting()}, $firstName',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text(DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
                style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.settings_rounded, size: 28),
          ),
          IconButton(
            onPressed: () {
              final index = 2;
              setState(() => currentIndex = index);
            },
            icon: const Icon(Icons.notifications_none_rounded, size: 28),
          ),
        ],
      ),
      body: IndexedStack(
        index: currentIndex,
        children: [
          _buildHomeContent(),
          MedicineScreen(),
          const AlertsScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: const Color(0xFF16796F),
        unselectedItemColor: isDark ? Colors.white60 : Colors.grey,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.medication_rounded), label: 'Medicine'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_rounded), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1C2C39);

    return StreamBuilder<List<MedicineSchedule>>(
      stream: _schedulesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF16796F)));
        }

        final schedules = snapshot.data ?? [];
        final takenCount = schedules.where((s) => s.isTaken).length;
        final totalCount = schedules.length;
        final progress = totalCount == 0 ? 0.0 : takenCount / totalCount;

        final nextReminder = schedules.firstWhere((s) => !s.isTaken, orElse: () => schedules.isNotEmpty ? schedules.first : MedicineSchedule(id: '', userId: '', medicineName: 'No upcoming doses', compartment: '', scheduledTime: '--', dosage: ''));

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          color: const Color(0xFF16796F),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReminderCard(nextReminder),
                const SizedBox(height: 18),
                if (_isBoxConnected && _boxStatus != null) ...[
                  _buildEnvironmentCard(),
                  const SizedBox(height: 22),
                ],
                Text('Medicine Compartments',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 14),
                _buildCompartmentGrid(schedules),
                const SizedBox(height: 24),
                _buildVisualCompartmentStatus(),
                const SizedBox(height: 24),
                Text("Today's Progress",
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 14),
                _buildProgressCard(takenCount, totalCount, progress),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnvironmentCard() {
    final temp = _boxStatus?['temperature'];
    final hum = _boxStatus?['humidity'];
    final tempStr = temp is num ? temp.toStringAsFixed(1) : '--';
    final humStr = hum is num ? hum.toStringAsFixed(0) : '--';

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sensors_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Box Environment', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildEnvItem(
                  icon: Icons.thermostat_rounded,
                  label: 'Temperature',
                  value: '$tempStr°C',
                ),
              ),
              Container(width: 1, height: 56, color: Colors.white.withOpacity(0.35)),
              Expanded(
                child: _buildEnvItem(
                  icon: Icons.water_drop_rounded,
                  label: 'Humidity',
                  value: '$humStr%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnvItem({required IconData icon, required String label, required String value}) {
    return Column(
      children: [
        Icon(icon, size: 28, color: Colors.white),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.86))),
      ],
    );
  }

  Widget _buildVisualCompartmentStatus() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1C2C39);
    final data = _boxStatus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Smart Box Live Status',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: textColor)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isBoxConnected ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _isBoxConnected ? Colors.green : Colors.red, width: 1),
              ),
              child: Row(
                children: [
                  Icon(_isBoxConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                      size: 14, color: _isBoxConnected ? Colors.green : Colors.red),
                  const SizedBox(width: 4),
                  Text(_isBoxConnected ? 'Online' : 'Offline',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isBoxConnected ? Colors.green : Colors.red)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.5,
                  children: [
                    _buildCompartmentIndicator(
                      label: 'Cup 1',
                      isPresent: data?['compartment1_present'],
                      distance: data?['sensor1_distance'],
                    ),
                    _buildCompartmentIndicator(
                      label: 'Cup 2',
                      isPresent: data?['compartment2_present'],
                      distance: data?['sensor2_distance'],
                    ),
                    _buildCompartmentIndicator(
                      label: 'Cup 3',
                      isPresent: data?['compartment3_present'],
                      distance: data?['sensor3_distance'],
                    ),
                    _buildCompartmentIndicator(
                      label: 'Cup 4',
                      isPresent: data?['compartment4_present'],
                      distance: data?['sensor4_distance'],
                    ),
                  ],
                ),
                if (!_isBoxConnected) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Connect your Care Cube for live updates.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompartmentIndicator({required String label, dynamic isPresent, dynamic distance}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color color;
    IconData icon;
    String statusText;

    if (isPresent == null) {
      color = Colors.blueGrey.withOpacity(0.6);
      icon = Icons.inventory_2_outlined;
      statusText = 'No Data';
    } else if (isPresent == true) {
      color = const Color(0xFF16796F);
      icon = Icons.medication_rounded;
      statusText = 'Filled';
    } else {
      color = Colors.orange;
      icon = Icons.radio_button_unchecked_rounded;
      statusText = 'Empty';
    }

    final distStr = distance is num ? '${distance.toInt()} mm' : '--';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
              ),
              Icon(icon, color: color, size: 22),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF1C2C39))),
                Text(statusText,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                Text(distStr,
                    style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.grey,
                        fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(MedicineSchedule s) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFF16796F), borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Next Reminder', style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 10),
            Text(s.medicineName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Time: ${s.scheduledTime}', style: const TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 10),
            Text(s.isTaken ? 'Dose Taken' : 'Ready to take - ${s.compartment}', style: const TextStyle(color: Colors.white70, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildCompartmentGrid(List<MedicineSchedule> schedules) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (schedules.isEmpty) return Text('Add schedules in the Medicine tab.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87));

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1.05),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: schedules.length > 4 ? 4 : schedules.length,
      itemBuilder: (context, index) {
        final s = schedules[index];
        final liveStatus = _liveStatusFor(s.compartment);
        return buildCompartmentCard(
          icon: Icons.medication_rounded,
          title: s.medicineName,
          subtitle: s.scheduledTime,
          status: liveStatus ?? (s.isTaken ? 'Taken' : s.compartment),
          isTaken: liveStatus == 'Empty' || (liveStatus == null && s.isTaken),
        );
      },
    );
  }

  Widget buildCompartmentCard({required IconData icon, required String title, required String subtitle, required String status, required bool isTaken}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C2C39);
    final subtitleColor = isDark ? Colors.white60 : Colors.grey;

    return Card(
      elevation: 3,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 42, color: isTaken ? Colors.grey : const Color(0xFF16796F)),
            const SizedBox(height: 9),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 14, color: subtitleColor)),
            const SizedBox(height: 6),
            Text(status, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isTaken ? Colors.green : const Color(0xFF16796F))),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(int taken, int total, double progress) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.black;

    return Card(
      elevation: 3,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Medicine taken', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: titleColor)),
                Text('$taken / $total', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF16796F))),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: isDark ? Colors.white12 : const Color(0xFFE0E0E0),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF16796F)),
              ),
            ),
            const SizedBox(height: 10),
            Text(taken == total && total > 0 ? 'All doses for today completed!' : 'Keep going! Your health is important.', style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
