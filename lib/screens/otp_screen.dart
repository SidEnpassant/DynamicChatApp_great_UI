import 'package:dynamichatapp/screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:pinput/pinput.dart';
import '../services/auth_service.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String? email;
  final String? password;
  const OtpScreen({
    super.key,
    required this.verificationId,
    this.email,
    this.password,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  void _verifyOtp() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _otpController.text.trim(),
      );

      UserCredential userCredential;

      if (widget.email != null && widget.password != null) {
        // SIGN-UP FLOW
        userCredential = await _authService.signUpAndLinkPhone(
          email: widget.email!,
          password: widget.password!,
          credential: credential,
        );
      } else {
        // SIGN-IN FLOW
        userCredential = await _authService.signInWithPhoneCredential(
          credential,
        );
      }

      if (userCredential.user != null && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          PageTransition(
            type: PageTransitionType.fade,
            child: const HomeScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Verification Failed: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const Text(
                    'Enter Verification Code',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 48),
                  Pinput(length: 6, controller: _otpController),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyOtp,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Verify'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
