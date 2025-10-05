import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nhap/Hospital/specialty_details.dart';
import '../Forums/Chat/chat_screen.dart';
import 'doctor_availability_calendar.dart';
import 'hospital_page.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';

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
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      margin: const EdgeInsets.all(16.0),
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildProfileSection(context),
                const SizedBox(height: 24),
                _buildInfoGrid(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 16,
            right: 16,
            child: _buildActionButtons(context),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Colors.grey[800],
          backgroundImage: doctorDetails['User Pic']?.isNotEmpty ?? false
              ? NetworkImage(doctorDetails['User Pic'])
              : const AssetImage('assets/Images/placeholder.png') as ImageProvider,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "${doctorDetails['Lname'] ?? ''} ${doctorDetails['Fname'] ?? ''} ${doctorDetails['Title'] ?? ''}",
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          doctorDetails['status'] ?? 'Available',
          style: TextStyle(
            fontSize: 12,
            color: doctorDetails['status'] == 'Available' ? Colors.green : Colors.red,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildInfoBox(
          Icons.gavel_outlined,
          'Bar',
          hospitalName,
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
        _buildInfoBox(
          Icons.business,
          'Practice',
          departmentName,
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
        _buildInfoBox(
          Icons.location_on,
          'Region',
          doctorDetails['Region'],
          onTap: () => _showInfoDialog(context, 'Region', doctorDetails['Region']),
        ),
        _buildInfoBox(
          Icons.calendar_month_outlined,
          'Year of Call',
          "${doctorDetails['Experience'] ?? 'N/A'}",
          onTap: () => _showInfoDialog(context, 'Experience', "${doctorDetails['Experience'] ?? 'N/A'}"),
        ),
      ],
    );
  }

  Widget _buildInfoBox(IconData icon, String label, String? value, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[700]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              value ?? 'Not available',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String? value) {
    if (value == null || value.isEmpty) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title, style: TextStyle(color: Colors.white)),
          content: Text(value, style: TextStyle(color: Colors.grey[300])),
          backgroundColor: Colors.grey[900],
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.message, color: Colors.black),
            label: const Text('Message Lawyer', style: TextStyle(color: Colors.black)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              elevation: 4,
            ),
            onPressed: () async {
              final String otherUserId = doctorDetails['User ID'];
              final chatRef = FirebaseFirestore.instance.collection('Chats');

              // Find existing chat
              final existingChat = await chatRef
                  .where('participants', arrayContains: currentUser.uid)
                  .get();

              DocumentSnapshot? foundChat;
              for (var doc in existingChat.docs) {
                if ((doc['participants'] as List).contains(otherUserId)) {
                  foundChat = doc;
                  break;
                }
              }

              // If chat doesn’t exist, create one
              if (foundChat == null) {
                final newChatRef = await chatRef.add({
                  'participants': [currentUser.uid, otherUserId],
                  'createdAt': FieldValue.serverTimestamp(),
                });

                // Fetch the created document as a snapshot
                foundChat = await newChatRef.get();
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    chatId: foundChat!.id,
                    recipientId: otherUserId,
                    recipientName:
                    "${doctorDetails['Fname'] ?? ''} ${doctorDetails['Lname'] ?? ''}",
                    recipientPic: doctorDetails['User Pic'] ?? '',
                    recipientRole: doctorDetails['Role'] is bool
                        ? doctorDetails['Role']
                        : (doctorDetails['Role']?.toString().toLowerCase() == 'true'),

                  ),
                ),
              );
            },

          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.calendar_month, color: Colors.black),
            label: const Text('Book', style: TextStyle(color: Colors.black)),
            style: ElevatedButton.styleFrom(
              backgroundColor: isReferral ? Colors.grey[700] : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              elevation: isReferral ? 0 : 4,
            ),
            onPressed: isReferral ? null : () => _showCalendarDialog(context),
          ),
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
          content: Text('${doctorId == null ? 'Lawyers' : 'Chamber'} ID is missing'),
          backgroundColor: Colors.grey[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
