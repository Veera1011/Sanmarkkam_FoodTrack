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
            // Header with Logo and Login
            Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isLargeScreen ? 80 : 24,
                vertical: 20,
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/images/sanmarkkam-logo1.png',
                          height: 50,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'SANMARKKAM',
                          style: TextStyle(
                            fontSize: isLargeScreen ? 24 : 20,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFFDB813),
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFDB813),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isLargeScreen ? 32 : 24,
                          vertical: isLargeScreen ? 16 : 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.login, size: 20),
                      label: const Text(
                        'STAFF LOGIN',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Hero Section
            Container(
              width: double.infinity,
              color: const Color(0xFFFFFBF0),
              padding: EdgeInsets.symmetric(
                horizontal: isLargeScreen ? 120 : 32,
                vertical: isLargeScreen ? 100 : 60,
              ),
              child: Column(
                children: [
                  Text(
                    'Empowering Lives Through\nEducation & Service',
                    style: TextStyle(
                      fontSize: isLargeScreen ? 48 : 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey.shade900,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'A non-profit organization dedicated to empowering students and graduates through free training, job placement, counseling, career guidance, and support for those in need.',
                    style: TextStyle(
                      fontSize: isLargeScreen ? 20 : 16,
                      color: Colors.grey.shade700,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _launchURL,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFDB813),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isLargeScreen ? 48 : 32,
                        vertical: isLargeScreen ? 20 : 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'LEARN MORE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Stats Section
            Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isLargeScreen ? 80 : 24,
                vertical: isLargeScreen ? 80 : 60,
              ),
              child: Column(
                children: [
                  Text(
                    'OUR IMPACT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFDB813),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Wrap(
                    spacing: isLargeScreen ? 80 : 40,
                    runSpacing: 40,
                    alignment: WrapAlignment.center,
                    children: const [
                      _StatBox(number: '2,368', label: 'Counselling\nSessions'),
                      _StatBox(number: '410', label: 'Training\nPrograms'),
                      _StatBox(number: '134', label: 'Job\nPlacements'),
                    ],
                  ),
                ],
              ),
            ),

            // Services Section
            Container(
              color: const Color(0xFFFFFBF0),
              padding: EdgeInsets.symmetric(
                horizontal: isLargeScreen ? 120 : 32,
                vertical: isLargeScreen ? 80 : 60,
              ),
              child: Column(
                children: [
                  Text(
                    'WHAT WE DO',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFDB813),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Our Core Services',
                    style: TextStyle(
                      fontSize: isLargeScreen ? 36 : 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey.shade900,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isLargeScreen ? 60 : 40),
                  _buildServicesGrid(isLargeScreen),
                ],
              ),
            ),

            // Mission Statement
            Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isLargeScreen ? 120 : 32,
                vertical: isLargeScreen ? 80 : 60,
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBF0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'OUR MISSION',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFDB813),
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Building a Better Future',
                    style: TextStyle(
                      fontSize: isLargeScreen ? 36 : 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey.shade900,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'We are committed to creating opportunities for students and graduates through comprehensive support systems. From scholarships and career guidance to essential supplies for those in need, we believe in empowering every individual to reach their full potential.',
                    style: TextStyle(
                      fontSize: isLargeScreen ? 18 : 16,
                      color: Colors.grey.shade700,
                      height: 1.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              color: Colors.grey.shade50,
              padding: EdgeInsets.symmetric(
                horizontal: isLargeScreen ? 80 : 24,
                vertical: 40,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/sanmarkkam-logo1.png',
                        height: 40,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'SANMARKKAM',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFDB813),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
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
                  const SizedBox(height: 16),
                  Text(
                    '© 2025 Sanmarkkam.org • All rights reserved',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
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

  Widget _buildServicesGrid(bool isLargeScreen) {
    return Wrap(
      spacing: isLargeScreen ? 32 : 16,
      runSpacing: isLargeScreen ? 32 : 24,
      alignment: WrapAlignment.center,
      children: const [
        _ServiceCard(
          icon: Icons.school_rounded,
          title: 'Student Counselling',
          description: 'Scholarships, counselling, and admission guidance - all free of cost.',
        ),
        _ServiceCard(
          icon: Icons.work_rounded,
          title: 'Career Guidance',
          description: 'Comprehensive grooming for professionals and graduates.',
        ),
        _ServiceCard(
          icon: Icons.spa_rounded,
          title: 'Healthy Living',
          description: 'Lifestyle camps with meditation and yoga sessions.',
        ),
        _ServiceCard(
          icon: Icons.volunteer_activism_rounded,
          title: 'Support Services',
          description: 'Essential supplies for those who need it most.',
        ),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 600;

    return Container(
      width: isLargeScreen ? 260 : size.width - 64,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFDB813),
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.6,
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
      width: 120,
      child: Column(
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFDB813),
              height: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}