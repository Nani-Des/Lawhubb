import 'package:flutter/material.dart';

class SearchableOption {
  const SearchableOption({
    required this.id,
    required this.label,
    this.subtitle,
  });

  final String id;
  final String label;
  final String? subtitle;
}

/// Searchable bottom sheet with multi-select; returns selected option ids in order.
Future<List<String>> showSearchableMultiOptionPicker(
  BuildContext context, {
  required String title,
  required List<SearchableOption> options,
  String searchHint = 'Search…',
  List<String> initialSelectedIds = const [],
}) async {
  if (options.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('No options available right now.'),
        backgroundColor: Colors.redAccent,
      ),
    );
    return const [];
  }

  final result = await showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.grey[900],
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return _SearchableMultiOptionBody(
        title: title,
        options: options,
        searchHint: searchHint,
        initialSelectedIds: initialSelectedIds,
      );
    },
  );
  return result ?? const [];
}

/// Searchable bottom sheet; returns selected option id or null if dismissed.
Future<String?> showSearchableOptionPicker(
  BuildContext context, {
  required String title,
  required List<SearchableOption> options,
  String searchHint = 'Search…',
}) async {
  if (options.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('No options available right now.'),
        backgroundColor: Colors.redAccent,
      ),
    );
    return null;
  }

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.grey[900],
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return _SearchableOptionBody(
        title: title,
        options: options,
        searchHint: searchHint,
      );
    },
  );
}

class _SearchableMultiOptionBody extends StatefulWidget {
  const _SearchableMultiOptionBody({
    required this.title,
    required this.options,
    required this.searchHint,
    required this.initialSelectedIds,
  });

  final String title;
  final List<SearchableOption> options;
  final String searchHint;
  final List<String> initialSelectedIds;

  @override
  State<_SearchableMultiOptionBody> createState() =>
      _SearchableMultiOptionBodyState();
}

class _SearchableMultiOptionBodyState extends State<_SearchableMultiOptionBody> {
  final _filter = TextEditingController();
  late List<SearchableOption> _filtered;
  late List<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.options);
    _selectedIds = List.from(widget.initialSelectedIds);
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
        _filtered = List.from(widget.options);
      } else {
        _filtered = widget.options
            .where((e) {
              final label = e.label.toLowerCase();
              final subtitle = (e.subtitle ?? '').toLowerCase();
              return label.contains(q) ||
                  subtitle.contains(q) ||
                  e.id.toLowerCase().contains(q);
            })
            .toList();
      }
    });
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
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
          Text(
            'Select one or more. The first selected becomes your primary practice.',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _filter,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: widget.searchHint,
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
            height: MediaQuery.sizeOf(context).height * 0.5,
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'No matches found.',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final row = _filtered[index];
                      final selected = _selectedIds.contains(row.id);
                      final order = selected ? _selectedIds.indexOf(row.id) + 1 : null;
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (_) => _toggle(row.id),
                        title: Text(
                          row.label,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: row.subtitle != null
                            ? Text(
                                row.subtitle!,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              )
                            : order == 1
                                ? Text(
                                    'Primary practice',
                                    style: TextStyle(
                                      color: Colors.tealAccent.withValues(alpha: 0.9),
                                      fontSize: 12,
                                    ),
                                  )
                                : order != null
                                    ? Text(
                                        'Additional practice $order',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12,
                                        ),
                                      )
                                    : null,
                        activeColor: Colors.tealAccent,
                        checkColor: Colors.black,
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _selectedIds.isEmpty
                ? null
                : () => Navigator.pop(context, _selectedIds),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              _selectedIds.isEmpty
                  ? 'Select at least one practice'
                  : 'Confirm (${_selectedIds.length} selected)',
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchableOptionBody extends StatefulWidget {
  const _SearchableOptionBody({
    required this.title,
    required this.options,
    required this.searchHint,
  });

  final String title;
  final List<SearchableOption> options;
  final String searchHint;

  @override
  State<_SearchableOptionBody> createState() => _SearchableOptionBodyState();
}

class _SearchableOptionBodyState extends State<_SearchableOptionBody> {
  final _filter = TextEditingController();
  late List<SearchableOption> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.options);
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
        _filtered = List.from(widget.options);
      } else {
        _filtered = widget.options
            .where((e) {
              final label = e.label.toLowerCase();
              final subtitle = (e.subtitle ?? '').toLowerCase();
              return label.contains(q) ||
                  subtitle.contains(q) ||
                  e.id.toLowerCase().contains(q);
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
              hintText: widget.searchHint,
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
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'No matches found.',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final row = _filtered[index];
                      return ListTile(
                        title: Text(
                          row.label,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: row.subtitle != null
                            ? Text(
                                row.subtitle!,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              )
                            : null,
                        onTap: () => Navigator.pop(context, row.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
