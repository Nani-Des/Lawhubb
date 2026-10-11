import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:nhap/l10n/app_localizations.dart';

import 'library_catalog.dart';

class UploadPDFPage extends StatefulWidget {
  const UploadPDFPage({super.key});

  @override
  State<UploadPDFPage> createState() => _UploadPDFPageState();
}

class _UploadPDFPageState extends State<UploadPDFPage> {
  final _formKey = GlobalKey<FormState>();
  File? selectedFile;
  String title = '', author = '', description = '';
  String category = 'Other';
  double price = 0;
  bool uploading = false;
  String fileExtension = '';

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final ext = result.files.single.extension?.toLowerCase() ?? '';

      if (['pdf', 'doc', 'docx'].contains(ext)) {
        setState(() {
          selectedFile = file;
          fileExtension = ext;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context)?.selectPdfOrWordDocument ??
                    'Please select a PDF or Word document'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> uploadFile() async {
    if (selectedFile == null || !_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to upload books.')),
      );
      return;
    }

    _formKey.currentState!.save();
    setState(() => uploading = true);

    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${title.replaceAll(" ", "_")}.$fileExtension';

      final ref =
          FirebaseStorage.instance.ref().child('library_files/$fileName');

      await ref.putFile(selectedFile!);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('library').add({
        'title': title.trim(),
        'author': author.trim(),
        'category': libraryCategoryOrOther(category),
        'description': description.trim(),
        'price': price,
        'url': url,
        'fileType': fileExtension.toLowerCase(),
        'uploadedBy': user.uid,
        'sellerId': user.uid,
        'sellerEmail': user.email ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)?.uploadedSuccessfully ??
                'Uploaded Successfully!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload failed. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
            AppLocalizations.of(context)?.uploadDocument ?? 'Upload to Bookshop'),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      body: uploading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.tealAccent))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    ElevatedButton.icon(
                      onPressed: pickFile,
                      icon: const Icon(Icons.file_present, color: Colors.white),
                      label: Text(
                        selectedFile == null
                            ? (AppLocalizations.of(context)
                                    ?.selectPdfOrWordFile ??
                                'Select PDF or Word File')
                            : (AppLocalizations.of(context)
                                    ?.selected(fileExtension.toUpperCase()) ??
                                'Selected: ${fileExtension.toUpperCase()}'),
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    buildField(
                        AppLocalizations.of(context)?.fieldTitle ?? 'Title',
                        (v) => title = v!),
                    buildField(
                        AppLocalizations.of(context)?.fieldAuthor ?? 'Author',
                        (v) => author = v!),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: DropdownButtonFormField<String>(
                        value: kLibraryUploadCategories.contains(category)
                            ? category
                            : 'Other',
                        decoration: InputDecoration(
                          labelText:
                              AppLocalizations.of(context)?.fieldCategory ??
                                  'Category',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        dropdownColor: Colors.grey[900],
                        style: const TextStyle(color: Colors.white),
                        items: kLibraryUploadCategories
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => category = v ?? 'Other'),
                        validator: (v) => (v == null || v.isEmpty)
                            ? (AppLocalizations.of(context)?.required ??
                                'Required')
                            : null,
                      ),
                    ),
                    buildField(
                        AppLocalizations.of(context)?.fieldDescription ??
                            'Preface / Description',
                        (v) => description = v!,
                        lines: 3),
                    buildField(
                        AppLocalizations.of(context)?.fieldPrice ??
                            'Price (GHS) — 0 for free',
                        (v) => price = double.tryParse(v ?? '') ?? 0,
                        required: false),
                    const SizedBox(height: 8),
                    Text(
                      'Paid books use Paystack. Buyers get instant access; you are recorded as the seller for payouts.',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: uploadFile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                          AppLocalizations.of(context)?.uploadButton ?? 'Upload',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget buildField(String label, FormFieldSetter<String> onSaved,
      {int lines = 1, bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.grey[900],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        style: const TextStyle(color: Colors.white),
        maxLines: lines,
        validator: required
            ? (v) => (v == null || v.isEmpty)
                ? (AppLocalizations.of(context)?.required ?? 'Required')
                : null
            : null,
        onSaved: onSaved,
      ),
    );
  }
}
