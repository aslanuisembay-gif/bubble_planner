import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../app_state.dart';
import '../planner_languages.dart';
import '../translations.dart';

class NotesSheet extends StatefulWidget {
  const NotesSheet({super.key});

  @override
  State<NotesSheet> createState() => _NotesSheetState();
}

String _notePreviewText(String raw) =>
    raw.replaceAll('[photo]', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

String _noteDisplayTitle(NoteItem note, String lang) {
  final title = note.title.trim();
  if (title.isNotEmpty) return title;
  return tr('notesUntitled', lang: lang);
}

class _NotesSheetState extends State<NotesSheet> {
  void _openEditor(NoteItem note) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NoteEditorSheet(noteId: note.id),
    );
  }

  Future<void> _createNewNote() async {
    final app = context.read<AppState>();
    final id = await app.createEmptyNote();
    if (!mounted) return;
    final created = app.notes.firstWhere(
      (e) => e.id == id,
      orElse: () => NoteItem(
        id: id,
        text: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    _openEditor(created);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.languageCode;
    final notes = [...app.notes]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121018),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                tr('notesTitle', lang: lang),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _createNewNote,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withValues(alpha: 0.06),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Create new note',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: notes.isEmpty
                ? Center(
                    child: Text(
                      tr('notesEmpty', lang: lang),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  )
                : ListView.separated(
                    itemCount: notes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final n = notes[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _openEditor(n),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.description_outlined,
                                color: Color(0xFF93C5FD),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _noteDisplayTitle(n, lang),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _notePreviewText(n.text).isEmpty
                                          ? tr('notesUntitled', lang: lang)
                                          : _notePreviewText(n.text),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.65),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => app.deleteNote(n.id),
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

enum _NoteInputMode { none, keyboard, voice }

class _NoteEditorSheet extends StatefulWidget {
  const _NoteEditorSheet({required this.noteId});
  final String noteId;

  @override
  State<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<_NoteEditorSheet> {
  static const _kPhotoMarker = '[photo]';

  final SpeechToText _speech = SpeechToText();
  final List<TextEditingController> _segmentControllers = [];
  final List<FocusNode> _segmentFocus = [];
  List<String> _localImages = [];
  Timer? _debounce;
  bool _inited = false;
  bool _listening = false;
  _NoteInputMode _mode = _NoteInputMode.none;
  String _inputLanguageCode = 'en';
  String? _voiceLocaleId;
  String _voiceBaseSegmentText = '';
  int _activeSegmentIndex = 0;
  late final TextEditingController _titleController;

  int _indexForFocusNode(FocusNode node) {
    for (var i = 0; i < _segmentFocus.length; i++) {
      if (identical(_segmentFocus[i], node)) return i;
    }
    return -1;
  }

  void _bindFocusTracking(FocusNode node) {
    node.addListener(() {
      if (!node.hasFocus || !mounted) return;
      final idx = _indexForFocusNode(node);
      if (idx >= 0) {
        setState(() => _activeSegmentIndex = idx);
      }
    });
  }

  void _closeEditor() {
    _flushToAppNow();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    _disposeSegments();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _NoteEditorSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noteId != widget.noteId) {
      _inited = false;
    }
  }

  void _disposeSegments() {
    for (final c in _segmentControllers) {
      c.removeListener(_scheduleFlush);
      c.dispose();
    }
    for (final f in _segmentFocus) {
      f.dispose();
    }
    _segmentControllers.clear();
    _segmentFocus.clear();
  }

  Uint8List _safeDecodeImage(String raw) {
    try {
      return base64Decode(raw);
    } catch (_) {
      return Uint8List(0);
    }
  }

  void _hydrateFromNote(NoteItem note) {
    _disposeSegments();
    var parts = note.text.split(_kPhotoMarker);
    if (parts.isEmpty) {
      parts = [''];
    }
    var imgs = List<String>.from(note.imagesBase64);
    while (parts.length < imgs.length + 1) {
      parts.add('');
    }
    if (parts.length > imgs.length + 1) {
      final mergeFrom = imgs.length;
      final tail = parts.sublist(mergeFrom).join(_kPhotoMarker);
      parts = [...parts.sublist(0, mergeFrom), tail];
    }
    while (imgs.length < parts.length - 1) {
      imgs.add('');
    }
    while (imgs.length > parts.length - 1) {
      imgs.removeLast();
    }
    _localImages = imgs;
    _titleController.text = note.title;

    for (var i = 0; i < parts.length; i++) {
      final c = TextEditingController(text: parts[i]);
      final fn = FocusNode();
      _bindFocusTracking(fn);
      c.addListener(_scheduleFlush);
      _segmentControllers.add(c);
      _segmentFocus.add(fn);
    }
    if (_segmentControllers.isEmpty) {
      final c = TextEditingController();
      final fn = FocusNode();
      _bindFocusTracking(fn);
      c.addListener(_scheduleFlush);
      _segmentControllers.add(c);
      _segmentFocus.add(fn);
    }
    _activeSegmentIndex = 0;
  }

  void _scheduleFlush() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 260), _flushToApp);
  }

  void _flushToApp() {
    if (!mounted) return;
    final text = _segmentControllers.map((c) => c.text).join(_kPhotoMarker);
    context.read<AppState>().updateNoteContent(
      widget.noteId,
      text: text,
      imagesBase64: List<String>.from(_localImages),
    );
  }

  void _flushToAppNow() {
    _debounce?.cancel();
    _flushToApp();
  }

  Future<void> _toggleVoice() async {
    if (_listening) {
      await _speech.stop();
      setState(() {
        _listening = false;
        _mode = _NoteInputMode.keyboard;
      });
      return;
    }
    final ok = await _speech.initialize();
    if (!ok || !mounted) return;
    final seg = _activeSegmentIndex.clamp(0, _segmentControllers.length - 1);
    setState(() {
      _mode = _NoteInputMode.voice;
      _listening = true;
      _voiceBaseSegmentText = _segmentControllers[seg].text.trim();
    });
    await _speech.listen(
      localeId: _voiceLocaleId,
      onResult: (r) {
        if (!mounted) return;
        final recognized = r.recognizedWords.trim();
        if (recognized.isEmpty) return;
        final joined = _voiceBaseSegmentText.isEmpty
            ? recognized
            : '$_voiceBaseSegmentText $recognized';
        final s = _activeSegmentIndex.clamp(0, _segmentControllers.length - 1);
        setState(() {
          _segmentControllers[s].text = joined;
          _segmentControllers[s].selection =
              TextSelection.collapsed(offset: _segmentControllers[s].text.length);
        });
        _flushToApp();
      },
    );
  }

  Future<void> _insertPhotoAtCursor() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await picker.pickImage(source: source, imageQuality: 80, maxWidth: 1800);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final b64 = base64Encode(bytes);

    final seg = _activeSegmentIndex.clamp(0, _segmentControllers.length - 1);
    final controller = _segmentControllers[seg];
    final text = controller.text;
    final sel = controller.selection;
    final start = sel.isValid ? sel.start.clamp(0, text.length) : text.length;
    final end = sel.isValid ? sel.end.clamp(0, text.length) : text.length;
    final left = text.substring(0, start);
    final right = text.substring(end);
    controller.text = left;
    controller.selection = TextSelection.collapsed(offset: left.length);

    _localImages.insert(seg, b64);
    final insertIdx = seg + 1;
    final rightController = TextEditingController(text: right);
    final rightFocus = FocusNode();
    rightController.addListener(_scheduleFlush);
    _bindFocusTracking(rightFocus);
    _segmentControllers.insert(insertIdx, rightController);
    _segmentFocus.insert(insertIdx, rightFocus);

    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      rightFocus.requestFocus();
      rightController.selection = const TextSelection.collapsed(offset: 0);
    });
    _flushToAppNow();
  }

  void _removeImageAt(int imageIndex) {
    if (imageIndex < 0 || imageIndex >= _localImages.length) return;
    if (imageIndex + 1 >= _segmentControllers.length) return;
    _localImages.removeAt(imageIndex);
    final left = _segmentControllers[imageIndex].text;
    final right = _segmentControllers[imageIndex + 1].text;
    _segmentControllers[imageIndex].text = left + right;
    _segmentControllers[imageIndex].selection =
        TextSelection.collapsed(offset: left.length);

    _segmentControllers[imageIndex + 1].removeListener(_scheduleFlush);
    _segmentControllers[imageIndex + 1].dispose();
    _segmentFocus[imageIndex + 1].dispose();
    _segmentControllers.removeAt(imageIndex + 1);
    _segmentFocus.removeAt(imageIndex + 1);

    if (_activeSegmentIndex > imageIndex + 1) {
      _activeSegmentIndex -= 1;
    } else if (_activeSegmentIndex == imageIndex + 1) {
      _activeSegmentIndex = imageIndex;
    }
    setState(() {});
    _flushToAppNow();
  }

  List<Widget> _buildEditorBlocks(String lang) {
    final out = <Widget>[];
    for (var i = 0; i < _segmentControllers.length; i++) {
      final imageSlot = i;
      out.add(
        TextField(
          controller: _segmentControllers[i],
          focusNode: _segmentFocus[i],
          autocorrect: true,
          enableSuggestions: true,
          smartDashesType: SmartDashesType.enabled,
          smartQuotesType: SmartQuotesType.enabled,
          readOnly: _listening,
          onTap: () {
            if (_mode != _NoteInputMode.keyboard) {
              setState(() => _mode = _NoteInputMode.keyboard);
            }
            setState(() => _activeSegmentIndex = i);
          },
          textAlignVertical: TextAlignVertical.top,
          minLines: 1,
          maxLines: null,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: i == 0 ? tr('notesTypeHere', lang: lang) : null,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
          ),
        ),
      );
      if (imageSlot < _localImages.length) {
        out.add(const SizedBox(height: 10));
        out.add(
          _NoteInlineImage(
            bytes: _safeDecodeImage(_localImages[imageSlot]),
            onRemove: () => _removeImageAt(imageSlot),
          ),
        );
        out.add(const SizedBox(height: 10));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.languageCode;
    final note = app.notes.firstWhere((e) => e.id == widget.noteId, orElse: () {
      return NoteItem(
        id: widget.noteId,
        text: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    if (!_inited) {
      _hydrateFromNote(note);
      _inited = true;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF151018),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    maxLines: 1,
                    autocorrect: true,
                    enableSuggestions: true,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: tr('notesUntitled', lang: lang),
                      hintStyle: const TextStyle(color: Colors.white54),
                    ),
                    onChanged: (value) {
                      context.read<AppState>().updateNoteMeta(
                            widget.noteId,
                            title: value,
                          );
                    },
                  ),
                ),
                IconButton(
                  onPressed: () => _closeEditor(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _mode == _NoteInputMode.none
                        ? tr('notesChooseInputHint', lang: lang)
                        : _mode == _NoteInputMode.voice
                            ? tr('notesListening', lang: lang)
                            : tr('typeYourTaskHint', lang: lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: SizedBox(
                width: 210,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _NoteMicButton(
                      isListening: _listening,
                      onTap: _toggleVoice,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      children: [
                        Material(
                          color: _mode == _NoteInputMode.keyboard
                              ? const Color(0xFF60A5FA).withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.08),
                          shape: const CircleBorder(),
                          child: IconButton(
                            onPressed: () {
                              setState(() {
                                _mode = _NoteInputMode.keyboard;
                                _listening = false;
                              });
                              _speech.stop();
                            },
                            icon: Icon(
                              Icons.keyboard_alt_outlined,
                              color: _mode == _NoteInputMode.keyboard
                                  ? const Color(0xFF60A5FA)
                                  : Colors.white70,
                            ),
                            tooltip: tr('type', lang: lang),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Material(
                          color: Colors.white.withValues(alpha: 0.08),
                          shape: const CircleBorder(),
                          child: IconButton(
                            onPressed: _insertPhotoAtCursor,
                            icon: const Icon(Icons.image_outlined, color: Colors.white),
                            tooltip: tr('notesAddPhoto', lang: lang),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  Text(
                    tr('notesInputLanguageLabel', lang: lang),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _inputLanguageCode,
                      isDense: true,
                      dropdownColor: const Color(0xFF221A28),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                      items: kPlannerLanguageCodes
                          .map(
                            (code) => DropdownMenuItem<String>(
                              value: code,
                              child: Text(
                                '${plannerLanguageNativeLabel(code)} ($code)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _inputLanguageCode = value;
                          _voiceLocaleId = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _buildEditorBlocks(lang),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.icon(
                onPressed: _closeEditor,
                icon: const Icon(Icons.save_rounded, size: 20),
                label: Text(
                  tr('save', lang: lang),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteInlineImage extends StatelessWidget {
  const _NoteInlineImage({
    required this.bytes,
    required this.onRemove,
  });

  final Uint8List bytes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: bytes.isEmpty
              ? Container(
                  width: double.infinity,
                  height: 180,
                  color: Colors.white12,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                  ),
                )
              : Image.memory(
                  bytes,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                ),
        ),
        Positioned(
          right: 6,
          top: 6,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, size: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _NoteMicButton extends StatelessWidget {
  const _NoteMicButton({
    required this.isListening,
    required this.onTap,
  });

  final bool isListening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const recordingAccent = Color(0xFFFF4F88);
    const idleAccent = Color(0xFF8B5CF6);
    final accent = isListening ? recordingAccent : idleAccent;
    final fillColor = isListening
        ? const Color(0xFF3B0E1E).withValues(alpha: 0.92)
        : Colors.black.withValues(alpha: 0.35);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 118,
          height: 118,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fillColor,
                border: Border.all(color: accent, width: 3.4),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: isListening ? 0.75 : 0.45),
                    blurRadius: isListening ? 30 : 24,
                    spreadRadius: isListening ? 2 : 1,
                  ),
                ],
              ),
              child: Icon(
                isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
                size: 52,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
