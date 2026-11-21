import 'package:flutter/material.dart';

class StatusFooter extends StatelessWidget {
  final String statusText;
  final int sectionCount;
  final int shadowCount;
  final bool isSaving;

  const StatusFooter({
    super.key,
    required this.statusText,
    required this.sectionCount,
    required this.shadowCount,
    this.isSaving = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF181824),
        border: Border(top: BorderSide(color: Color(0xFF2E2E44))),
      ),
      child: Row(
        children: [
          Icon(
            isSaving ? Icons.sync : Icons.check_circle_outline,
            size: 14,
            color: isSaving ? Colors.amber : Colors.greenAccent,
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: const TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
          ),
          const Spacer(),
          Text(
            '$sectionCount Sections',
            style: const TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
          ),
          const SizedBox(width: 16),
          Text(
            '$shadowCount Local Shadows Available',
            style: const TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
          ),
        ],
      ),
    );
  }
}
