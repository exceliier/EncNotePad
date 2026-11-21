import 'dart:convert';
import 'dart:typed_data';
import 'document_model.dart';

class DocumentMapper {
  /// Converts DocumentModel to strictly encoded UTF-8 JSON bytes.
  static Uint8List toBytes(DocumentModel document) {
    final jsonMap = document.toJson();
    final jsonString = jsonEncode(jsonMap);
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  /// Parses UTF-8 JSON bytes into a DocumentModel.
  static DocumentModel fromBytes(Uint8List bytes) {
    final jsonString = utf8.decode(bytes);
    final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
    return DocumentModel.fromJson(jsonMap);
  }
}
