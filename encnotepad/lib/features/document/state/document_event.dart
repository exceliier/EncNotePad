import '../../shadow_copies/domain/shadow_model.dart';

abstract class DocumentEvent {}

class CreateNewDocumentEvent extends DocumentEvent {
  final String filePath;
  final String password;
  CreateNewDocumentEvent({required this.filePath, required this.password});
}

class OpenDocumentEvent extends DocumentEvent {
  final String filePath;
  final String password;
  OpenDocumentEvent({required this.filePath, required this.password});
}

class AddSectionEvent extends DocumentEvent {
  final String? title;
  AddSectionEvent({this.title});
}

class UpdateSectionTitleEvent extends DocumentEvent {
  final String sectionId;
  final String title;
  UpdateSectionTitleEvent({required this.sectionId, required this.title});
}

class DeleteSectionEvent extends DocumentEvent {
  final String sectionId;
  DeleteSectionEvent({required this.sectionId});
}

class ReorderSectionEvent extends DocumentEvent {
  final int oldIndex;
  final int newIndex;
  ReorderSectionEvent({required this.oldIndex, required this.newIndex});
}

class ToggleSectionCollapseEvent extends DocumentEvent {
  final String sectionId;
  ToggleSectionCollapseEvent({required this.sectionId});
}

class AddPartEvent extends DocumentEvent {
  final String sectionId;
  final String? title;
  AddPartEvent({required this.sectionId, this.title});
}

class DeletePartEvent extends DocumentEvent {
  final String sectionId;
  final String partId;
  DeletePartEvent({required this.sectionId, required this.partId});
}

class UpdatePartEvent extends DocumentEvent {
  final String sectionId;
  final String partId;
  final String? title;
  final String? body;
  UpdatePartEvent({
    required this.sectionId,
    required this.partId,
    this.title,
    this.body,
  });
}

class ReorderPartEvent extends DocumentEvent {
  final String sectionId;
  final int oldIndex;
  final int newIndex;
  ReorderPartEvent({
    required this.sectionId,
    required this.oldIndex,
    required this.newIndex,
  });
}

class TriggerAutoSaveEvent extends DocumentEvent {}

class CreateManualShadowEvent extends DocumentEvent {}

class RestoreShadowEvent extends DocumentEvent {
  final ShadowModel shadow;
  RestoreShadowEvent({required this.shadow});
}

class CloseDocumentEvent extends DocumentEvent {}

class LockDocumentEvent extends DocumentEvent {}

class UnlockDocumentEvent extends DocumentEvent {
  final String password;
  UnlockDocumentEvent({required this.password});
}
