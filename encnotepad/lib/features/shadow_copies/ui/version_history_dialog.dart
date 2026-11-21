import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../domain/shadow_model.dart';

class VersionHistoryDialog extends StatefulWidget {
  final List<ShadowModel> shadows;
  final void Function(ShadowModel shadow) onRestore;

  const VersionHistoryDialog({
    super.key,
    required this.shadows,
    required this.onRestore,
  });

  @override
  State<VersionHistoryDialog> createState() => _VersionHistoryDialogState();
}

class _VersionHistoryDialogState extends State<VersionHistoryDialog> {
  ShadowModel? _selectedShadow;

  @override
  void initState() {
    super.initState();
    if (widget.shadows.isNotEmpty) {
      _selectedShadow = widget.shadows.last;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.history, color: Colors.lightBlueAccent),
          SizedBox(width: 8),
          Text('Local Version History (Shadow Copies)'),
        ],
      ),
      content: SizedBox(
        width: 700,
        height: 450,
        child: widget.shadows.isEmpty
            ? const Center(child: Text('No local shadow copies available yet.'))
            : Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ListView.builder(
                      itemCount: widget.shadows.length,
                      itemBuilder: (context, index) {
                        final shadow = widget.shadows[widget.shadows.length - 1 - index];
                        final isSelected = _selectedShadow?.filename == shadow.filename;

                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: const Color(0xFF2E2E44),
                          leading: Icon(
                            shadow.trigger == ShadowTrigger.sessionOpen
                                ? Icons.lock_open
                                : (shadow.trigger == ShadowTrigger.manual
                                    ? Icons.bookmark
                                    : Icons.timer),
                            size: 18,
                            color: isSelected ? Colors.lightBlueAccent : Colors.white70,
                          ),
                          title: Text(
                            shadow.filename,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${dateFormat.format(shadow.timestamp)} • ${(shadow.fileSizeBytes / 1024).toStringAsFixed(1)} KB',
                            style: const TextStyle(fontSize: 11, color: Colors.white54),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedShadow = shadow;
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const VerticalDivider(color: Color(0xFF38384E)),
                  Expanded(
                    flex: 3,
                    child: _selectedShadow == null
                        ? const Center(child: Text('Select a snapshot to preview'))
                        : Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedShadow!.filename,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text('Created: ${dateFormat.format(_selectedShadow!.timestamp)}'),
                                Text('Trigger: ${_selectedShadow!.trigger.name}'),
                                Text('File Size: ${(_selectedShadow!.fileSizeBytes / 1024).toStringAsFixed(2)} KB'),
                                Text('Sections: ${_selectedShadow!.sectionCount}'),
                                Text('Total Parts: ${_selectedShadow!.partCount}'),
                                const Spacer(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.restore),
                                      label: const Text('Restore This Snapshot'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        widget.onRestore(_selectedShadow!);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
