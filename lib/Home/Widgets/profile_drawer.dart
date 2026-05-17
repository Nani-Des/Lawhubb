import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nhap/l10n/app_localizations.dart';
import 'package:nhap/Appointments/referral_form.dart';
import 'package:nhap/Appointments/Referral%20screens/referral_details_page.dart';
import '../../Auth/auth_screen.dart';
import '../../Auth/lawyer_registration_screen.dart';
import '../../Auth/auth_service.dart';
import '../../main_layout.dart';
import '../../booking_page.dart';
import '../../utils/app_navigation.dart';
import '../../main.dart';
import '../../Settings/blocked_users_page.dart';
import '../home_page.dart';
import 'package:provider/provider.dart';
import 'package:nhap/utils/country_utils.dart';
import 'package:nhap/widgets/searchable_country_sheet.dart';
import 'package:nhap/widgets/profile_avatar.dart';

class ProfileDrawer extends StatefulWidget {
  final AnimationController controller;
  final Animation<Offset> slideAnimation;
  final bool showProfileDrawer;

  const ProfileDrawer({
    required this.controller,
    required this.slideAnimation,
    required this.showProfileDrawer,
    super.key,
  });

  @override
  _ProfileDrawerState createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends State<ProfileDrawer> {
  Future<DocumentSnapshot>? _userDataFuture;
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  bool _isEditing = false;
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  String _editCountryCode = kDefaultCountryCode;

  DocumentSnapshot? _cachedUserData;
  bool _isCacheValid = false;

  @override
  void initState() {
    super.initState();
    _refreshUserData();
  }

  void _refreshUserData() {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    setState(() {
      _isCacheValid = false;
      _userDataFuture = currentUser != null ? _fetchUserData() : null;
    });
  }

  Future<DocumentSnapshot> _fetchUserData() async {
    // Return cached data if valid
    if (_isCacheValid && _cachedUserData != null) {
      return _cachedUserData!;
    }

    // #region agent log
    final logFile = File(
        r'c:\Users\HP\PROJECTS\flutter_projects\lawhubb\Lawhubb\.cursor\debug.log');
    void debugLog(
        String hypothesisId, String message, Map<String, dynamic> data) {
      try {
        final entry = jsonEncode({
              'hypothesisId': hypothesisId,
              'location': 'profile_drawer.dart:_fetchUserData',
              'message': message,
              'data': data,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'sessionId': 'debug-session'
            }) +
            '\n';
        logFile.writeAsStringSync(entry, mode: FileMode.append);
      } catch (_) {}
    }

    // #endregion
    final User? currentUser = FirebaseAuth.instance.currentUser;
    // #region agent log
    debugLog('A', 'Auth check in profile drawer', {
      'userIsNull': currentUser == null,
      'userId': currentUser?.uid ?? 'null'
    });
    // #endregion
    if (currentUser == null) {
      throw Exception('User not logged in');
    }
    // #region agent log
    debugLog('A', 'Before Firestore query profile drawer',
        {'userId': currentUser.uid, 'collection': 'Users'});
    // #endregion
    try {
      final DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUser.uid)
          .get();
      // #region agent log
      debugLog('C', 'Firestore query result profile drawer',
          {'docExists': userDoc.exists, 'userId': currentUser.uid});
      // #endregion
      if (!userDoc.exists || userDoc['Status'] != true) {
        throw Exception('User data is deleted or does not exist');
      }

      // Cache the data
      _cachedUserData = userDoc;
      _isCacheValid = true;

      return userDoc;
    } catch (e) {
      // #region agent log
      debugLog('A', 'Firestore query FAILED profile drawer',
          {'error': e.toString(), 'userId': currentUser.uid});
      // #endregion
      rethrow;
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _updateUserData() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final Map<String, dynamic> userData = {
        'Fname': _firstNameController.text,
        'Lname': _lastNameController.text,
        'Mobile Number': _mobileController.text,
        'Region': _regionController.text,
        'Email': _emailController.text,
        'Country': _editCountryCode.trim().toUpperCase(),
        'CountryRequired': false,
      };
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUser.uid)
          .update(userData);
      setState(() {
        _userDataFuture = _fetchUserData();
        _isEditing = false;
      });
    }
  }

  Future<bool> _requiresRecentLogin(User user) async {
    try {
      await user.delete();
      return false;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return true;
      }
      rethrow;
    }
  }

  Future<void> _deleteUserAccount(BuildContext context) async {
    final localizations = AppLocalizations.of(context);
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations?.noUserLoggedIn ??
              'No user is currently logged in'),
          backgroundColor: Colors.grey[800],
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    bool isDoctor = false;
    try {
      final DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUser.uid)
          .get();
      isDoctor = userDoc.exists && userDoc['Role'] == true;
    } catch (e) {
      print('Error checking user role: $e');
    }

    if (isDoctor && await _requiresRecentLogin(currentUser)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations?.lawyerReauthRequired ??
              'Lawyers must log out and log in again to delete their account'),
          backgroundColor: Colors.grey[800],
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.deleteAccountTitle ?? 'Delete Account',
            style: TextStyle(color: Colors.white)),
        content: Text(
          localizations?.deleteAccountConfirmation ??
              'Are you sure you want to permanently delete your account? This action cannot be undone.',
          style: TextStyle(color: Colors.grey[300]),
        ),
        backgroundColor: Colors.grey[900],
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations?.cancelButton ?? 'Cancel',
                style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(localizations?.deleteButton ?? 'Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmDelete != true) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUser.uid)
          .update({
        'Status': false,
        'Email': null,
      });

      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();

      try {
        await currentUser.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code != 'requires-recent-login') {
          print('Non-critical deletion error: $e');
        }
      }

      Provider.of<UserModel>(context, listen: false).clearUserId();
      await Provider.of<AuthService>(context, listen: false).signOut();

      if (context.mounted) {
        setState(() {
          _userDataFuture = null;
          _imageFile = null;
          _isEditing = false;
        });
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations?.accountDeletedSuccess ??
                'Account deleted successfully. You are now logged out'),
            backgroundColor: Colors.grey[800],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      final String errorMessage = e is FirebaseAuthException
          ? e.message ?? 'Failed to disable account'
          : e.toString();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.grey[800],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _checkAndNavigate(BuildContext context,
      {required bool isReferralForm}) async {
    final localizations = AppLocalizations.of(context);
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      pushAppRoute(context, const AuthScreen());
      return;
    }

    final DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .get();
    final bool isDoctor = userDoc.exists && userDoc['Role'] == true;
    if (!isDoctor) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(localizations?.accessDenied ?? 'Access Denied',
                style: TextStyle(color: Colors.white)),
            content: Text(
              (localizations?.onlyLawyersAccess ??
                      'Only Lawyers can access {form}.')
                  .toString()
                  .replaceFirst(
                      '{form}',
                      isReferralForm
                          ? (localizations?.referralForm ?? 'Referral Form')
                          : (localizations?.referrals ?? 'Referrals')),
              style: TextStyle(color: Colors.grey[300]),
            ),
            backgroundColor: Colors.grey[900],
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(localizations?.okButton ?? 'OK',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
      return;
    }

    pushAppRoute(
      context,
      isReferralForm
          ? const ReferralForm()
          : ReferralDetailsPage(userId: user.uid),
    );
  }

  @override
  void didUpdateWidget(covariant ProfileDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showProfileDrawer && !oldWidget.showProfileDrawer) {
      _refreshUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    // Get bottom nav bar height from MediaQuery - kBottomNavigationBarHeight is typically 56-80px
    // Adding safe area padding for devices with home indicator
    final bottomNavBarHeight = kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom;

    if (!widget.showProfileDrawer) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: widget.slideAnimation,
      child: GestureDetector(
        onVerticalDragEnd: (_) => widget.controller.reverse(),
        child: Container(
          width: double.infinity,
          margin: EdgeInsets.only(bottom: bottomNavBarHeight),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: Colors.grey[900], // Dark grey background
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black54,
                  blurRadius: 12,
                  offset: Offset(0, -6)), // Darker shadow
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Consumer<AuthService>(
                builder:
                    (BuildContext context, AuthService authService, Widget? _) {
                  if (authService.currentUser == null ||
                      _userDataFuture == null) {
                    return const SizedBox.shrink();
                  }

                  return FutureBuilder<DocumentSnapshot>(
                    future: _userDataFuture,
                    builder: (BuildContext context,
                        AsyncSnapshot<DocumentSnapshot> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white), // White progress indicator
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline,
                                  color: Colors.red, size: 40),
                              SizedBox(height: 8),
                              Text(
                                'Error: ${snapshot.error}',
                                style: TextStyle(color: Colors.redAccent),
                                textAlign: TextAlign.center,
                              ),
                              TextButton(
                                onPressed: _refreshUserData,
                                child: Text(localizations?.retry ?? 'Retry',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                      }

                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return const SizedBox.shrink();
                      }

                      final Map<String, dynamic> userData =
                          snapshot.data!.data() as Map<String, dynamic>;
                      final String? userImageUrl =
                          userData['User Pic'] as String?;
                      final String? firstName = userData['Fname'] as String?;
                      final String? lastName = userData['Lname'] as String?;
                      final String? mobileNumber =
                          userData['Mobile Number'] as String?;
                      final String? region = userData['Region'] as String?;
                      final String? email = userData['Email'] as String?;
                      final String countryLine =
                          effectiveCountryCode(userData);

                      if (_isEditing) {
                        _regionController.text = region ?? '';
                        _mobileController.text = mobileNumber ?? '';
                        _emailController.text = email ?? '';
                        _firstNameController.text = firstName ?? '';
                        _lastNameController.text = lastName ?? '';
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  if (_isEditing) {
                                    _updateUserData();
                                  } else {
                                    setState(() {
                                      _isEditing = true;
                                      _editCountryCode =
                                          effectiveCountryCode(userData);
                                    });
                                  }
                                },
                                child: Text(
                                  _isEditing
                                      ? (localizations?.saveButton ?? 'Save')
                                      : (localizations?.editButton ?? 'Edit'),
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: _isEditing ? _pickImage : null,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                ProfileAvatar.circle(
                                  radius: 50,
                                  imageUrl: userImageUrl,
                                  imageFile: _imageFile,
                                  backgroundColor: Colors.grey[800],
                                ),
                                if (_isEditing)
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.edit,
                                        color: Colors.black, size: 16),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(height: 12),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _isEditing
                                ? Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    color: Colors.grey[
                                        850], // Slightly lighter grey card
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        children: [
                                          TextFormField(
                                            controller: _firstNameController,
                                            decoration: InputDecoration(
                                              labelText:
                                                  localizations?.firstName ??
                                                      'First Name',
                                              labelStyle: TextStyle(
                                                  color: Colors.grey[400]),
                                              border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                    color: Colors.grey[700]!),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                    color: Colors.white),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
                                          SizedBox(height: 12),
                                          TextFormField(
                                            controller: _lastNameController,
                                            decoration: InputDecoration(
                                              labelText:
                                                  localizations?.lastName ??
                                                      'Last Name',
                                              labelStyle: TextStyle(
                                                  color: Colors.grey[400]),
                                              border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                    color: Colors.grey[700]!),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                    color: Colors.white),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
                                          SizedBox(height: 12),
                                          InkWell(
                                            onTap: () async {
                                              final code =
                                                  await showSearchableCountryPicker(
                                                context,
                                                title: 'Country',
                                              );
                                              if (code != null && mounted) {
                                                setState(() =>
                                                    _editCountryCode = code);
                                              }
                                            },
                                            child: InputDecorator(
                                              decoration: InputDecoration(
                                                labelText: 'Country',
                                                labelStyle: TextStyle(
                                                    color: Colors.grey[400]),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                  borderSide: BorderSide(
                                                      color: Colors.grey[700]!),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderSide: BorderSide(
                                                      color: Colors.white),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                filled: true,
                                                fillColor: Colors.grey[850],
                                                suffixIcon: const Icon(
                                                  Icons.arrow_drop_down,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                              child: Text(
                                                '${countryNameFromCode(_editCountryCode)} ($_editCountryCode)',
                                                style: const TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ),
                                          ),
                                          SizedBox(height: 12),
                                          TextFormField(
                                            controller: _regionController,
                                            decoration: InputDecoration(
                                              labelText:
                                                  'State / region (local)',
                                              labelStyle: TextStyle(
                                                  color: Colors.grey[400]),
                                              border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                    color: Colors.grey[700]!),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                    color: Colors.white),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
                                          SizedBox(height: 12),
                                          TextFormField(
                                            controller: _mobileController,
                                            decoration: InputDecoration(
                                              labelText:
                                                  localizations?.mobileNumber ??
                                                      'Mobile Number',
                                              labelStyle: TextStyle(
                                                  color: Colors.grey[400]),
                                              border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                    color: Colors.grey[700]!),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                    color: Colors.white),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            keyboardType: TextInputType.phone,
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
                                          SizedBox(height: 50),
                                        ],
                                      ),
                                    ),
                                  )
                                : Column(
                                    children: [
                                      Text(
                                        '$firstName $lastName',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white, // White text
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            email ??
                                                (localizations?.noEmail ??
                                                    'No email'),
                                            style: TextStyle(
                                                fontSize: 8,
                                                color: Colors.grey[400]),
                                          ),
                                          Text(
                                            '  ||  ',
                                            style: TextStyle(
                                                fontSize: 8,
                                                color: Colors.grey[600]),
                                          ),
                                          Text(
                                            '$countryLine  •  ${region ?? (localizations?.noRegion ?? 'No region')}',
                                            style: TextStyle(
                                                fontSize: 8,
                                                color: Colors.grey[400]),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                          ),
                          if (!_isEditing)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildInfoBox(
                                    icon: Icons.message_outlined,
                                    label:
                                        localizations?.bookings ?? 'Bookings',
                                    value: mobileNumber,
                                    onTap: () {
                                      final User? currentUser =
                                          FirebaseAuth.instance.currentUser;
                                      if (currentUser != null) {
                                        pushAppRoute(
                                          context,
                                          BookingPage(
                                              currentUserId: currentUser.uid),
                                        );
                                      }
                                    },
                                  ),
                                  SizedBox(width: 20),
                                  _buildInfoBox(
                                    icon: Icons.person_add,
                                    label: localizations?.referAClient ??
                                        'Refer A Client',
                                    value: region,
                                    onTap: () => _checkAndNavigate(context,
                                        isReferralForm: true),
                                  ),
                                  SizedBox(width: 20),
                                  _buildInfoBox(
                                    icon: Icons.description,
                                    label:
                                        localizations?.referrals ?? 'Referrals',
                                    value: region,
                                    onTap: () => _checkAndNavigate(context,
                                        isReferralForm: false),
                                  ),
                                ],
                              ),
                            ),
                          if (userData['Role'] != true) ...[
                            SizedBox(height: 16),
                            Container(
                              margin: EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey[850],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[800]!),
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    (userData['lawyerVerificationStatus'] ==
                                            'pending')
                                        ? Icons.hourglass_top
                                        : Icons.gavel_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  userData['lawyerVerificationStatus'] ==
                                          'pending'
                                      ? 'Lawyer application pending'
                                      : 'Apply to be a lawyer',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15),
                                ),
                                subtitle: Text(
                                  userData['lawyerVerificationStatus'] ==
                                          'pending'
                                      ? 'Awaiting admin verification'
                                      : 'Submit documents for admin review',
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 12),
                                ),
                                trailing: Icon(Icons.arrow_forward_ios,
                                    color: Colors.grey[600], size: 16),
                                onTap: userData['lawyerVerificationStatus'] ==
                                        'pending'
                                    ? null
                                    : () {
                                        pushAppRoute(
                                          context,
                                          const LawyerRegistrationScreen(),
                                        );
                                      },
                              ),
                            ),
                          ],
                          SizedBox(height: 16),
                          Container(
                            margin: EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey[850],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[800]!),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.block,
                                    color: Colors.white, size: 20),
                              ),
                              title: Text(
                                localizations?.blockedUsers ?? 'Blocked Users',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15),
                              ),
                              subtitle: Text(
                                localizations?.manageBlockedUsers ??
                                    'Manage blocked users',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 12),
                              ),
                              trailing: Icon(Icons.arrow_forward_ios,
                                  color: Colors.grey[600], size: 16),
                              onTap: () {
                                pushAppRoute(
                                  context,
                                  const BlockedUsersPage(),
                                );
                              },
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Semantics(
                                label: localizations?.deleteAccountTitle ??
                                    'Delete Account',
                                child: ElevatedButton.icon(
                                  onPressed: () => _deleteUserAccount(context),
                                  icon: Icon(Icons.delete_forever,
                                      size: 18, color: Colors.white),
                                  label: Text(
                                      localizations?.deleteButtonLabel ??
                                          'Delete',
                                      style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                  ),
                                ),
                              ),
                              Semantics(
                                label: localizations?.logoutButtonLabel ??
                                    'Logout',
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    try {
                                      await Provider.of<AuthService>(context,
                                              listen: false)
                                          .signOut();
                                      Provider.of<UserModel>(context,
                                              listen: false)
                                          .clearUserId();
                                      setState(() {
                                        _userDataFuture = null;
                                        _imageFile = null;
                                        _isEditing = false;
                                      });
                                      if (context.mounted) {
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  const MainLayout()),
                                          (route) => false,
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                '${localizations?.logoutFailed.toString().replaceFirst('{error}', e.toString()) ?? "Logout failed: $e"}'),
                                            backgroundColor: Colors.grey[800],
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: Icon(Icons.logout,
                                      size: 18, color: Colors.black),
                                  label: Text(
                                      localizations?.logoutButton ?? 'Logout',
                                      style: TextStyle(color: Colors.black)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBox({
    required IconData icon,
    required String label,
    required String? value,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[850], // Slightly lighter grey
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: Colors.white,
                size: 24,
                semanticLabel: label), // White icon
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              value ?? 'N/A',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
