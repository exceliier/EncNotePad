enum ShadowTrigger {
  sessionOpen,
  milestone,
  manual,
}

class ShadowModel {
  final String filename;
  final String filePath;
  final int sequenceNumber;
  final DateTime timestamp;
  final ShadowTrigger trigger;
  final int fileSizeBytes;
  final int sectionCount;
  final int partCount;

  ShadowModel({
    required this.filename,
    required this.filePath,
    required this.sequenceNumber,
    required this.timestamp,
    required this.trigger,
    required this.fileSizeBytes,
    required this.sectionCount,
    required this.partCount,
  });

  Map<String, dynamic> toJson() => {
    'filename': filename,
    'sequence_number': sequenceNumber,
    'timestamp': timestamp.toIso8601String(),
    'trigger': trigger.name,
    'file_size_bytes': fileSizeBytes,
    'section_count': sectionCount,
    'part_count': partCount,
  };

  factory ShadowModel.fromJson(Map<String, dynamic> json, String directoryPath) {
    final fname = json['filename'] as String;
    return ShadowModel(
      filename: fname,
      filePath: '$directoryPath/$fname',
      sequenceNumber: json['sequence_number'] as int? ?? 1,
      timestamp: DateTime.parse(json['timestamp'] as String),
      trigger: ShadowTrigger.values.firstWhere(
        (t) => t.name == json['trigger'],
        orElse: () => ShadowTrigger.milestone,
      ),
      fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
      sectionCount: json['section_count'] as int? ?? 0,
      partCount: json['part_count'] as int? ?? 0,
    );
  }
}
