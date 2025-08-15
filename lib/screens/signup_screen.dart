// lib/screens/signup_screen.dart
import 'package:country_picker/country_picker.dart';
import 'package:dynamichatapp/screens/otp_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:page_transition/page_transition.dart';
import '../widgets/custom_textfield.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  Country selectedCountry = CountryParser.parseCountryCode('US');

  void _sendOtpForSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final fullPhoneNumber = "+${selectedCountry.phoneCode}$phone";

    if (email.isEmpty || password.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all fields.")));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: fullPhoneNumber,
      verificationCompleted: (credential) {},
      verificationFailed: (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Verification Failed: ${e.message}")),
        );
      },
      codeSent: (verificationId, resendToken) {
        setState(() {
          _isLoading = false;
        });
        Navigator.push(
          context,
          PageTransition(
            type: PageTransitionType.rightToLeftWithFade,
            // Pass all data to the OTP screen for final account creation
            child: OtpScreen(
              verificationId: verificationId,
              email: email,
              password: password,
            ),
          ),
        );
      },
      codeAutoRetrievalTimeout: (verificationId) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    // Build a UI similar to your LoginScreen to collect email, password, and phone
    // For brevity, a simplified structure is shown here.
    // You should copy the beautiful UI from your login_screen.dart
    return Scaffold(
      appBar: AppBar(title: const Text("Create Account")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Create Your Account",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            CustomTextField(controller: _emailController, hintText: "Email"),
            const SizedBox(height: 10),
            CustomTextField(
              controller: _passwordController,
              hintText: "Password",
              obscureText: true,
            ),
            const SizedBox(height: 10),
            CustomTextField(
              controller: _phoneController,
              hintText: 'Phone number',
              prefixIcon: Icons.phone,
              // ... Add your country picker prefix widget here ...
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendOtpForSignUp,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text("Verify Phone & Sign Up"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
