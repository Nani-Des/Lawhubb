import 'package:flutter/material.dart';
import 'package:nhap/widgets/profile_avatar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nhap/Hospital/specialty_details.dart';
import 'package:nhap/l10n/app_localizations.dart';
import '../Forums/Chat/chat_screen.dart';
import '../Forums/Chat/voice_call_screen.dart';
import 'doctor_availability_calendar.dart';
import 'hospital_page.dart';
import 'package:uuid/uuid.dart';
import '../Services/follow_service.dart';
import '../utils/user_facing_errors.dart';

class DoctorInfoWidget extends StatelessWidget {
  final Map<String, dynamic> doctorDetails;
  final String hospitalName;
  final String departmentName;
  final String departmentId;
  final String hospitalId;
  final Function(String) onCall;
  final bool isReferral;

  const DoctorInfoWidget({
    Key? key,
    required this.doctorDetails,
    required this.hospitalName,
    required this.departmentName,
    required this.departmentId,
    required this.hospitalId,
    required this.onCall,
    required this.isReferral,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header Section with Gradient
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.grey[900]!,
                      Colors.black,
                    ],
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    // Profile Avatar with Status
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ProfileAvatar.circle(
                            imageUrl: doctorDetails['User Pic']?.toString(),
                            radius: 40,
                            backgroundColor: Colors.grey[800],
                          ),
                        ),
                        // Status Indicator
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: (doctorDetails['status'] == 'Available' ||
                                      doctorDetails['isOnline'] == true)
                                  ? Colors.grey[300]
                                  : Colors.grey[600],
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Name
                    Text(
                      "${doctorDetails['Title'] ?? ''} ${doctorDetails['Fname'] ?? ''} ${doctorDetails['Lname'] ?? ''}"
                          .trim(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (doctorDetails['status'] == 'Available' ||
                                  doctorDetails['isOnline'] == true)
                              ? Colors.grey[600]!
                              : Colors.grey[700]!,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        (doctorDetails['status'] == 'Available' ||
                                doctorDetails['isOnline'] == true)
                            ? 'Available'
                            : 'Offline',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: (doctorDetails['status'] == 'Available' ||
                                  doctorDetails['isOnline'] == true)
                              ? Colors.grey[300]
                              : Colors.grey[500],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Info Cards Section
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Title
                    const Text(
                      'Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Info Cards Grid
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.3,
                      children: [
                        _buildModernInfoCard(
                          context,
                          icon: Icons.gavel_rounded,
                          title: 'Chamber',
                          value: hospitalName,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HospitalPage(
                                  hospitalId: hospitalId,
                                  isReferral: isReferral,
                                ),
                              ),
                            );
                          },
                        ),
                        _buildModernInfoCard(
                          context,
                          icon: Icons.business_center_rounded,
                          title: 'Practice Area',
                          value: departmentName,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SpecialtyDetails(
                                  hospitalId: hospitalId,
                                  isReferral: isReferral,
                                  initialDepartmentId: departmentId,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Action Buttons
                    _buildActionButtons(context),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String? value,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[700]!, width: 1),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400],
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value ?? 'N/A',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Column(
      children: [
        // Primary Action: Voice Call
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: currentUser == null
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please log in to make voice calls'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                : () {
                    final String otherUserId = doctorDetails['User ID'];
                    final recipientName =
                        "${doctorDetails['Fname'] ?? ''} ${doctorDetails['Lname'] ?? ''}"
                            .trim();

                    // Generate unique channel name using UUID (max 64 chars)
                    final uuid = const Uuid();
                    final channelName =
                        uuid.v4().replaceAll('-', '').substring(0, 32);

                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VoiceCallScreen(
                            channelName: channelName,
                            recipientId: otherUserId,
                            recipientName: recipientName.isNotEmpty
                                ? recipientName
                                : 'Lawyer',
                            isInitiator: true,
                          ),
                        ),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.phone_rounded, size: 18, color: Colors.black),
                SizedBox(width: 8),
                Text(
                  'Voice Call',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Follow Button
        if (currentUser != null && currentUser.uid != doctorDetails['User ID'])
          _FollowButton(
            currentUserId: currentUser.uid,
            targetUserId: doctorDetails['User ID'],
          ),

        if (currentUser != null && currentUser.uid != doctorDetails['User ID'])
          const SizedBox(height: 8),

        // Secondary Actions Row
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: currentUser == null
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please log in to message lawyers'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    : () async {
                        final String otherUserId = doctorDetails['User ID'];
                        final uid = currentUser.uid;
                        final chatId = uid.compareTo(otherUserId) < 0
                            ? '${uid}_$otherUserId'
                            : '${otherUserId}_$uid';

                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                chatId: chatId,
                                recipientId: otherUserId,
                                recipientName:
                                    "${doctorDetails['Fname'] ?? ''} ${doctorDetails['Lname'] ?? ''}",
                                recipientPic: doctorDetails['User Pic'] ?? '',
                                recipientRole: doctorDetails['Role'] is bool
                                    ? doctorDetails['Role']
                                    : (doctorDetails['Role']
                                            ?.toString()
                                            .toLowerCase() ==
                                        'true'),
                              ),
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.message_rounded, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Message',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed:
                    isReferral ? null : () => _showCalendarDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isReferral ? Colors.grey[800] : Colors.white,
                  foregroundColor: isReferral ? Colors.grey[500] : Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: isReferral ? 0 : 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.calendar_today_rounded, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Book',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showCalendarDialog(BuildContext context) {
    final String? doctorId = doctorDetails['User ID'];
    final String? hospitalId = doctorDetails['Hospital ID'];

    if (doctorId == null || hospitalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(doctorId == null
              ? (AppLocalizations.of(context)?.lawyerIdMissing ??
                  'Lawyer ID is missing')
              : (AppLocalizations.of(context)?.chamberIdMissing ??
                  'Chamber ID is missing')),
          backgroundColor: Colors.grey[800],
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DoctorAvailabilityCalendar(
          doctorId: doctorId,
          hospitalId: hospitalId,
        );
      },
    );
  }
}

class _FollowButton extends StatefulWidget {
  final String currentUserId;
  final String targetUserId;

  const _FollowButton({
    required this.currentUserId,
    required this.targetUserId,
  });

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  late Future<bool> _isFollowingFuture;

  @override
  void initState() {
    super.initState();
    _isFollowingFuture =
        FollowService().isFollowing(widget.currentUserId, widget.targetUserId);
  }

  void _refreshFollowStatus() {
    setState(() {
      _isFollowingFuture = FollowService()
          .isFollowing(widget.currentUserId, widget.targetUserId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isFollowingFuture,
      builder: (context, snapshot) {
        final isFollowing = snapshot.data ?? false;

        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () async {
              final followService = FollowService();

              try {
                if (isFollowing) {
                  await followService.unfollowUser(
                      widget.currentUserId, widget.targetUserId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Unfollowed'),
                        backgroundColor: Colors.grey,
                      ),
                    );
                  }
                } else {
                  await followService.followUser(
                      widget.currentUserId, widget.targetUserId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Following'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
                _refreshFollowStatus();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(UserFacingErrors.actionFailed(action: 'follow user')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(
                  color: isFollowing ? Colors.grey[700]! : Colors.white),
              backgroundColor:
                  isFollowing ? Colors.grey[800] : Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isFollowing ? Icons.person_remove : Icons.person_add,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  isFollowing ? 'Following' : 'Follow',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
