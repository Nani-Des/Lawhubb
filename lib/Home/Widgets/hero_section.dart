import 'package:flutter/material.dart';

class HeroSection extends StatefulWidget {
  final String userName;
  final bool isLoggedIn;

  const HeroSection({
    super.key,
    required this.userName,
    required this.isLoggedIn,
  });

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection> {

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.isLoggedIn
                                ? 'Your legal journey continues here'
                                : 'Join thousands of legal professionals',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[850],
                        border: Border.all(
                          color: Colors.grey[800]!,
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.balance,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Search functionality coming soon'),
                        backgroundColor: Colors.grey[800],
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Search lawyers, chambers...',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.tune_rounded,
                          color: Colors.grey[600],
                          size: 18,
                        ),
                      ],
                    ),
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
