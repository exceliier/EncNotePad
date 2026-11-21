import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../state/document_bloc.dart';
import '../state/document_event.dart';
import '../state/document_state.dart';
import 'widgets/section_card.dart';
import 'widgets/status_footer.dart';
import '../../shadow_copies/ui/version_history_dialog.dart';

class EditorScreen extends StatelessWidget {
  final DocumentActiveState state;

  const EditorScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<DocumentBloc>();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          bloc.add(TriggerAutoSaveEvent());
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
      appBar: AppBar(
        title: Text(
          state.filePath.split(RegExp(r'[/\\]')).last,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.save,
              color: state.isDirty ? Colors.amberAccent : Colors.white70,
            ),
            tooltip: state.isDirty ? 'Save Now (Ctrl+S) - Unsaved changes' : 'All changes saved',
            onPressed: state.isDirty && !state.isSaving
                ? () => bloc.add(TriggerAutoSaveEvent())
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Section',
            onPressed: () => bloc.add(AddSectionEvent()),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Version History (Shadow Copies)',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => VersionHistoryDialog(
                  shadows: state.shadowCopies,
                  onRestore: (shadow) => bloc.add(RestoreShadowEvent(shadow: shadow)),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_add),
            tooltip: 'Create Shadow Snapshot Now',
            onPressed: () => bloc.add(CreateManualShadowEvent()),
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline),
            tooltip: 'Lock Document',
            onPressed: () => bloc.add(LockDocumentEvent()),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close Document',
            onPressed: () => bloc.add(CloseDocumentEvent()),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: state.document.sections.isEmpty
                ? Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add First Section'),
                      onPressed: () => bloc.add(AddSectionEvent()),
                    ),
                  )
                : ListView.builder(
                    itemCount: state.document.sections.length,
                    itemBuilder: (context, index) {
                      final section = state.document.sections[index];
                      return SectionCard(
                        key: ValueKey(section.id),
                        section: section,
                        index: index,
                        totalSections: state.document.sections.length,
                        onTitleChanged: (title) {
                          bloc.add(UpdateSectionTitleEvent(
                            sectionId: section.id,
                            title: title,
                          ));
                        },
                        onToggleCollapse: () =>
                            bloc.add(ToggleSectionCollapseEvent(sectionId: section.id)),
                        onDelete: () =>
                            bloc.add(DeleteSectionEvent(sectionId: section.id)),
                        onReorder: (oldIdx, newIdx) =>
                            bloc.add(ReorderSectionEvent(oldIndex: oldIdx, newIndex: newIdx)),
                        onAddPart: () =>
                            bloc.add(AddPartEvent(sectionId: section.id)),
                        onUpdatePart: (partId, title, body) => bloc.add(UpdatePartEvent(
                          sectionId: section.id,
                          partId: partId,
                          title: title,
                          body: body,
                        )),
                        onDeletePart: (partId) => bloc.add(DeletePartEvent(
                          sectionId: section.id,
                          partId: partId,
                        )),
                        onReorderPart: (oldIdx, newIdx) => bloc.add(ReorderPartEvent(
                          sectionId: section.id,
                          oldIndex: oldIdx,
                          newIndex: newIdx,
                        )),
                      );
                    },
                  ),
          ),
          StatusFooter(
            statusText: state.statusText,
            sectionCount: state.document.sections.length,
            shadowCount: state.shadowCopies.length,
            isSaving: state.isSaving,
          ),
        ],
      ),
    ),
  ),
);
  }
}
