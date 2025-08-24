import 'package:dynamichatapp/core/config/OneSignalAppCredentials.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/config/firebase_options.dart';
import 'features/auth/auth_gate.dart';
import 'shared/services/auth_service.dart';
import 'shared/services/notification_service.dart';
import 'shared/services/e2ee_service.dart';
import 'core/theme/theme.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().initialize();

  initOneSignal();

  // Initialize E2EE service
  final e2eeService = E2EEService();
  // Note: E2EE will be initialized when user logs in, not at app startup
  // This is because we need an authenticated user to generate keys

  runApp(const MyApp());
}

void initOneSignal() {
  const String oneSignalAppId = OnesignalappCredentials.OneSignalId;
  OneSignal.initialize(oneSignalAppId);

  OneSignal.Notifications.requestPermission(true);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<AuthService>(
      create: (_) => AuthService(),
      child: MaterialApp(
        title: 'Flutter Chat App',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const AuthGate(),
      ),
    );
  }
}
