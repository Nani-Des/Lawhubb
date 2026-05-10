import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nhap/news_stand.dart';
import '../Home/Widgets/organization_list_view.dart';
import '../Library/library_page.dart';

class GeneralHospitalPage extends StatelessWidget {
  // Function to check if the user is an active doctor
  Future<bool> _isActiveDoctor() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final userDoc =
    await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();

    if (!userDoc.exists) return false;

    final data = userDoc.data()!;
    final bool isDoctor = data['Role'] == true;
    final bool isActive = data['Status'] == true;

    return isDoctor && isActive;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isActiveDoctor(),
      builder: (context, snapshot) {
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.grey],
              ),
            ),
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 200.0,
                  floating: false,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: EdgeInsets.only(left: 56, bottom: 16),
                    title: Container(
                      padding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Chambers',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          shadows: [
                            Shadow(
                              blurRadius: 6.0,
                              color: Colors.black54,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/Images/General Hospital Page.jpg',
                          fit: BoxFit.cover,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.2),
                                Colors.black.withOpacity(0.6),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  backgroundColor: Colors.teal,
                  elevation: 6.0,
                  automaticallyImplyLeading: false,
                  leadingWidth: 280,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 2),
                        SizedBox(
                          width: 100,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                            ),
                            icon: Icon(Icons.library_books,
                                color: Colors.black, size: 18),
                            label: Flexible(
                              child: Text(
                                "Library",
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LibraryPage(),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(width: 6),
                        SizedBox(
                          width: 100,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.orangeAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                            ),
                            icon: Icon(Icons.newspaper,
                                color: Colors.black, size: 18),
                            label: Flexible(
                              child: Text(
                                "News",
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const NewsStandPage(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: OrganizationListView(
                        showSearchBar: true,
                        isReferral: false,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Custom widget for popup menu items
class _MenuItem extends StatefulWidget {
  final IconData icon;
  final String label;

  const _MenuItem({required this.icon, required this.label});

  @override
  __MenuItemState createState() => __MenuItemState();
}

class __MenuItemState extends State<_MenuItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: Colors.teal,
                size: 20.0,
              ),
              SizedBox(width: 12.0),
              Text(
                widget.label,
                style: TextStyle(
                  color: Colors.teal.shade900,
                  fontSize: 16.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
