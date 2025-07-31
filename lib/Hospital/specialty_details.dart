import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nhap/Hospital/shift_schedule_Table.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../Services/firebase_service.dart';
import 'Widgets/custom_nav_bar.dart';
import 'doctor_profile.dart';

class SpecialtyDetails extends StatefulWidget {
  final String hospitalId;
  final bool isReferral;
  final String? initialDepartmentId;
  final Function? selectHealthFacility;

  SpecialtyDetails({
    required this.hospitalId,
    this.initialDepartmentId,
    required this.isReferral,
    this.selectHealthFacility,
  });

  @override
  _SpecialtyDetailsState createState() => _SpecialtyDetailsState();
}

class _SpecialtyDetailsState extends State<SpecialtyDetails> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _animation;
  final FirebaseService _firebaseService = FirebaseService();

  Map<String, String> _hospitalDetails = {'hospitalName': '', 'logo': ''};
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _doctors = [];

  bool _isLoading = true;
  bool _isDoctorsLoading = false;
  String? _selectedDepartmentId;
  bool _isOffline = false;

  final GlobalKey _servicekey = GlobalKey();
  final GlobalKey _specialtycalendarKey = GlobalKey();

  late AnimationController _textAnimationController;
  late Animation<double> _textFadeAnimation;

  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkConnectivity();
    _loadCachedState();
  }

  void _initializeAnimations() {
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

    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _animation = ColorTween(
      begin: Colors.grey[800],
      end: Colors.grey[600],
    ).animate(_controller);

    _progressAnimationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(_progressAnimationController);
  }

  Future<void> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = connectivityResult.contains(ConnectivityResult.none);
    });

    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (mounted) {
        setState(() {
          _isOffline = results.contains(ConnectivityResult.none);
        });
      }
    });
  }

  Future<void> _loadCachedState() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenWalkthrough = prefs.getBool('hasSeenEmergencyWalkthrough_${widget.hospitalId}') ?? false;

    final cachedHospitalDetails = prefs.getString('hospital-details-${widget.hospitalId}');
    final cachedDepartments = prefs.getString('Practices-${widget.hospitalId}');
    final cachedSelectedDepartmentId = prefs.getString('selected-Practice-${widget.hospitalId}');

    setState(() {
      if (cachedHospitalDetails != null) {
        _hospitalDetails = Map<String, String>.from(jsonDecode(cachedHospitalDetails));
      }
      if (cachedDepartments != null) {
        _departments = List<Map<String, dynamic>>.from(jsonDecode(cachedDepartments));
      }
      _selectedDepartmentId = cachedSelectedDepartmentId ?? widget.initialDepartmentId;
      _isLoading = false;
    });

    if (_selectedDepartmentId != null) {
      final cachedDoctors = prefs.getString('Lawyers-${widget.hospitalId}-$_selectedDepartmentId');
      if (cachedDoctors != null) {
        setState(() {
          _doctors = List<Map<String, dynamic>>.from(jsonDecode(cachedDoctors));
        });
      }
    }

    if (!_isOffline) {
      await _loadHospitalData();
    } else if (_departments.isNotEmpty && _selectedDepartmentId != null) {
      await _loadDoctorsForDepartment(_selectedDepartmentId!);
    }

    if (!hasSeenWalkthrough && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ShowCaseWidget.of(context)?.startShowCase([_servicekey, _specialtycalendarKey]);
        prefs.setBool('hasSeenEmergencyWalkthrough_${widget.hospitalId}', true);
      });
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.setString('hospital-details-${widget.hospitalId}', jsonEncode(_hospitalDetails));
      await prefs.setString('departments-${widget.hospitalId}', jsonEncode(_departments));
      if (_selectedDepartmentId != null) {
        await prefs.setString('selected-department-${widget.hospitalId}', _selectedDepartmentId!);
      }
      if (_doctors.isNotEmpty && _selectedDepartmentId != null) {
        await prefs.setString('Lawyers-${widget.hospitalId}-$_selectedDepartmentId', jsonEncode(_doctors));
      }
    } catch (e) {
      debugPrint('Error saving state: $e');
    }
  }

  Future<void> _loadHospitalData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      Map<String, String> hospitalDetails = await _firebaseService.getHospitalDetails(widget.hospitalId);
      List<Map<String, dynamic>> departments = await _firebaseService.getDepartmentsForHospital(widget.hospitalId);

      setState(() {
        _hospitalDetails = hospitalDetails;
        _departments = departments;
        _isLoading = false;

        if (_selectedDepartmentId == null && _departments.isNotEmpty) {
          _selectedDepartmentId = _departments.first['Practice ID'];
        }
        if (_selectedDepartmentId != null &&
            _departments.any((dept) => dept['Practice ID'] == _selectedDepartmentId)) {
          _loadDoctorsForDepartment(_selectedDepartmentId!);
        }
      });
      await _saveState();
    } catch (error) {
      debugPrint('Error fetching Chamber data: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDoctorsForDepartment(String departmentId) async {
    setState(() {
      _isDoctorsLoading = true;
      _selectedDepartmentId = departmentId;
    });

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'Lawyers-${widget.hospitalId}-$departmentId';

    if (_isOffline) {
      final cachedDoctors = prefs.getString(cacheKey);
      if (cachedDoctors != null) {
        setState(() {
          _doctors = List<Map<String, dynamic>>.from(jsonDecode(cachedDoctors));
          _isDoctorsLoading = false;
        });
        await _saveState();
        return;
      }
    }

    try {
      List<Map<String, dynamic>> doctors = await _firebaseService.getDoctorsForDepartment(widget.hospitalId, departmentId);
      setState(() {
        _doctors = doctors;
        _isDoctorsLoading = false;
      });
      await prefs.setString(cacheKey, jsonEncode(doctors));
      await _saveState();
    } catch (error) {
      debugPrint('Error fetching doctors: $error');
      final cachedDoctors = prefs.getString(cacheKey);
      if (cachedDoctors != null) {
        setState(() {
          _doctors = List<Map<String, dynamic>>.from(jsonDecode(cachedDoctors));
        });
      }
      setState(() {
        _isDoctorsLoading = false;
      });
      await _saveState();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _textAnimationController.dispose();
    _progressAnimationController.dispose();
    super.dispose();
  }

  Widget _buildSophisticatedProgressIndicator() {
    return AnimatedBuilder(
      animation: _progressAnimationController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: _progressAnimation.value,
                strokeWidth: 8,
                backgroundColor: Colors.grey.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.grey[900]!, Colors.grey[700]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${(_progressAnimation.value * 100).toInt()}%',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,  // Black background
      appBar: AppBar(
        backgroundColor: Colors.grey[900],  // Dark grey app bar
        elevation: 0,
        title: Text(
          _hospitalDetails['hospitalName']?.isNotEmpty == true
              ? _hospitalDetails['hospitalName']!
              : 'Loading ...',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSophisticatedProgressIndicator(),
            SizedBox(height: 16),
            Text(
              "Loading Chamber Data...",
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ],
        ),
      )
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.grey[800],
                      child: _hospitalDetails['logo']?.isNotEmpty == true
                          ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: _hospitalDetails['logo']!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                          errorWidget: (context, url, error) => Icon(Icons.error, color: Colors.white),
                        ),
                      )
                          : Icon(Icons.local_hospital, color: Colors.white),
                    ),
                  ],
                ),

              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: MediaQuery.of(context).size.width * 0.30,
                  padding: const EdgeInsets.all(8.0),
                  child: ListView.builder(
                    itemCount: _departments.length,
                    itemBuilder: (context, index) {
                      String departmentId = _departments[index]['Practice ID'];
                      return Column(
                        children: [
                          GestureDetector(
                            onTap: () => _loadDoctorsForDepartment(departmentId),
                            child: _specialtyLabel(
                              _departments[index]['Practice Name'],
                              departmentId == _selectedDepartmentId,
                            ),
                          ),
                          SizedBox(height: 30),
                        ],
                      );
                    },
                  ),
                ),
                Expanded(
                  flex: 7,
                  child: _isDoctorsLoading
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSophisticatedProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          "Loading Doctors...",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  )
                      : _doctors.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 30, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No Lawyers available',
                          style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    itemCount: _doctors.length,
                    itemBuilder: (context, index) {
                      var doctor = _doctors[index];
                      return _doctorDetailCard(
                        doctor['userId'],
                        doctor['name'],
                        doctor['experience'],
                        doctor['userPic'],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
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
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          FloatingActionButton(
            onPressed: () {
              String selectedHospitalName =
              _hospitalDetails['hospitalName']?.isNotEmpty == true
                  ? _hospitalDetails['hospitalName']!
                  : 'Unknown Hospital';

              Navigator.pop(context, selectedHospitalName);
              Navigator.pop(context, selectedHospitalName);
              Navigator.pop(context, selectedHospitalName);

              Future.delayed(Duration(milliseconds: 300), () {
                if (widget.selectHealthFacility != null) {
                  widget.selectHealthFacility!(selectedHospitalName);
                }
              });
            },
            child: Icon(Icons.add, color: Colors.black),
            backgroundColor: Colors.white,
          ),
        ],
      )
          : null,
      bottomNavigationBar:
      widget.isReferral ? null : CustomBottomNavBarHospital(hospitalId: widget.hospitalId),
    );
  }

  Widget _specialtyLabel(String title, bool isSelected) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.grey[800] : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : Colors.grey[300],
        ),
      ),
    );
  }

  Widget _doctorDetailCard(String userId, String name, String experience, String userPic) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DoctorProfileScreen(
              userId: userId,
              isReferral: widget.isReferral,
            ),
          ),
        );
      },
      child: Card(
        elevation: 4,
        margin: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        color: Colors.grey[900],  // Dark grey card
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey[800],
            child: userPic.isNotEmpty
                ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: userPic,
                fit: BoxFit.cover,
                placeholder: (context, url) => CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                errorWidget: (context, url, error) => Icon(Icons.person, color: Colors.white),
              ),
            )
                : Icon(Icons.person, color: Colors.white),
          ),
          title: Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            experience,
            style: TextStyle(fontSize: 10, color: Colors.grey[400]),
          ),
        ),
      ),
    );
  }
}