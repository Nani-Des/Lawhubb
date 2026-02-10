import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nhap/l10n/app_localizations.dart';
import '../../Hospital/doctor_profile.dart';
import '../../bot/widget/openai_service.dart';

class SearchBar1 extends StatefulWidget {
  const SearchBar1({Key? key}) : super(key: key);

  @override
  _SearchBar1State createState() => _SearchBar1State();
}

class _SearchBar1State extends State<SearchBar1> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  bool _hasText = false;

  List<Map<String, dynamic>> _lawyerSuggestions = [];
  String? _botResponse; // AI-matched practice name

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _hasText = _controller.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 🔍 Fetch direct lawyer matches by name or region (while typing)
  Future<void> _fetchLawyerSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _lawyerSuggestions = [];
        _botResponse = null;
      });
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('Role', isEqualTo: true)
          .where('Status', isEqualTo: true)
          .get();

      final queryLower = query.toLowerCase();
      final lawyers = snapshot.docs
          .map((doc) => {
                ...doc.data(),
                'userId': doc.id,
              })
          .where((lawyer) =>
              (lawyer['Fname']?.toLowerCase().contains(queryLower) ?? false) ||
              (lawyer['Lname']?.toLowerCase().contains(queryLower) ?? false) ||
              (lawyer['Region']?.toLowerCase().contains(queryLower) ?? false))
          .toList();

      setState(() {
        _lawyerSuggestions = lawyers;
        _botResponse = null;
      });
    } catch (e) {
      print('Error fetching lawyers: $e');
    }
  }

  // 🧠 Use AI to classify query into one of the practices (on Send)
  Future<void> _handleNoMatchWithAI(String query) async {
    if (query.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // Fetch available practice names
      final practiceSnapshot =
          await FirebaseFirestore.instance.collection('Practice').get();
      final practices = practiceSnapshot.docs
          .map((e) => e['Practice Name'] as String)
          .toList();

      if (practices.isEmpty) {
        print('⚠️ No practices found in database.');
        setState(() {
          _isLoading = false;
          _lawyerSuggestions = [];
          _botResponse = null;
        });
        return;
      }

      // AI prompt
      final prompt =
          "Classify the following legal issue into one of these practices: ${practices.join(', ')}. "
          "Respond ONLY with the exact name of the matching practice. "
          "Query: $query";

      final aiResponse = await OpenAIService.sendMessage(prompt);
      final cleanedResponse = aiResponse.trim();

      // Find matching practice
      QueryDocumentSnapshot<Map<String, dynamic>>? matchedPractice;
      for (var doc in practiceSnapshot.docs) {
        final name = (doc['Practice Name'] as String?)?.toLowerCase();
        if (name == cleanedResponse.toLowerCase()) {
          matchedPractice = doc;
          break;
        }
      }

      if (matchedPractice == null) {
        print(
            '⚠️ AI response "$cleanedResponse" did not match any known practice.');
        setState(() {
          _isLoading = false;
          _lawyerSuggestions = [];
          _botResponse = null;
        });
        return;
      }

      final practiceId = matchedPractice['Practice ID'];
      await _fetchLawyersByPractice(practiceId, cleanedResponse);
    } catch (e) {
      print('Error in AI handling: $e');
      setState(() => _isLoading = false);
    }
  }

  // 👩🏾‍⚖️ Fetch lawyers whose Practice ID matches AI result
  Future<void> _fetchLawyersByPractice(
      String practiceId, String practiceName) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('Role', isEqualTo: true)
          .where('Status', isEqualTo: true)
          .where('Practice ID', isEqualTo: practiceId)
          .get();

      final lawyers = snapshot.docs
          .map((doc) => {
                ...doc.data(),
                'userId': doc.id,
              })
          .toList();

      setState(() {
        _lawyerSuggestions = lawyers;
        _botResponse = practiceName;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching lawyers by practice: $e');
      setState(() => _isLoading = false);
    }
  }

  // 📨 Called when user taps Send
  void _onSendPressed() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    // If there are already matching lawyers, don't call AI
    if (_lawyerSuggestions.isNotEmpty) {
      print('✅ Direct match found. No AI needed.');
      return;
    }

    await _handleNoMatchWithAI(query);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Column(
      children: [
        // 🔍 Search Bar
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: localizations?.findLawyerOrDescribe ??
                        'Find a Lawyer or describe your issue',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                    prefixIcon: const Icon(Icons.search, color: Colors.white),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) {
                    setState(() {
                      _hasText = value.isNotEmpty;
                    });
                    _fetchLawyerSuggestions(value);
                  },
                ),
              ),
              if (_hasText && !_isLoading)
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _onSendPressed,
                ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 📜 Suggestions Section
        if (_lawyerSuggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black54,
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _botResponse != null
                        ? 'Suggested Lawyers for your issue ($_botResponse)'
                        : 'Lawyers',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[300],
                    ),
                  ),
                ),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _lawyerSuggestions.length,
                    itemBuilder: (context, index) {
                      final lawyer = _lawyerSuggestions[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DoctorProfileScreen(
                                userId: lawyer['userId'],
                                isReferral: false,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundImage: lawyer['User Pic'] != null
                                    ? CachedNetworkImageProvider(
                                        lawyer['User Pic'])
                                    : null,
                                child: lawyer['User Pic'] == null
                                    ? const Icon(Icons.person,
                                        size: 30, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${lawyer['Title'] ?? ''} ${lawyer['Lname'] ?? ''}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
