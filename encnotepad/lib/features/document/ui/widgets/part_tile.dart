import 'package:flutter/material.dart';
import '../../domain/document_model.dart';

class PartTile extends StatefulWidget {
  final String sectionId;
  final PartModel part;
  final int index;
  final int totalParts;
  final void Function(String? title, String? body) onUpdate;
  final VoidCallback onDelete;
  final void Function(int oldIndex, int newIndex) onReorder;

  const PartTile({
    super.key,
    required this.sectionId,
    required this.part,
    required this.index,
    required this.totalParts,
    required this.onUpdate,
    required this.onDelete,
    required this.onReorder,
  });

  @override
  State<PartTile> createState() => _PartTileState();
}

class _PartTileState extends State<PartTile> {
  late TextEditingController _titleController;
  late TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.part.title);
    _bodyController = TextEditingController(text: widget.part.body);
  }

  @override
  void didUpdateWidget(covariant PartTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.part.title != _titleController.text) {
      _titleController.text = widget.part.title;
    }
    if (widget.part.body != _bodyController.text) {
      _bodyController.text = widget.part.body;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF222232),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF38384E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _titleController,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Part Title (e.g. Bank Account)',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onChanged: (val) => widget.onUpdate(val, null),
                ),
              ),
              const SizedBox(width: 8),
              if (widget.index > 0)
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 16),
                  tooltip: 'Move Up',
                  onPressed: () => widget.onReorder(widget.index, widget.index - 1),
                ),
              if (widget.index < widget.totalParts - 1)
                IconButton(
                  icon: const Icon(Icons.arrow_downward, size: 16),
                  tooltip: 'Move Down',
                  onPressed: () => widget.onReorder(widget.index, widget.index + 2),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                tooltip: 'Delete Part',
                onPressed: widget.onDelete,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bodyController,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(fontSize: 13, height: 1.4),
            decoration: const InputDecoration(
              hintText: 'Enter secure details, credentials, or notes...',
              isDense: true,
              contentPadding: EdgeInsets.all(8),
            ),
            onChanged: (val) => widget.onUpdate(null, val),
          ),
        ],
      ),
    );
  }
}
