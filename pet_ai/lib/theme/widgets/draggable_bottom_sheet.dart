import 'package:flutter/material.dart';

class DraggableBottomSheet extends StatefulWidget {
  final Map<String, String> allItems;
  final String hintText;
  final ScrollController? scrollController;

  const DraggableBottomSheet({
    super.key,
    required this.allItems,
    required this.hintText,
    this.scrollController,
  });

  @override
  State<DraggableBottomSheet> createState() => _DraggableBottomSheetState();
}

class _DraggableBottomSheetState extends State<DraggableBottomSheet> {
  late Map<String, String> _filtered;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.allItems;
    _searchCtrl.addListener(_filter);
  }

  void _filter() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered =
          widget.allItems.entries.where(
                (e) => e.value.toLowerCase().contains(query),
              )
              as Map<String, String>;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 12,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 5,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: widget.hintText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text(
                      'Ничего не найдено',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: widget.scrollController,
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final id = _filtered.keys.elementAt(index);
                      final name = _filtered.values.elementAt(index);
                      return ListTile(
                        title: Text(name),
                        onTap: () => Navigator.pop(context, id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
