import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:nhap/l10n/app_localizations.dart';

class UploadPDFPage extends StatefulWidget {
  const UploadPDFPage({super.key});

  @override
  State<UploadPDFPage> createState() => _UploadPDFPageState();
}

class _UploadPDFPageState extends State<UploadPDFPage> {
  final _formKey = GlobalKey<FormState>();
  File? selectedFile;
  String title = '', author = '', category = '', description = '';
  double price = 0;
  bool uploading = false;
  String fileExtension = '';

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any, // ✅ opens full system file explorer
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final ext = result.files.single.extension?.toLowerCase() ?? '';

      // ✅ Accept only PDF, DOC, or DOCX
      if (['pdf', 'doc', 'docx'].contains(ext)) {
        setState(() {
          selectedFile = file;
          fileExtension = ext;
        });
      } else {
        // ⚠️ Show error if unsupported file is chosen
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

  /// Upload to Firebase Storage and save metadata
  Future<void> uploadFile() async {
    if (selectedFile == null || !_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();
    setState(() => uploading = true);

    // ✅ Use dynamic file extension
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${title.replaceAll(" ", "_")}.$fileExtension';

    final ref = FirebaseStorage.instance.ref().child('library_files/$fileName');

    await ref.putFile(selectedFile!);
    final url = await ref.getDownloadURL();

    await FirebaseFirestore.instance.collection('library').add({
      'title': title,
      'author': author,
      'category': category,
      'description': description,
      'price': price,
      'url': url,
      'fileType': fileExtension,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      setState(() => uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)?.uploadedSuccessfully ??
                'Uploaded Successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
            AppLocalizations.of(context)?.uploadDocument ?? "Upload Document"),
        backgroundColor: Colors.redAccent,
        centerTitle: true,
      ),
      body: uploading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.redAccent))
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
                                "Select PDF or Word File")
                            : (AppLocalizations.of(context)
                                    ?.selected(fileExtension.toUpperCase()) ??
                                "Selected: ${fileExtension.toUpperCase()}"),
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    buildField(
                        AppLocalizations.of(context)?.fieldTitle ?? "Title",
                        (v) => title = v!),
                    buildField(
                        AppLocalizations.of(context)?.fieldAuthor ?? "Author",
                        (v) => author = v!),
                    buildField(
                        AppLocalizations.of(context)?.fieldCategory ??
                            "Category",
                        (v) => category = v!),
                    buildField(
                        AppLocalizations.of(context)?.fieldDescription ??
                            "Preface / Description",
                        (v) => description = v!,
                        lines: 3),
                    buildField(
                        AppLocalizations.of(context)?.fieldPrice ??
                            "Price (GHS)",
                        (v) => price = double.tryParse(v ?? '') ?? 0),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: uploadFile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                          AppLocalizations.of(context)?.uploadButton ??
                              "Upload",
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
      {int lines = 1}) {
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
        validator: (v) => (v == null || v.isEmpty)
            ? (AppLocalizations.of(context)?.required ?? 'Required')
            : null,
        onSaved: onSaved,
      ),
    );
  }
}
