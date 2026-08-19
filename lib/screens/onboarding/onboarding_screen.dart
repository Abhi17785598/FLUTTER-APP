import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/auth_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {

  final PageController _pageController = PageController();

  int currentIndex = 0;

  final List<Map<String, dynamic>> slides = [
    {
      "title": "Find Your Dream Home",
      "subtitle":
          "Browse thousands of verified properties across India",
      "icon": Icons.home_work_outlined,
      "color": const Color(0xFF5B50E8),
    },
    {
      "title": "Post Property Easily",
      "subtitle":
          "Upload photos, details and connect with buyers instantly",
      "icon": Icons.add_business_outlined,
      "color": const Color(0xFF10B981),
    },
    {
      "title": "Schedule Site Visits",
      "subtitle":
          "Connect with owners and visit your future property",
      "icon": Icons.calendar_month_outlined,
      "color": const Color(0xFFF97316),
    },
  ];

Future<void> finishOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding_done', true);

  if (!mounted) return;

  context.read<AuthProvider>().enableNavigation();
}

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Column(
          children: [

            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: finishOnboarding,
                child: const Text(
                  "Skip",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: slides.length,

                onPageChanged: (value) {
                  setState(() {
                    currentIndex = value;
                  });
                },

                itemBuilder: (context, index) {

                  final slide = slides[index];

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),

                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                        Container(
                          height: 180,
                          width: 180,

                          decoration: BoxDecoration(
                            color: slide["color"].withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),

                          child: Icon(
                            slide["icon"],
                            size: 90,
                            color: slide["color"],
                          ),
                        ),

                        const SizedBox(height: 50),

                        Text(
                          slide["title"],
                          textAlign: TextAlign.center,

                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 20),

                        Text(
                          slide["subtitle"],
                          textAlign: TextAlign.center,

                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,

              children: List.generate(
                slides.length,
                (index) {

                  final bool isActive = currentIndex == index;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),

                    margin: const EdgeInsets.symmetric(horizontal: 4),

                    height: 8,
                    width: isActive ? 28 : 8,

                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF5B50E8)
                          : Colors.grey.shade300,

                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 40),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),

              child: SizedBox(
                width: double.infinity,
                height: 56,

                child: ElevatedButton(

                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B50E8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),

                  onPressed: () {

                    if (currentIndex == slides.length - 1) {

                      finishOnboarding();

                    } else {

                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },

                  child: Text(
                    currentIndex == slides.length - 1
                        ? "Get Started"
                        : "Next",

                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}