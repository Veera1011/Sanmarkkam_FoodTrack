import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  Future<void> _launchURL() async {
    final Uri url = Uri.parse('https://www.sanmarkkam.org');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {}
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 700;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF6),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ✅ Header
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isLargeScreen ? 80 : 24,
                vertical: 18,
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
                          height: 48,
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD84E),
                        foregroundColor: Colors.black87,
                        elevation: 3,
                        padding: EdgeInsets.symmetric(
                          horizontal: isLargeScreen ? 30 : 20,
                          vertical: isLargeScreen ? 14 : 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.login_rounded, size: 20),
                      label: Text(
                        'STAFF LOGIN',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ✅ Hero Section
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFFBE3), Color(0xFFFFF7C0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isLargeScreen ? 120 : 32,
                vertical: isLargeScreen ? 100 : 60,
              ),
              child: Column(
                children: [
                  Text(
                    'Empowering Lives Through\nEducation & Service',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: isLargeScreen ? 46 : 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'A non-profit organization dedicated to empowering students and graduates through free training, job placement, counseling, career guidance, and essential support.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: isLargeScreen ? 18 : 15,
                      color: Colors.grey.shade700,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _launchURL,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD84E),
                      foregroundColor: Colors.black87,
                      elevation: 2,
                      padding: EdgeInsets.symmetric(
                        horizontal: isLargeScreen ? 50 : 32,
                        vertical: isLargeScreen ? 20 : 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'LEARN MORE',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ✅ Stats Section
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
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFFC400),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Wrap(
                    spacing: isLargeScreen ? 100 : 50,
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

            // ✅ Services Section
            Container(
              color: const Color(0xFFFFFBE8),
              padding: EdgeInsets.symmetric(
                horizontal: isLargeScreen ? 120 : 32,
                vertical: isLargeScreen ? 80 : 60,
              ),
              child: Column(
                children: [
                  Text(
                    'WHAT WE DO',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFFC400),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Our Core Services',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: isLargeScreen ? 36 : 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 50),
                  _buildServicesGrid(isLargeScreen),
                ],
              ),
            ),

            // ✅ Mission Section
            Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isLargeScreen ? 120 : 32,
                vertical: isLargeScreen ? 80 : 60,
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9E2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'OUR MISSION',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFFC400),
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Building a Better Future',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: isLargeScreen ? 36 : 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'We are committed to creating opportunities for students and graduates through scholarships, guidance, and essential resources to empower every individual.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: isLargeScreen ? 18 : 16,
                      color: Colors.grey.shade700,
                      height: 1.8,
                    ),
                  ),
                ],
              ),
            ),

            // ✅ Footer
            Container(
              color: const Color(0xFFFFFBE3),
              padding: EdgeInsets.symmetric(
                horizontal: isLargeScreen ? 80 : 24,
                vertical: 40,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/sanmarkkam-logo1.png',
                          height: 40),
                      const SizedBox(width: 12),
                      Text(
                        'SANMARKKAM',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFFFC400),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _launchURL,
                    child: Text(
                      'www.sanmarkkam.org',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        color: const Color(0xFFFFB700),
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '© 2025 Sanmarkkam.org • All rights reserved',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: Colors.grey.shade700,
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
      runSpacing: 24,
      alignment: WrapAlignment.center,
      children: const [
        _ServiceCard(
          icon: Icons.school_rounded,
          title: 'Student Counselling',
          description:
          'Scholarships, counselling, and admission guidance — all free of cost.',
        ),
        _ServiceCard(
          icon: Icons.work_rounded,
          title: 'Career Guidance',
          description:
          'Comprehensive grooming and professional development programs.',
        ),
        _ServiceCard(
          icon: Icons.spa_rounded,
          title: 'Healthy Living',
          description:
          'Lifestyle and wellness programs including yoga and meditation.',
        ),
        _ServiceCard(
          icon: Icons.volunteer_activism_rounded,
          title: 'Support Services',
          description: 'Essential resources for those in need of assistance.',
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 260,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFFFC400), size: 36),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.nunito(
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
  const _StatBox({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          Text(
            number,
            style: GoogleFonts.poppins(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFFFC400),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
