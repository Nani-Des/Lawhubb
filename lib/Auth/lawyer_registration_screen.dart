import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:nhap/Auth/auth_service.dart';
import 'package:nhap/utils/country_utils.dart';
import 'package:nhap/widgets/searchable_country_sheet.dart';

/// Same pipeline as [LawhubbAdminPanel] lawyer signup: `Users` + `LawyerVerificationRequests`.
class LawyerRegistrationScreen extends StatefulWidget {
  const LawyerRegistrationScreen({super.key});

  @override
  State<LawyerRegistrationScreen> createState() =>
      _LawyerRegistrationScreenState();
}

class _LawyerRegistrationScreenState extends State<LawyerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fname = TextEditingController();
  final _lname = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _existingPassword = TextEditingController();

  bool _isNewAccount = true;
  String _countryCode = kDefaultCountryCode;
  bool _submitting = false;
  String _submitStatus = '';

  PlatformFile? _licence;
  PlatformFile? _bar;
  PlatformFile? _gba;

  @override
  void dispose() {
    _fname.dispose();
    _lname.dispose();
    _email.dispose();
    _mobile.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _existingPassword.dispose();
    super.dispose();
  }

  Future<Map<String, Object?>> _uploadOne(
    String uid,
    String key,
    PlatformFile file,
  ) async {
    final safeName = file.name.replaceAll(RegExp(r'\s+'), '_');
    final storagePath =
        'lawyer_verification/$uid/${key}_${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final ref = FirebaseStorage.instance.ref().child(storagePath);
    if (file.bytes != null) {
      await ref.putData(file.bytes!);
    } else if (file.path != null) {
      await ref.putFile(File(file.path!));
    } else {
      throw StateError('Could not read file data.');
    }
    final url = await ref.getDownloadURL();
    return {'url': url, 'path': storagePath, 'name': file.name};
  }

  Future<void> _pickFile(void Function(PlatformFile?) setFile) async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (r != null && r.files.isNotEmpty) {
      setState(() => setFile(r.files.first));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_licence == null || _bar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Practising licence and Bar enrolment documents are required.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _submitStatus = _isNewAccount
          ? 'Creating your account…'
          : 'Signing in…';
    });
    User? provisioned;

    try {
      final auth = FirebaseAuth.instance;
      final db = FirebaseFirestore.instance;
      final fname = _fname.text.trim();
      final lname = _lname.text.trim();
      final email = _email.text.trim();
      final mobile = _mobile.text.trim();
      final fullName = '$fname $lname'.trim();
      final cc = _countryCode.trim().toUpperCase();

      late String uid;

      if (_isNewAccount) {
        final pw = _password.text.trim();
        final cred =
            await auth.createUserWithEmailAndPassword(email: email, password: pw);
        provisioned = cred.user;
        uid = cred.user!.uid;
      } else {
        final pw = _existingPassword.text.trim();
        final cred = await auth.signInWithEmailAndPassword(
          email: email,
          password: pw,
        );
        uid = cred.user!.uid;

        final reqSnap =
            await db.collection('LawyerVerificationRequests').doc(uid).get();
        if (reqSnap.data()?['status'] == 'pending') {
          throw StateError('pending');
        }
        final userSnap = await db.collection('Users').doc(uid).get();
        final u = userSnap.data();
        if (u?['lawyerVerificationStatus'] == 'pending') {
          throw StateError('pending');
        }
        if (u?['lawyerVerificationStatus'] == 'approved' && u?['Role'] == true) {
          throw StateError('already_lawyer');
        }
      }

      if (mounted) {
        setState(() => _submitStatus = 'Uploading documents…');
      }
      final practiceLicence = await _uploadOne(uid, 'practice_licence', _licence!);
      final barEnrolment = await _uploadOne(uid, 'bar_enrolment', _bar!);
      Map<String, Object?>? gbaMembership;
      if (_gba != null) {
        gbaMembership = await _uploadOne(uid, 'gba_membership', _gba!);
      }

      if (mounted) {
        setState(() => _submitStatus = 'Submitting application…');
      }
      await db.collection('Users').doc(uid).set(
        {
          'User ID': uid,
          'Fname': fname,
          'Lname': lname,
          'Email': email,
          'Mobile Number': mobile,
          'Title': '',
          'Designation': 'Applicant',
          'Practice ID': '',
          'Chamber ID': '',
          'Region': '',
          'Country': cc,
          'CountryRequired': false,
          'User Pic': '',
          'Role': false,
          'Status': true,
          'lawyerVerificationStatus': 'pending',
          'lawyerVerificationRequestedAt': FieldValue.serverTimestamp(),
          if (_isNewAccount) 'CreatedAt': Timestamp.now(),
        },
        SetOptions(merge: true),
      );

      await db.collection('LawyerVerificationRequests').doc(uid).set({
        'uid': uid,
        'email': email,
        'firstName': fname,
        'lastName': lname,
        'fullName': fullName.isEmpty ? 'Lawyer Applicant' : fullName,
        'mobile': mobile,
        'countryCode': cc,
        'status': 'pending',
        'requestedRole': 'lawyer',
        'documents': {
          'practiceLicence': practiceLicence,
          'barEnrolment': barEnrolment,
          'gbaMembership': gbaMembership,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Application submitted. An admin will verify your documents in LawHubb Admin.',
          ),
          backgroundColor: Colors.teal,
        ),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Authentication failed.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } on StateError catch (e) {
      if (!mounted) return;
      final msg = e.message == 'pending'
          ? 'You already have a lawyer verification application pending.'
          : e.message == 'already_lawyer'
              ? 'This account is already verified as a lawyer.'
              : (e.message.isNotEmpty ? e.message : 'Could not submit.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not submit application: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
      if (provisioned != null && _isNewAccount) {
        try {
          await provisioned.delete();
        } catch (_) {}
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitStatus = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Lawyer registration'),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
              const Text(
                'Submit documents for admin verification. Use the same email as your LawHubb account when choosing “Existing account”.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('New account')),
                  ButtonSegment(value: false, label: Text('Existing account')),
                ],
                selected: {_isNewAccount},
                onSelectionChanged: (s) {
                  setState(() => _isNewAccount = s.first);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fname,
                style: const TextStyle(color: Colors.white),
                decoration: _decoration('First name'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lname,
                style: const TextStyle(color: Colors.white),
                decoration: _decoration('Last name'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                style: const TextStyle(color: Colors.white),
                decoration: _decoration('Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!AuthService.isValidEmail(v.trim())) {
                    return 'Invalid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mobile,
                style: const TextStyle(color: Colors.white),
                decoration: _decoration('Mobile number'),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _submitting
                    ? null
                    : () async {
                        final c = await showSearchableCountryPicker(
                          context,
                          title: 'Country of practice',
                        );
                        if (c != null && mounted) {
                          setState(() => _countryCode = c);
                        }
                      },
                child: InputDecorator(
                  decoration: _decoration('Country'),
                  child: Text(
                    '${countryNameFromCode(_countryCode)} ($_countryCode)',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              if (_isNewAccount) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoration('Password (letters & numbers, min 6)'),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.length < 6) return 'At least 6 characters';
                    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(t)) {
                      return 'Letters and numbers only';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPassword,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoration('Confirm password'),
                  validator: (v) =>
                      v?.trim() != _password.text.trim()
                          ? 'Passwords do not match'
                          : null,
                ),
              ] else ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _existingPassword,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoration('Account password'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Enter your password' : null,
                ),
              ],
              const SizedBox(height: 20),
              _fileTile(
                'Practising licence (GLC certificate) *',
                _licence,
                () => _pickFile((f) => _licence = f),
              ),
              _fileTile(
                'Call to the Bar / enrolment *',
                _bar,
                () => _pickFile((f) => _bar = f),
              ),
              _fileTile(
                'GBA membership (optional)',
                _gba,
                () => _pickFile((f) => _gba = f),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.teal,
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit for verification'),
              ),
                ],
              ),
            ),
            if (_submitting)
              Positioned.fill(
                child: AbsorbPointer(
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.65),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.tealAccent,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _submitStatus.isEmpty
                                  ? 'Please wait…'
                                  : _submitStatus,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Do not close the app.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[400]),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey[700]!),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.tealAccent),
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      filled: true,
      fillColor: Colors.grey[900],
    );
  }

  Widget _fileTile(String label, PlatformFile? file, VoidCallback onPick) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          OutlinedButton(
            onPressed: _submitting ? null : onPick,
            child: Text(
              file?.name ?? 'Choose file',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

