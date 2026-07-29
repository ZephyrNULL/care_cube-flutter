import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:care_cube/main.dart';
import 'package:care_cube/screens/home_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String userName;
  final String email;

  const VerifyEmailScreen({
    super.key,
    required this.userName,
    required this.email,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool isResending = false;

  Future<void> resendVerificationEmail() async {
    setState(() {
      isResending = true;
    });

    try {
      await supabase.auth.signInWithOtp(
        email: widget.email,
      );
    } catch (e) {
      // Silently handle
    }

    if (!mounted) return;

    setState(() {
      isResending = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Verification email sent again to ${widget.email}',
        ),
      ),
    );
  }

  Future<void> continueAfterVerification() async {
    final session = supabase.auth.currentSession;

    if (session != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userName', widget.userName);
      await prefs.setString('email', widget.email);
      await prefs.setString('userId', supabase.auth.currentUser?.id ?? '');

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify your email first, or sign in again.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5FAF8),
        elevation: 0,
        foregroundColor: const Color(0xFF1C2C39),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 25),

              Container(
                width: 130,
                height: 130,
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F5EF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  size: 72,
                  color: Color(0xFF16796F),
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                'Check Your Email',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C2C39),
                ),
              ),

              const SizedBox(height: 14),

              const Text(
                'We have sent a verification OTP to',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  color: Color(0xFF596873),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                widget.email,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF16796F),
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Check your email inbox for the 6-digit OTP code. '
                    'Enter it in the verification screen, then return and press the button below.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Color(0xFF596873),
                ),
              ),

              const SizedBox(height: 35),

              SizedBox(
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: continueAfterVerification,
                  icon: const Icon(Icons.verified_rounded),
                  label: const Text(
                    'I HAVE VERIFIED MY EMAIL',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16796F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                height: 55,
                child: OutlinedButton.icon(
                  onPressed:
                      isResending ? null : resendVerificationEmail,
                  icon: isResending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(
                    isResending
                        ? 'SENDING...'
                        : 'RESEND VERIFICATION EMAIL',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF16796F),
                    side: const BorderSide(
                      color: Color(0xFF16796F),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F6F1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFF16796F),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Supabase email OTP is active. '
                            'An OTP code will be sent to your email for verification.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: Color(0xFF135F58),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
