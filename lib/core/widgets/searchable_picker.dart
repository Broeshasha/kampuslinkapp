import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A reusable bottom-sheet search picker for any labeled list —
/// used for country, university, and speciality selection.
class SearchablePicker<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) labelBuilder;
  final VoidCallback? onNotListed;

  const SearchablePicker({
    super.key,
    required this.title,
    required this.items,
    required this.labelBuilder,
    this.onNotListed,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required List<T> items,
    required String Function(T) labelBuilder,
    VoidCallback? onNotListed,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SearchablePicker<T>(
        title: title,
        items: items,
        labelBuilder: labelBuilder,
        onNotListed: onNotListed,
      ),
    );
  }

  @override
  State<SearchablePicker<T>> createState() => _SearchablePickerState<T>();
}

class _SearchablePickerState<T> extends State<SearchablePicker<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items
        .where((item) =>
            widget.labelBuilder(item).toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(widget.title,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final item = filtered[i];
                  return ListTile(
                    title: Text(widget.labelBuilder(item),
                        style: const TextStyle(color: Colors.white)),
                    onTap: () => Navigator.of(context).pop(item),
                  );
                },
              ),
            ),
            if (widget.onNotListed != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onNotListed!();
                  },
                  child: const Text("Can't find it? Tell us",
                      style: TextStyle(color: AppColors.accent)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}