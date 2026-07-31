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

  @override
  void initState() {
    super.initState();
    loadUserName();
    _initMqtt();
  }

  Future<void> _initMqtt() async {
    final prefs = await SharedPreferences.getInstance();
    final boxId = prefs.getString('esp32_box_id') ?? '';
    if (boxId.isNotEmpty) {
      await _mqttService.connect(boxId);
      _mqttService.statusStream.listen((data) {
        if (data.containsKey('dose_taken')) {
          final compartment = data['dose_taken'].toString();
          _handleDoseTakenFromBox(compartment);
        }
      });
    }
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
            Text('${getGreeting()}, $firstName 👋',
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
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded, size: 28)),
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
      stream: _supabaseService.schedulesStream,
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
            setState(() {}); // Trigger refresh
          },
          color: const Color(0xFF16796F),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReminderCard(nextReminder),
                const SizedBox(height: 22),
                Text('Medicine Compartments',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 14),
                _buildCompartmentGrid(schedules),
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
            const Text('💊 Next Reminder', style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 10),
            Text(s.medicineName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('⏰ ${s.scheduledTime}', style: const TextStyle(color: Colors.white, fontSize: 18)),
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
        return buildCompartmentCard(
          icon: Icons.medication_rounded,
          title: s.medicineName,
          subtitle: s.scheduledTime,
          status: s.isTaken ? 'Taken' : s.compartment,
          isTaken: s.isTaken,
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
