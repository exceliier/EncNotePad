import 'package:uuid/uuid.dart';

class DocumentMeta {
  final String version;
  final String app;
  final DateTime createdAt;
  final DateTime updatedAt;

  DocumentMeta({
    required this.version,
    required this.app,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DocumentMeta.create() {
    final now = DateTime.now().toUtc();
    return DocumentMeta(
      version: '1.0',
      app: 'EncNotePad',
      createdAt: now,
      updatedAt: now,
    );
  }

  DocumentMeta copyWith({DateTime? updatedAt}) {
    return DocumentMeta(
      version: version,
      app: app,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'app': app,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory DocumentMeta.fromJson(Map<String, dynamic> json) => DocumentMeta(
    version: json['version'] as String? ?? '1.0',
    app: json['app'] as String? ?? 'EncNotePad',
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );
}

class PartModel {
  final String id;
  final String title;
  final String body;
  final int order;

  PartModel({
    required this.id,
    required this.title,
    required this.body,
    required this.order,
  });

  factory PartModel.create({String? title, String? body, int order = 0}) {
    return PartModel(
      id: 'prt_${const Uuid().v4()}',
      title: title ?? 'New Part',
      body: body ?? '',
      order: order,
    );
  }

  PartModel copyWith({String? title, String? body, int? order}) {
    return PartModel(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'order': order,
  };

  factory PartModel.fromJson(Map<String, dynamic> json) => PartModel(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    order: json['order'] as int? ?? 0,
  );
}

class SectionModel {
  final String id;
  final String title;
  final bool isCollapsed;
  final int order;
  final List<PartModel> parts;

  SectionModel({
    required this.id,
    required this.title,
    required this.isCollapsed,
    required this.order,
    required this.parts,
  });

  factory SectionModel.create({String? title, int order = 0, bool isCollapsed = false}) {
    return SectionModel(
      id: 'sec_${const Uuid().v4()}',
      title: title ?? 'New Section',
      isCollapsed: isCollapsed,
      order: order,
      parts: [PartModel.create()],
    );
  }

  SectionModel copyWith({
    String? title,
    bool? isCollapsed,
    int? order,
    List<PartModel>? parts,
  }) {
    return SectionModel(
      id: id,
      title: title ?? this.title,
      isCollapsed: isCollapsed ?? this.isCollapsed,
      order: order ?? this.order,
      parts: parts ?? this.parts,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'is_collapsed': isCollapsed,
    'order': order,
    'parts': parts.map((p) => p.toJson()).toList(),
  };

  factory SectionModel.fromJson(Map<String, dynamic> json) => SectionModel(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    isCollapsed: json['is_collapsed'] as bool? ?? false,
    order: json['order'] as int? ?? 0,
    parts: (json['parts'] as List<dynamic>? ?? [])
        .map((p) => PartModel.fromJson(p as Map<String, dynamic>))
        .toList(),
  );
}

class DocumentModel {
  final DocumentMeta meta;
  final List<SectionModel> sections;

  DocumentModel({
    required this.meta,
    required this.sections,
  });

  factory DocumentModel.create({String? firstSectionTitle}) {
    return DocumentModel(
      meta: DocumentMeta.create(),
      sections: [SectionModel.create(title: firstSectionTitle ?? 'Default Section', isCollapsed: true)],
    );
  }

  DocumentModel copyWith({
    DocumentMeta? meta,
    List<SectionModel>? sections,
  }) {
    return DocumentModel(
      meta: meta ?? this.meta.copyWith(),
      sections: sections ?? this.sections,
    );
  }

  Map<String, dynamic> toJson() => {
    'meta': meta.toJson(),
    'content': sections.map((s) => s.toJson()).toList(),
  };

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      meta: DocumentMeta.fromJson(json['meta'] as Map<String, dynamic>),
      sections: (json['content'] as List<dynamic>? ?? [])
          .map((s) => SectionModel.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}
