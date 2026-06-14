import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Services/firebase_service.dart';
import 'doctor_info_widget.dart';
import 'package:nhap/utils/chamber_constants.dart';

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
      Map<String, dynamic> doctorDetails =
          await _firebaseService.getDoctorDetails(widget.userId);
      final altChamber =
          (doctorDetails['Alt Chamber'] as String?)?.trim() ?? '';
      final altPractice = (doctorDetails['Alt Practice'] as List?)
              ?.map((e) => e.toString())
              .where((s) => s.trim().isNotEmpty)
              .toList() ??
          <String>[];

      String departmentName = '';
      final departmentId = doctorDetails['departmentId'] as String? ?? '';
      if (departmentId.isNotEmpty) {
        try {
          departmentName =
              await _firebaseService.getDepartmentName(departmentId);
        } catch (_) {
          departmentName = altPractice.isNotEmpty ? altPractice.first : 'N/A';
        }
      } else if (altPractice.isNotEmpty) {
        departmentName = altPractice.first;
      }

      String hospitalName = altChamber;
      final hospitalId = doctorDetails['hospitalId'] as String? ?? '';
      if (hospitalName.isEmpty && hospitalId.isNotEmpty) {
        try {
          hospitalName = await _firebaseService.getHospitalName(hospitalId);
        } catch (_) {
          hospitalName = kNaChamberName;
        }
      } else if (hospitalName.isEmpty) {
        hospitalName = 'N/A';
      }

      setState(() {
        _doctorDetails = {
          ...doctorDetails,
          'Alt Practice': altPractice,
          'Alt Chamber': altChamber,
        };
        _departmentName = departmentName;
        _hospitalName = hospitalName;
        _isLoading = false;
      });
    } catch (error) {
      print('Error loading doctor details: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load lawyer details. Please check your network.'),
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
      backgroundColor: Colors.black,
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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