import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Forums/Public/Widgets/user_profile_screen.dart';

class LawyerDirectoryPage extends StatefulWidget {
  const LawyerDirectoryPage({super.key});

  @override
  State<LawyerDirectoryPage> createState() => _LawyerDirectoryPageState();
}

class _LawyerDirectoryPageState extends State<LawyerDirectoryPage> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedSpecialty;
  String _searchQuery = '';

  static const List<String> _specialties = [
    'All',
    'Criminal Law',
    'Family Law',
    'Corporate Law',
    'Property Law',
    'Employment Law',
    'Immigration Law',
    'Human Rights',
    'Tax Law',
    'Intellectual Property',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Lawyer Directory',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search lawyers by name...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon:
                        const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                ),
              ),
              SizedBox(
                height: 42,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  itemCount: _specialties.length,
                  itemBuilder: (context, i) {
                    final specialty = _specialties[i];
                    final isSelected = _selectedSpecialty == specialty ||
                        (specialty == 'All' && _selectedSpecialty == null);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(specialty),
                        selected: isSelected,
                        onSelected: (_) => setState(() {
                          _selectedSpecialty =
                              specialty == 'All' ? null : specialty;
                        }),
                        selectedColor: Colors.white,
                        backgroundColor: Colors.grey[900],
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontSize: 12,
                        ),
                        showCheckmark: false,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Users')
            .where('Role', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }

          var lawyers = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final fullName =
                '${data['Fname'] ?? ''} ${data['Lname'] ?? ''}'.toLowerCase();

            if (_searchQuery.isNotEmpty &&
                !fullName.contains(_searchQuery.toLowerCase())) {
              return false;
            }
            if (_selectedSpecialty != null) {
              final specialty =
                  (data['Specialty'] as String? ?? '').toLowerCase();
              if (!specialty
                  .contains(_selectedSpecialty!.toLowerCase())) {
                return false;
              }
            }
            return true;
          }).toList();

          if (lawyers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_search,
                      size: 60, color: Colors.grey[700]),
                  const SizedBox(height: 16),
                  const Text('No lawyers found',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  if (_selectedSpecialty != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          setState(() => _selectedSpecialty = null),
                      child: const Text('Clear filter'),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: lawyers.length,
            itemBuilder: (context, index) {
              final data =
                  lawyers[index].data() as Map<String, dynamic>;
              final fullName =
                  '${data['Fname'] ?? ''} ${data['Lname'] ?? ''}'.trim();
              final pic = data['User Pic'] as String? ?? '';
              final specialty = data['Specialty'] as String? ?? '';
              final userId = data['User ID'] as String? ?? '';

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 26,
                  backgroundImage:
                      pic.isNotEmpty ? NetworkImage(pic) : null,
                  backgroundColor: Colors.grey[800],
                  child: pic.isEmpty
                      ? Text(
                          fullName.isNotEmpty
                              ? fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 20),
                        )
                      : null,
                ),
                title: Text(
                  fullName,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: specialty.isNotEmpty
                    ? Text(specialty,
                        style: TextStyle(color: Colors.grey[400]))
                    : const Text('Lawyer',
                        style: TextStyle(color: Colors.grey)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent[700],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'View',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                onTap: userId.isNotEmpty
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                UserProfileScreen(userId: userId),
                          ),
                        )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
