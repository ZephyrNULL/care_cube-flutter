import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController fullNameController =
  TextEditingController();
  final TextEditingController emailController =
  TextEditingController();
  final TextEditingController phoneController =
  TextEditingController();
  final TextEditingController dobController =
  TextEditingController();
  final TextEditingController weightController =
  TextEditingController();
  final TextEditingController heightController =
  TextEditingController();
  final TextEditingController allergiesController =
  TextEditingController();
  final TextEditingController conditionsController =
  TextEditingController();

  final TextEditingController caregiverNameController =
  TextEditingController();
  final TextEditingController relationshipController =
  TextEditingController();
  final TextEditingController caregiverPhoneController =
  TextEditingController();
  final TextEditingController caregiverEmailController =
  TextEditingController();

  final TextEditingController emergencyNameController =
  TextEditingController();
  final TextEditingController emergencyPhoneController =
  TextEditingController();
  final TextEditingController hospitalController =
  TextEditingController();
  final TextEditingController addressController =
  TextEditingController();

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
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      fullNameController.text =
          prefs.getString("fullName") ?? "";

      emailController.text =
          prefs.getString("email") ?? "";

      phoneController.text =
          prefs.getString("phone") ?? "";

      dobController.text =
          prefs.getString("dob") ?? "";

      weightController.text =
          prefs.getString("weight") ?? "";

      heightController.text =
          prefs.getString("height") ?? "";

      allergiesController.text =
          prefs.getString("allergies") ?? "";

      conditionsController.text =
          prefs.getString("conditions") ?? "";

      caregiverNameController.text =
          prefs.getString("caregiverName") ?? "";

      relationshipController.text =
          prefs.getString("relationship") ?? "";

      caregiverPhoneController.text =
          prefs.getString("caregiverPhone") ?? "";

      caregiverEmailController.text =
          prefs.getString("caregiverEmail") ?? "";

      emergencyNameController.text =
          prefs.getString("emergencyName") ?? "";

      emergencyPhoneController.text =
          prefs.getString("emergencyPhone") ?? "";

      hospitalController.text =
          prefs.getString("hospital") ?? "";

      addressController.text =
          prefs.getString("address") ?? "";

      gender =
          prefs.getString("gender") ?? "Female";

      bloodGroup =
          prefs.getString("bloodGroup") ?? "O+";

      isLoading = false;
    });
  }

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isSaving = true;
    });

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString("fullName", fullNameController.text.trim());
    await prefs.setString("email", emailController.text.trim());
    await prefs.setString("phone", phoneController.text.trim());
    await prefs.setString("dob", dobController.text.trim());
    await prefs.setString("gender", gender);
    await prefs.setString("bloodGroup", bloodGroup);

    await prefs.setString("weight", weightController.text.trim());
    await prefs.setString("height", heightController.text.trim());

    await prefs.setString(
        "allergies", allergiesController.text.trim());

    await prefs.setString(
        "conditions", conditionsController.text.trim());

    await prefs.setString(
        "caregiverName",
        caregiverNameController.text.trim());

    await prefs.setString(
        "relationship",
        relationshipController.text.trim());

    await prefs.setString(
        "caregiverPhone",
        caregiverPhoneController.text.trim());

    await prefs.setString(
        "caregiverEmail",
        caregiverEmailController.text.trim());

    await prefs.setString(
        "emergencyName",
        emergencyNameController.text.trim());

    await prefs.setString(
        "emergencyPhone",
        emergencyPhoneController.text.trim());

    await prefs.setString(
        "hospital",
        hospitalController.text.trim());

    await prefs.setString(
        "address",
        addressController.text.trim());

    setState(() {
      isSaving = false;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Profile Saved Successfully"),
      ),
    );

    Navigator.pop(context, true);
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
        dobController.text =
        "${picked.day}/${picked.month}/${picked.year}";
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
          if (value == null || value
              .trim()
              .isEmpty) {
            return "Please enter $label";
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
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
        title: const Text(
          "Edit Profile",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF16796F),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF16796F),
        ),
      )
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF16796F),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white24,
                    child: Icon(
                      Icons.manage_accounts,
                      color: Colors.white,
                      size: 35,
                    ),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Create Your Profile",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          "Enter your personal and health information.",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              "Personal Information",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF16796F),
              ),
            ),

            const SizedBox(height: 15),

            buildTextField(
              controller: fullNameController,
              label: "Full Name",
              icon: Icons.person_outline,
            ),

            buildTextField(
              controller: emailController,
              label: "Email Address",
              icon: Icons.email_outlined,
              keyboard: TextInputType.emailAddress,
            ),

            buildTextField(
              controller: phoneController,
              label: "Phone Number",
              icon: Icons.phone_outlined,
              keyboard: TextInputType.phone,
            ),

            buildTextField(
              controller: dobController,
              label: "Date of Birth",
              icon: Icons.calendar_month_outlined,
              readOnly: true,
              onTap: pickDate,
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<String>(
                initialValue: gender,
                decoration: InputDecoration(
                  labelText: "Gender",
                  prefixIcon: const Icon(Icons.wc),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: "Female",
                    child: Text("Female"),
                  ),
                  DropdownMenuItem(
                    value: "Male",
                    child: Text("Male"),
                  ),
                  DropdownMenuItem(
                    value: "Other",
                    child: Text("Other"),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      gender = value;
                    });
                  }
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<String>(
                initialValue: bloodGroup,
                decoration: InputDecoration(
                  labelText: "Blood Group",
                  prefixIcon:
                  const Icon(Icons.bloodtype_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: "A+",
                    child: Text("A+"),
                  ),
                  DropdownMenuItem(
                    value: "A-",
                    child: Text("A-"),
                  ),
                  DropdownMenuItem(
                    value: "B+",
                    child: Text("B+"),
                  ),
                  DropdownMenuItem(
                    value: "B-",
                    child: Text("B-"),
                  ),
                  DropdownMenuItem(
                    value: "AB+",
                    child: Text("AB+"),
                  ),
                  DropdownMenuItem(
                    value: "AB-",
                    child: Text("AB-"),
                  ),
                  DropdownMenuItem(
                    value: "O+",
                    child: Text("O+"),
                  ),
                  DropdownMenuItem(
                    value: "O-",
                    child: Text("O-"),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      bloodGroup = value;
                    });
                  }
                },
              ),
            ),

            Row(
              children: [
                Expanded(
                  child: buildTextField(
                    controller: weightController,
                    label: "Weight (kg)",
                    icon: Icons.monitor_weight_outlined,
                    keyboard: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: buildTextField(
                    controller: heightController,
                    label: "Height (cm)",
                    icon: Icons.height,
                    keyboard: TextInputType.number,
                  ),
                ),
              ],
            ),

            buildTextField(
              controller: addressController,
              label: "Address",
              icon: Icons.home_outlined,
              maxLines: 2,
            ),

            const SizedBox(height: 10),

            const Divider(),

            const SizedBox(height: 15),

            const Text(
              "Health Information",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF16796F),
              ),
            ),

            const SizedBox(height: 15),

            buildTextField(
              controller: allergiesController,
              label: "Allergies",
              icon: Icons.warning_amber_outlined,
              maxLines: 3,
            ),

            buildTextField(
              controller: conditionsController,
              label: "Medical Conditions",
              icon: Icons.medical_information_outlined,
              maxLines: 3,
            ),

            const SizedBox(height: 10),

            const Divider(),

            const SizedBox(height: 15),

            const Text(
              "Caregiver Information",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF16796F),
              ),
            ),

            const SizedBox(height: 15),

            buildTextField(
              controller: caregiverNameController,
              label: "Caregiver Name",
              icon: Icons.person_pin_outlined,
            ),

            buildTextField(
              controller: relationshipController,
              label: "Relationship",
              icon: Icons.people_outline,
            ),

            buildTextField(
              controller: caregiverPhoneController,
              label: "Caregiver Phone",
              icon: Icons.call_outlined,
              keyboard: TextInputType.phone,
            ),

            buildTextField(
              controller: caregiverEmailController,
              label: "Caregiver Email",
              icon: Icons.alternate_email,
              keyboard: TextInputType.emailAddress,
            ),

            const SizedBox(height: 10),

            const Divider(),

            const SizedBox(height: 15),

            const Text(
              "Emergency Information",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF16796F),
              ),
            ),

            const SizedBox(height: 15),

            buildTextField(
              controller: emergencyNameController,
              label: "Emergency Contact Name",
              icon: Icons.contact_emergency_outlined,
            ),

            buildTextField(
              controller: emergencyPhoneController,
              label: "Emergency Contact Phone",
              icon: Icons.phone_in_talk_outlined,
              keyboard: TextInputType.phone,
            ),

            buildTextField(
              controller: hospitalController,
              label: "Preferred Hospital",
              icon: Icons.local_hospital_outlined,
            ),

            const SizedBox(height: 15),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F3F0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline,
                    color: Color(0xFF16796F),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Your profile is currently saved only on this device. Firebase will be connected later.",
                      style: TextStyle(
                        color: Color(0xFF315A55),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              height: 55,
              child: ElevatedButton.icon(
                onPressed:
                isSaving ? null : saveProfile,
                icon: isSaving
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  isSaving
                      ? "SAVING..."
                      : "SAVE PROFILE",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  const Color(0xFF16796F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}