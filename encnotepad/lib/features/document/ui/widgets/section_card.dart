import 'package:flutter/material.dart';
import '../../domain/document_model.dart';
import 'part_tile.dart';

class SectionCard extends StatefulWidget {
  final SectionModel section;
  final int index;
  final int totalSections;
  final bool isHighlighted;
  final String? highlightedPartId;
  final Set<String>? forcedExpandedPartIds;
  final Map<String, GlobalKey>? partKeys;
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
    this.isHighlighted = false,
    this.highlightedPartId,
    this.forcedExpandedPartIds,
    this.partKeys,
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
  final Set<String> _visibleDetailPartIds = {};

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.section.title);
    if (widget.forcedExpandedPartIds != null) {
      _visibleDetailPartIds.addAll(widget.forcedExpandedPartIds!);
    }
  }

  @override
  void didUpdateWidget(covariant SectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.section.title != _titleController.text) {
      _titleController.text = widget.section.title;
    }
    // If the section was just opened (collapsed -> uncollapsed), reset part details to hidden
    // per Requirement 1: "initialy when section opened disply only Part Titles"
    if (oldWidget.section.isCollapsed && !widget.section.isCollapsed) {
      _visibleDetailPartIds.clear();
    }
    if (widget.forcedExpandedPartIds != null) {
      _visibleDetailPartIds.addAll(widget.forcedExpandedPartIds!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allDetailsVisible = widget.section.parts.isNotEmpty &&
        widget.section.parts.every((p) => _visibleDetailPartIds.contains(p.id));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: widget.isHighlighted ? Colors.amberAccent : const Color(0xFF38384E),
            width: widget.isHighlighted ? 2.0 : 1.0,
          ),
        ),
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
                    tooltip: widget.section.isCollapsed ? 'Expand Section' : 'Collapse Section',
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
                  if (!widget.section.isCollapsed && widget.section.parts.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        allDetailsVisible ? Icons.visibility : Icons.visibility_off,
                        size: 18,
                        color: allDetailsVisible ? Colors.lightBlueAccent : Colors.white60,
                      ),
                      tooltip: allDetailsVisible
                          ? 'Hide All Part Details in Section'
                          : 'Show All Part Details in Section',
                      onPressed: () {
                        setState(() {
                          if (allDetailsVisible) {
                            _visibleDetailPartIds.clear();
                          } else {
                            _visibleDetailPartIds.addAll(widget.section.parts.map((p) => p.id));
                          }
                        });
                      },
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
                    key: widget.partKeys?[widget.section.parts[i].id] ??
                        ValueKey(widget.section.parts[i].id),
                    sectionId: widget.section.id,
                    part: widget.section.parts[i],
                    index: i,
                    totalParts: widget.section.parts.length,
                    isDetailsVisible: _visibleDetailPartIds.contains(widget.section.parts[i].id),
                    isHighlighted: widget.highlightedPartId == widget.section.parts[i].id,
                    onToggleDetails: () {
                      setState(() {
                        final pId = widget.section.parts[i].id;
                        if (_visibleDetailPartIds.contains(pId)) {
                          _visibleDetailPartIds.remove(pId);
                        } else {
                          _visibleDetailPartIds.add(pId);
                        }
                      });
                    },
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
                  onPressed: () {
                    widget.onAddPart();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
