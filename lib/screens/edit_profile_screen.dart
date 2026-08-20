import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabaseService = SupabaseService();

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController allergiesController = TextEditingController();
  final TextEditingController conditionsController = TextEditingController();

  final TextEditingController caregiverNameController = TextEditingController();
  final TextEditingController relationshipController = TextEditingController();
  final TextEditingController caregiverPhoneController = TextEditingController();
  final TextEditingController caregiverEmailController = TextEditingController();

  final TextEditingController emergencyNameController = TextEditingController();
  final TextEditingController emergencyPhoneController = TextEditingController();
  final TextEditingController hospitalController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  String gender = "Female";
  String bloodGroup = "O+";

  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load from local storage first for immediate availability
      setState(() {
        fullNameController.text = prefs.getString("fullName") ?? prefs.getString("userName") ?? "";
        emailController.text = prefs.getString("email") ?? "";
        phoneController.text = prefs.getString("phone") ?? "";
        dobController.text = prefs.getString("dob") ?? "";
        weightController.text = prefs.getString("weight") ?? "";
        heightController.text = prefs.getString("height") ?? "";
        allergiesController.text = prefs.getString("allergies") ?? "";
        conditionsController.text = prefs.getString("conditions") ?? "";
        caregiverNameController.text = prefs.getString("caregiverName") ?? "";
        relationshipController.text = prefs.getString("relationship") ?? "";
        caregiverPhoneController.text = prefs.getString("caregiverPhone") ?? "";
        caregiverEmailController.text = prefs.getString("caregiverEmail") ?? "";
        emergencyNameController.text = prefs.getString("emergencyName") ?? "";
        emergencyPhoneController.text = prefs.getString("emergencyPhone") ?? "";
        hospitalController.text = prefs.getString("hospital") ?? "";
        addressController.text = prefs.getString("address") ?? "";

        gender = prefs.getString("gender") ?? "Female";
        bloodGroup = prefs.getString("bloodGroup") ?? "O+";
        
        isLoading = false;
      });

      // Then try cloud fetch to update with latest
      final cloudProfile = await _supabaseService.getProfile().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      
      final user = Supabase.instance.client.auth.currentUser;

      if (!mounted) return;

      if (cloudProfile != null) {
        setState(() {
          if (cloudProfile['full_name'] != null) fullNameController.text = cloudProfile['full_name'];
          if (user?.email != null) emailController.text = user!.email!;
          if (cloudProfile['phone'] != null) phoneController.text = cloudProfile['phone'];
          if (cloudProfile['dob'] != null) dobController.text = cloudProfile['dob'];
          if (cloudProfile['weight'] != null) weightController.text = cloudProfile['weight'];
          if (cloudProfile['height'] != null) heightController.text = cloudProfile['height'];
          if (cloudProfile['allergies'] != null) allergiesController.text = cloudProfile['allergies'];
          if (cloudProfile['conditions'] != null) conditionsController.text = cloudProfile['conditions'];
          if (cloudProfile['caregiver_name'] != null) caregiverNameController.text = cloudProfile['caregiver_name'];
          if (cloudProfile['relationship'] != null) relationshipController.text = cloudProfile['relationship'];
          if (cloudProfile['caregiver_phone'] != null) caregiverPhoneController.text = cloudProfile['caregiver_phone'];
          if (cloudProfile['caregiver_email'] != null) caregiverEmailController.text = cloudProfile['caregiver_email'];
          if (cloudProfile['emergency_name'] != null) emergencyNameController.text = cloudProfile['emergency_name'];
          if (cloudProfile['emergency_phone'] != null) emergencyPhoneController.text = cloudProfile['emergency_phone'];
          if (cloudProfile['hospital'] != null) hospitalController.text = cloudProfile['hospital'];
          if (cloudProfile['address'] != null) addressController.text = cloudProfile['address'];
          if (cloudProfile['gender'] != null) gender = cloudProfile['gender'];
          if (cloudProfile['blood_group'] != null) bloodGroup = cloudProfile['blood_group'];
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isSaving = true;
    });

    final profileData = {
      'phone': phoneController.text.trim(),
      'dob': dobController.text.trim(),
      'gender': gender,
      'blood_group': bloodGroup,
      'weight': weightController.text.trim(),
      'height': heightController.text.trim(),
      'address': addressController.text.trim(),
      'allergies': allergiesController.text.trim(),
      'conditions': conditionsController.text.trim(),
      'caregiver_name': caregiverNameController.text.trim(),
      'relationship': relationshipController.text.trim(),
      'caregiver_phone': caregiverPhoneController.text.trim(),
      'caregiver_email': caregiverEmailController.text.trim(),
      'emergency_name': emergencyNameController.text.trim(),
      'emergency_phone': emergencyPhoneController.text.trim(),
      'hospital': hospitalController.text.trim(),
    };

    try {
      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("phone", phoneController.text.trim());
      await prefs.setString("dob", dobController.text.trim());
      await prefs.setString("gender", gender);
      await prefs.setString("bloodGroup", bloodGroup);
      await prefs.setString("weight", weightController.text.trim());
      await prefs.setString("height", heightController.text.trim());
      await prefs.setString("allergies", allergiesController.text.trim());
      await prefs.setString("conditions", conditionsController.text.trim());
      await prefs.setString("caregiverName", caregiverNameController.text.trim());
      await prefs.setString("relationship", relationshipController.text.trim());
      await prefs.setString("caregiverPhone", caregiverPhoneController.text.trim());
      await prefs.setString("caregiverEmail", caregiverEmailController.text.trim());
      await prefs.setString("emergencyName", emergencyNameController.text.trim());
      await prefs.setString("emergencyPhone", emergencyPhoneController.text.trim());
      await prefs.setString("hospital", hospitalController.text.trim());
      await prefs.setString("address", addressController.text.trim());

      // Try cloud sync
      final cloudSuccess = await _supabaseService.updateProfile(profileData).timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );

      if (mounted) {
        setState(() {
          isSaving = false;
        });

        if (cloudSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Saved Successfully")));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Saved locally. Could not sync with cloud."),
            backgroundColor: Colors.orange,
          ));
        }
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        dobController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    dobController.dispose();
    weightController.dispose();
    heightController.dispose();
    allergiesController.dispose();
    conditionsController.dispose();
    caregiverNameController.dispose();
    relationshipController.dispose();
    caregiverPhoneController.dispose();
    caregiverEmailController.dispose();
    emergencyNameController.dispose();
    emergencyPhoneController.dispose();
    hospitalController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    bool isRequired = false,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        validator: (value) {
          if (isRequired && (value == null || value.trim().isEmpty)) {
            return "Please enter $label";
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          filled: readOnly && onTap == null,
          fillColor: readOnly && onTap == null ? Colors.grey.shade100 : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAF8),
      appBar: AppBar(
        title: const Text("Edit Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF16796F),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF16796F)))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text("Personal Information", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF16796F))),
                  const SizedBox(height: 15),
                  buildTextField(controller: fullNameController, label: "Full Name", icon: Icons.person_outline, readOnly: true),
                  buildTextField(controller: emailController, label: "Email Address", icon: Icons.email_outlined, readOnly: true),
                  buildTextField(controller: phoneController, label: "Phone Number", icon: Icons.phone_outlined, keyboard: TextInputType.phone, isRequired: true),
                  buildTextField(controller: dobController, label: "Date of Birth", icon: Icons.calendar_month_outlined, readOnly: true, onTap: pickDate),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String>(
                      value: gender,
                      decoration: InputDecoration(labelText: "Gender", prefixIcon: const Icon(Icons.wc), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                      items: const [
                        DropdownMenuItem(value: "Female", child: Text("Female")),
                        DropdownMenuItem(value: "Male", child: Text("Male")),
                        DropdownMenuItem(value: "Other", child: Text("Other")),
                      ],
                      onChanged: (value) { if (value != null) setState(() { gender = value; }); },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String>(
                      value: bloodGroup,
                      decoration: InputDecoration(labelText: "Blood Group", prefixIcon: const Icon(Icons.bloodtype_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                      items: const ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (value) { if (value != null) setState(() { bloodGroup = value; }); },
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(child: buildTextField(controller: weightController, label: "Weight (kg)", icon: Icons.monitor_weight_outlined, keyboard: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(child: buildTextField(controller: heightController, label: "Height (cm)", icon: Icons.height, keyboard: TextInputType.number)),
                    ],
                  ),
                  buildTextField(controller: addressController, label: "Address", icon: Icons.home_outlined, maxLines: 2),
                  const SizedBox(height: 10),
                  const Divider(),
                  const SizedBox(height: 15),
                  const Text("Health Information", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF16796F))),
                  const SizedBox(height: 15),
                  buildTextField(controller: allergiesController, label: "Allergies", icon: Icons.warning_amber_outlined, maxLines: 3),
                  buildTextField(controller: conditionsController, label: "Medical Conditions", icon: Icons.medical_information_outlined, maxLines: 3),
                  const SizedBox(height: 10),
                  const Divider(),
                  const SizedBox(height: 15),
                  const Text("Caregiver Information", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF16796F))),
                  const SizedBox(height: 15),
                  buildTextField(controller: caregiverNameController, label: "Caregiver Name", icon: Icons.person_pin_outlined),
                  buildTextField(controller: relationshipController, label: "Relationship", icon: Icons.people_outline),
                  buildTextField(controller: caregiverPhoneController, label: "Caregiver Phone", icon: Icons.call_outlined, keyboard: TextInputType.phone),
                  buildTextField(controller: caregiverEmailController, label: "Caregiver Email", icon: Icons.alternate_email, keyboard: TextInputType.emailAddress),
                  const SizedBox(height: 10),
                  const Divider(),
                  const SizedBox(height: 15),
                  const Text("Emergency Information", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF16796F))),
                  const SizedBox(height: 15),
                  buildTextField(controller: emergencyNameController, label: "Emergency Contact Name", icon: Icons.contact_emergency_outlined),
                  buildTextField(controller: emergencyPhoneController, label: "Emergency Contact Phone", icon: Icons.phone_in_talk_outlined, keyboard: TextInputType.phone),
                  buildTextField(controller: hospitalController, label: "Preferred Hospital", icon: Icons.local_hospital_outlined),
                  const SizedBox(height: 25),
                  SizedBox(
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: isSaving ? null : saveProfile,
                      icon: isSaving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Icon(Icons.save_outlined),
                      label: Text(isSaving ? "SAVING..." : "SAVE PROFILE", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16796F), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
