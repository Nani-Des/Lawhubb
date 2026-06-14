import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:nhap/Auth/auth_service.dart';
import 'package:nhap/utils/country_utils.dart';
import 'package:nhap/utils/country_regions.dart';
import 'package:nhap/utils/chamber_constants.dart';
import 'package:nhap/utils/user_facing_errors.dart';
import 'package:nhap/Services/firebase_service.dart';
import 'package:nhap/widgets/searchable_country_sheet.dart';
import 'package:nhap/widgets/searchable_option_sheet.dart';

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
  final _altChamberController = TextEditingController();
  final _altPracticeInputController = TextEditingController();
  final _regionController = TextEditingController();

  bool _isNewAccount = true;
  String _countryCode = kDefaultCountryCode;
  String _nationalityCode = kDefaultCountryCode;
  String _ghanaRegion = 'Select a region';
  String _selectedChamberId = '';
  String _selectedChamberName = '';
  String _selectedPracticeId = '';
  String _selectedPracticeName = '';
  List<String> _selectedPracticeIds = [];
  List<String> _selectionAltPractice = [];
  List<String> _typedAltPractice = [];
  bool _loadingPractices = false;
  bool _submitting = false;
  String _submitStatus = '';

  final _firebaseService = FirebaseService();

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
    _altChamberController.dispose();
    _altPracticeInputController.dispose();
    _regionController.dispose();
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

  Future<void> _pickChamber() async {
    final snap = await FirebaseFirestore.instance.collection('Chamber').get();
    final options = snap.docs
        .map((d) {
          final data = d.data();
          final name = data['Chamber Name']?.toString().trim();
          return SearchableOption(
            id: d.id,
            label: (name != null && name.isNotEmpty) ? name : d.id,
          );
        })
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    if (!mounted) return;
    final id = await showSearchableOptionPicker(
      context,
      title: 'Select chamber',
      options: options,
      searchHint: 'Search chambers…',
    );
    if (id == null || !mounted) return;

    final selected = options.firstWhere((o) => o.id == id);
    setState(() {
      _selectedChamberId = id;
      _selectedChamberName = selected.label;
      _altChamberController.clear();
      _selectedPracticeId = '';
      _selectedPracticeName = '';
      _selectedPracticeIds = [];
      _selectionAltPractice = [];
      _loadingPractices = true;
    });

    try {
      final practices =
          await _firebaseService.getDepartmentsForHospital(id);
      if (!mounted) return;
      if (practices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This chamber has no practices yet. Choose another chamber or contact support.',
            ),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load practices for this chamber.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingPractices = false);
    }
  }

  void _applySelectedPractices(List<SearchableOption> options, List<String> ids) {
    if (ids.isEmpty) {
      setState(() {
        _selectedPracticeIds = [];
        _selectedPracticeId = '';
        _selectedPracticeName = '';
        _selectionAltPractice = [];
      });
      return;
    }

    final idToLabel = {for (final o in options) o.id: o.label};
    final primaryId = ids.first;
    final altFromSelection = ids
        .skip(1)
        .map((id) => idToLabel[id] ?? id)
        .where((name) => name.trim().isNotEmpty)
        .toList();

    setState(() {
      _selectedPracticeIds = List.from(ids);
      _selectedPracticeId = primaryId;
      _selectedPracticeName = idToLabel[primaryId] ?? primaryId;
      _selectionAltPractice = altFromSelection;
    });
  }

  Future<void> _pickPractice() async {
    if (_selectedChamberId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a chamber first or type your chamber name below.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _loadingPractices = true);
    try {
      final practices =
          await _firebaseService.getDepartmentsForHospital(_selectedChamberId);
      if (!mounted) return;
      if (practices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No practices available for this chamber. Add custom practice names below.',
            ),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return;
      }

      final options = practices
          .map(
            (p) => SearchableOption(
              id: p['Practice ID'] as String,
              label: p['Practice Name'] as String,
            ),
          )
          .toList()
        ..sort((a, b) => a.label.compareTo(b.label));

      final ids = await showSearchableMultiOptionPicker(
        context,
        title: 'Select practice(s)',
        options: options,
        searchHint: 'Search practices…',
        initialSelectedIds: _selectedPracticeIds,
      );
      if (!mounted) return;
      _applySelectedPractices(options, ids);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load practices.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingPractices = false);
    }
  }

  void _addAltPractice() {
    final name = _altPracticeInputController.text.trim();
    if (name.isEmpty) return;
    if (_allAltPractice.any((p) => p.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This practice is already listed.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }
    setState(() {
      _typedAltPractice = [..._typedAltPractice, name];
      _altPracticeInputController.clear();
    });
  }

  void _removeAltPractice(String name) {
    setState(() {
      _typedAltPractice =
          _typedAltPractice.where((p) => p != name).toList();
    });
  }

  List<String> get _allAltPractice => [
        ..._selectionAltPractice,
        ..._typedAltPractice,
      ];

  String get _altChamber => _altChamberController.text.trim();

  bool get _hasChamber =>
      _selectedChamberId.isNotEmpty || _altChamber.isNotEmpty;

  bool get _hasPractice =>
      _selectedPracticeId.isNotEmpty || _allAltPractice.isNotEmpty;

  String _practiceSummary() {
    final parts = <String>[];
    if (_selectedPracticeName.isNotEmpty) {
      parts.add('Primary: $_selectedPracticeName');
    }
    if (_selectionAltPractice.isNotEmpty) {
      parts.add('From list: ${_selectionAltPractice.join(', ')}');
    }
    if (_typedAltPractice.isNotEmpty) {
      parts.add('Custom: ${_typedAltPractice.join(', ')}');
    }
    if (parts.isEmpty) {
      return _selectedChamberId.isEmpty && _altChamber.isNotEmpty
          ? 'Add practice name(s) below'
          : _selectedChamberId.isEmpty
              ? 'Select a chamber first'
              : 'Tap to select practice(s)';
    }
    return parts.join('\n');
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
    if (!_hasChamber || !_hasPractice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please provide your chamber and at least one practice (select from the list or type custom names).',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final regionValue = isGhanaCountry(_countryCode)
        ? _ghanaRegion
        : _regionController.text.trim();
    if (!isValidRegionForCountry(_countryCode, regionValue)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isGhanaCountry(_countryCode)
                ? 'Please select your Ghana region.'
                : 'Please enter your state, province, or region.',
          ),
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

      var chamberIdToSave = _selectedChamberId;
      var chamberNameToSave = _selectedChamberName;
      if (_altChamber.isNotEmpty) {
        final naId = await resolveNaChamberId(db);
        if (naId == null) {
          throw StateError('na_chamber_missing');
        }
        chamberIdToSave = naId;
        chamberNameToSave = kNaChamberName;
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
          'Practice ID': _selectedPracticeId,
          'Chamber ID': chamberIdToSave,
          'Alt Chamber': _altChamber,
          'Alt Practice': _allAltPractice,
          'Region': regionValue,
          'Country': cc,
          'Nationality': _nationalityCode.trim().toUpperCase(),
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
        'nationality': _nationalityCode.trim().toUpperCase(),
        'region': regionValue,
        'chamberId': chamberIdToSave,
        'chamberName': chamberNameToSave,
        'practiceId': _selectedPracticeId,
        'practiceName': _selectedPracticeName,
        'altChamber': _altChamber,
        'altPractice': _allAltPractice,
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
          content: Text(UserFacingErrors.auth(e, context: 'lawyer_registration')),
          backgroundColor: Colors.redAccent,
        ),
      );
    } on StateError catch (e) {
      if (!mounted) return;
      final msg = UserFacingErrors.lawyerRegistrationState(e.message) ??
          UserFacingErrors.actionFailed(action: 'submit your application');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(UserFacingErrors.generic(
            context: 'lawyer_registration',
            error: e,
          )),
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
                onTap: _submitting || _altChamber.isNotEmpty ? null : _pickChamber,
                child: InputDecorator(
                  decoration: _decoration('Chamber (select from list)'),
                  child: Text(
                    _selectedChamberId.isEmpty
                        ? _altChamber.isNotEmpty
                            ? 'Using custom chamber name below'
                            : 'Tap to select a chamber'
                        : _selectedChamberName,
                    style: TextStyle(
                      color: _selectedChamberId.isEmpty
                          ? Colors.grey[500]
                          : Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _altChamberController,
                enabled: !_submitting,
                style: const TextStyle(color: Colors.white),
                decoration: _decoration('Or type your chamber name *'),
                onChanged: (value) {
                  if (value.trim().isNotEmpty) {
                    setState(() {
                      _selectedChamberId = '';
                      _selectedChamberName = '';
                      _selectedPracticeId = '';
                      _selectedPracticeName = '';
                      _selectedPracticeIds = [];
                      _selectionAltPractice = [];
                    });
                  } else {
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: (_submitting ||
                        _loadingPractices ||
                        _altChamber.isNotEmpty)
                    ? null
                    : _pickPractice,
                child: InputDecorator(
                  decoration: _decoration('Practice (select from list)'),
                  child: _loadingPractices
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _practiceSummary(),
                          style: TextStyle(
                            color: _hasPractice ? Colors.white : Colors.grey[500],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _altPracticeInputController,
                      enabled: !_submitting,
                      style: const TextStyle(color: Colors.white),
                      decoration: _decoration('Or type practice name(s) *'),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _addAltPractice(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: IconButton.filled(
                      onPressed: _submitting ? null : _addAltPractice,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.teal,
                      ),
                      icon: const Icon(Icons.add, color: Colors.white),
                      tooltip: 'Add practice',
                    ),
                  ),
                ],
              ),
              if (_typedAltPractice.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _typedAltPractice
                      .map(
                        (name) => Chip(
                          label: Text(name),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: _submitting ? null : () => _removeAltPractice(name),
                          backgroundColor: Colors.grey[850],
                          labelStyle: const TextStyle(color: Colors.white),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              InkWell(
                onTap: _submitting
                    ? null
                    : () async {
                        final c = await showSearchableCountryPicker(
                          context,
                          title: 'Nationality',
                        );
                        if (c != null && mounted) {
                          setState(() => _nationalityCode = c);
                        }
                      },
                child: InputDecorator(
                  decoration: _decoration('Nationality *'),
                  child: Text(
                    '${countryNameFromCode(_nationalityCode)} ($_nationalityCode)',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
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
                          setState(() {
                            _countryCode = c;
                            if (!isGhanaCountry(c)) {
                              _ghanaRegion = 'Select a region';
                            } else {
                              _regionController.clear();
                            }
                          });
                        }
                      },
                child: InputDecorator(
                  decoration: _decoration('Country of practice *'),
                  child: Text(
                    '${countryNameFromCode(_countryCode)} ($_countryCode)',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (isGhanaCountry(_countryCode))
                DropdownButtonFormField<String>(
                  value: kGhanaRegionOptions.contains(_ghanaRegion)
                      ? _ghanaRegion
                      : 'Select a region',
                  decoration: _decoration('Region (Ghana) *'),
                  dropdownColor: Colors.grey[900],
                  style: const TextStyle(color: Colors.white),
                  items: [
                    const DropdownMenuItem(
                      value: 'Select a region',
                      child: Text('Select a region'),
                    ),
                    ...kGhanaRegionOptions.map(
                      (r) => DropdownMenuItem(value: r, child: Text(r)),
                    ),
                  ],
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _ghanaRegion = v ?? 'Select a region'),
                )
              else
                TextFormField(
                  controller: _regionController,
                  enabled: !_submitting,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoration('State / province / region *'),
                  textCapitalization: TextCapitalization.words,
                ),
              const SizedBox(height: 12),
              if (_isNewAccount) ...[
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

