import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nhap/l10n/app_localizations.dart';
import '../../Hospital/doctor_profile.dart';
import '../../bot/widget/openai_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nhap/utils/country_utils.dart';

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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final meSnap = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();
      final myCountry = effectiveCountryCode(meSnap.data());

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
              effectiveCountryCode(Map<String, dynamic>.from(lawyer)) ==
                  myCountry &&
              ((lawyer['Fname']?.toLowerCase().contains(queryLower) ??
                      false) ||
                  (lawyer['Lname']?.toLowerCase().contains(queryLower) ??
                      false) ||
                  (lawyer['Region']?.toLowerCase().contains(queryLower) ??
                      false)))
          .toList();

      setState(() {
        _lawyerSuggestions = lawyers;
        _botResponse = null;
      });
    } catch (e, st) {
      debugPrint('Error fetching lawyers: $e\n$st');
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
          .map((e) => e.data()['Practice Name'] as String?)
          .whereType<String>()
          .where((n) => n.trim().isNotEmpty)
          .toList();

      if (practices.isEmpty) {
        debugPrint('⚠️ No practices found in database.');
        setState(() {
          _isLoading = false;
          _lawyerSuggestions = [];
          _botResponse = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Practice areas are not available yet.'),
            ),
          );
        }
        return;
      }

      final aiResponse = await OpenAIService.classifyPractice(
        userQuery: query,
        practiceNames: practices,
      );
      if (aiResponse.isEmpty) {
        setState(() {
          _isLoading = false;
          _lawyerSuggestions = [];
          _botResponse = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not match your issue to a practice. Try different words or check your connection.',
              ),
            ),
          );
        }
        return;
      }

      final matchedPractice =
          _matchPracticeDocument(aiResponse, practiceSnapshot.docs);
      if (matchedPractice == null) {
        debugPrint(
            '⚠️ AI practice match failed for: ${aiResponse.trim()}');
        setState(() {
          _isLoading = false;
          _lawyerSuggestions = [];
          _botResponse = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No matching practice area was found. Try describing your issue differently.',
              ),
            ),
          );
        }
        return;
      }

      final practiceName =
          matchedPractice['Practice Name'] as String? ?? aiResponse.trim();
      final practiceId = matchedPractice['Practice ID'];
      await _fetchLawyersByPractice(practiceId, practiceName);
    } catch (e, st) {
      debugPrint('Error in AI handling: $e\n$st');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
          ),
        );
      }
    }
  }

  // 👩🏾‍⚖️ Fetch lawyers whose Practice ID matches AI result
  Future<void> _fetchLawyersByPractice(
      dynamic practiceId, String practiceName) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('Users')
              .where('Role', isEqualTo: true)
              .where('Status', isEqualTo: true)
              .where('Practice ID', isEqualTo: practiceId)
              .get();

      if (snapshot.docs.isEmpty && practiceId != null) {
        final asInt = practiceId is int
            ? practiceId
            : int.tryParse(practiceId.toString());
        if (asInt != null) {
          snapshot = await FirebaseFirestore.instance
              .collection('Users')
              .where('Role', isEqualTo: true)
              .where('Status', isEqualTo: true)
              .where('Practice ID', isEqualTo: asInt)
              .get();
        }
      }

      if (snapshot.docs.isEmpty &&
          practiceId != null &&
          practiceId.toString().trim().isNotEmpty) {
        final asString = practiceId.toString().trim();
        snapshot = await FirebaseFirestore.instance
            .collection('Users')
            .where('Role', isEqualTo: true)
            .where('Status', isEqualTo: true)
            .where('Practice ID', isEqualTo: asString)
            .get();
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _lawyerSuggestions = [];
          _botResponse = null;
          _isLoading = false;
        });
        return;
      }

      final meSnap = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();
      final myCountry = effectiveCountryCode(meSnap.data());

      final lawyers = snapshot.docs
          .map((doc) => {
                ...doc.data(),
                'userId': doc.id,
              })
          .where((lawyer) =>
              effectiveCountryCode(Map<String, dynamic>.from(lawyer)) ==
              myCountry)
          .toList();

      setState(() {
        _lawyerSuggestions = lawyers;
        _botResponse = practiceName;
        _isLoading = false;
      });

      if (lawyers.isEmpty && mounted) {
        final message = snapshot.docs.isNotEmpty
            ? 'No lawyers in your country for $practiceName yet.'
            : 'No lawyers listed for $practiceName yet.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      debugPrint('Error fetching lawyers by practice: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Refresh name/region matches for the current query, then run AI classification only if still empty.
  Future<void> _onSendPressed() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _fetchLawyerSuggestions(query);

      if (_lawyerSuggestions.isNotEmpty) {
        setState(() {
          _isLoading = false;
          _botResponse = null;
        });
        return;
      }

      if (FirebaseAuth.instance.currentUser == null) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sign in to find lawyers by legal issue.'),
            ),
          );
        }
        return;
      }

      await _handleNoMatchWithAI(query);
    } catch (e, st) {
      debugPrint('Find lawyer send error: $e\n$st');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not complete search. Please try again.'),
          ),
        );
      }
    }
  }

  /// Maps AI output to a Firestore practice doc (handles quotes / partial matches).
  Map<String, dynamic>? _matchPracticeDocument(
    String aiRaw,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    var cleaned = aiRaw.trim();
    if (cleaned.length >= 2) {
      final a = cleaned[0];
      final b = cleaned[cleaned.length - 1];
      if ((a == '"' || a == "'") && a == b) {
        cleaned = cleaned.substring(1, cleaned.length - 1).trim();
      }
    }
    final lower = cleaned.toLowerCase();

    for (final doc in docs) {
      final data = doc.data();
      final name = (data['Practice Name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      final nl = name.toLowerCase();
      if (lower == nl || lower.contains(nl) || nl.contains(lower)) {
        return data;
      }
    }

    for (final doc in docs) {
      final data = doc.data();
      final name = (data['Practice Name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      final nl = name.toLowerCase();
      final words = nl.split(RegExp(r'\s+'));
      var hits = 0;
      for (final w in words) {
        if (w.length > 2 && lower.contains(w)) hits++;
      }
      if (hits >= 2 || (hits == 1 && words.length == 1)) {
        return data;
      }
    }

    return null;
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
                                '${lawyer['Fname'] ?? ''} ${lawyer['Lname'] ?? ''}'
                                    .trim(),
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
