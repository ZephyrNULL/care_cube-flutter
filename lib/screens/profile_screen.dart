import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String fullName = '';
  String email = '';
  String phone = '';
  String dateOfBirth = '';
  String gender = '';
  String bloodGroup = '';
  String weight = '';
  String height = '';
  String address = '';

  String allergies = '';
  String conditions = '';

  String caregiverName = '';
  String relationship = '';
  String caregiverPhone = '';
  String caregiverEmail = '';

  String emergencyName = '';
  String emergencyPhone = '';
  String hospital = '';

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final SharedPreferences prefs =
        await SharedPreferences.getInstance();

    final user = supabase.auth.currentUser;
    final supabaseEmail = user?.email ?? '';

    if (!mounted) return;

    setState(() {
      fullName = prefs.getString('fullName') ?? prefs.getString('userName') ?? '';
      email = supabaseEmail.isNotEmpty ? supabaseEmail : (prefs.getString('email') ?? '');
      phone = prefs.getString('phone') ?? '';
      dateOfBirth = prefs.getString('dob') ?? '';
      gender = prefs.getString('gender') ?? '';
      bloodGroup = prefs.getString('bloodGroup') ?? '';
      weight = prefs.getString('weight') ?? '';
      height = prefs.getString('height') ?? '';
      address = prefs.getString('address') ?? '';

      allergies = prefs.getString('allergies') ?? '';
      conditions = prefs.getString('conditions') ?? '';

      caregiverName = prefs.getString('caregiverName') ?? '';
      relationship = prefs.getString('relationship') ?? '';
      caregiverPhone = prefs.getString('caregiverPhone') ?? '';
      caregiverEmail = prefs.getString('caregiverEmail') ?? '';

      emergencyName = prefs.getString('emergencyName') ?? '';
      emergencyPhone = prefs.getString('emergencyPhone') ?? '';
      hospital = prefs.getString('hospital') ?? '';

      isLoading = false;
    });
  }

  Future<void> openEditProfile() async {
    final bool? profileSaved =
        await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const EditProfileScreen(),
      ),
    );

    if (profileSaved == true) {
      await loadProfile();
    }
  }

  String displayValue(String value) {
    if (value.trim().isEmpty) {
      return 'Not added';
    }

    return value;
  }

  String get profileName {
    if (fullName.trim().isEmpty) {
      return 'Create your profile';
    }

    return fullName;
  }

  String get profileEmail {
    if (email.trim().isEmpty) {
      return 'Add your personal details';
    }

    return email;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAF8),
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF16796F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF16796F),
              ),
            )
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: loadProfile,
                color: const Color(0xFF16796F),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    18,
                    16,
                    30,
                  ),
                  children: [
                    buildProfileHeader(),

                    const SizedBox(height: 22),

                    const SectionTitle(
                      title: 'Personal Information',
                    ),

                    const SizedBox(height: 12),

                    buildInformationCard(
                      children: [
                        buildInformationRow(
                          icon: Icons.person_outline_rounded,
                          label: 'Full Name',
                          value: displayValue(fullName),
                        ),
                        const ProfileDivider(),
                        buildInformationRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: displayValue(email),
                        ),
                        const ProfileDivider(),
                        buildInformationRow(
                          icon: Icons.phone_outlined,
                          label: 'Phone Number',
                          value: displayValue(phone),
                        ),
                        const ProfileDivider(),
                        buildInformationRow(
                          icon: Icons.calendar_month_outlined,
                          label: 'Date of Birth',
                          value: displayValue(dateOfBirth),
                        ),
                        const ProfileDivider(),
                        buildInformationRow(
                          icon: Icons.wc_rounded,
                          label: 'Gender',
                          value: displayValue(gender),
                        ),
                        const ProfileDivider(),
                        buildInformationRow(
                          icon: Icons.bloodtype_outlined,
                          label: 'Blood Group',
                          value: displayValue(bloodGroup),
                        ),
                        const ProfileDivider(),
                        buildInformationRow(
                          icon: Icons.monitor_weight_outlined,
                          label: 'Weight',
                          value: weight.trim().isEmpty
                              ? 'Not added'
                              : '$weight kg',
                        ),
                        const ProfileDivider(),
                        buildInformationRow(
                          icon: Icons.height_rounded,
                          label: 'Height',
                          value: height.trim().isEmpty
                              ? 'Not added'
                              : '$height cm',
                        ),
                        const ProfileDivider(),
                        buildInformationRow(
                          icon: Icons.home_outlined,
                          label: 'Address',
                          value: displayValue(address),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    const SectionTitle(
                      title: 'Health Information',
                    ),

                    const SizedBox(height: 12),

                    buildInformationCard(
                      children: [
                        buildInformationRow(
                          icon: Icons.warning_amber_rounded,
                          label: 'Allergies',
                          value: displayValue(allergies),
                        ),
                        const ProfileDivider(),
                        buildInformationRow(
                          icon: Icons.medical_information_outlined,
                          label: 'Medical Conditions',
                          value: displayValue(conditions),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    const SectionTitle(
                      title: 'Caregiver Details',
                    ),

                    const SizedBox(height: 12),

                    buildInformationCard(
                      children: [
                        buildInformationRow(
                          icon: Icons.favorite_outline_rounded,
                          label: 'Caregiver Name',
                          value: displayValue(caregiverName),
                        ),
                        const ProfileDivider(),
                        buildInformationRow(
                          icon: Icons.people_outline_rounded,
                          label: 'Relationship',
                          value: displayValue(relationship),
                        ),
                        const ProfileDivider(),
                        buildInformationRow(
                          icon: Icons.call_outlined,
                          label: 'Caregiver Phone',
                          value: displayValue(caregiverPhone),
                        ),
                        const ProfileDivider(),
                        buildInformationRow(
                          icon: Icons.alternate_email_rounded,
                          label: 'Caregiver Email',
                          value: displayValue(caregiverEmail),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    const SectionTitle(
                      title: 'Emergency Information',
                    ),

                    const SizedBox(height: 12),

                    buildInformationCard(
                      children: [
                        buildInformationRow(
                          icon: Icons.contact_emergency_outlined,
                          label: 'Emergency Contact Name',
                          value: displayValue(emergencyName),
                        ),
                        const ProfileDivider(),
                        buildInformationRow(
                          icon: Icons.phone_in_talk_outlined,
                          label: 'Emergency Contact Phone',
                          value: displayValue(emergencyPhone),
                        ),
                        const ProfileDivider(),
                        buildInformationRow(
                          icon: Icons.local_hospital_outlined,
                          label: 'Preferred Hospital',
                          value: displayValue(hospital),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    const SectionTitle(
                      title: 'Care Cube Information',
                    ),

                    const SizedBox(height: 12),

                    buildCareCubeCard(),

                    const SizedBox(height: 22),

                    const SectionTitle(
                      title: 'Account',
                    ),

                    const SizedBox(height: 12),

                    buildMenuCard(),

                    const SizedBox(height: 22),

                    SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: showLogoutDialog,
                        icon: const Icon(
                          Icons.logout_rounded,
                        ),
                        label: const Text(
                          'LOG OUT',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB33A3A),
                          backgroundColor: const Color(0xFFFFF6F6),
                          side: const BorderSide(
                            color: Color(0xFFE8B7B7),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Care Cube • Version 1.0.0',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF7B898F),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF16796F),
            Color(0xFF2F9C8F),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3816796F),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: const Color(0x38FFFFFF),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 58,
                  color: Colors.white,
                ),
              ),
              Positioned(
                right: -2,
                bottom: 2,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1D5FA7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    size: 19,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            profileName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            profileEmail,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFE7F5F2),
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton.icon(
              onPressed: openEditProfile,
              icon: const Icon(
                Icons.edit_outlined,
                size: 19,
              ),
              label: const Text(
                'EDIT PROFILE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF16796F),
                elevation: 0,
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

  Widget buildInformationCard({
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: const Color(0xFFE3ECE9),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget buildInformationRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F6F1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF16796F),
              size: 23,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7B898F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C2C39),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCareCubeCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE3ECE9),
        ),
      ),
      child: const Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.inventory_2_rounded,
                size: 32,
                color: Color(0xFF16796F),
              ),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Care Cube',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Connect your medicine box to view real-time information.',
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          Text(
            'ESP32 connection available via Connect Box screen.',
            style: TextStyle(
              color: Color(0xFF16796F),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMenuCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: const Color(0xFFE3ECE9),
        ),
      ),
      child: Column(
        children: [
          buildMenuItem(
            icon: Icons.lock_outline_rounded,
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: () {
              _showChangePasswordDialog();
            },
          ),
          const ProfileDivider(),
          buildMenuItem(
            icon: Icons.notifications_none_rounded,
            title: 'Notification Settings',
            subtitle: 'Manage medicine reminders and alerts',
            onTap: () {
              showDemoMessage(
                'Notification settings will be connected later.',
              );
            },
          ),
          const ProfileDivider(),
          buildMenuItem(
            icon: Icons.info_outline_rounded,
            title: 'About Care Cube',
            subtitle: 'Smart medicine reminder system',
            onTap: showAboutDialog,
          ),
        ],
      ),
    );
  }

  Widget buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 14,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF16796F),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF7B898F),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF8D999E),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final emailController = TextEditingController(
      text: supabase.auth.currentUser?.email ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'A password reset link will be sent to your email.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isNotEmpty) {
                  try {
                    await supabase.auth.resetPasswordForEmail(email);
                    if (!mounted) return;
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Password reset email sent to $email'),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16796F),
                foregroundColor: Colors.white,
              ),
              child: const Text('SEND RESET LINK'),
            ),
          ],
        );
      },
    );
  }

  void showDemoMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void showAboutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('About Care Cube'),
          content: const Text(
            'Care Cube is a smart medicine reminder and monitoring system '
                'designed to support patients and caregivers.\n\n'
                'Powered by Supabase Authentication.\n'
                'ESP32 integration for real-time medicine scheduling.\n\n'
                'Version 1.0.0',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }

  void showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Log out?'),
          content: const Text(
            'Are you sure you want to log out?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                try {
                  await supabase.auth.signOut();
                } catch (e) {
                  // Silently handle
                }

                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('isLoggedIn', false);

                if (!mounted) return;

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginScreen(),
                  ),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB33A3A),
                foregroundColor: Colors.white,
              ),
              child: const Text('LOG OUT'),
            ),
          ],
        );
      },
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;

  const SectionTitle({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1C2C39),
      ),
    );
  }
}

class ProfileDivider extends StatelessWidget {
  const ProfileDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 72),
      child: Divider(height: 1),
    );
  }
}
