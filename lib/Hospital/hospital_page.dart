import 'package:flutter/material.dart';
import 'package:nhap/Hospital/Widgets/custom_nav_bar.dart';
import 'package:nhap/Hospital/specialty_details.dart';
import '../Services/firebase_service.dart';
import '../try.dart';
import 'Widgets/calender_page.dart';
import 'hospital_service_screen.dart';

class HospitalPage extends StatefulWidget {
  final String hospitalId;
  final bool isReferral;
  final Function? selectHealthFacility;

  const HospitalPage({
    super.key,
    required this.hospitalId,
    required this.isReferral,
    this.selectHealthFacility,
  });

  @override
  _HospitalPageState createState() => _HospitalPageState();
}

class _HospitalPageState extends State<HospitalPage>
    with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  Map<String, String> _hospitalDetails = {'hospitalName': '', 'logo': ''};

  late AnimationController _textAnimationController;
  late Animation<double> _textFadeAnimation;

  @override
  void initState() {
    super.initState();
    _textAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _textFadeAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _textAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _loadHospitalData();
  }

  Future<void> _loadHospitalData() async {
    try {
      Map<String, String> hospitalDetails =
      await _firebaseService.getHospitalDetails(widget.hospitalId);
      setState(() {
        _hospitalDetails = hospitalDetails;
      });
    } catch (error) {
      print('Error fetching hospital data: $error');
    }
  }

  @override
  void dispose() {
    _textAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _hospitalDetails['hospitalName'] ?? 'Loading ..',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.grey[900],  // Dark grey app bar
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[900]!, Colors.black],  // Dark grey to black gradient
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
          child: Column(
            children: [
              const Text(
                'Welcome',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,  // White text for contrast
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CardButton(
                      title: 'Get A Lawyer',
                      icon: Icons.person,
                      gradient: LinearGradient(
                        colors: [Colors.grey[800]!, Colors.grey[600]!],  // Grey gradient
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SpecialtyDetails(
                              hospitalId: widget.hospitalId,
                              isReferral: widget.isReferral,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Flexible(
                          child: CardButton(
                            title: 'Chamber Events',
                            icon: Icons.medical_services,
                            gradient: LinearGradient(
                              colors: [Colors.grey[800]!, Colors.grey[600]!],  // Grey gradient
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          HospitalServiceScreen(hospitalId: widget.hospitalId, isReferral: widget.isReferral)));
                            },
                          ),
                        ),
                        const SizedBox(width: 20),
                        Flexible(
                          child: CardButton(
                            title: 'Chamber Activities',
                            icon: Icons.calendar_today,
                            gradient: LinearGradient(
                              colors: [Colors.grey[800]!, Colors.grey[600]!],  // Grey gradient
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          CalenderPage(hospitalId: widget.hospitalId, isReferral: widget.isReferral)));
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: widget.isReferral
          ? Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FadeTransition(
            opacity: _textFadeAnimation,
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Text(
                "Tap Here To Add Hospital",
                style: TextStyle(
                  color: Colors.white,  // White text for visibility
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          FloatingActionButton(
            onPressed: () {
              String selectedHospitalName = _hospitalDetails['hospitalName'] ?? 'Loading Hospital..';

              Navigator.pop(context, selectedHospitalName);
              Navigator.pop(context, selectedHospitalName);

              Future.delayed(Duration(milliseconds: 300), () {
                if (widget.selectHealthFacility != null) {
                  widget.selectHealthFacility!(selectedHospitalName);
                }
              });
            },
            child: Icon(Icons.add, color: Colors.black),  // Black icon
            backgroundColor: Colors.white,  // White button
          ),
        ],
      )
          : null,
      bottomNavigationBar: widget.isReferral ? null : CustomBottomNavBarHospital(hospitalId: widget.hospitalId),
    );
  }
}

class CardButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const CardButton({
    super.key,
    required this.title,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool isPhysicians = title == 'Get A Lawyer';

    return Card(
      elevation: 12,
      shadowColor: Colors.black.withOpacity(0.4),  // Darker shadow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: isPhysicians
              ? MediaQuery.of(context).size.width * 0.7
              : MediaQuery.of(context).size.width * 0.4,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),  // Dark shadow
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: isPhysicians
                ? _buildHorizontalLayout()
                : _buildVerticalLayout(),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalLayout() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),  // Subtle white overlay
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            size: 30,
            color: Colors.white,  // White icon
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,  // White text
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap to explore',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[300],  // Light grey text
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey[300],  // Light grey icon
          size: 22,
        ),
      ],
    );
  }

  Widget _buildVerticalLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),  // Subtle white overlay
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 30,
            color: Colors.white,  // White icon
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,  // White text
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Tap',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[300],  // Light grey text
          ),
        ),
      ],
    );
  }
}