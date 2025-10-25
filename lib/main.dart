import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/auth/login_screen.dart';
import 'screens/home/dashboard_screen.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with web config
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyByUrVnnV0rNyvc1MrFVPcTbIU__DlybzA",
        authDomain: "sanmarkkamfoodtrack-a0da7.firebaseapp.com",
        projectId: "sanmarkkamfoodtrack-a0da7",
        storageBucket: "sanmarkkamfoodtrack-a0da7.firebasestorage.app",
        messagingSenderId: "804207222477",
        appId: "1:804207222477:web:b8722fa014e7d027451384",
        measurementId: "G-KKHGGXY1DS",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Food Inventory Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: authState.when(
        data: (user) => user != null ? const DashboardScreen() : const LoginScreen(),
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) => Scaffold(
          body: Center(child: Text('Error: $error')),
        ),
      ),
    );
  }
}