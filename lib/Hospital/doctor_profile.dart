import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Services/firebase_service.dart';
import 'doctor_info_widget.dart';

class DoctorProfileScreen extends StatefulWidget {
  final String userId;
  final bool isReferral;

  DoctorProfileScreen({required this.isReferral, required this.userId});

  @override
  _DoctorProfileScreenState createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  Map<String, dynamic> _doctorDetails = {};
  String _departmentName = '';
  String _hospitalName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDoctorDetails();
  }

  Future<void> _loadDoctorDetails() async {
    try {
      Map<String, dynamic> doctorDetails = await _firebaseService.getDoctorDetails(widget.userId);
      String departmentName = await _firebaseService.getDepartmentName(doctorDetails['departmentId']);
      String hospitalName = await _firebaseService.getHospitalName(doctorDetails['hospitalId']);

      setState(() {
        _doctorDetails = doctorDetails;
        _departmentName = departmentName;
        _hospitalName = hospitalName;
        _isLoading = false;
      });
    } catch (error) {
      print('Error loading doctor details: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load doctor details. Please check your network.'),
          backgroundColor: Colors.grey[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            "${_doctorDetails['Title'] ?? ''} ${_doctorDetails['Lname'] ?? ''}",
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,  // White text for contrast
            ),
          ),
        ),
        backgroundColor: Colors.grey[900],  // Dark grey app bar
        elevation: 0,
      ),
      backgroundColor: Colors.black,  // Black background
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),  // White progress indicator
        ),
      )
          : DoctorInfoWidget(
        doctorDetails: {
          ..._doctorDetails,
          'User ID': widget.userId,
          'Hospital ID': _doctorDetails['hospitalId'],
        },
        hospitalName: _hospitalName,
        departmentName: _departmentName,
        hospitalId: _doctorDetails['hospitalId'],
        departmentId: _doctorDetails['departmentId'] ?? '',
        onCall: _makePhoneCall,
        isReferral: widget.isReferral,
      ),
    );
  }
}