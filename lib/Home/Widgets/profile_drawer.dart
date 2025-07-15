import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nhap/Appointments/referral_form.dart';
import 'package:nhap/Appointments/Referral%20screens/referral_details_page.dart';
import '../../Auth/auth_screen.dart';
import '../../Auth/auth_service.dart';
import '../../booking_page.dart';
import '../../main.dart';
import '../home_page.dart';
import 'package:provider/provider.dart';

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

  @override
  void initState() {
    super.initState();
    _refreshUserData();
  }

  void _refreshUserData() {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    setState(() {
      _userDataFuture = currentUser != null ? _fetchUserData() : null;
    });
  }

  Future<DocumentSnapshot> _fetchUserData() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User not logged in');
    }
    final DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(currentUser.uid)
        .get();
    if (!userDoc.exists || userDoc['Status'] != true) {
      throw Exception('User data is deleted or does not exist');
    }
    return userDoc;
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
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
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No user is currently logged in'),
          backgroundColor: Colors.grey[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          content: Text('Lawyers must log out and log in again to delete their account'),
          backgroundColor: Colors.grey[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Account', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone.',
          style: TextStyle(color: Colors.grey[300]),
        ),
        backgroundColor: Colors.grey[900],
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmDelete != true) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('Users').doc(currentUser.uid).update({
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
            content: Text('Account deleted successfully. You are now logged out'),
            backgroundColor: Colors.grey[800],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      final String errorMessage = e is FirebaseAuthException ? e.message ?? 'Failed to disable account' : e.toString();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.grey[800],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _checkAndNavigate(BuildContext context, {required bool isReferralForm}) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const AuthScreen()));
      return;
    }

    final DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
    final bool isDoctor = userDoc.exists && userDoc['Role'] == true;
    if (!isDoctor) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Access Denied', style: TextStyle(color: Colors.white)),
            content: Text(
              "Only Lawyers can access ${isReferralForm ? 'Referral Form' : 'Referrals'}.",
              style: TextStyle(color: Colors.grey[300]),
            ),
            backgroundColor: Colors.grey[900],
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => isReferralForm ? const ReferralForm() : ReferralDetailsPage(userId: user.uid),
      ),
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
    if (!widget.showProfileDrawer) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: widget.slideAnimation,
      child: GestureDetector(
        onVerticalDragEnd: (_) => widget.controller.reverse(),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[900],  // Dark grey background
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, -6)),  // Darker shadow
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Consumer<AuthService>(
                builder: (BuildContext context, AuthService authService, Widget? _) {
                  if (authService.currentUser == null || _userDataFuture == null) {
                    return const SizedBox.shrink();
                  }

                  return FutureBuilder<DocumentSnapshot>(
                    future: _userDataFuture,
                    builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),  // White progress indicator
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, color: Colors.red, size: 40),
                              SizedBox(height: 8),
                              Text(
                                'Error: ${snapshot.error}',
                                style: TextStyle(color: Colors.redAccent),
                                textAlign: TextAlign.center,
                              ),
                              TextButton(
                                onPressed: _refreshUserData,
                                child: Text('Retry', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                      }

                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return const SizedBox.shrink();
                      }

                      final Map<String, dynamic> userData = snapshot.data!.data() as Map<String, dynamic>;
                      final String? userImageUrl = userData['User Pic'] as String?;
                      final String? firstName = userData['Fname'] as String?;
                      final String? lastName = userData['Lname'] as String?;
                      final String? mobileNumber = userData['Mobile Number'] as String?;
                      final String? region = userData['Region'] as String?;
                      final String? email = userData['Email'] as String?;

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
                                    setState(() => _isEditing = true);
                                  }
                                },
                                child: Text(
                                  _isEditing ? 'Save' : 'Edit',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: _isEditing ? _pickImage : null,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.grey[800],  // Darker grey avatar background
                                  backgroundImage: _imageFile != null
                                      ? FileImage(_imageFile!)
                                      : (userImageUrl != null && userImageUrl.isNotEmpty
                                      ? NetworkImage(userImageUrl)
                                      : null),
                                  child: _imageFile == null && (userImageUrl == null || userImageUrl.isEmpty)
                                      ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                                      : null,
                                ),
                                if (_isEditing)
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.edit, color: Colors.black, size: 16),
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              color: Colors.grey[850],  // Slightly lighter grey card
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _firstNameController,
                                      decoration: InputDecoration(
                                        labelText: 'First Name',
                                        labelStyle: TextStyle(color: Colors.grey[400]),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: Colors.grey[700]!),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: Colors.white),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    SizedBox(height: 12),
                                    TextFormField(
                                      controller: _lastNameController,
                                      decoration: InputDecoration(
                                        labelText: 'Last Name',
                                        labelStyle: TextStyle(color: Colors.grey[400]),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: Colors.grey[700]!),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: Colors.white),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    SizedBox(height: 12),
                                    TextFormField(
                                      controller: _regionController,
                                      decoration: InputDecoration(
                                        labelText: 'Region',
                                        labelStyle: TextStyle(color: Colors.grey[400]),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: Colors.grey[700]!),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: Colors.white),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    SizedBox(height: 12),
                                    TextFormField(
                                      controller: _mobileController,
                                      decoration: InputDecoration(
                                        labelText: 'Mobile Number',
                                        labelStyle: TextStyle(color: Colors.grey[400]),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: Colors.grey[700]!),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: Colors.white),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      keyboardType: TextInputType.phone,
                                      style: TextStyle(color: Colors.white),
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
                                    color: Colors.white,  // White text
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      email ?? 'No email',
                                      style: TextStyle(fontSize: 8, color: Colors.grey[400]),
                                    ),
                                    Text(
                                      '  ||  ',
                                      style: TextStyle(fontSize: 8, color: Colors.grey[600]),
                                    ),
                                    Text(
                                      region ?? 'No region',
                                      style: TextStyle(fontSize: 8, color: Colors.grey[400]),
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
                                    label: 'Bookings',
                                    value: mobileNumber,
                                    onTap: () {
                                      final User? currentUser = FirebaseAuth.instance.currentUser;
                                      if (currentUser != null) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => BookingPage(currentUserId: currentUser.uid),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  SizedBox(width: 20),
                                  _buildInfoBox(
                                    icon: Icons.person_add,
                                    label: 'Refer A Client',
                                    value: region,
                                    onTap: () => _checkAndNavigate(context, isReferralForm: true),
                                  ),
                                  SizedBox(width: 20),
                                  _buildInfoBox(
                                    icon: Icons.description,
                                    label: 'Referrals',
                                    value: region,
                                    onTap: () => _checkAndNavigate(context, isReferralForm: false),
                                  ),
                                ],
                              ),
                            ),
                          SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Semantics(
                                label: 'Delete Account',
                                child: ElevatedButton.icon(
                                  onPressed: () => _deleteUserAccount(context),
                                  icon: Icon(Icons.block, size: 18, color: Colors.white),
                                  label: Text('Delete', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ),
                              ),
                              Semantics(
                                label: 'Logout',
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    try {
                                      await GoogleSignIn().signOut();
                                      await Provider.of<AuthService>(context, listen: false).signOut();
                                      Provider.of<UserModel>(context, listen: false).clearUserId();
                                      setState(() {
                                        _userDataFuture = null;
                                        _imageFile = null;
                                        _isEditing = false;
                                      });
                                      if (context.mounted) {
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(builder: (context) => HomePage()),
                                              (route) => false,
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Logout failed: $e'),
                                            backgroundColor: Colors.grey[800],
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: Icon(Icons.logout, size: 18, color: Colors.black),
                                  label: Text('Logout', style: TextStyle(color: Colors.black)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          color: Colors.grey[850],  // Slightly lighter grey
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24, semanticLabel: label),  // White icon
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
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