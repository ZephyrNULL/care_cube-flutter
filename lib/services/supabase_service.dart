import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/medicine_schedule.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;

  // Realtime Stream for Schedules
  Stream<List<MedicineSchedule>> get schedulesStream {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      print('Supabase Stream: No user logged in, returning empty stream');
      // Return a stream that emits an empty list but stays open to potential rebuilds
      return Stream.value(<MedicineSchedule>[]);
    }

    print('Supabase Stream: Starting listen for user $userId');
    
    return _supabase
        .from('schedules')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('scheduled_time', ascending: true)
        .map((data) {
          print('Supabase Stream: Received ${data.length} items for $userId');
          return data.map((json) => MedicineSchedule.fromJson(json)).toList();
        })
        .handleError((error) {
          print('Supabase Stream Error: $error');
          return <MedicineSchedule>[];
        });
  }

  Future<List<MedicineSchedule>> getSchedules() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('schedules')
          .select()
          .eq('user_id', userId)
          .order('scheduled_time', ascending: true);

      return (response as List)
          .map((json) => MedicineSchedule.fromJson(json))
          .toList();
    } catch (e) {
      print('Supabase Fetch Error: $e');
      return [];
    }
  }

  Future<bool> addSchedule(MedicineSchedule schedule) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final Map<String, dynamic> data = {
        'user_id': userId,
        'medicine_name': schedule.medicineName,
        'compartment': schedule.compartment,
        'scheduled_time': schedule.scheduledTime,
        'dosage': schedule.dosage,
        'notes': schedule.notes,
        'is_active': true,
        'is_taken': false,
      };

      print('Supabase Add: Inserting $data');
      await _supabase.from('schedules').insert(data);
      print('Supabase Add: Success');
      return true;
    } catch (e) {
      print('Supabase Insert Error: $e');
      return false;
    }
  }

  Future<bool> deleteSchedule(String id) async {
    try {
      print('Supabase Delete: Removing ID $id');
      await _supabase.from('schedules').delete().eq('id', id);
      print('Supabase Delete: Success');
      return true;
    } catch (e) {
      print('Supabase Delete Error: $e');
      return false;
    }
  }

  Future<bool> updateScheduleTaken(String id, bool taken) async {
    try {
      await _supabase
          .from('schedules')
          .update({'is_taken': taken})
          .eq('id', id);
      return true;
    } catch (e) {
      print('Supabase Update Taken Error: $e');
      return false;
    }
  }

  Future<bool> saveBoxIdToCloud(String boxId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase.from('profiles').upsert({
        'id': userId,
        'box_id': boxId,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Supabase Profile Upsert Error: $e');
      return false;
    }
  }

  Future<String?> getBoxIdFromCloud() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final data = await _supabase
          .from('profiles')
          .select('box_id')
          .eq('id', userId)
          .maybeSingle();
      
      return data?['box_id'] as String?;
    } catch (e) {
      return null;
    }
  }
}
