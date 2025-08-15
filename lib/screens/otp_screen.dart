import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import '../services/auth_service.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String? email; // Make email optional
  final String? password; // Make password optional
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

  // void _verifyOtp() async {
  //   setState(() {
  //     _isLoading = true;
  //   });

  //   try {
  //     final credential = PhoneAuthProvider.credential(
  //       verificationId: widget.verificationId,
  //       smsCode: _otpController.text.trim(),
  //     );
  //     await _authService.signInWithCredential(credential);
  //     // AuthGate will handle navigation
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text("Failed to verify OTP: ${e.toString()}")),
  //     );
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         _isLoading = false;
  //       });
  //     }
  //   }
  // }

  void _verifyOtp() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _otpController.text.trim(),
      );

      // Check if this is a sign-up or sign-in flow
      if (widget.email != null && widget.password != null) {
        // SIGN-UP FLOW: Create user and link phone
        await _authService.signUpAndLinkPhone(
          email: widget.email!,
          password: widget.password!,
          credential: credential,
        );
      } else {
        // SIGN-IN FLOW: Just sign in with phone
        await _authService.signInWithPhoneCredential(credential);
      }
      // AuthGate will handle navigation to HomeScreen
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
        // ... (copy gradient from login_screen.dart)
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
                  Pinput(
                    length: 6,
                    controller: _otpController,
                    // You can customize the theme to match your app
                  ),
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
