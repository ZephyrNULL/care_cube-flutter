import 'package:flutter/material.dart';
import 'package:flutter_system_ringtones/flutter_system_ringtones.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

class SoundSelectionScreen extends StatefulWidget {
  const SoundSelectionScreen({super.key});

  @override
  State<SoundSelectionScreen> createState() => _SoundSelectionScreenState();
}

class _SoundSelectionScreenState extends State<SoundSelectionScreen> {
  List<Ringtone> _ringtones = [];
  bool _isLoading = true;
  String? _selectedUri;
  String? _previewingUri;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadSounds();
  }

  @override
  void dispose() {
    _notificationService.stopPreview();
    super.dispose();
  }

  Future<void> _loadSounds() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUri = prefs.getString('alarm_sound_uri');
    
    try {
      final alarms = await FlutterSystemRingtones.getAlarmSounds();
      final ringtones = await FlutterSystemRingtones.getRingtoneSounds();
      
      final allSounds = [...alarms, ...ringtones];
      final seenUris = <String>{};
      final uniqueSounds = <Ringtone>[];
      
      for (var sound in allSounds) {
        if (!seenUris.contains(sound.uri)) {
          seenUris.add(sound.uri);
          uniqueSounds.add(sound);
        }
      }

      if (mounted) {
        setState(() {
          _ringtones = uniqueSounds;
          _selectedUri = savedUri;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _togglePreview(String uri) async {
    if (_previewingUri == uri) {
      await _notificationService.stopPreview();
      setState(() {
        _previewingUri = null;
      });
    } else {
      // Stop any existing preview first
      await _notificationService.stopPreview();
      setState(() {
        _previewingUri = uri;
      });
      await _notificationService.previewSound(uri);
    }
  }

  Future<void> _saveAndExit() async {
    await _notificationService.stopPreview();
    
    if (_selectedUri == null) {
      Navigator.pop(context);
      return;
    }

    final ringtone = _ringtones.firstWhere((r) => r.uri == _selectedUri);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alarm_sound_uri', ringtone.uri);
    await prefs.setString('alarm_sound_name', ringtone.title);
    await prefs.setString('alarm_sound', 'custom');
    
    if (mounted) {
      Navigator.pop(context, ringtone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5FAF8),
      appBar: AppBar(
        title: const Text('Phone Alarm Sounds'),
        backgroundColor: const Color(0xFF16796F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF16796F)))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF16796F).withOpacity(0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.music_note_rounded, color: Color(0xFF16796F), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tap the play button to preview. Tap it again to stop the sound.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : const Color(0xFF135F58),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _ringtones.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
                    itemBuilder: (context, index) {
                      final ringtone = _ringtones[index];
                      final isSelected = _selectedUri == ringtone.uri;
                      final isPreviewing = _previewingUri == ringtone.uri;
                      
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Radio<String>(
                          value: ringtone.uri,
                          groupValue: _selectedUri,
                          activeColor: const Color(0xFF16796F),
                          onChanged: (value) {
                            setState(() {
                              _selectedUri = value;
                            });
                            if (value != null) _togglePreview(value);
                          },
                        ),
                        title: Text(
                          ringtone.title,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isDark ? Colors.white : const Color(0xFF1C2C39),
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            isPreviewing ? Icons.stop_circle_rounded : Icons.play_circle_outline_rounded,
                            color: const Color(0xFF16796F),
                            size: 32,
                          ),
                          onPressed: () => _togglePreview(ringtone.uri),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedUri = ringtone.uri;
                          });
                          _togglePreview(ringtone.uri);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _saveAndExit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16796F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'SET AS REMINDER SOUND',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
