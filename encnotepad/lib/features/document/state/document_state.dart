import 'dart:typed_data';
import '../domain/document_model.dart';
import '../../shadow_copies/domain/shadow_model.dart';

abstract class DocumentState {}

class DocumentIdleState extends DocumentState {}

class DocumentLoadingState extends DocumentState {
  final String message;
  DocumentLoadingState({this.message = 'Processing...'});
}

class DocumentActiveState extends DocumentState {
  final DocumentModel document;
  final String filePath;
  final Uint8List salt;
  final int kdfId;
  final bool isDirty;
  final bool isSaving;
  final String statusText;
  final List<ShadowModel> shadowCopies;
  final String searchQuery;

  DocumentActiveState({
    required this.document,
    required this.filePath,
    required this.salt,
    required this.kdfId,
    this.isDirty = false,
    this.isSaving = false,
    this.statusText = 'All changes saved locally',
    this.shadowCopies = const [],
    this.searchQuery = '',
  });

  DocumentActiveState copyWith({
    DocumentModel? document,
    String? filePath,
    Uint8List? salt,
    int? kdfId,
    bool? isDirty,
    bool? isSaving,
    String? statusText,
    List<ShadowModel>? shadowCopies,
    String? searchQuery,
  }) {
    return DocumentActiveState(
      document: document ?? this.document,
      filePath: filePath ?? this.filePath,
      salt: salt ?? this.salt,
      kdfId: kdfId ?? this.kdfId,
      isDirty: isDirty ?? this.isDirty,
      isSaving: isSaving ?? this.isSaving,
      statusText: statusText ?? this.statusText,
      shadowCopies: shadowCopies ?? this.shadowCopies,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class DocumentLockedState extends DocumentState {
  final String filePath;
  final Uint8List salt;
  final int kdfId;
  final String? errorMessage;

  DocumentLockedState({
    required this.filePath,
    required this.salt,
    required this.kdfId,
    this.errorMessage,
  });
}

class DocumentErrorState extends DocumentState {
  final String errorMessage;
  DocumentErrorState({required this.errorMessage});
}
