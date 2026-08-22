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

  bool _isConnected = false;

  int? _sensor1Distance;
  int? _sensor2Distance;
  int? _sensor3Distance;
  int? _sensor4Distance;
  bool? _compartment1Present;
  bool? _compartment2Present;
  bool? _compartment3Present;
  bool? _compartment4Present;
  int _medicineCount = 0;
  int _totalCompartments = 2;

  double? _temperature;
  double? _humidity;

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
        if (!mounted) return;
        setState(() {
          _sensor1Distance = data['sensor1_distance'] is num ? (data['sensor1_distance'] as num).toInt() : _sensor1Distance;
          _sensor2Distance = data['sensor2_distance'] is num ? (data['sensor2_distance'] as num).toInt() : _sensor2Distance;
          _sensor3Distance = data['sensor3_distance'] is num ? (data['sensor3_distance'] as num).toInt() : _sensor3Distance;
          _sensor4Distance = data['sensor4_distance'] is num ? (data['sensor4_distance'] as num).toInt() : _sensor4Distance;
          _compartment1Present = data['compartment1_present'] is bool ? data['compartment1_present'] as bool : _compartment1Present;
          _compartment2Present = data['compartment2_present'] is bool ? data['compartment2_present'] as bool : _compartment2Present;
          _compartment3Present = data['compartment3_present'] is bool ? data['compartment3_present'] as bool : _compartment3Present;
          _compartment4Present = data['compartment4_present'] is bool ? data['compartment4_present'] as bool : _compartment4Present;
          _medicineCount = data['medicine_count'] is num ? (data['medicine_count'] as num).toInt() : _medicineCount;
          _totalCompartments = data['total_compartments'] is num ? (data['total_compartments'] as num).toInt() : _totalCompartments;
          _temperature = data['temperature'] is num ? (data['temperature'] as num).toDouble() : _temperature;
          _humidity = data['humidity'] is num ? (data['humidity'] as num).toDouble() : _humidity;
          _isConnected = true;
        });
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C2C39);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(color: backgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(25))),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Add New Medicine', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                    IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: textColor)),
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
                          Text('Time', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final time = await showTimePicker(context: context, initialTime: selectedTime);
                              if (time != null) setModalState(() => selectedTime = time);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                              child: Row(children: [Icon(Icons.access_time, size: 20, color: textColor), const SizedBox(width: 8), Text(selectedTime.format(context), style: TextStyle(color: textColor))]),
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
                          Text('Compartment', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedCompartment,
                                isExpanded: true,
                                dropdownColor: backgroundColor,
                                style: TextStyle(color: textColor),
                                items: ['Cup 1', 'Cup 2', 'Cup 3', 'Cup 4'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(color: textColor)))).toList(),
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

                      final schedule = MedicineSchedule(id: '', userId: '', medicineName: nameController.text, compartment: selectedCompartment, scheduledTime: selectedTime.format(context), dosage: dosageController.text, notes: notesController.text);

                      // Sync schedule time to ESP32 via MQTT
                      if (_isConnected) {
                        final sensorNum = schedule.sensorNumber;
                        // Parse the time for 24h format to send to ESP32
                        final hour24 = selectedTime.hour;
                        final minute24 = selectedTime.minute;
                        _mqttService.publishScheduleToBox(sensorNum, hour24, minute24);
                        // Also send as add_schedule command for logging
                        _mqttService.publishCommand('add_schedule', schedule.toEsp32Json());
                      }

                      final newId = await _supabaseService.addSchedule(schedule);
                      if (newId != null) {
                        await _notificationService.scheduleMedicineAlarm(newId, schedule.medicineName, selectedTime.format(context));
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1C2C39);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF66747D);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5FAF8),
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
                  Text('Medicine Box Status', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 6),
                  Text('Monitor your compartments and today\'s dose schedules in real time.', style: TextStyle(fontSize: 15, height: 1.4, color: subTextColor)),
                  const SizedBox(height: 22),
                  _buildEnvironmentCard(),
                  const SizedBox(height: 24),
                  Text('Your Schedules', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 15),
                  if (schedules.isEmpty)
                    Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('No schedules added yet.', style: TextStyle(color: subTextColor))))
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: schedules.length,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1A212E) : const Color(0xFFEAF3FF), borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? const Color(0xFF2563A6).withOpacity(0.5) : const Color(0xFFA3C4FF))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF2563A6)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Connect your ESP32 Care Cube box to see real-time data.', style: TextStyle(fontSize: 13, height: 1.45, color: isDark ? Colors.white70 : const Color(0xFF2563A6))),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C2C39);
    final subTextColor = isDark ? Colors.white60 : const Color(0xFF596873);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(19), border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE3ECE9)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.045), blurRadius: 10, offset: const Offset(0, 5))]),
      child: Row(
        children: [
          Container(width: 50, height: 50, decoration: BoxDecoration(color: schedule.isTaken ? Colors.grey.withOpacity(0.1) : (isDark ? const Color(0xFF1A2E2A) : const Color(0xFFE6F6F1)), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.medication_rounded, color: schedule.isTaken ? Colors.grey : const Color(0xFF16796F), size: 28)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(schedule.medicineName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: schedule.isTaken ? Colors.grey : textColor)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.access_time_rounded, size: 14, color: schedule.isTaken ? Colors.grey : const Color(0xFF16796F)), const SizedBox(width: 4), Text(schedule.scheduledTime, style: TextStyle(fontSize: 13, color: subTextColor)),
                const SizedBox(width: 12), Icon(Icons.inventory_2_outlined, size: 14, color: schedule.isTaken ? Colors.grey : const Color(0xFF16796F)), const SizedBox(width: 4), Text(schedule.isTaken ? 'Taken' : schedule.compartment, style: TextStyle(fontSize: 13, color: schedule.isTaken ? Colors.green : subTextColor)),
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
    final tempStr = _temperature != null ? _temperature!.toStringAsFixed(1) : '--';
    final humStr = _humidity != null ? _humidity!.toStringAsFixed(0) : '--';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF16796F), Color(0xFF2F9C8F)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: const Color(0xFF16796F).withOpacity(0.22), blurRadius: 16, offset: const Offset(0, 7))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.medication_rounded, color: Colors.white), SizedBox(width: 8), Text('Live Compartment Status', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white))]),
          const SizedBox(height: 12),
          // Temperature and Humidity
          Row(
            children: [
              Icon(Icons.thermostat_rounded, size: 18, color: Colors.white.withOpacity(0.9)),
              const SizedBox(width: 6),
              Text('$tempStr°C', style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.9))),
              const SizedBox(width: 20),
              Icon(Icons.water_drop_rounded, size: 18, color: Colors.white.withOpacity(0.9)),
              const SizedBox(width: 6),
              Text('$humStr%', style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.9))),
            ],
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _buildCompartmentItem(compartment: 'Cup 1', present: _compartment1Present, distance: _sensor1Distance)),
            Container(width: 1, height: 72, color: Colors.white.withOpacity(0.35)),
            Expanded(child: _buildCompartmentItem(compartment: 'Cup 2', present: _compartment2Present, distance: _sensor2Distance)),
          ]),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white24, height: 1),
          ),
          Row(children: [
            Expanded(child: _buildCompartmentItem(compartment: 'Cup 3', present: _compartment3Present, distance: _sensor3Distance)),
            Container(width: 1, height: 72, color: Colors.white.withOpacity(0.35)),
            Expanded(child: _buildCompartmentItem(compartment: 'Cup 4', present: _compartment4Present, distance: _sensor4Distance)),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(_isConnected ? Icons.update_rounded : Icons.wifi_off_rounded, size: 19, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isConnected ? '$_medicineCount of $_totalCompartments compartments filled' : 'Offline - using demo data',
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompartmentItem({required String compartment, required bool? present, required int? distance}) {
    final bool filled = present ?? false;
    final bool known = present != null;
    return Column(
      children: [
        Icon(known && filled ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 36, color: known && filled ? Colors.white : Colors.white70),
        const SizedBox(height: 8),
        Text(known ? (filled ? 'Filled' : 'Empty') : '--', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 3),
        Text('$compartment · ${known ? '$distance mm' : '--'}', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.86))),
      ],
    );
  }

  Widget _buildCareCubeStatusSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1C2C39);

    final String compartmentsSummary = [
      if (_compartment1Present != null) 'Cup 1: ${_compartment1Present! ? 'Filled' : 'Empty'}',
      if (_compartment2Present != null) 'Cup 2: ${_compartment2Present! ? 'Filled' : 'Empty'}',
      if (_compartment3Present != null) 'Cup 3: ${_compartment3Present! ? 'Filled' : 'Empty'}',
      if (_compartment4Present != null) 'Cup 4: ${_compartment4Present! ? 'Filled' : 'Empty'}',
    ].join(' · ');

    final tempStr = _temperature != null ? '${_temperature!.toStringAsFixed(1)}°C' : '--';
    final humStr = _humidity != null ? '${_humidity!.toStringAsFixed(0)}%' : '--';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Care Cube Status', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 14),
        _buildStatusCard(icon: _isConnected ? Icons.check_circle_rounded : Icons.cancel_rounded, title: 'Medicine Status', description: _isConnected ? '$_medicineCount of $_totalCompartments compartments filled.' : 'Box not connected.', iconColour: _isConnected ? const Color(0xFF16796F) : const Color(0xFFB33A3A), backgroundColour: _isConnected ? (isDark ? const Color(0xFF1A2E2A) : const Color(0xFFE6F6F1)) : (isDark ? const Color(0xFF2E1A1A) : const Color(0xFFFFE4E4))),
        const SizedBox(height: 12),
        _buildStatusCard(icon: Icons.thermostat_rounded, title: 'Environment', description: 'Temp: $tempStr · Humidity: $humStr', iconColour: const Color(0xFF2563A6), backgroundColour: isDark ? const Color(0xFF1A212E) : const Color(0xFFEAF3FF)),
        const SizedBox(height: 12),
        _buildStatusCard(icon: Icons.inventory_2_rounded, title: 'Compartments', description: compartmentsSummary.isNotEmpty ? compartmentsSummary : 'Waiting for box data...', iconColour: const Color(0xFF7B5B15), backgroundColour: isDark ? const Color(0xFF2E2A1A) : const Color(0xFFFFF6DD)),
      ],
    );
  }

  Widget _buildStatusCard({required IconData icon, required String title, required String description, required Color iconColour, required Color backgroundColour}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: backgroundColour, borderRadius: BorderRadius.circular(17)), child: Row(children: [Container(width: 46, height: 46, decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.white.withOpacity(0.75), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: iconColour, size: 27)), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1C2C39))), const SizedBox(height: 3), Text(description, style: TextStyle(fontSize: 13, height: 1.35, color: isDark ? Colors.white70 : const Color(0xFF596873)))]))]));
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required String hint, required IconData icon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1C2C39);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)), const SizedBox(height: 8), TextField(controller: controller, style: TextStyle(color: textColor), decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey), prefixIcon: Icon(icon, size: 22, color: isDark ? Colors.white70 : null), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF16796F))), filled: true, fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50))]);
  }
}
