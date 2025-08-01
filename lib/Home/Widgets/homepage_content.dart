import 'package:flutter/material.dart';
import 'package:nhap/Home/Widgets/speech_bubble.dart';
import 'doctors_row_item.dart';
import 'organization_list_view.dart';
import 'search_bar1.dart';

class HomePageContent extends StatefulWidget {
  const HomePageContent({Key? key}) : super(key: key);

  @override
  _HomePageContentState createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.grey[900]!, Colors.black],  // Dark grey to black gradient
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 80.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SearchBar1(),
                    SpeechBubble(
                      onPressed: () {
                        print("See Doctor now! tapped");
                      },
                      textStyle: const TextStyle(
                        fontSize: 15.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,  // Changed to white for contrast
                      ),
                    ),
                    DoctorsRowItem(),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: OrganizationListView(showSearchBar: false, isReferral: false),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}