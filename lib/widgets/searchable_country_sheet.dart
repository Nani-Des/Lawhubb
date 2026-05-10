import 'package:flutter/material.dart';
import 'package:nhap/utils/country_utils.dart';

/// Searchable bottom sheet; returns selected ISO alpha-2 code or null if dismissed.
Future<String?> showSearchableCountryPicker(
  BuildContext context, {
  String title = 'Select your country',
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.grey[900],
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return _SearchableCountryBody(title: title);
    },
  );
}

class _SearchableCountryBody extends StatefulWidget {
  const _SearchableCountryBody({required this.title});

  final String title;

  @override
  State<_SearchableCountryBody> createState() => _SearchableCountryBodyState();
}

class _SearchableCountryBodyState extends State<_SearchableCountryBody> {
  final _filter = TextEditingController();
  List<Map<String, String>> _filtered = List.from(kCountryChoices);

  @override
  void initState() {
    super.initState();
    _filter.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _filter.removeListener(_applyFilter);
    _filter.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _filter.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List.from(kCountryChoices);
      } else {
        _filtered = kCountryChoices
            .where((e) {
              final name = (e['name'] ?? '').toLowerCase();
              final code = (e['code'] ?? '').toLowerCase();
              return name.contains(q) || code.contains(q);
            })
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: pad.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white70),
              ),
            ],
          ),
          TextField(
            controller: _filter,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by name or code',
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: Colors.grey[850],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final row = _filtered[index];
                final code = row['code'] ?? '';
                final name = row['name'] ?? '';
                return ListTile(
                  title: Text(
                    name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    code,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  onTap: () => Navigator.pop(context, code),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
