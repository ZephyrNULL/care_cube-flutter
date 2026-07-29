import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isConfiguring = false;
  int _step = 1;

  void _sendToBox() async {
    setState(() => _isConfiguring = true);

    try {
      // The ESP32 is at 192.168.4.1 when in setup mode
      final response = await http.post(
        Uri.parse('http://192.168.4.1/setup'),
        body: jsonEncode({
          'ssid': _ssidController.text.trim(),
          'pass': _passwordController.text,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_wifi_ssid', _ssidController.text);
        
        if (mounted) {
          setState(() => _step = 3);
          Future.delayed(const Duration(seconds: 3), () => Navigator.pop(context));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not reach Care Cube. Are you connected to its Wi-Fi?')),
        );
      }
    } finally {
      if (mounted) setState(() => _isConfiguring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAF8),
      appBar: AppBar(
        title: const Text('Easy Setup Wizard'),
        backgroundColor: const Color(0xFF16796F),
        foregroundColor: Colors.white,
      ),
      body: Stepper(
        currentStep: _step - 1,
        onStepContinue: () {
          if (_step == 1) setState(() => _step = 2);
          else if (_step == 2) _sendToBox();
        },
        onStepCancel: () => setState(() => _step = 1),
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 20),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: details.onStepContinue,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16796F), foregroundColor: Colors.white),
              child: Text(_step == 2 ? 'FINISH SETUP' : 'NEXT STEP'),
            ),
          ),
        ),
        steps: [
          Step(
            title: const Text('Connect to Box'),
            content: const Text(
              '1. Go to your phone Wi-Fi settings.\n'
              '2. Connect to the network named "CareCube_Setup".\n'
              '3. Come back here once connected.',
            ),
            isActive: _step >= 1,
          ),
          Step(
            title: const Text('Home Wi-Fi Details'),
            content: Column(
              children: [
                const Text('Enter your home Wi-Fi name and password so the box can connect to the internet.'),
                const SizedBox(height: 15),
                TextField(
                  controller: _ssidController,
                  decoration: const InputDecoration(labelText: 'Wi-Fi Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                ),
              ],
            ),
            isActive: _step >= 2,
          ),
          Step(
            title: const Text('All Done!'),
            content: const Text('Success! Your Care Cube is rebooting and will link to your app in a moment.'),
            isActive: _step >= 3,
          ),
        ],
      ),
    );
  }
}
