import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  Future<void> _launchURL() async {
    final Uri url = Uri.parse('https://www.sanmarkkam.org');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      // Handle error silently or show message
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Section
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFFDB813),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    Image.asset(
                      'assets/images/sanmarkkam-logo1.png',
                      height: isLargeScreen ? 140 : 100,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'SANMARKKAM',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Empowering Lives Through Education & Service',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),

            // Mission Section
            Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isLargeScreen ? 80 : 24,
                vertical: 60,
              ),
              child: Column(
                children: [
                  const Text(
                    'OUR MISSION',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFDB813),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'A non-profit organization empowering students and graduates through free training, job placement, counseling, career guidance, scholarships, and support for those in need.',
                    style: TextStyle(
                      fontSize: isLargeScreen ? 20 : 17,
                      color: Colors.grey.shade800,
                      height: 1.7,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Services Section
            Container(
              color: Colors.grey.shade50,
              padding: EdgeInsets.symmetric(
                horizontal: isLargeScreen ? 80 : 24,
                vertical: 60,
              ),
              child: Column(
                children: [
                  const Text(
                    'WHAT WE DO',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFDB813),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _ServiceItem(
                    icon: Icons.school_outlined,
                    title: 'Student Counselling',
                    description: 'Scholarships, counselling, and admission guidance - all free of cost for deserving students.',
                  ),
                  _ServiceItem(
                    icon: Icons.work_outline,
                    title: 'Career Guidance',
                    description: 'Comprehensive grooming for professionals, graduates, and students to achieve career success.',
                  ),
                  _ServiceItem(
                    icon: Icons.spa_outlined,
                    title: 'Healthy Living',
                    description: 'Lifestyle camps with meditation and yoga sessions for self-discovery and wellness.',
                  ),
                  _ServiceItem(
                    icon: Icons.volunteer_activism_outlined,
                    title: 'Support for the Needy',
                    description: 'Grocery kits, food, clothing, and essential supplies for those who need it most.',
                  ),
                ],
              ),
            ),

            // Stats Section
            Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isLargeScreen ? 80 : 24,
                vertical: 60,
              ),
              child: Column(
                children: [
                  const Text(
                    'OUR IMPACT',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFDB813),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Wrap(
                    spacing: 40,
                    runSpacing: 40,
                    alignment: WrapAlignment.center,
                    children: const [
                      _StatBox(number: '2,368', label: 'Counselling Sessions'),
                      _StatBox(number: '410', label: 'Training Programs'),
                      _StatBox(number: '134', label: 'Job Placements'),
                    ],
                  ),
                ],
              ),
            ),

            // CTA Section
            Container(
              color: const Color(0xFFFDB813),
              padding: EdgeInsets.symmetric(
                horizontal: isLargeScreen ? 80 : 24,
                vertical: 80,
              ),
              child: Column(
                children: [
                  const Text(
                    'FOOD TRACKING SYSTEM',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Access Our Internal Management System',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () {
                      // Use push instead of pushReplacement
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFFDB813),
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_forward, size: 20),
                        SizedBox(width: 12),
                        Text(
                          'LOGIN',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'For authorized staff members only',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              color: Colors.grey.shade900,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _launchURL,
                    child: const Text(
                      'www.sanmarkkam.org',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFFFDB813),
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '© 2025 Sanmarkkam.org • All rights reserved',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _ServiceItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFDB813),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade700,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String number;
  final String label;

  const _StatBox({
    required this.number,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFDF113),
              height: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}