import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

import '../services/mqtt_service.dart';
import '../services/esp32_service.dart';
import '../services/supabase_service.dart';
import '../models/medicine_schedule.dart';
import '../main.dart';

import 'setup_wizard_screen.dart';

class ConnectBoxScreen extends StatefulWidget {
  const ConnectBoxScreen({super.key});

  @override
  State<ConnectBoxScreen> createState() => _ConnectBoxScreenState();
}

class _ConnectBoxScreenState extends State<ConnectBoxScreen> {
  final TextEditingController boxIdController = TextEditingController();
  final MqttService _mqttService = MqttService();
  final Esp32Service _esp32Service = Esp32Service();
  final SupabaseService _supabaseService = SupabaseService();
  
  bool isConnecting = false;
  bool isConnected = false;
  Map<String, dynamic>? boxStatus;

  @override
  void initState() {
    super.initState();
    _loadSavedBoxId();
  }

  Future<void> _loadSavedBoxId() async {
    final prefs = await SharedPreferences.getInstance();
    
    // First try cloud
    String? savedId = await _supabaseService.getBoxIdFromCloud();
    
    // If not in cloud, try local
    savedId ??= prefs.getString('esp32_box_id') ?? '';
    
    // REMOVED: Auto-generation of ID here to prevent "fake" connection state
    
    boxIdController.text = savedId;
    _mqttService.statusStream.listen((data) {
      if (mounted) {
        setState(() {
          boxStatus = data;
          isConnected = true;
        });
      }
    });

    // Auto-connect to MQTT if we have an ID
    if (savedId.isNotEmpty) {
      final success = await _mqttService.connect(savedId);
      if (mounted) setState(() => isConnected = success);
    }
  }

  Future<void> _connectToMqtt() async {
    setState(() {
      isConnecting = true;
    });

    final boxId = boxIdController.text.trim();
    if (boxId.isEmpty) {
      setState(() => isConnecting = false);
      _showError('Please enter a Box ID');
      return;
    }

    final connected = await _mqttService.connect(boxId);

    if (!mounted) return;

    setState(() {
      isConnecting = false;
      isConnected = connected;
    });

    if (connected) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('esp32_box_id', boxId);
      await prefs.setBool('box_connected', true); // Set actual connection flag
      await _supabaseService.saveBoxIdToCloud(boxId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connected Successfully! Alerts are now active.'),
          backgroundColor: Color(0xFF16796F),
        ),
      );
    } else {
      _showError('Could not connect. Please check the Box ID.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showEsp32CodeDialog() {
    final boxId = boxIdController.text.trim().isEmpty ? 'CARE-1234' : boxIdController.text.trim();
    final code = _esp32Service.generateEsp32ArduinoCode([], boxId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ESP32 Arduino Code'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Text(
              code,
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showDemoMessage('Code ready to be copied');
            },
            child: const Text('COPY'),
          ),
        ],
      ),
    );
  }

  void _showDemoMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    boxIdController.dispose();
    _mqttService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5FAF8),
      appBar: AppBar(
        title: const Text(
          'Remote Box Connection',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF16796F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildConnectionHeader(),
            const SizedBox(height: 20),
            _buildConnectionCard(isDark),
            const SizedBox(height: 15),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SetupWizardScreen()),
                );
              },
              icon: const Icon(Icons.auto_fix_high_rounded),
              label: const Text('SETUP NEW BOX (AUTO)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF16796F),
                side: const BorderSide(color: Color(0xFF16796F)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (isConnected) ...[
              const SizedBox(height: 20),
              _buildBoxStatusCard(isDark),
            ],
            const SizedBox(height: 20),
            _buildMqttInfoCard(isDark),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showEsp32CodeDialog,
              icon: const Icon(Icons.code_rounded),
              label: const Text('GENERATE UPDATED ESP32 CODE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF2C3E50) : const Color(0xFF1C2C39),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionHeader() {
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
          Icon(
            isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            size: 42,
            color: Colors.white,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'Remote Linked' : 'Not Linked',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isConnected
                      ? 'Connected via MQTT Broker'
                      : 'Link your box for remote access.',
                  style: const TextStyle(
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

  Widget _buildConnectionCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE3ECE9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Care Cube Box ID',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1C2C39),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Unique ID to identify your box remotely.',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : const Color(0xFF7B898F)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: boxIdController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: 'e.g., CARE-1234',
              hintStyle: TextStyle(color: isDark ? Colors.white24 : null),
              prefixIcon: Icon(Icons.tag_rounded, color: isDark ? Colors.white70 : null),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade400),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF16796F),
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: isConnecting ? null : _connectToMqtt,
              icon: isConnecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.link_rounded),
              label: Text(
                isConnecting ? 'LINKING...' : 'LINK REMOTE BOX',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16796F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoxStatusCard(bool isDark) {
    if (boxStatus == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2E2A) : const Color(0xFFE6F6F1),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFF16796F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Remote Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF135F58),
            ),
          ),
          const SizedBox(height: 12),
          _buildStatusRow('Temperature', '${boxStatus!['temperature']}°C', isDark),
          _buildStatusRow('Humidity', '${boxStatus!['humidity']}%', isDark),
          _buildStatusRow('Battery', '${boxStatus!['battery']}%', isDark),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF596873))),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF135F58))),
        ],
      ),
    );
  }

  Widget _buildMqttInfoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A212E) : const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: isDark ? const Color(0xFF2563A6).withOpacity(0.5) : const Color(0xFF2563A6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.public_rounded, color: Color(0xFF2563A6)),
              const SizedBox(width: 10),
              Text(
                'Remote Access Info',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A3A6B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Parents/Caregivers abroad: Just enter the Box ID above to see live data and receive alerts. No local setup is required for you.',
            style: TextStyle(fontSize: 14, height: 1.6, color: isDark ? Colors.white70 : const Color(0xFF2563A6)),
          ),
        ],
      ),
    );
  }
}
