import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/document_model.dart';
import '../state/document_bloc.dart';
import '../state/document_event.dart';
import '../state/document_state.dart';
import 'widgets/change_password_dialog.dart';
import 'widgets/section_card.dart';
import 'widgets/status_footer.dart';
import '../../shadow_copies/ui/version_history_dialog.dart';

enum SearchResultType { section, part }

class SearchResultItem {
  final SearchResultType type;
  final String sectionId;
  final String sectionTitle;
  final String? partId;
  final String? partTitle;
  final String matchLocation;
  final String snippet;

  SearchResultItem({
    required this.type,
    required this.sectionId,
    required this.sectionTitle,
    this.partId,
    this.partTitle,
    required this.matchLocation,
    required this.snippet,
  });
}

List<SearchResultItem> computeSearchResults(DocumentModel doc, String query) {
  if (query.trim().isEmpty) return [];
  final q = query.trim().toLowerCase();
  final results = <SearchResultItem>[];

  for (final section in doc.sections) {
    final sTitle = section.title.trim().isEmpty ? 'Untitled Section' : section.title;

    // Section Title match
    if (sTitle.toLowerCase().contains(q)) {
      results.add(SearchResultItem(
        type: SearchResultType.section,
        sectionId: section.id,
        sectionTitle: sTitle,
        matchLocation: 'Section Title',
        snippet: sTitle,
      ));
    }

    // Check Parts in this Section
    for (final part in section.parts) {
      final pTitle = part.title.trim().isEmpty ? 'Untitled Part' : part.title;
      final titleMatched = pTitle.toLowerCase().contains(q);
      final bodyMatched = part.body.toLowerCase().contains(q);

      if (titleMatched) {
        results.add(SearchResultItem(
          type: SearchResultType.part,
          sectionId: section.id,
          sectionTitle: sTitle,
          partId: part.id,
          partTitle: pTitle,
          matchLocation: 'Part Title',
          snippet: pTitle,
        ));
      }

      if (bodyMatched) {
        final lower = part.body.toLowerCase();
        final idx = lower.indexOf(q);
        final start = (idx - 24).clamp(0, part.body.length);
        final end = (idx + q.length + 24).clamp(0, part.body.length);
        var snippet = part.body.substring(start, end).replaceAll('\n', ' ');
        if (start > 0) snippet = '...$snippet';
        if (end < part.body.length) snippet = '$snippet...';

        results.add(SearchResultItem(
          type: SearchResultType.part,
          sectionId: section.id,
          sectionTitle: sTitle,
          partId: part.id,
          partTitle: pTitle,
          matchLocation: 'Part Details',
          snippet: snippet,
        ));
      }
    }
  }

  return results;
}

class EditorScreen extends StatefulWidget {
  final DocumentActiveState state;

  const EditorScreen({super.key, required this.state});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isSearchOpen = false;
  String? _highlightedSectionId;
  String? _highlightedPartId;
  final Set<String> _forcedExpandedPartIds = {};
  Timer? _highlightTimer;

  final Map<String, GlobalKey> _sectionKeys = {};
  final Map<String, GlobalKey> _partKeys = {};

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _highlightTimer?.cancel();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchOpen = !_isSearchOpen;
      if (_isSearchOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _searchFocusNode.requestFocus();
        });
      } else {
        _searchController.clear();
      }
    });
  }

  List<SearchResultItem> _computeSearchResults(String query) =>
      computeSearchResults(widget.state.document, query);

  Future<void> _navigateToSelection(SearchResultItem result) async {
    final bloc = context.read<DocumentBloc>();

    // 1. Ensure the parent section is expanded
    bloc.add(EnsureSectionExpandedEvent(sectionId: result.sectionId));

    // 2. Unhide part details if navigating to a part
    if (result.type == SearchResultType.part && result.partId != null) {
      setState(() {
        _forcedExpandedPartIds.add(result.partId!);
        _highlightedPartId = result.partId;
        _highlightedSectionId = null;
      });
    } else {
      setState(() {
        _highlightedSectionId = result.sectionId;
        _highlightedPartId = null;
      });
    }

    // 3. Allow state to rebuild expanded section & unhide details, then smoothly scroll
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    final targetKey = (result.type == SearchResultType.part && result.partId != null)
        ? _partKeys[result.partId]
        : _sectionKeys[result.sectionId];

    if (targetKey?.currentContext != null) {
      Scrollable.ensureVisible(
        targetKey!.currentContext!,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
        alignment: 0.1,
      );
    } else {
      // Fallback scroll by estimating section position
      final secIndex = widget.state.document.sections.indexWhere((s) => s.id == result.sectionId);
      if (secIndex != -1 && _scrollController.hasClients) {
        final total = widget.state.document.sections.length;
        final targetOffset = (secIndex / total) * _scrollController.position.maxScrollExtent;
        await _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
        // Retry ensureVisible after scrolling closer
        if (targetKey?.currentContext != null) {
          Scrollable.ensureVisible(
            targetKey!.currentContext!,
            duration: const Duration(milliseconds: 200),
            alignment: 0.1,
          );
        }
      }
    }

    // Reset highlight after 3 seconds
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _highlightedSectionId = null;
          _highlightedPartId = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<DocumentBloc>();
    final sections = widget.state.document.sections;
    final allCollapsed = sections.isNotEmpty && sections.every((s) => s.isCollapsed);
    final searchResults = _computeSearchResults(_searchController.text);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          bloc.add(TriggerAutoSaveEvent());
        },
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          _toggleSearch();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_isSearchOpen) {
            _toggleSearch();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.state.filePath.split(RegExp(r'[/\\]')).last,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.save,
                  color: widget.state.isDirty ? Colors.amberAccent : Colors.white70,
                ),
                tooltip: widget.state.isDirty
                    ? 'Save Now (Ctrl+S) - Unsaved changes'
                    : 'All changes saved',
                onPressed: widget.state.isDirty && !widget.state.isSaving
                    ? () => bloc.add(TriggerAutoSaveEvent())
                    : null,
              ),
              IconButton(
                icon: Icon(
                  Icons.search,
                  color: _isSearchOpen ? Colors.lightBlueAccent : Colors.white70,
                ),
                tooltip: 'Search Sections & Parts (Ctrl+F)',
                onPressed: _toggleSearch,
              ),
              IconButton(
                icon: Icon(allCollapsed ? Icons.unfold_more : Icons.unfold_less),
                tooltip: allCollapsed ? 'Expand All Sections' : 'Collapse All Sections',
                onPressed: () {
                  if (allCollapsed) {
                    bloc.add(ExpandAllSectionsEvent());
                  } else {
                    bloc.add(CollapseAllSectionsEvent());
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add Section',
                onPressed: () => bloc.add(AddSectionEvent()),
              ),
              IconButton(
                icon: const Icon(Icons.password),
                tooltip: 'Change Master Password',
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => const ChangePasswordDialog(),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'Version History (Shadow Copies)',
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => VersionHistoryDialog(
                      shadows: widget.state.shadowCopies,
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
              // Search Panel
              if (_isSearchOpen)
                Container(
                  color: const Color(0xFF1E1E2C),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              decoration: InputDecoration(
                                prefixIcon:
                                    const Icon(Icons.search, color: Colors.lightBlueAccent, size: 20),
                                hintText:
                                    'Search sections, parts, notes... (Esc to close)',
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {});
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            tooltip: 'Close Search',
                            onPressed: _toggleSearch,
                          ),
                        ],
                      ),
                      // Results list
                      if (_searchController.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        if (searchResults.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'No matching sections or parts found.',
                              style: TextStyle(color: Colors.white60, fontSize: 13),
                            ),
                          )
                        else ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: Text(
                              'Results: ${searchResults.length} match${searchResults.length == 1 ? '' : 'es'} (select to navigate directly):',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.lightBlueAccent),
                            ),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 220),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF161622),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF38384E)),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: searchResults.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1, color: Color(0xFF282838)),
                                itemBuilder: (context, idx) {
                                  final item = searchResults[idx];
                                  final isSection = item.type == SearchResultType.section;

                                  return InkWell(
                                    onTap: () => _navigateToSelection(item),
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isSection
                                                ? Icons.folder_outlined
                                                : Icons.description_outlined,
                                            size: 18,
                                            color: isSection
                                                ? Colors.blueAccent
                                                : Colors.lightGreenAccent,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        isSection
                                                            ? item.sectionTitle
                                                            : item.partTitle!,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: isSection
                                                            ? Colors.blue.withAlpha(50)
                                                            : Colors.teal.withAlpha(50),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        item.matchLocation,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: isSection
                                                              ? Colors.lightBlueAccent
                                                              : Colors.tealAccent,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  isSection
                                                      ? 'Section match'
                                                      : 'In Section: ${item.sectionTitle} • ${item.snippet}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.white70,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.arrow_forward_ios,
                                              size: 12, color: Colors.white38),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              // Document Sections List
              Expanded(
                child: sections.isEmpty
                    ? Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add First Section'),
                          onPressed: () => bloc.add(AddSectionEvent()),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        cacheExtent: 20000,
                        itemCount: sections.length,
                        itemBuilder: (context, index) {
                          final section = sections[index];
                          final sKey =
                              _sectionKeys.putIfAbsent(section.id, () => GlobalKey());

                          return SectionCard(
                            key: sKey,
                            section: section,
                            index: index,
                            totalSections: sections.length,
                            isHighlighted: _highlightedSectionId == section.id,
                            highlightedPartId: _highlightedPartId,
                            forcedExpandedPartIds: _forcedExpandedPartIds,
                            partKeys: _partKeys,
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
                            onAddPart: () {
                              bloc.add(AddPartEvent(sectionId: section.id));
                            },
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
                statusText: widget.state.statusText,
                sectionCount: sections.length,
                shadowCount: widget.state.shadowCopies.length,
                isSaving: widget.state.isSaving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
