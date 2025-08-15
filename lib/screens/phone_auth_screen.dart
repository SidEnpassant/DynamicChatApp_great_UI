import 'package:country_picker/country_picker.dart';
import 'package:dynamichatapp/screens/otp_screen.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import '../services/auth_service.dart';
import '../widgets/custom_textfield.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  Country selectedCountry = Country(
    phoneCode: "91",
    countryCode: "IN",
    e164Sc: 0,
    geographic: true,
    level: 1,
    name: "India",
    example: "9876543210",
    displayName: "India",
    displayNameNoCountryCode: "IN",
    e164Key: "",
  );

  void _sendOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');

    final phoneNumber = "+${selectedCountry.phoneCode}$phone";

    if (_phoneController.text.trim().isEmpty) {
      // Show error
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await _authService.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) {
        // Handle auto-verification if needed
      },
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
            child: OtpScreen(verificationId: verificationId),
          ),
        );
      },
      codeAutoRetrievalTimeout: (verificationId) {
        // Handle timeout
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use similar styling as your LoginScreen
      body: Container(
        decoration: BoxDecoration(
          // ... (copy gradient from login_screen.dart)
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                // ... (copy UI structure from login_screen.dart)
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Enter Your Phone Number',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 48),
                    CustomTextField(
                      controller: _phoneController,
                      hintText: 'Enter phone number',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a phone number';
                        }
                        // Basic length check
                        if (value.replaceAll(RegExp(r'\D'), '').length < 7) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                      prefixIcon: Icons.phone,
                      prefixWidget: InkWell(
                        onTap: () {
                          showCountryPicker(
                            context: context,
                            countryListTheme: const CountryListThemeData(
                              bottomSheetHeight: 500,
                            ),
                            onSelect: (value) {
                              setState(() {
                                selectedCountry = value;
                              });
                            },
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                          child: Text(
                            "${selectedCountry.flagEmoji} +${selectedCountry.phoneCode}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendOtp,
                        style: ElevatedButton.styleFrom(
                          // ... your button style from login_screen.dart
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text('Send OTP'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
