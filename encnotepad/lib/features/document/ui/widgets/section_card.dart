import 'package:flutter/material.dart';
import '../../domain/document_model.dart';
import 'part_tile.dart';

class SectionCard extends StatefulWidget {
  final SectionModel section;
  final int index;
  final int totalSections;
  final void Function(String title) onTitleChanged;
  final VoidCallback onToggleCollapse;
  final VoidCallback onDelete;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onAddPart;
  final void Function(String partId, String? title, String? body) onUpdatePart;
  final void Function(String partId) onDeletePart;
  final void Function(int oldIdx, int newIdx) onReorderPart;

  const SectionCard({
    super.key,
    required this.section,
    required this.index,
    required this.totalSections,
    required this.onTitleChanged,
    required this.onToggleCollapse,
    required this.onDelete,
    required this.onReorder,
    required this.onAddPart,
    required this.onUpdatePart,
    required this.onDeletePart,
    required this.onReorderPart,
  });

  @override
  State<SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<SectionCard> {
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.section.title);
  }

  @override
  void didUpdateWidget(covariant SectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.section.title != _titleController.text) {
      _titleController.text = widget.section.title;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    widget.section.isCollapsed ? Icons.arrow_right : Icons.arrow_drop_down,
                    size: 24,
                  ),
                  tooltip: widget.section.isCollapsed ? 'Expand' : 'Collapse',
                  onPressed: widget.onToggleCollapse,
                ),
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Section Title',
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      suffixText: '(${widget.section.parts.length} parts)',
                    ),
                    onChanged: widget.onTitleChanged,
                  ),
                ),
                if (widget.index > 0)
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    tooltip: 'Move Section Up',
                    onPressed: () => widget.onReorder(widget.index, widget.index - 1),
                  ),
                if (widget.index < widget.totalSections - 1)
                  IconButton(
                    icon: const Icon(Icons.arrow_downward, size: 18),
                    tooltip: 'Move Section Down',
                    onPressed: () => widget.onReorder(widget.index, widget.index + 2),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                  tooltip: 'Delete Section',
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            if (!widget.section.isCollapsed) ...[
              const Divider(color: Color(0xFF38384E)),
              const SizedBox(height: 4),
              for (int i = 0; i < widget.section.parts.length; i++)
                PartTile(
                  key: ValueKey(widget.section.parts[i].id),
                  sectionId: widget.section.id,
                  part: widget.section.parts[i],
                  index: i,
                  totalParts: widget.section.parts.length,
                  onUpdate: (title, body) =>
                      widget.onUpdatePart(widget.section.parts[i].id, title, body),
                  onDelete: () => widget.onDeletePart(widget.section.parts[i].id),
                  onReorder: widget.onReorderPart,
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Part'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.lightBlueAccent,
                  side: const BorderSide(color: Color(0xFF38384E)),
                ),
                onPressed: widget.onAddPart,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
