import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import '../services/mqtt_service.dart';
import '../services/notification_service.dart';
import '../models/medicine_schedule.dart';
import 'connect_box_screen.dart';

class MedicineScreen extends StatefulWidget {
  const MedicineScreen({super.key});

  @override
  State<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends State<MedicineScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final MqttService _mqttService = MqttService();
  final NotificationService _notificationService = NotificationService();
  
  String _temperature = '--';
  String _humidity = '--';
  bool _isConnected = false;
  String _batteryLevel = '--';

  late Stream<List<MedicineSchedule>> _schedulesStream;

  @override
  void initState() {
    super.initState();
    _schedulesStream = _supabaseService.schedulesStream;
    _initMqtt();
    _notificationService.init();
  }

  Future<void> _refreshData() async {
    setState(() {
      _schedulesStream = _supabaseService.schedulesStream;
    });
  }

  Future<void> _initMqtt() async {
    final prefs = await SharedPreferences.getInstance();
    final boxId = prefs.getString('esp32_box_id') ?? '';
    if (boxId.isEmpty) return;

    final connected = await _mqttService.connect(boxId);
    if (connected) {
      if (mounted) setState(() => _isConnected = true);
      _mqttService.statusStream.listen((data) {
        if (mounted) {
          setState(() {
            _temperature = data['temperature']?.toString() ?? _temperature;
            _humidity = data['humidity']?.toString() ?? _humidity;
            _batteryLevel = data['battery']?.toString() ?? _batteryLevel;
            _isConnected = true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _mqttService.disconnect();
    super.dispose();
  }

  Future<void> _deleteSchedule(String id) async {
    final success = await _supabaseService.deleteSchedule(id);
    if (success) {
      _notificationService.cancelAlarm(id);
      if (mounted) {
        // Triggering a local rebuild to refresh the stream
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule deleted')));
      }
    }
  }

  void _showAddScheduleDialog() {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    final notesController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();
    String selectedCompartment = 'Cup 1';
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Add New Medicine', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1C2C39))),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 20),
                _buildTextField(controller: nameController, label: 'Medicine Name', hint: 'e.g. Paracetamol', icon: Icons.medication_outlined),
                const SizedBox(height: 16),
                _buildTextField(controller: dosageController, label: 'Dosage', hint: 'e.g. 1 Tablet', icon: Icons.numbers_outlined),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Time', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1C2C39))),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final time = await showTimePicker(context: context, initialTime: selectedTime);
                              if (time != null) setModalState(() => selectedTime = time);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                              child: Row(children: [const Icon(Icons.access_time, size: 20), const SizedBox(width: 8), Text(selectedTime.format(context))]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Compartment', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1C2C39))),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedCompartment,
                                isExpanded: true,
                                items: ['Cup 1', 'Cup 2', 'Cup 3', 'Cup 4'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                onChanged: (val) { if (val != null) setModalState(() => selectedCompartment = val); },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(controller: notesController, label: 'Notes (Optional)', hint: 'e.g. Take after food', icon: Icons.note_alt_outlined),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : () async {
                      if (nameController.text.isEmpty || dosageController.text.isEmpty) return;
                      setModalState(() => isSaving = true);
                      final timeStr = selectedTime.format(context);
                      final schedule = MedicineSchedule(id: '', userId: '', medicineName: nameController.text, compartment: selectedCompartment, scheduledTime: timeStr, dosage: dosageController.text, notes: notesController.text);
                      final success = await _supabaseService.addSchedule(schedule);
                      if (success) {
                        if (_isConnected) _mqttService.publishCommand('add_schedule', schedule.toEsp32Json());
                        await _notificationService.scheduleMedicineAlarm(DateTime.now().toIso8601String(), schedule.medicineName, timeStr);
                        if (mounted) Navigator.pop(context);
                      }
                      if (mounted) setModalState(() => isSaving = false);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16796F), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    child: isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('ADD SCHEDULE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAF8),
      appBar: AppBar(
        title: const Text('Medicine Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF16796F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConnectBoxScreen()),
              );
            },
            icon: const Icon(Icons.settings_input_antenna_rounded),
            tooltip: 'Connect Box',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showAddScheduleDialog, backgroundColor: const Color(0xFF16796F), child: const Icon(Icons.add, color: Colors.white)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: const Color(0xFF16796F),
          child: StreamBuilder<List<MedicineSchedule>>(
            stream: _schedulesStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red))),
                    const SizedBox(height: 20),
                    ElevatedButton(onPressed: _refreshData, child: const Text('Retry')),
                  ],
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF16796F)));
              }
              final schedules = snapshot.data ?? [];
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                const Text('Medicine Box Status', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1C2C39))),
                const SizedBox(height: 6),
                const Text('Monitor storage conditions and today\'s dose compartments.', style: TextStyle(fontSize: 15, height: 1.4, color: Color(0xFF66747D))),
                const SizedBox(height: 22),
                _buildEnvironmentCard(),
                const SizedBox(height: 24),
                const Text('Your Schedules', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Color(0xFF1C2C39))),
                const SizedBox(height: 15),
                if (schedules.isEmpty) 
                   const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No schedules added yet.', style: TextStyle(color: Color(0xFF66747D)))))
                else
                  ListView.separated(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: schedules.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildScheduleCard(schedules[index]),
                  ),
                const SizedBox(height: 24),
                _buildCareCubeStatusSection(),
                const SizedBox(height: 20),
                if (!_isConnected) _buildConnectPrompt(),
              ],
            );
          },
        ),
      ),
    ),
  );
}

  Widget _buildConnectPrompt() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFFEAF3FF), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFA3C4FF))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF2563A6)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Connect your ESP32 Care Cube box to see real-time data.', style: TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF2563A6))),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConnectBoxScreen())),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563A6), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: const Text('CONNECT BOX', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(MedicineSchedule schedule) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19), border: Border.all(color: const Color(0xFFE3ECE9)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.045), blurRadius: 10, offset: const Offset(0, 5))]),
      child: Row(
        children: [
          Container(width: 50, height: 50, decoration: BoxDecoration(color: schedule.isTaken ? Colors.grey.shade100 : const Color(0xFFE6F6F1), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.medication_rounded, color: schedule.isTaken ? Colors.grey : const Color(0xFF16796F), size: 28)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(schedule.medicineName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: schedule.isTaken ? Colors.grey : const Color(0xFF1C2C39))),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.access_time_rounded, size: 14, color: schedule.isTaken ? Colors.grey : const Color(0xFF16796F)), const SizedBox(width: 4), Text(schedule.scheduledTime, style: const TextStyle(fontSize: 13, color: Color(0xFF596873))),
                const SizedBox(width: 12), Icon(Icons.inventory_2_outlined, size: 14, color: schedule.isTaken ? Colors.grey : const Color(0xFF16796F)), const SizedBox(width: 4), Text(schedule.isTaken ? 'Taken' : schedule.compartment, style: TextStyle(fontSize: 13, color: schedule.isTaken ? Colors.green : const Color(0xFF596873))),
              ]),
            ]),
          ),
          IconButton(onPressed: () { if (_isConnected) _mqttService.publishCommand('open', {'compartment': schedule.compartment}); }, icon: const Icon(Icons.open_in_new_rounded, color: Color(0xFF16796F))),
          IconButton(onPressed: () => _deleteSchedule(schedule.id), icon: const Icon(Icons.delete_outline, color: Color(0xFFB33A3A))),
        ],
      ),
    );
  }

  Widget _buildEnvironmentCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF16796F), Color(0xFF2F9C8F)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: const Color(0xFF16796F).withOpacity(0.22), blurRadius: 16, offset: const Offset(0, 7))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.sensors_rounded, color: Colors.white), SizedBox(width: 8), Text('Live Storage Conditions', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white))]),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: _buildSensorItem(icon: Icons.thermostat_rounded, label: 'Temperature', value: '$_temperature°C')),
            Container(width: 1, height: 72, color: Colors.white.withOpacity(0.35)),
            Expanded(child: _buildSensorItem(icon: Icons.water_drop_rounded, label: 'Humidity', value: '$_humidity%')),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [Icon(_isConnected ? Icons.update_rounded : Icons.wifi_off_rounded, size: 19, color: Colors.white), const SizedBox(width: 8), Text(_isConnected ? 'Live Remote Status' : 'Offline - using demo data', style: const TextStyle(fontSize: 13, color: Colors.white))]),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorItem({required IconData icon, required String label, required String value}) {
    return Column(children: [Icon(icon, size: 36, color: Colors.white), const SizedBox(height: 8), Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 3), Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.86)))]);
  }

  Widget _buildCareCubeStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Care Cube Status', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Color(0xFF1C2C39))),
        const SizedBox(height: 14),
        _buildStatusCard(icon: _isConnected ? Icons.check_circle_rounded : Icons.cancel_rounded, title: 'Storage Conditions', description: _isConnected ? 'Within safe range.' : 'Box not connected.', iconColour: _isConnected ? const Color(0xFF16796F) : const Color(0xFFB33A3A), backgroundColour: _isConnected ? const Color(0xFFE6F6F1) : const Color(0xFFFFE4E4)),
        const SizedBox(height: 12),
        _buildStatusCard(icon: Icons.battery_full_rounded, title: 'Battery Level', description: '$_batteryLevel% remaining', iconColour: const Color(0xFF7B5B15), backgroundColour: const Color(0xFFFFF6DD)),
      ],
    );
  }

  Widget _buildStatusCard({required IconData icon, required String title, required String description, required Color iconColour, required Color backgroundColour}) {
    return Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: backgroundColour, borderRadius: BorderRadius.circular(17)), child: Row(children: [Container(width: 46, height: 46, decoration: BoxDecoration(color: Colors.white.withOpacity(0.75), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: iconColour, size: 27)), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1C2C39))), const SizedBox(height: 3), Text(description, style: const TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF596873)))])),]));
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required String hint, required IconData icon}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1C2C39))), const SizedBox(height: 8), TextField(controller: controller, decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, size: 22), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF16796F))), filled: true, fillColor: Colors.grey.shade50))]);
  }
}
