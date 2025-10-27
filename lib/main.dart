import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/auth/landing_screen.dart';
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

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Sanmarkkam.org FoodTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.yellow),
        useMaterial3: true,
      ),
      home: authState.when(
        data: (user) {
          print('Auth state changed: user = ${user?.email}');
          // If user is logged in, show dashboard
          // If not logged in, show landing page
          return user != null ? const DashboardScreen() : const LandingScreen();
        },
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