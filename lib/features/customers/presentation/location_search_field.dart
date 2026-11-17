import 'package:flutter/material.dart';

/// County, sub-county, or ward picker you can type into.
///
/// [items] holds 0–2000 names. A blank search shows every name. Typing keeps
/// names that contain the text, ignoring case. [allowAll] adds an All row
/// for list filters. Choosing a name calls [onChanged] with that name, or
/// with an empty string for All.
class LocationSearchField extends StatelessWidget {
  const LocationSearchField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.allowAll = false,
    this.enabled = true,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final bool allowAll;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final shown = value.trim().isEmpty ? (allowAll ? 'All' : '') : value;
    return InkWell(
      onTap: enabled ? () => _open(context) : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: const Icon(Icons.search),
        ),
        child: Text(
          shown.isEmpty ? 'Choose' : shown,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LocationSearchSheet(
        label: label,
        items: items,
        allowAll: allowAll,
      ),
    );
    if (picked != null) onChanged(picked);
  }
}

class _LocationSearchSheet extends StatefulWidget {
  const _LocationSearchSheet({
    required this.label,
    required this.items,
    required this.allowAll,
  });

  final String label;
  final List<String> items;
  final bool allowAll;

  @override
  State<_LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<_LocationSearchSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typed = _query.text.trim().toLowerCase();
    final shown = typed.isEmpty
        ? widget.items
        : widget.items
            .where((name) => name.toLowerCase().contains(typed))
            .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                key: Key('location_search_${widget.label}'),
                controller: _query,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Search ${widget.label.toLowerCase()}',
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  if (widget.allowAll && typed.isEmpty)
                    ListTile(
                      title: const Text('All'),
                      onTap: () => Navigator.of(context).pop(''),
                    ),
                  if (shown.isEmpty)
                    const ListTile(title: Text('No match')),
                  for (final name in shown)
                    ListTile(
                      key: Key('location_choice_$name'),
                      title: Text(name),
                      onTap: () => Navigator.of(context).pop(name),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
