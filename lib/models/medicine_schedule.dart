class MedicineSchedule {
  final String id;
  final String userId;
  final String medicineName;
  final String compartment;
  final String scheduledTime;
  final String dosage;
  final String notes;
  final bool isActive;
  final bool isTaken;
  final DateTime createdAt;

  MedicineSchedule({
    required this.id,
    required this.userId,
    required this.medicineName,
    required this.compartment,
    required this.scheduledTime,
    required this.dosage,
    this.notes = '',
    this.isActive = true,
    this.isTaken = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get sensorNumber {
    if (compartment.toLowerCase().contains('cup 1') ||
        compartment.toLowerCase().contains('sensor 1') ||
        compartment == '1') return 1;
    if (compartment.toLowerCase().contains('cup 2') ||
        compartment.toLowerCase().contains('sensor 2') ||
        compartment == '2') return 2;
    if (compartment.toLowerCase().contains('cup 3') ||
        compartment.toLowerCase().contains('sensor 3') ||
        compartment == '3') return 3;
    if (compartment.toLowerCase().contains('cup 4') ||
        compartment.toLowerCase().contains('sensor 4') ||
        compartment == '4') return 4;
    return 1;
  }

  factory MedicineSchedule.fromJson(Map<String, dynamic> json) {
    return MedicineSchedule(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      medicineName: json['medicine_name'] ?? '',
      compartment: json['compartment'] ?? '',
      scheduledTime: json['scheduled_time'] ?? '',
      dosage: json['dosage'] ?? '',
      notes: json['notes'] ?? '',
      isActive: json['is_active'] ?? true,
      isTaken: json['is_taken'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
      'user_id': userId,
      'medicine_name': medicineName,
      'compartment': compartment,
      'scheduled_time': scheduledTime,
      'dosage': dosage,
      'notes': notes,
      'is_active': isActive,
      'is_taken': isTaken,
      'created_at': createdAt.toIso8601String(),
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  Map<String, dynamic> toEsp32Json() {
    return {
      'compartment': compartment,
      'scheduled_time': scheduledTime,
      'medicine_name': medicineName,
      'dosage': dosage,
      'active': isActive,
    };
  }
}

class DoseSlot {
  final String label;
  final String time;
  final String compartment;
  final List<MedicineSchedule> medicines;

  DoseSlot({
    required this.label,
    required this.time,
    required this.compartment,
    this.medicines = const [],
  });

  bool get hasMedicines => medicines.isNotEmpty;
  bool get allTaken => medicines.every((m) => m.isTaken);
  int get totalDoses => medicines.length;
}
