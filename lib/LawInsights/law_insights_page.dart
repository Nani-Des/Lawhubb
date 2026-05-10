import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nhap/l10n/app_localizations.dart';
import '../Auth/login_required_shell.dart';
import 'create_insight_dialog.dart';
import 'insight_card.dart';
import 'Services/law_insights_service.dart';
import '../../Services/follow_service.dart';

class LawInsightsPage extends StatefulWidget {
  const LawInsightsPage({super.key});

  @override
  State<LawInsightsPage> createState() => _LawInsightsPageState();
}

class _LawInsightsPageState extends State<LawInsightsPage> {
  final LawInsightsService _service = LawInsightsService();
  final FollowService _followService = FollowService();
  final ScrollController _scrollController = ScrollController();
  String _selectedFilter = 'All';
  Set<String> _followingList = {};

  @override
  void initState() {
    super.initState();
    // Clean up expired insights on load
    _service.cleanExpiredInsights();
    _loadFollowingList();
  }

  Future<void> _loadFollowingList() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final following =
            await _followService.getFollowingList(currentUser.uid);
        setState(() {
          _followingList = following.toSet();
        });
      } catch (e) {
        debugPrint('Error loading following list: $e');
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshInsights() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() {});
  }

  Future<bool> _isLawyer() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final userDoc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) return false;
    return userDoc.data()?['Role'] == true;
  }

  void _showAccessDeniedDialog() {
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          localizations?.accessDenied ?? 'Access Denied',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          localizations?.onlyLawyersCanShare ??
              'Only Lawyers can share videos and content on Law Insights.',
          style: const TextStyle(color: Colors.grey),
        ),
        backgroundColor: Colors.grey[900],
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              localizations?.ok ?? 'OK',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      final localizations = AppLocalizations.of(context);
      return LoginRequiredShell(
        title: localizations?.lawInsights ?? 'Law Insights',
        message: 'Sign in to browse Law Insights.',
        onAuthResolved: () => setState(() {}),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.grey[800]!,
                ),
              ),
              child: const Icon(
                Icons.lightbulb_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              AppLocalizations.of(context)?.lawInsights ?? 'Law Insights',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: () async {
              final isLawyer = await _isLawyer();
              if (!isLawyer) {
                _showAccessDeniedDialog();
                return;
              }
              final result = await showDialog(
                context: context,
                builder: (context) =>
                    CreateInsightDialog(userId: currentUser.uid),
              );
              if (result == true) {
                _refreshInsights();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshInsights,
        color: Colors.white,
        backgroundColor: Colors.grey[900],
        child: Column(
          children: [
            // Filter chips
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(
                    label: AppLocalizations.of(context)?.filterAll ?? 'All',
                    isSelected: _selectedFilter == 'All',
                    onTap: () => setState(() => _selectedFilter = 'All'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: AppLocalizations.of(context)?.filterCases ?? 'Cases',
                    isSelected: _selectedFilter == 'Cases',
                    onTap: () => setState(() => _selectedFilter = 'Cases'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: AppLocalizations.of(context)?.filterLegalIssues ??
                        'Legal Issues',
                    isSelected: _selectedFilter == 'Legal Issues',
                    onTap: () =>
                        setState(() => _selectedFilter = 'Legal Issues'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: AppLocalizations.of(context)?.filterLegalTopics ??
                        'Legal Topics',
                    isSelected: _selectedFilter == 'Legal Topics',
                    onTap: () =>
                        setState(() => _selectedFilter = 'Legal Topics'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: AppLocalizations.of(context)?.filterTrending ??
                        'Trending',
                    isSelected: _selectedFilter == 'Trending',
                    onTap: () => setState(() => _selectedFilter = 'Trending'),
                  ),
                ],
              ),
            ),
            // Insights feed
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _selectedFilter == 'All'
                    ? _service.getInsightsStream()
                    : _selectedFilter == 'Trending'
                        ? _service.getTrendingInsightsStream()
                        : _service.getInsightsByCategoryStream(_selectedFilter),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 64,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(context)?.noInsightsYet ??
                                'No insights yet',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)?.beFirstToShare ??
                                'Be the first to share your legal insights!',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final insights = snapshot.data!.docs;

                  // Sort insights: followed users first, then by date (newest first)
                  final sortedInsights =
                      List<QueryDocumentSnapshot>.from(insights);
                  sortedInsights.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;

                    final aUserId = aData['userId'] as String? ?? '';
                    final bUserId = bData['userId'] as String? ?? '';

                    final aIsFollowed = _followingList.contains(aUserId);
                    final bIsFollowed = _followingList.contains(bUserId);

                    // If one is followed and the other isn't, prioritize followed
                    if (aIsFollowed && !bIsFollowed) return -1;
                    if (!aIsFollowed && bIsFollowed) return 1;

                    // If both are followed or both aren't, sort by timestamp (newest first)
                    final aTimestamp = aData['createdAt'] as Timestamp?;
                    final bTimestamp = bData['createdAt'] as Timestamp?;

                    if (aTimestamp == null && bTimestamp == null) return 0;
                    if (aTimestamp == null) return 1;
                    if (bTimestamp == null) return -1;

                    return bTimestamp.compareTo(aTimestamp);
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: sortedInsights.length,
                    itemBuilder: (context, index) {
                      final insight = sortedInsights[index];
                      return InsightCard(
                        insightId: insight.id,
                        insightData: insight.data() as Map<String, dynamic>,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.grey[800]!,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
